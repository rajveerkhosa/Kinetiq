from __future__ import annotations

from .models import SetLog, ExerciseConfig, UserSettings, Suggestion, Action
from .units import (
    to_kg, from_kg, round_to_increment, clamp_int,
    increment_in_kg, max_jump_in_kg, normalize_display_weight
)
from .progression import jump_from_rpe, rep_delta_from_rpe


def validate_inputs(last_set: SetLog, cfg: ExerciseConfig) -> None:
    rep_min, rep_max = cfg.rep_range
    if rep_min < 1 or rep_max < rep_min:
        raise ValueError(f"Invalid rep_range {cfg.rep_range}")
    if not (1.0 <= last_set.rpe <= 10.0):
        raise ValueError(f"RPE must be between 1 and 10. Got {last_set.rpe}")
    if last_set.reps < 1:
        raise ValueError("reps must be >= 1")
    if last_set.weight <= 0:
        raise ValueError("weight must be > 0")


def _dynamic_weight_increase_kg(
    rpe: float,
    settings: UserSettings,
    inc_kg: float,
    max_jump_kg: float
) -> float:
    """
    Compute weight increase amount in kg based on RPE,
    respecting:
      - minimum realistic delta (>= 5 lb or >= 2.5 kg)
      - minimum rounding increment
      - max jump cap
    """
    # Minimum realistic "total weight" increase (gym plates)
    min_delta_user = 5.0 if settings.unit.value == "lb" else 2.5  # lb or kg
    min_delta_kg = to_kg(min_delta_user, settings.unit)

    # Jump from RPE (returned in user's unit) -> convert to kg
    change_user = jump_from_rpe(rpe, settings.unit)
    change_kg = to_kg(change_user, settings.unit)

    # Enforce minimums:
    # - at least 5 lb total (or 2.5 kg total)
    # - at least one increment (for rounding consistency)
    change_kg = max(change_kg, min_delta_kg, inc_kg)

    # Cap max jump
    return min(max_jump_kg, change_kg)



def suggest_next_set_from_rpe(
    last_set: SetLog,
    cfg: ExerciseConfig,
    settings: UserSettings,
    debug: bool = False
) -> Suggestion:
    """
    WEIGHT-FIRST + RESET-TO-rep_min behavior (your preference):

    - If RPE < rpe_min (too easy):
        -> increase weight (dynamic jump) AND reset reps to rep_min

    - If rpe_min <= RPE <= rpe_max (in target):
        -> if reps < rep_max and RPE is high-ish (>= 8.0): add reps (dynamic, clamped)
        -> if reps == rep_max and RPE manageable: add weight (dynamic) and reset reps to rep_min
        -> else: stay

    - If RPE > rpe_max (too hard):
        -> if reps <= rep_min: lower weight (one increment)
        -> else: lower reps (dynamic delta, clamped)

    Reps are always clamped inside [rep_min, rep_max].
    Internal weight arithmetic is in kg.
    """
    validate_inputs(last_set, cfg)

    rep_min, rep_max = cfg.rep_range
    rpe_min, rpe_max = cfg.target_rpe_range

    w_kg = to_kg(last_set.weight, settings.unit)
    inc_kg = increment_in_kg(settings, cfg.weight_increment_override)
    max_jump_kg = max_jump_in_kg(settings, cfg.max_jump_override)

    reps = last_set.reps
    rpe = last_set.rpe

    next_w_kg = w_kg
    next_reps = clamp_int(reps, rep_min, rep_max)
    action: Action = "stay"
    reason = ""

    # -----------------------
    # TOO HARD
    # -----------------------
    if rpe > rpe_max:
        if reps <= rep_min:
            change = min(max_jump_kg, inc_kg)
            next_w_kg = w_kg - change
            next_reps = rep_min
            action = "lower_weight"
            reason = f"RPE {rpe:.1f} > {rpe_max:.1f} at low reps; reduce weight and reset reps to {rep_min}."
        else:
            delta = rep_delta_from_rpe(rpe)  # -1 at very high RPE
            next_reps = clamp_int(reps + delta, rep_min, rep_max)
            action = "lower_reps"
            reason = f"RPE {rpe:.1f} > {rpe_max:.1f}; reduce reps slightly."

    # -----------------------
    # TOO EASY  -> WEIGHT FIRST + RESET reps
    # -----------------------
    elif rpe < rpe_min:
        change = _dynamic_weight_increase_kg(rpe, settings, inc_kg, max_jump_kg)
        next_w_kg = w_kg + change
        next_reps = rep_min
        action = "add_weight"
        reason = f"RPE {rpe:.1f} < {rpe_min:.1f}; increase weight first and reset reps to {rep_min}."

    # -----------------------
    # IN TARGET RANGE
    # -----------------------
    else:
        # If we're on the harder side of the target range and not at cap, add reps.
        if reps < rep_max and rpe >= 8.0:
            delta = rep_delta_from_rpe(rpe)  # often 0 or +1 here
            delta = max(1, delta)            # ensure forward motion
            next_reps = clamp_int(reps + delta, rep_min, rep_max)
            action = "add_reps"
            reason = f"RPE {rpe:.1f} is high in-range; add reps toward {rep_max}."

        # At rep cap: add weight if manageable, otherwise stay
        elif reps >= rep_max:
            mid = (rpe_min + rpe_max) / 2.0
            if rpe <= mid:
                change = _dynamic_weight_increase_kg(rpe, settings, inc_kg, max_jump_kg)
                next_w_kg = w_kg + change
                next_reps = rep_min
                action = "add_weight"
                reason = (
                    f"At rep cap with manageable RPE ({rpe:.1f}); add weight and reset reps to {rep_min}."
                )
            else:
                action = "stay"
                next_reps = rep_max
                reason = f"At rep cap and RPE ({rpe:.1f}) is hard; repeat to solidify."

        else:
            action = "stay"
            next_reps = clamp_int(reps, rep_min, rep_max)
            reason = f"RPE {rpe:.1f} in target; keep weight and reps."

    # Round + cap jump after rounding
    next_w_kg = round_to_increment(next_w_kg, inc_kg)
    if abs(next_w_kg - w_kg) > max_jump_kg:
        next_w_kg = w_kg + (max_jump_kg if next_w_kg > w_kg else -max_jump_kg)
        next_w_kg = round_to_increment(next_w_kg, inc_kg)

    next_weight_user = from_kg(next_w_kg, settings.unit)
    next_weight_user = normalize_display_weight(next_weight_user, settings.unit)

    dbg = None
    if debug:
        dbg = {
            "inputs": {"weight_user": last_set.weight, "weight_kg": w_kg, "reps": reps, "rpe": rpe},
            "config": {
                "rep_range": cfg.rep_range,
                "target_rpe_range": cfg.target_rpe_range,
                "inc_kg": inc_kg,
                "max_jump_kg": max_jump_kg,
                "unit": settings.unit.value,
            },
            "outputs": {"next_weight_kg": next_w_kg, "next_weight_user": next_weight_user, "next_reps": next_reps},
        }

    return Suggestion(
        action=action,
        next_weight=next_weight_user,
        next_reps=next_reps,
        unit=settings.unit,
        explanation=reason,
        debug=dbg
    )
