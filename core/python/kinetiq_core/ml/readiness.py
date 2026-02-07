from __future__ import annotations

from typing import List, Tuple

from ..models import SetLog, ExerciseConfig, UserSettings
from .state import MLState
from .features import make_feature_vector, summarize_history


def fatigue_label(history: List[SetLog]) -> float:
    """
    Self-supervised label:
      fatigued (1) if recent RPE trend is rising noticeably
      else ready (0)

    This is simple on purpose. You can improve later.
    """
    h = summarize_history(history)
    return 1.0 if h.rpe_trend_3 >= 0.8 else 0.0  # ~0.8 RPE increase across 3 recent sets


def readiness_proba(
    state: MLState,
    user_id: str,
    exercise: ExerciseConfig,
    settings: UserSettings,
    proposed_weight: float,
    proposed_reps: int,
    history: List[SetLog],
) -> float:
    x = make_feature_vector(state, user_id, exercise, settings, proposed_weight, proposed_reps, history)
    return state.readiness_model.predict_proba(x)
