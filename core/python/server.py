"""
Kinetiq ML API Server
---------------------
FastAPI wrapper around kinetiq_core.

Run:
    pip install -e ".[server]"
    uvicorn server:app --reload --port 8000

Endpoints:
    POST /suggest  -> Suggestion JSON
    GET  /health   -> {"status": "ok"}
"""
from __future__ import annotations

import json
import os
from contextlib import asynccontextmanager
from dataclasses import asdict
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import BackgroundTasks, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from kinetiq_core import suggest_next_set
from kinetiq_core.models import (
    ExerciseConfig,
    FitnessGoal,
    SetLog,
    Suggestion,
    Unit,
    UserSettings,
)
from kinetiq_core.ml.state import MLState
from kinetiq_core.ml.calibration import RPECalibration
from kinetiq_core.ml.online_models import OnlineLinearRegressor, OnlineLogisticRegressor
from kinetiq_core.ml.bandit import LinUCBBandit
from kinetiq_core.ml.embeddings import EmbeddingTable
from kinetiq_core.ml.bayesian_rpe import BayesianRPEPredictor
from kinetiq_core.ml.user_clustering import UserClustering

# ── Persistence directory ──────────────────────────────────────────────────────
DATA_DIR = Path(__file__).parent / "data"
DATA_DIR.mkdir(exist_ok=True)


# ── MLState serialization ──────────────────────────────────────────────────────

def _serialize_ml_state(state: MLState) -> Dict[str, Any]:
    return {
        "rpe_model": state.rpe_model.to_dict(),
        "readiness_model": state.readiness_model.to_dict(),
        "bandit": {
            "dim": state.bandit.dim,
            "alpha": state.bandit.alpha,
            "Ainv": state.bandit.Ainv,
            "b": state.bandit.b,
            "action_history": state.bandit.action_history,
        },
        "calibration_by_ex": {
            k: {"n": v.n, "bias": v.bias, "m2": v.m2}
            for k, v in state.calibration_by_ex.items()
        },
        "user_embed": {
            "dim": state.user_embed.dim,
            "lr": state.user_embed.lr,
            "table": state.user_embed.table,
        },
        "ex_embed": {
            "dim": state.ex_embed.dim,
            "lr": state.ex_embed.lr,
            "table": state.ex_embed.table,
        },
        "bayesian_rpe": state.bayesian_rpe.to_dict(),
        "user_clustering": state.user_clustering.to_dict(),
    }


def _deserialize_ml_state(d: Dict[str, Any]) -> MLState:
    rpe_model = OnlineLinearRegressor.from_dict(d["rpe_model"])
    readiness_model = OnlineLogisticRegressor.from_dict(d["readiness_model"])

    bandit_d = d["bandit"]
    bandit = LinUCBBandit(dim=bandit_d["dim"], alpha=bandit_d["alpha"])
    bandit.Ainv = bandit_d["Ainv"]
    bandit.b = bandit_d["b"]
    bandit.action_history = bandit_d.get("action_history", {})

    calibration_by_ex = {
        k: RPECalibration(n=v["n"], bias=v["bias"], m2=v["m2"])
        for k, v in d.get("calibration_by_ex", {}).items()
    }

    ue_d = d["user_embed"]
    user_embed = EmbeddingTable(dim=ue_d["dim"], lr=ue_d["lr"], table=ue_d["table"])

    ee_d = d["ex_embed"]
    ex_embed = EmbeddingTable(dim=ee_d["dim"], lr=ee_d["lr"], table=ee_d["table"])

    # New models — defensive fallback for old JSON files that predate these fields
    if "bayesian_rpe" in d:
        bayesian_rpe = BayesianRPEPredictor.from_dict(d["bayesian_rpe"])
    else:
        bayesian_rpe = BayesianRPEPredictor(dim=16)

    if "user_clustering" in d:
        user_clustering = UserClustering.from_dict(d["user_clustering"])
    else:
        user_clustering = UserClustering()

    return MLState(
        rpe_model=rpe_model,
        readiness_model=readiness_model,
        bandit=bandit,
        calibration_by_ex=calibration_by_ex,
        user_embed=user_embed,
        ex_embed=ex_embed,
        bayesian_rpe=bayesian_rpe,
        user_clustering=user_clustering,
    )


def _state_path(user_id: str) -> Path:
    return DATA_DIR / f"ml_state_{user_id}.json"


def _save_ml_state(user_id: str, state: MLState) -> None:
    try:
        with _state_path(user_id).open("w") as f:
            json.dump(_serialize_ml_state(state), f)
    except Exception as e:
        print(f"[warn] Failed to save MLState for {user_id}: {e}")


def _load_ml_state(user_id: str) -> Optional[MLState]:
    path = _state_path(user_id)
    if not path.exists():
        return None
    try:
        with path.open() as f:
            return _deserialize_ml_state(json.load(f))
    except Exception as e:
        print(f"[warn] Failed to load MLState for {user_id}: {e}")
        return None


# ── In-memory state store ──────────────────────────────────────────────────────
_ml_states: Dict[str, MLState] = {}


# ── App lifespan ───────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load persisted states on startup
    for path in DATA_DIR.glob("ml_state_*.json"):
        user_id = path.stem.replace("ml_state_", "")
        state = _load_ml_state(user_id)
        if state is not None:
            _ml_states[user_id] = state
            print(f"[startup] Loaded MLState for user '{user_id}'")
    yield
    # Save all states on shutdown
    for user_id, state in _ml_states.items():
        _save_ml_state(user_id, state)
        print(f"[shutdown] Saved MLState for user '{user_id}'")


# ── FastAPI app ────────────────────────────────────────────────────────────────
app = FastAPI(title="Kinetiq ML API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Pydantic request / response models ────────────────────────────────────────

class SetLogIn(BaseModel):
    weight: float
    reps: int
    rpe: float
    ts: Optional[str] = None


class ExerciseConfigIn(BaseModel):
    name: str
    rep_range: List[int]
    target_rpe_range: List[float] = [7.0, 9.0]
    weight_increment_override: Optional[float] = None
    max_jump_override: Optional[float] = None
    reps_step: int = 1


class SettingsIn(BaseModel):
    unit: str = "lb"
    lb_increment: float = 2.5
    kg_increment: float = 1.25
    max_jump_lb: float = 10.0
    max_jump_kg: float = 5.0
    goal: str = "both"


class SuggestRequest(BaseModel):
    user_id: str = "default"
    exercise: ExerciseConfigIn
    settings: SettingsIn
    last_set: SetLogIn
    history: List[SetLogIn] = []
    use_ml: bool = True
    debug: bool = False


class PlateauInfoOut(BaseModel):
    is_plateau: bool
    weeks_at_same_weight: int
    rpe_trend: float
    recommendation: str
    explanation: str


class RPEReliabilityOut(BaseModel):
    score: float
    variance: float
    n_observations: int
    weight_in_decisions: float


class SuggestionOut(BaseModel):
    action: str
    next_weight: float
    next_reps: int
    unit: str
    explanation: str
    plateau_info: Optional[PlateauInfoOut] = None
    rpe_reliability: Optional[RPEReliabilityOut] = None


# ── Helper: map request → kinetiq_core types ──────────────────────────────────

def _build_exercise(req_ex: ExerciseConfigIn) -> ExerciseConfig:
    return ExerciseConfig(
        name=req_ex.name,
        rep_range=(req_ex.rep_range[0], req_ex.rep_range[1]),
        target_rpe_range=(req_ex.target_rpe_range[0], req_ex.target_rpe_range[1]),
        weight_increment_override=req_ex.weight_increment_override,
        max_jump_override=req_ex.max_jump_override,
        reps_step=req_ex.reps_step,
    )


def _build_settings(req_s: SettingsIn) -> UserSettings:
    goal_map = {
        "strength": FitnessGoal.STRENGTH,
        "hypertrophy": FitnessGoal.HYPERTROPHY,
        "both": FitnessGoal.BOTH,
    }
    return UserSettings(
        unit=Unit(req_s.unit),
        lb_increment=req_s.lb_increment,
        kg_increment=req_s.kg_increment,
        max_jump_lb=req_s.max_jump_lb,
        max_jump_kg=req_s.max_jump_kg,
        goal=goal_map.get(req_s.goal.lower(), FitnessGoal.BOTH),
    )


def _suggestion_to_out(s: Suggestion) -> SuggestionOut:
    plateau = None
    if s.plateau_info is not None:
        p = s.plateau_info
        plateau = PlateauInfoOut(
            is_plateau=p.is_plateau,
            weeks_at_same_weight=p.weeks_at_same_weight,
            rpe_trend=p.rpe_trend,
            recommendation=p.recommendation,
            explanation=p.explanation,
        )
    reliability = None
    if s.rpe_reliability is not None:
        r = s.rpe_reliability
        reliability = RPEReliabilityOut(
            score=r.score,
            variance=r.variance,
            n_observations=r.n_observations,
            weight_in_decisions=r.weight_in_decisions,
        )
    return SuggestionOut(
        action=s.action,
        next_weight=s.next_weight,
        next_reps=s.next_reps,
        unit=s.unit.value,
        explanation=s.explanation,
        plateau_info=plateau,
        rpe_reliability=reliability,
    )


# ── Endpoints ──────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "version": "0.1.0"}


@app.post("/suggest", response_model=SuggestionOut)
async def suggest(req: SuggestRequest, background_tasks: BackgroundTasks):
    # Get or create MLState for this user
    state = _ml_states.get(req.user_id)
    if state is None:
        state = MLState()
        _ml_states[req.user_id] = state

    exercise = _build_exercise(req.exercise)
    settings = _build_settings(req.settings)
    last_set = SetLog(weight=req.last_set.weight, reps=req.last_set.reps, rpe=req.last_set.rpe)
    history = [SetLog(weight=s.weight, reps=s.reps, rpe=s.rpe) for s in req.history]

    suggestion = suggest_next_set(
        exercise=exercise,
        last_set=last_set,
        settings=settings,
        debug=req.debug,
        use_ml=req.use_ml,
        ml_state=state,
        user_id=req.user_id,
        history=history,
    )

    # Persist state asynchronously so the response isn't blocked
    background_tasks.add_task(_save_ml_state, req.user_id, state)

    return _suggestion_to_out(suggestion)
