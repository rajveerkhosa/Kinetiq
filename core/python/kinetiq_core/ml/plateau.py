from __future__ import annotations

import math
from typing import Dict, List, Tuple

from ..models import SetLogWithTs, PlateauResult


def _iso_week_key(ts: str | None, index: int) -> str:
    """
    Convert an ISO-8601 timestamp string to a week key like '2026-W10'.
    If ts is None, use the index as a synthetic week (each set = same week).
    """
    if ts is None:
        return "week_0"
    try:
        # Minimal ISO date parsing without external deps: "2026-03-11T..." or "2026-03-11"
        date_part = ts.split("T")[0]
        year, month, day = int(date_part[:4]), int(date_part[5:7]), int(date_part[8:10])
        # Compute ISO week number (simplified: day-of-year / 7)
        # Using the correct ISO week calculation
        ordinal = _days_since_epoch(year, month, day)
        # Jan 4 is always in week 1 of its year
        jan4_ordinal = _days_since_epoch(year, 1, 4)
        # Find the Monday of week 1
        jan4_weekday = (jan4_ordinal + 3) % 7  # 0=Mon
        week1_monday = jan4_ordinal - jan4_weekday
        week_num = (ordinal - week1_monday) // 7 + 1
        if week_num < 1:
            week_num = 52
            year -= 1
        elif week_num > 52:
            # Check if it belongs to week 1 of next year
            dec28_ordinal = _days_since_epoch(year, 12, 28)
            dec28_weekday = (dec28_ordinal + 3) % 7
            last_week_monday = dec28_ordinal - dec28_weekday
            if ordinal >= last_week_monday + 7:
                week_num = 1
                year += 1
        return f"{year}-W{week_num:02d}"
    except Exception:
        return f"week_{index}"


def _days_since_epoch(year: int, month: int, day: int) -> int:
    """Compute a simple integer day ordinal (doesn't need to be from any real epoch)."""
    # Simplified ordinal: cumulative days, good enough for week differences
    days_per_month = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
    if leap:
        days_per_month[2] = 29
    ordinal = year * 365 + year // 4 - year // 100 + year // 400
    for m in range(1, month):
        ordinal += days_per_month[m]
    ordinal += day
    return ordinal


def _linear_slope(values: List[float]) -> float:
    """Compute the slope of a best-fit line through (i, values[i])."""
    n = len(values)
    if n < 2:
        return 0.0
    x_mean = (n - 1) / 2.0
    y_mean = sum(values) / n
    numerator = sum((i - x_mean) * (v - y_mean) for i, v in enumerate(values))
    denominator = sum((i - x_mean) ** 2 for i in range(n))
    if denominator == 0:
        return 0.0
    return numerator / denominator


def detect_plateau(
    history: List[SetLogWithTs],
    weeks_to_check: int = 3,
    adaptation_rate: float = 1.0,
) -> PlateauResult:
    """
    Detect if an athlete has plateaued on this exercise.

    Algorithm:
    1. Bucket history by ISO week.
    2. Find max weight per week.
    3. Compute effective window = max(2, round(weeks_to_check / adaptation_rate)).
    4. If last N weeks all have same max_weight → is_plateau=True.
    5. Compute RPE slope over the plateau period.
    6. rising RPE + plateau → "deload" recommendation.
    7. plateau + flat RPE → "vary_reps" recommendation.
    8. No plateau → "maintain".

    Args:
        history: List of sets with optional timestamps.
        weeks_to_check: Number of weeks with same weight before declaring plateau.
        adaptation_rate: >1 = adapts faster (fewer weeks needed), <1 = adapts slower.
    """
    if not history:
        return PlateauResult(
            is_plateau=False,
            weeks_at_same_weight=0,
            rpe_trend=0.0,
            recommendation="maintain",
            explanation="No history available.",
        )

    # Bucket by week
    week_sets: Dict[str, List[SetLogWithTs]] = {}
    for i, s in enumerate(history):
        week_key = _iso_week_key(s.ts, i)
        week_sets.setdefault(week_key, []).append(s)

    # Sort weeks chronologically (ISO week keys sort correctly as strings)
    sorted_weeks = sorted(week_sets.keys())

    if len(sorted_weeks) < 2:
        return PlateauResult(
            is_plateau=False,
            weeks_at_same_weight=1,
            rpe_trend=0.0,
            recommendation="maintain",
            explanation="Not enough weekly data yet.",
        )

    # Max weight per week
    max_weight_by_week = {
        week: max(s.weight for s in sets)
        for week, sets in week_sets.items()
    }

    # Effective plateau window
    effective_weeks = max(2, round(weeks_to_check / adaptation_rate))
    recent_weeks = sorted_weeks[-effective_weeks:]
    recent_max_weights = [max_weight_by_week[w] for w in recent_weeks]

    # Check plateau: all recent weeks at same max weight
    is_plateau = len(set(recent_max_weights)) == 1
    weeks_at_same = len(recent_weeks)

    # RPE trend over plateau period
    rpe_values: List[float] = []
    for week in recent_weeks:
        avg_rpe = sum(s.rpe for s in week_sets[week]) / len(week_sets[week])
        rpe_values.append(avg_rpe)
    rpe_trend = _linear_slope(rpe_values)

    if not is_plateau:
        return PlateauResult(
            is_plateau=False,
            weeks_at_same_weight=0,
            rpe_trend=round(rpe_trend, 3),
            recommendation="maintain",
            explanation="Weight is progressing normally.",
        )

    # Determine recommendation
    if rpe_trend > 0.2:
        recommendation = "deload"
        explanation = (
            f"Same weight for {weeks_at_same} weeks and RPE is rising "
            f"(+{rpe_trend:.1f}/week). Consider a deload: reduce weight ~10%."
        )
    else:
        recommendation = "vary_reps"
        explanation = (
            f"Same weight for {weeks_at_same} weeks. RPE is stable — "
            "try varying your rep scheme before increasing weight."
        )

    return PlateauResult(
        is_plateau=True,
        weeks_at_same_weight=weeks_at_same,
        rpe_trend=round(rpe_trend, 3),
        recommendation=recommendation,
        explanation=explanation,
    )


def apply_auto_deload(
    plateau: PlateauResult,
    current_weight: float,
    deload_fraction: float = 0.10,
) -> Tuple[bool, float]:
    """
    Determine if an automatic deload should be triggered.

    Trigger condition: plateau.is_plateau AND plateau.weeks_at_same_weight >= 3.

    Returns:
        (should_deload, deload_weight) where deload_weight is rounded to nearest 2.5 lb.
    """
    if not plateau.is_plateau or plateau.weeks_at_same_weight < 3:
        return False, current_weight
    raw = current_weight * (1.0 - deload_fraction)
    deload_weight = round(raw / 2.5) * 2.5
    return True, deload_weight


def is_deload_week(
    history: List[SetLogWithTs],
    deload_threshold: float = 0.90,
) -> bool:
    """
    Returns True if the most recent week's max weight is less than
    deload_threshold * previous week's max weight, indicating a deload is in progress.
    """
    if not history:
        return False

    week_sets: Dict[str, List[SetLogWithTs]] = {}
    for i, s in enumerate(history):
        wk = _iso_week_key(s.ts, i)
        week_sets.setdefault(wk, []).append(s)

    sorted_weeks = sorted(week_sets.keys())
    if len(sorted_weeks) < 2:
        return False

    prev_max = max(s.weight for s in week_sets[sorted_weeks[-2]])
    curr_max = max(s.weight for s in week_sets[sorted_weeks[-1]])

    return curr_max < deload_threshold * prev_max
