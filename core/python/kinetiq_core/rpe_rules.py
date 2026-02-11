from __future__ import annotations

from typing import List, Optional, Tuple

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
    min_delta_user = 5.0 if settings.unit.value == "lb" else 2.5
    min_delta_kg = to_kg(min_delta_user, settings.unit)

    change_user = jump_from_rpe(rpe, settings.unit)
    change_kg = to_kg(change_user, settings.unit)

    change_kg = max(change_kg, min_delta_kg, inc_kg)
    return min(max_jump_kg, change_kg)


def _recent_same_prescription_rpes(
    history: Optional[List[SetLog]],
    weight: float,
    reps: int,
    k: int = 3,
) -> List[float]:
    """
    Grab up to the last k RPEs from history where (weight,reps) match.
    Most recent first.
    """
    if not history:
        return []
    out: List[float] = []
    for s in reversed(history):
        if float(s.weight) == float(weight) and int(s.reps) == int(reps):
            out.append(float(s.rpe))
            if len(out) >= k:
                break
    return out


def _should_add_weight_from_rpe_drop(
    history: Optional[List[SetLog]],
    last_set: SetLog,
    drop_threshold: float = 1.0,
    k_baseline: int = 3,
) -> Tuple[bool, str]:
    """
    Jeff-style trigger:
    If the same weight+reps has gotten easier by ~1 RPE compared to baseline,
    it's a green light to increase load next time.

    Implementation:
    - baseline = average of older matches (excluding the most recent match)
    - current = last_set.rpe
    - if baseline - current >= threshold -> True

    Needs at least 2 matches total (baseline + current).
    """
    if not history or len(history) < 2:
        return False, ""

    matches = _recent_same_prescription_rpes(history, last_set.weight, last_set.reps, k=k_baseline + 1)
    if len(matches) < 2:
        return False, ""

    current = matches[0]
    baseline_pool = matches[1:]  # older ones
    baseline = sum(baseline_pool) / len(baseline_pool)

    improvement = baseline - current
    if improvement >= drop_threshold:
        return True, f"RPE dropped by {improvement:.1f} (baseline {baseline:.1f} → current {current:.1f}) for same weight/reps."
    return False, ""


def suggest_next_set_from_rpe(
    last_set: SetLog,
    cfg: ExerciseConfig,
    settings: UserSettings,
    debug: bool = False,
    history: Optional[List[SetLog]] = None,  # ✅ NEW (backwards compatible)
) -> Suggestion:
    """
    JEFF-STYLE B (Double progression + RPE-drop trigger):

    Core idea:
    - Progress reps across a rep range first (double progression).
    - Increase weight when:
        (a) you're at rep_max with manageable RPE
        OR
        (b) the SAME weight+reps got easier by ~1 RPE (RPE drop trigger)

    Safety:
    - If RPE too high -> lower weight or reps.
    - Always clamp reps to [rep_min, rep_max].
    - Internal weight math is in kg.
    """
    validate_inputs(last_set, cfg)

    rep_min, rep_max = cfg.rep_range
    rpe_min, rpe_max = cfg.target_rpe_range

    w_kg = to_kg(last_set.weight, settings.unit)
    inc_kg = increment_in_kg(settings, cfg.weight_increment_override)
    max_jump_kg = max_jump_in_kg(settings, cfg.max_jump_override)

    reps = int(last_set.reps)
    rpe = float(last_set.rpe)

    next_w_kg = w_kg
    next_reps = clamp_int(reps, rep_min, rep_max)
    action: Action = "stay"
    reason = ""

    # Jeff-style constants (tunable)
    # - push reps if <= 8.5 in target
    # - hold steady when near top of target to avoid overshoot
    reps_push_ceiling = 8.5

    # -----------------------
    # TOO HARD (safety first)
    # -----------------------
    if rpe > rpe_max:
        if reps <= rep_min:
            change = min(max_jump_kg, inc_kg)
            next_w_kg = w_kg - change
            next_reps = rep_min
            action = "lower_weight"
            reason = f"RPE {rpe:.1f} > {rpe_max:.1f} at low reps; reduce weight and reset reps to {rep_min}."
        else:
            delta = rep_delta_from_rpe(rpe)  # negative at high RPE
            next_reps = clamp_int(reps + delta, rep_min, rep_max)
            action = "lower_reps"
            reason = f"RPE {rpe:.1f} > {rpe_max:.1f}; reduce reps slightly."

    # -----------------------
    # TOO EASY (Jeff-style: reps-first, not weight-first)
    # -----------------------
    elif rpe < rpe_min:
        if reps < rep_max:
            next_reps = clamp_int(reps + 1, rep_min, rep_max)
            action = "add_reps"
            reason = f"RPE {rpe:.1f} < {rpe_min:.1f}; add reps first (double progression)."
        else:
            change = _dynamic_weight_increase_kg(rpe, settings, inc_kg, max_jump_kg)
            next_w_kg = w_kg + change
            next_reps = rep_min
            action = "add_weight"
            reason = f"RPE {rpe:.1f} < {rpe_min:.1f} at rep cap; add weight and reset reps to {rep_min}."

    # -----------------------
    # IN TARGET RANGE (Jeff-style)
    # -----------------------
    else:
        # Jeff trigger: RPE drop by ~1 for same weight/reps
        drop_ok, drop_msg = _should_add_weight_from_rpe_drop(history, last_set, drop_threshold=1.0, k_baseline=3)

        # If at rep cap, weight goes up if not too hard
        if reps >= rep_max:
            mid = (rpe_min + rpe_max) / 2.0
            if rpe <= mid or drop_ok:
                change = _dynamic_weight_increase_kg(rpe, settings, inc_kg, max_jump_kg)
                next_w_kg = w_kg + change
                next_reps = rep_min
                action = "add_weight"
                if drop_ok:
                    reason = f"At rep cap + {drop_msg} → add weight and reset reps to {rep_min}."
                else:
                    reason = f"At rep cap with manageable RPE ({rpe:.1f}); add weight and reset reps to {rep_min}."
            else:
                action = "stay"
                next_reps = rep_max
                reason = f"At rep cap and RPE ({rpe:.1f}) is hard; repeat to solidify."

        # Otherwise: push reps sooner (reps-first within the range)
        else:
            if rpe <= reps_push_ceiling:
                next_reps = clamp_int(reps + 1, rep_min, rep_max)
                action = "add_reps"
                reason = f"RPE {rpe:.1f} in target and not near failure; add reps toward {rep_max}."
            else:
                action = "stay"
                next_reps = clamp_int(reps, rep_min, rep_max)
                reason = f"RPE {rpe:.1f} near top of target; stay to avoid overshooting."

            # If the RPE-drop trigger says it's easier now, allow load increase even before rep_max
            # (Optional but Jeff-authentic)
            if drop_ok and rpe <= (rpe_max - 0.2):
                change = _dynamic_weight_increase_kg(rpe, settings, inc_kg, max_jump_kg)
                next_w_kg = w_kg + change
                next_reps = rep_min
                action = "add_weight"
                reason = f"{drop_msg} → add weight early (Jeff-style) and reset reps to {rep_min}."

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
