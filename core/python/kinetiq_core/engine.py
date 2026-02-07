from __future__ import annotations

from typing import List, Optional

from .models import ExerciseConfig, SetLog, UserSettings, Suggestion
from .rpe_rules import suggest_next_set_from_rpe


def suggest_next_set(
    exercise: ExerciseConfig,
    last_set: SetLog,
    settings: UserSettings,
    debug: bool = False,
    *,
    use_ml: bool = False,
    ml_state: Optional["MLState"] = None,
    user_id: str = "default",
    history: Optional[List[SetLog]] = None,
) -> Suggestion:
    """
    Main entry point.

    If use_ml=True and ml_state/history provided, uses ML policy.
    Otherwise falls back to rule-based policy.
    """
    if use_ml and ml_state is not None and history is not None:
        from .ml.policy import suggest_next_set_ml
        return suggest_next_set_ml(
            state=ml_state,
            user_id=user_id,
            exercise=exercise,
            last_set=last_set,
            settings=settings,
            history=history,
            debug=debug,
        )

    return suggest_next_set_from_rpe(last_set, exercise, settings, debug=debug)
