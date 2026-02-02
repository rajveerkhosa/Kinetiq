from __future__ import annotations

from .models import SetLog, ExerciseConfig, UserSettings, Suggestion, Action
from .units import (
    to_kg, from_kg, round_to_increment, clamp_int,
    increment_in_kg, max_jump_in_kg, normalize_display_weight
)
from .progression import jump_from_rpe


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
    Compute the next weight increase amount in kg based on RPE,
    respecting minimum increment and max jump.
    """
    # jump_from_rpe returns in user's unit; convert to kg
    change_user = jump_from_rpe(rpe, settings.unit)
    change_kg = to_kg(change_user, settings.unit)

    # Ensure we at least move by one increment if we decided to increase
    change_kg = max(change_kg, inc_kg)

    # Cap by max jump
    return min(max_jump_kg, change_kg)


def suggest_next_set_from_rpe(
    last_set: SetLog,
    cfg: ExerciseConfig,
    settings: UserSettings,
    debug: bool = False
) -> Suggestion:
    """
    Decision system:
    - Too easy: add reps until rep_max, then add weight (dynamic jump) and reset reps to rep_min
    - In target: add reps toward rep_max; at rep_max add weight (dynamic jump) if manageable else stay
    - Too hard: lower reps or lower weight depending on how close you are to rep_min

    When adding weight, reps RESET to rep_min.
    Internal calculations are done in kg to keep unit handling simple.
    """
    validate_inputs(last_set, cfg)

    rep_min, rep_max = cfg.rep_range
    rpe_min, rpe_max = cfg.target_rpe_range

    # Convert weight to kg for internal arithmetic
    w_kg = to_kg(last_set.weight, settings.unit)
    inc_kg = increment_in_kg(settings, cfg.weight_increment_override)
    max_jump_kg = max_jump_in_kg(settings, cfg.max_jump_override)

    reps = last_set.reps
    rpe = last_set.rpe

    next_w_kg = w_kg
    next_reps = reps
    action: Action = "stay"
    reason = ""

    # Too hard
    if rpe > rpe_max:
        if reps <= rep_min:
            # drop weight by one increment (conservative for safety)
            change = min(max_jump_kg, inc_kg)
            next_w_kg = w_kg - change
            next_reps = clamp_int(reps, rep_min, rep_max)
            action = "lower_weight"
            reason = f"RPE {rpe:.1f} > {rpe_max:.1f} at low reps; reduce weight."
        else:
            next_reps = clamp_int(reps - cfg.reps_step, rep_min, rep_max)
            action = "lower_reps"
            reason = f"RPE {rpe:.1f} > {rpe_max:.1f}; reduce reps slightly."

    # Too easy
    elif rpe < rpe_min:
        if reps >= rep_max:
            # dynamic weight increase based on very low RPE
            change = _dynamic_weight_increase_kg(rpe, settings, inc_kg, max_jump_kg)
            next_w_kg = w_kg + change
            next_reps = rep_min
            action = "add_weight"
            reason = (
                f"RPE {rpe:.1f} < {rpe_min:.1f} and reps capped; "
                f"add weight and reset reps to {rep_min}."
            )
        else:
            next_reps = clamp_int(reps + cfg.reps_step, rep_min, rep_max)
            action = "add_reps"
            reason = f"RPE {rpe:.1f} < {rpe_min:.1f}; add reps."

    # In target zone
    else:
        if reps < rep_max:
            next_reps = clamp_int(reps + cfg.reps_step, rep_min, rep_max)
            action = "add_reps"
            reason = f"RPE {rpe:.1f} in target; add reps toward {rep_max}."
        else:
            # At rep cap: if manageable, add weight; if hard-ish, repeat
            mid = (rpe_min + rpe_max) / 2.0
            if rpe <= mid:
                change = _dynamic_weight_increase_kg(rpe, settings, inc_kg, max_jump_kg)
                next_w_kg = w_kg + change
                next_reps = rep_min
                action = "add_weight"
                reason = (
                    f"At rep cap with manageable RPE ({rpe:.1f}); "
                    f"add weight and reset reps to {rep_min}."
                )
            else:
                action = "stay"
                next_reps = rep_max
                reason = (
                    f"At rep cap but RPE ({rpe:.1f}) is on the hard side; "
                    "repeat to solidify."
                )

    # Round + cap jump (again, after rounding)
    next_w_kg = round_to_increment(next_w_kg, inc_kg)
    if abs(next_w_kg - w_kg) > max_jump_kg:
        next_w_kg = w_kg + (max_jump_kg if next_w_kg > w_kg else -max_jump_kg)
        next_w_kg = round_to_increment(next_w_kg, inc_kg)

    # Convert back to user's unit for display
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
