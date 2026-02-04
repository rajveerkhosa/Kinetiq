from __future__ import annotations

from typing import Dict, Optional, Tuple

from .models import ExerciseConfig, UserSettings, Unit


def _is_lower_body_heavy(exercise_name: str) -> bool:
    name = exercise_name.lower()
    return ("deadlift" in name) or ("dead" in name) or ("squat" in name)


def default_increment_for_exercise(settings: UserSettings, exercise_name: str) -> float:
    """
    Defaults:
    - Squat / Deadlift: 5 lb (or ~2.5 kg)
    - Everything else: 2.5 lb (or ~1.25 kg)
    Returned in the user's unit (lb/kg).
    """
    heavy = _is_lower_body_heavy(exercise_name)

    if settings.unit == Unit.LB:
        return 5.0 if heavy else 2.5

    # KG equivalents
    return 2.5 if heavy else 1.25


def default_max_jump_for_exercise(settings: UserSettings, exercise_name: str) -> float:
    """
    Defaults:
    - Squat / Deadlift: larger allowed jumps
      * LB: 15
      * KG: ~7.5
    - Everything else:
      * LB: 10
      * KG: ~5
    Returned in the user's unit (lb/kg).
    """
    heavy = _is_lower_body_heavy(exercise_name)

    if settings.unit == Unit.LB:
        return 15.0 if heavy else 10.0

    return 7.5 if heavy else 5.0


def make_exercise(
    name: str,
    rep_range: Tuple[int, int],
    target_rpe_range: Tuple[float, float] = (7.0, 9.0),
    settings: Optional[UserSettings] = None,
) -> ExerciseConfig:
    """
    Create an ExerciseConfig with sensible defaults for:
    - increment (per exercise)
    - max jump (per exercise)
    """
    settings = settings or UserSettings(unit=Unit.LB)

    inc = default_increment_for_exercise(settings, name)
    max_jump = default_max_jump_for_exercise(settings, name)

    return ExerciseConfig(
        name=name,
        rep_range=rep_range,
        target_rpe_range=target_rpe_range,
        weight_increment_override=inc,  # stored in user's unit
        max_jump_override=max_jump,     # stored in user's unit
        reps_step=1,
    )


def common_presets(settings: Optional[UserSettings] = None) -> Dict[str, ExerciseConfig]:
    """
    A starter set of presets (you can expand later).
    """
    settings = settings or UserSettings(unit=Unit.LB)

    return {
        "bench_press": make_exercise("bench_press", (5, 8), settings=settings),
        "overhead_press": make_exercise("overhead_press", (5, 8), settings=settings),
        "barbell_row": make_exercise("barbell_row", (6, 10), settings=settings),
        "squat": make_exercise("squat", (5, 8), settings=settings),
        "deadlift": make_exercise("deadlift", (3, 6), settings=settings),
    }
