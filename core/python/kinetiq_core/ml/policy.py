from __future__ import annotations

from typing import List, Tuple

from ..models import SetLog, ExerciseConfig, UserSettings, Suggestion
from ..rpe_rules import suggest_next_set_from_rpe
from ..units import normalize_display_weight
from .state import MLState
from .features import make_feature_vector
from .readiness import fatigue_label


ACTIONS = ["add_weight", "add_reps", "stay", "lower_reps", "lower_weight"]


def _candidate_sets(ex: ExerciseConfig, last: SetLog, settings: UserSettings) -> List[Tuple[str, float, int]]:
    """
    Generate a small set of candidate next sets for scoring.
    We don't try to search everything—just reasonable options.
    """
    rep_min, rep_max = ex.rep_range

    # Start from rule-based suggestion as one candidate
    # (Important: keeps behavior safe)
    return []


def _weight_candidates(last_w: float, unit: str) -> List[float]:
    # Use 5-lb minimum step logic: propose +5, +10, +15 (and -5)
    # (your rule engine enforces minimum anyway; these are candidate probes)
    if unit == "kg":
        return [last_w + 2.5, last_w + 5.0, last_w + 7.5, last_w - 2.5]
    return [last_w + 5.0, last_w + 10.0, last_w + 15.0, last_w - 5.0]


def suggest_next_set_ml(
    state: MLState,
    user_id: str,
    exercise: ExerciseConfig,
    last_set: SetLog,
    settings: UserSettings,
    history: List[SetLog],
    debug: bool = False,
) -> Suggestion:
    """
    ML policy:
      1) Calibrate user's RPE per exercise
      2) Train/predict readiness
      3) Train/predict next-set RPE for candidate sets
      4) Use bandit to choose strategy action
      5) Return best candidate suggestion
      6) Fallback to rule engine if insufficient data
    """
    # ---- 0) Fallback early if no history
    if len(history) < 3:
        # just use rules
        return suggest_next_set_from_rpe(last_set, exercise, settings, debug=debug)

    # ---- 1) Calibration (per exercise)
    cal = state.calibration_by_ex.get(exercise.name)
    if cal is None:
        from .calibration import RPECalibration
        cal = RPECalibration()
        state.calibration_by_ex[exercise.name] = cal

    # We'll use model prediction as "expected", update residual
    # Expected RPE for the set they just did (using the same features)
    x_last = make_feature_vector(state, user_id, exercise, settings, last_set.weight, last_set.reps, history[:-1])
    rpe_expected = state.rpe_model.predict(x_last)

    residual = last_set.rpe - rpe_expected
    cal.update(residual)

    calibrated_rpe = cal.calibrate(last_set.rpe)
    calibrated_rpe = max(1.0, min(10.0, calibrated_rpe))

    # ---- 2) Train readiness model (self-supervised)
    # label from history trend
    y_fatigue = fatigue_label(history)
    state.readiness_model.update(x_last, y_fatigue)

    # ---- 3) Update RPE model on the last observed set
    state.rpe_model.update(x_last, last_set.rpe)

    # ---- 4) Candidate generation
    rep_min, rep_max = exercise.rep_range
    candidates: List[Tuple[str, float, int]] = []

    # Candidate weights around current
    for w in _weight_candidates(last_set.weight, settings.unit.value):
        # weight-first reset style: propose rep_min for weight increases
        if w > last_set.weight:
            candidates.append(("add_weight", w, rep_min))
        elif w < last_set.weight:
            candidates.append(("lower_weight", w, rep_min))

    # Candidate reps (within range)
    if last_set.reps < rep_max:
        candidates.append(("add_reps", last_set.weight, min(rep_max, last_set.reps + 1)))
        candidates.append(("add_reps", last_set.weight, min(rep_max, last_set.reps + 2)))
    if last_set.reps > rep_min:
        candidates.append(("lower_reps", last_set.weight, max(rep_min, last_set.reps - 1)))

    candidates.append(("stay", last_set.weight, max(rep_min, min(rep_max, last_set.reps))))

    # ---- 5) Score candidates with predicted RPE + bandit
    rpe_min_t, rpe_max_t = exercise.target_rpe_range

    # Context x for bandit: based on current set context (not candidate)
    x_ctx = make_feature_vector(state, user_id, exercise, settings, last_set.weight, last_set.reps, history)

    chosen_action = state.bandit.choose(ACTIONS, x_ctx)

    best = None
    best_score = -1e9

    for action, w, reps in candidates:
        # prefer candidates matching the bandit's action (but allow others if clearly better)
        x_c = make_feature_vector(state, user_id, exercise, settings, w, reps, history)
        pred_rpe = state.rpe_model.predict(x_c)

        # reward = closeness to target zone + progress bonus - failure risk
        # closeness: 1 when inside zone, decreases as you move away
        if pred_rpe < rpe_min_t:
            closeness = 1.0 - (rpe_min_t - pred_rpe) / 5.0
        elif pred_rpe > rpe_max_t:
            closeness = 1.0 - (pred_rpe - rpe_max_t) / 5.0
        else:
            closeness = 1.0

        # progress bonus: prefer higher weight, then higher reps
        progress = 0.0
        if w > last_set.weight:
            progress += (w - last_set.weight) / 15.0
        if reps > last_set.reps:
            progress += (reps - last_set.reps) / 3.0

        # penalty if predicted too hard
        penalty = 0.0
        if pred_rpe >= 9.5:
            penalty = 0.75

        # action match bonus
        match = 0.15 if action == chosen_action else 0.0

        score = closeness + progress + match - penalty

        if score > best_score:
            best_score = score
            best = (action, w, reps, pred_rpe)

    if best is None:
        return suggest_next_set_from_rpe(last_set, exercise, settings, debug=debug)

    action, next_w, next_reps, pred_rpe = best

    # ---- 6) Bandit update (reward from what we *expect*)
    # (Later you can update with true observed reward after user logs next set)
    expected_reward = max(-1.0, min(1.0, best_score - 0.5))
    state.bandit.update(chosen_action, x_ctx, expected_reward)

    # ---- 7) Return Suggestion (keep your standard shape)
    next_w = normalize_display_weight(float(next_w), settings.unit)

    explanation = (
        f"ML policy chose '{chosen_action}'. Predicted next RPE ≈ {pred_rpe:.1f} "
        f"(target {rpe_min_t:.1f}–{rpe_max_t:.1f})."
    )

    dbg = None
    if debug:
        dbg = {
            "calibrated_rpe": calibrated_rpe,
            "bandit_action": chosen_action,
            "best_score": best_score,
            "pred_rpe_best": pred_rpe,
            "candidates_considered": len(candidates),
        }

    return Suggestion(
        action=action,
        next_weight=next_w,
        next_reps=int(next_reps),
        unit=settings.unit,
        explanation=explanation,
        debug=dbg,
    )
