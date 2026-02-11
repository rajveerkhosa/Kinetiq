from __future__ import annotations

from typing import List, Tuple

from kinetiq_core.models import SetLog, ExerciseConfig, UserSettings, Suggestion
from kinetiq_core.rpe_rules import suggest_next_set_from_rpe
from kinetiq_core.units import normalize_display_weight

from .state import MLState
from .features import make_feature_vector
from .calibration import RPECalibration
from .readiness import fatigue_label


ACTIONS = ["add_weight", "add_reps", "stay", "lower_reps", "lower_weight"]


def _weight_candidates(last_weight: float) -> List[float]:
    """
    Candidate weight changes (lb).
    Must respect your philosophy: realistic gym jumps.
    """
    return [
        last_weight + 5.0,
        last_weight + 10.0,
        last_weight - 5.0,
    ]


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
    ML-enhanced policy with hard safety guardrails.

    RULES ALWAYS WIN WHEN:
    - Not enough history
    - RPE too high
    - ML predicts unsafe outcomes

    ML ONLY:
    - Chooses between reasonable rule-like options
    - Personalizes timing (reps vs weight)
    """

    # --------------------------------------------------
    # HARD GUARDRAILS (safety first)
    # --------------------------------------------------
    rpe_min, rpe_max = exercise.target_rpe_range
    rep_min, rep_max = exercise.rep_range

    # Not enough data → rules only
    if history is None or len(history) < 6:
        return suggest_next_set_from_rpe(last_set, exercise, settings, debug=debug)

    # Too hard → rules handle deloads
    if last_set.rpe > rpe_max:
        return suggest_next_set_from_rpe(last_set, exercise, settings, debug=debug)

    # --------------------------------------------------
    # Calibration (per exercise)
    # --------------------------------------------------
    if exercise.name not in state.calibration_by_ex:
        state.calibration_by_ex[exercise.name] = RPECalibration()

    cal = state.calibration_by_ex[exercise.name]

    # Predict RPE for the last performed set
    x_last = make_feature_vector(
        state,
        user_id,
        exercise,
        settings,
        last_set.weight,
        last_set.reps,
        history[:-1],
    )

    pred_last_rpe = state.rpe_model.predict(x_last)
    cal.update(last_set.rpe - pred_last_rpe)
    state.rpe_model.update(x_last, last_set.rpe)

    calibrated_rpe = max(1.0, min(10.0, cal.calibrate(last_set.rpe)))

    # --------------------------------------------------
    # Readiness model update (self-supervised)
    # --------------------------------------------------
    fatigue = fatigue_label(history)
    state.readiness_model.update(x_last, fatigue)

    # --------------------------------------------------
    # Candidate generation (RULE-LIKE ONLY)
    # --------------------------------------------------
    candidates: List[Tuple[str, float, int]] = []

    # Weight candidates (always reset to rep_min)
    for w in _weight_candidates(last_set.weight):
        if w > 0:
            candidates.append(("add_weight", w, rep_min))

    # Rep candidates
    if last_set.reps < rep_max:
        candidates.append(("add_reps", last_set.weight, min(rep_max, last_set.reps + 1)))

    if last_set.reps > rep_min:
        candidates.append(("lower_reps", last_set.weight, max(rep_min, last_set.reps - 1)))

    candidates.append(("stay", last_set.weight, last_set.reps))

    # --------------------------------------------------
    # Contextual bandit (preference only, not authority)
    # --------------------------------------------------
    x_ctx = make_feature_vector(
        state,
        user_id,
        exercise,
        settings,
        last_set.weight,
        last_set.reps,
        history,
    )

    preferred_action = state.bandit.choose(ACTIONS, x_ctx)

    # --------------------------------------------------
    # Score candidates using predicted RPE + rule priorities
    # --------------------------------------------------
    best = None
    best_score = -1e9
    best_pred_rpe = last_set.rpe

    for action, w, reps in candidates:
        x = make_feature_vector(state, user_id, exercise, settings, w, reps, history)
        pred_rpe = state.rpe_model.predict(x)

        # HARD STOP: never allow predicted RPE > 9.3
        if pred_rpe > 9.3:
            continue

        # Target-zone closeness
        if pred_rpe < rpe_min:
            closeness = 1.0 - (rpe_min - pred_rpe) / 3.0
        elif pred_rpe > rpe_max:
            closeness = 1.0 - (pred_rpe - rpe_max) / 3.0
        else:
            closeness = 1.0

        # Progress reward (weight > reps)
        progress = 0.0
        if w > last_set.weight:
            progress += (w - last_set.weight) / 10.0
        if reps > last_set.reps:
            progress += 0.3

        # Penalize unsafe behavior
        penalty = 0.0
        if action == "add_weight" and calibrated_rpe >= 8.7:
            penalty += 0.6
        if action == "add_reps" and calibrated_rpe >= 9.0:
            penalty += 0.5

        # Bandit preference (small nudge only)
        preference = 0.15 if action == preferred_action else 0.0

        score = closeness + progress + preference - penalty

        if score > best_score:
            best_score = score
            best = (action, w, reps)
            best_pred_rpe = pred_rpe

    # If nothing safe → rules
    if best is None:
        return suggest_next_set_from_rpe(last_set, exercise, settings, debug=debug)

    # --------------------------------------------------
    # Bandit update (expected reward proxy)
    # --------------------------------------------------
    reward = max(-1.0, min(1.0, best_score - 0.5))
    state.bandit.update(preferred_action, x_ctx, reward)

    action, next_weight, next_reps = best
    next_weight = normalize_display_weight(next_weight, settings.unit)

    return Suggestion(
        action=action,
        next_weight=next_weight,
        next_reps=next_reps,
        unit=settings.unit,
        explanation=(
            f"ML selected '{action}' with predicted RPE ≈ {best_pred_rpe:.1f} "
            f"(target {rpe_min:.1f}–{rpe_max:.1f})."
        ),
        debug={
            "calibrated_rpe": calibrated_rpe,
            "preferred_action": preferred_action,
            "predicted_rpe": best_pred_rpe,
            "score": best_score,
        } if debug else None,
    )
