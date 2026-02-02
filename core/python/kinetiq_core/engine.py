from __future__ import annotations

from .models import SetLog, ExerciseConfig, UserSettings, Suggestion
from .rpe_rules import suggest_next_set_from_rpe


def suggest_next_set(
    exercise: ExerciseConfig,
    last_set: SetLog,
    settings: UserSettings,
    debug: bool = False
) -> Suggestion:
    """
    High-level entrypoint: your app calls this after the user logs a set and RPE.
    """
    return suggest_next_set_from_rpe(last_set=last_set, cfg=exercise, settings=settings, debug=debug)
