from __future__ import annotations

from dataclasses import dataclass
from typing import List

from ..models import SetLog, ExerciseConfig, UserSettings
from .state import MLState


@dataclass
class HistorySummary:
    last_rpe: float = 8.0
    avg_rpe_3: float = 8.0
    rpe_trend_3: float = 0.0


def summarize_history(history: List[SetLog]) -> HistorySummary:
    if not history:
        return HistorySummary()
    recent = history[-3:] if len(history) >= 3 else history
    last = recent[-1].rpe
    avg = sum(s.rpe for s in recent) / len(recent)
    trend = (recent[-1].rpe - recent[0].rpe) if len(recent) >= 2 else 0.0
    return HistorySummary(last_rpe=last, avg_rpe_3=avg, rpe_trend_3=trend)


def make_feature_vector(
    state: MLState,
    user_id: str,
    exercise: ExerciseConfig,
    settings: UserSettings,
    proposed_weight: float,
    proposed_reps: int,
    history: List[SetLog],
) -> List[float]:
    rep_min, rep_max = exercise.rep_range
    h = summarize_history(history)

    u = state.user_embed.get(user_id)         # 4 dims
    e = state.ex_embed.get(exercise.name)     # 4 dims

    w = proposed_weight / 500.0
    r = proposed_reps / 30.0
    rr_min = rep_min / 30.0
    rr_max = rep_max / 30.0

    last_rpe = h.last_rpe / 10.0
    avg_rpe = h.avg_rpe_3 / 10.0
    trend = max(-1.0, min(1.0, h.rpe_trend_3 / 10.0))

    unit_flag = 1.0 if settings.unit.value == "kg" else 0.0

    return [
        w, r,
        rr_min, rr_max,
        last_rpe, avg_rpe, trend,
        unit_flag,
        u[0], u[1], u[2], u[3],
        e[0], e[1], e[2], e[3],
    ]
