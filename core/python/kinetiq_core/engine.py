from __future__ import annotations

from typing import List, Optional

from .models import SetLog, ExerciseConfig, UserSettings, Suggestion
from .rpe_rules import suggest_next_set_from_rpe

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
    """
    if use_ml and suggest_next_set_ml is not None and ml_state is not None:
        return suggest_next_set_ml(
            state=ml_state,
            user_id=user_id,
            exercise=exercise,
            last_set=last_set,
            settings=settings,
            history=history or [],
            debug=debug,
        )

    # ✅ pass history into rules
    return suggest_next_set_from_rpe(
        last_set=last_set,
        cfg=exercise,
        settings=settings,
        debug=debug,
        history=history or [],
    )
