from __future__ import annotations
from dataclasses import dataclass


@dataclass
class RPECalibration:
    n: int = 0
    bias: float = 0.0
    m2: float = 0.0

    def update(self, residual: float) -> None:
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
        return rpe - self.bias
