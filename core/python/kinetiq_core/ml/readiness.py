from __future__ import annotations

from typing import List

from ..models import SetLog
from .features import summarize_history


def fatigue_label(history: List[SetLog]) -> float:
    h = summarize_history(history)
    return 1.0 if h.rpe_trend_3 >= 0.8 else 0.0
