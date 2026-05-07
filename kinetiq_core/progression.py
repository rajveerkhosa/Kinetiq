from __future__ import annotations

from .models import Unit
from .units import to_kg


def jump_from_rpe_lb(rpe: float) -> float:
    """
    Weight jump rule (in pounds) scaled to realistic gym increments.

    Output range: 5–15 lb

    - RPE 1–3  : 15 -> 10
    - RPE 4–7  : 10 -> 5
    - RPE 7–10 : 5 (flat)

    NOTE: This function only applies when the engine has decided to "add_weight".
    """
    rpe = max(1.0, min(10.0, rpe))

    # RPE 1 -> 15, RPE 3 -> 10
    if rpe <= 3.0:
        # linear slope: (10-15)/(3-1) = -2.5
        return 17.5 - 2.5 * rpe

    # RPE 4 -> 10, RPE 7 -> 5
    if rpe <= 7.0:
        # slope: (5-10)/(7-4) = -5/3
        return 10.0 + (rpe - 4.0) * (-5.0 / 3.0)

    # RPE 7–10 stays at 5
    return 5.0


def jump_from_rpe(rpe: float, unit: Unit) -> float:
    """
    Same rule, returned in the user's unit.
    If unit is KG, converts the lb jump to kg.
    """
    jump_lb = jump_from_rpe_lb(rpe)
    return to_kg(jump_lb, Unit.LB) if unit == Unit.KG else jump_lb


def rep_delta_from_rpe(rpe: float) -> int:
    """
    Dynamic rep change based on RPE (1–10).

    Returns: +3, +2, +1, 0, or -1 reps.
    Caller must clamp suggested reps into the working rep range.
    """
    rpe = max(1.0, min(10.0, rpe))

    if rpe <= 3.0:
        return 3
    if rpe <= 6.0:
        return 2
    if rpe <= 8.0:
        return 1
    if rpe <= 9.0:
        return 0
    return -1
