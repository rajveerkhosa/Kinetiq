from __future__ import annotations

from ..models import RPEReliabilityResult
from .calibration import RPECalibration


def compute_rpe_reliability(calibration: RPECalibration) -> RPEReliabilityResult:
    """
    Compute how much to trust this athlete's RPE readings for an exercise.

    Uses Welford running variance from RPECalibration:
    - Low variance → consistent RPE reporter → high score → trust RPE more.
    - High variance → inconsistent RPE reporter → low score → down-weight RPE.

    score = 1.0 / (1.0 + variance)
      - variance=0   → score=1.0 (perfect consistency)
      - variance=1   → score=0.5
      - variance=4   → score=0.2

    weight_in_decisions:
      - Needs at least 5 observations before we have meaningful variance.
      - Before that: neutral weight of 0.5.
      - After that:  0.3 + 0.7 * score  (ranges from 0.3 to 1.0).
    """
    variance = calibration.variance
    n = calibration.n

    score = 1.0 / (1.0 + variance)

    if n >= 5:
        weight = 0.3 + 0.7 * score
    else:
        weight = 0.5

    return RPEReliabilityResult(
        score=round(score, 3),
        variance=round(variance, 4),
        n_observations=n,
        weight_in_decisions=round(weight, 3),
    )
