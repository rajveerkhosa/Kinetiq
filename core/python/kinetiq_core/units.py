from __future__ import annotations

from .models import Unit, UserSettings

LB_PER_KG = 2.2046226218


def to_kg(weight: float, unit: Unit) -> float:
    return weight / LB_PER_KG if unit == Unit.LB else weight


def from_kg(weight_kg: float, unit: Unit) -> float:
    return weight_kg * LB_PER_KG if unit == Unit.LB else weight_kg


def round_to_increment(x: float, inc: float) -> float:
    inc = max(1e-9, inc)
    return round(x / inc) * inc


def clamp_int(x: int, lo: int, hi: int) -> int:
    return max(lo, min(hi, x))


def increment_in_kg(settings: UserSettings, override: float | None = None) -> float:
    """
    Returns increment expressed in kg, regardless of user's chosen display unit.
    override is expressed in the user's unit (lb or kg).
    """
    if override is not None:
        return to_kg(override, settings.unit)

    if settings.unit == Unit.LB:
        return to_kg(settings.lb_increment, Unit.LB)
    return settings.kg_increment


def max_jump_in_kg(settings: UserSettings, override: float | None = None) -> float:
    """
    Returns max jump expressed in kg, regardless of user's chosen display unit.
    override is expressed in the user's unit (lb or kg).
    """
    if override is not None:
        return to_kg(override, settings.unit)

    if settings.unit == Unit.LB:
        return to_kg(settings.max_jump_lb, Unit.LB)
    return settings.max_jump_kg


def normalize_display_weight(weight: float, unit: Unit) -> float:
    """
    Just for display niceness (avoid 184.999999).
    Does not affect internal logic.
    """
    if unit == Unit.LB:
        # show to nearest 0.5 lb (common)
        return round(weight * 2) / 2
    # show to nearest 0.25 kg (common)
    return round(weight * 4) / 4
