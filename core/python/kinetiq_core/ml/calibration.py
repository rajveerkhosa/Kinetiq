from __future__ import annotations

from dataclasses import dataclass


@dataclass
class RPECalibration:
    """
    Tracks:
      bias: average (reported - expected)
      var:  variance of residuals
    """
    n: int = 0
    bias: float = 0.0
    m2: float = 0.0  # for variance via Welford

    def update(self, residual: float) -> None:
        # residual = reported_rpe - predicted_rpe
        self.n += 1
        delta = residual - self.bias
        self.bias += delta / self.n
        delta2 = residual - self.bias
        self.m2 += delta * delta2

    @property
    def variance(self) -> float:
        if self.n < 2:
            return 1.0
        return self.m2 / (self.n - 1)

    def calibrate(self, rpe: float) -> float:
        # subtract bias -> "calibrated" RPE
        return rpe - self.bias
