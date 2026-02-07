from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

from ..models import SetLog, ExerciseConfig, UserSettings
from .state import MLState


def clip(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


@dataclass
class HistorySummary:
    # simple rolling summary (can evolve later)
    last_rpe: float = 8.0
    avg_rpe_3: float = 8.0
    rpe_trend_3: float = 0.0  # last - first over last 3
    sessions_since: float = 1.0


def summarize_history(history: List[SetLog]) -> HistorySummary:
    if not history:
        return HistorySummary()
    last = history[-1].rpe
    recent = history[-3:] if len(history) >= 3 else history
    avg = sum(s.rpe for s in recent) / len(recent)
    trend = (recent[-1].rpe - recent[0].rpe) if len(recent) >= 2 else 0.0
    return HistorySummary(last_rpe=last, avg_rpe_3=avg, rpe_trend_3=trend, sessions_since=1.0)


def make_feature_vector(
    state: MLState,
    user_id: str,
    exercise: ExerciseConfig,
    settings: UserSettings,
    proposed_weight: float,
    proposed_reps: int,
    history: List[SetLog],
) -> List[float]:
    """
    Fixed-length vector (dim=16) combining:
    - proposed set properties
    - rep range
    - recent history stats
    - user + exercise embeddings (4 + 4)
    """
    rep_min, rep_max = exercise.rep_range
    h = summarize_history(history)

    # embeddings (8 dims total)
    u = state.user_embed.get(user_id)               # 4
    e = state.ex_embed.get(exercise.name)           # 4

    # normalized scalars
    w = proposed_weight / 500.0                     # assume <=500lb typical (safe scaling)
    r = proposed_reps / 30.0                        # assume <=30 reps typical
    rr_min = rep_min / 30.0
    rr_max = rep_max / 30.0

    last_rpe = h.last_rpe / 10.0
    avg_rpe = h.avg_rpe_3 / 10.0
    trend = clip(h.rpe_trend_3 / 10.0, -1.0, 1.0)

    # unit (lb=0, kg=1)
    unit_flag = 1.0 if settings.unit.value == "kg" else 0.0

    x = [
        w, r,
        rr_min, rr_max,
        last_rpe, avg_rpe,
        trend,
        unit_flag,
        u[0], u[1], u[2], u[3],
        e[0], e[1], e[2], e[3],
    ]
    return x
