from __future__ import annotations

from dataclasses import replace
from typing import List, Optional

from .models import SetLog, SetLogWithTs, ExerciseConfig, UserSettings, Suggestion
from .rpe_rules import suggest_next_set_from_rpe
from .presets import adaptation_rate_for_exercise

# Optional ML
try:
    from .ml.policy import suggest_next_set_ml
    from .ml.state import MLState
except Exception:
    suggest_next_set_ml = None
    MLState = None


def suggest_next_set(
    exercise: ExerciseConfig,
    last_set: SetLog,
    settings: UserSettings,
    debug: bool = False,
    use_ml: bool = False,
    ml_state: Optional["MLState"] = None,
    user_id: str = "default",
    history: Optional[List[SetLog]] = None,
) -> Suggestion:
    """
    Central entrypoint.

    - If use_ml=True and ML is available -> ML policy (still should be guardrailed).
    - Else -> deterministic rpe_rules (Jeff-style B uses history to detect RPE drops).
    - Always attaches plateau_info and rpe_reliability to the returned Suggestion.
    """
    if use_ml and suggest_next_set_ml is not None and ml_state is not None:
        base = suggest_next_set_ml(
            state=ml_state,
            user_id=user_id,
            exercise=exercise,
            last_set=last_set,
            settings=settings,
            history=history or [],
            debug=debug,
        )
    else:
        # ✅ pass history into rules
        base = suggest_next_set_from_rpe(
            last_set=last_set,
            cfg=exercise,
            settings=settings,
            debug=debug,
            history=history or [],
        )

    # ── Plateau detection ──────────────────────────────────────────────────────
    plateau_info = None
    if history and len(history) >= 6:
        try:
            from .ml.plateau import detect_plateau
            rate = adaptation_rate_for_exercise(exercise.name)
            ts_history = [SetLogWithTs(s.weight, s.reps, s.rpe) for s in history]
            plateau_info = detect_plateau(ts_history, adaptation_rate=rate)
        except Exception:
            pass  # never let plateau detection break the main suggestion path

    # ── RPE reliability ────────────────────────────────────────────────────────
    rpe_reliability = None
    if ml_state is not None:
        try:
            from .ml.rpe_reliability import compute_rpe_reliability
            calib_map = getattr(ml_state, "calibration_by_ex", {})
            if exercise.name in calib_map:
                rpe_reliability = compute_rpe_reliability(calib_map[exercise.name])
        except Exception:
            pass  # never break the main path

    return replace(base, plateau_info=plateau_info, rpe_reliability=rpe_reliability)
