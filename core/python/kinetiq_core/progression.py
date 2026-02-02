from __future__ import annotations

from .models import Unit
from .units import to_kg


def jump_from_rpe_lb(rpe: float) -> float:
    """
    Piecewise jump rule (in pounds):

    RPE 1–3   -> 10 to 5 lb increase
    RPE 4–7   -> 5 to 2.5 lb increase
    RPE 7–9   -> 2.5 to 0.5 lb increase
    RPE 9–10  -> 0.5 to 0 lb increase

    Returned value is continuous and can be rounded by the caller.
    """
    rpe = max(1.0, min(10.0, rpe))

    if rpe <= 3.0:
        # 1 -> 10, 3 -> 5
        # linear: y = 12.5 - 2.5*rpe
        return 12.5 - 2.5 * rpe

    if rpe <= 7.0:
        # 4 -> 5, 7 -> 2.5
        # slope = (2.5-5)/(7-4) = -0.833333...
        return 5.0 + (rpe - 4.0) * (-2.5 / 3.0)

    if rpe <= 9.0:
        # 7 -> 2.5, 9 -> 0.5
        # slope = (0.5-2.5)/(9-7) = -1
        return 2.5 + (rpe - 7.0) * (-1.0)

    # 9 -> 0.5, 10 -> 0
    return max(0.0, 0.5 * (10.0 - rpe))


def jump_from_rpe(rpe: float, unit: Unit) -> float:
    """
    Same rule, returned in the user's unit.
    If user unit is KG, converts the lb jump to kg.
    """
    jump_lb = jump_from_rpe_lb(rpe)
    if unit == Unit.KG:
        return to_kg(jump_lb, Unit.LB)
    return jump_lb
