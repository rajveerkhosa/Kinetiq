from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import List, Tuple


# ── Pure-Python matrix utilities (self-contained, no bandit.py import) ────────

def _scaled_identity(d: int, scale: float) -> List[List[float]]:
    return [[scale if i == j else 0.0 for j in range(d)] for i in range(d)]


def _matvec(A: List[List[float]], x: List[float]) -> List[float]:
    return [sum(A[i][j] * x[j] for j in range(len(x))) for i in range(len(A))]


def _dot(a: List[float], b: List[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def _add_rank1(A: List[List[float]], u: List[float], scale: float = 1.0) -> None:
    """A += scale * u u^T  (in-place)"""
    d = len(u)
    for i in range(d):
        for j in range(d):
            A[i][j] += scale * u[i] * u[j]


def _solve(A: List[List[float]], b: List[float]) -> List[float]:
    """Solve A x = b via Gaussian elimination with partial pivoting. d=16, so O(d^3) is fine."""
    d = len(b)
    # Augmented matrix [A | b]
    M = [A[i][:] + [b[i]] for i in range(d)]

    for col in range(d):
        # Partial pivot
        pivot_row = max(range(col, d), key=lambda r: abs(M[r][col]))
        M[col], M[pivot_row] = M[pivot_row], M[col]

        pivot = M[col][col]
        if abs(pivot) < 1e-12:
            continue
        for row in range(col + 1, d):
            factor = M[row][col] / pivot
            for k in range(col, d + 1):
                M[row][k] -= factor * M[col][k]

    # Back substitution
    x = [0.0] * d
    for i in range(d - 1, -1, -1):
        if abs(M[i][i]) < 1e-12:
            x[i] = 0.0
        else:
            x[i] = (M[i][d] - sum(M[i][j] * x[j] for j in range(i + 1, d))) / M[i][i]
    return x


# ── Bayesian RPE Predictor ─────────────────────────────────────────────────────

@dataclass
class BayesianRPEPredictor:
    """
    Online Bayesian Linear Regression for RPE prediction.

    Posterior over weight vector w is N(m, S) where S = S_inv^{-1}.
    We track the precision matrix S_inv and information vector b = S_inv @ m.

    Conjugate update per observation (x, y):
        S_inv_new = S_inv + (1/noise_variance) * x x^T
        b_new     = b     + (1/noise_variance) * y * x

    Predict:
        m    = S_inv^{-1} b  (solve via Gaussian elimination)
        mean = m^T x
        pred_var = noise_variance + x^T S_inv^{-1} x
        uncertainty_95 = 1.96 * sqrt(pred_var)
    """

    dim: int
    prior_precision: float = 1.0
    noise_variance: float = 1.0

    # Precision matrix and information vector (initialized to prior)
    _S_inv: List[List[float]] = field(default_factory=list)
    _b: List[float] = field(default_factory=list)

    def __post_init__(self) -> None:
        if not self._S_inv:
            self._S_inv = _scaled_identity(self.dim, self.prior_precision)
        if not self._b:
            self._b = [0.0] * self.dim

    def update(self, x: List[float], y_rpe: float) -> None:
        """Incorporate one observation (feature vector x, observed RPE y_rpe)."""
        inv_noise = 1.0 / self.noise_variance
        # S_inv += (1/sigma^2) * x x^T
        _add_rank1(self._S_inv, x, scale=inv_noise)
        # b += (1/sigma^2) * y * x
        for i in range(self.dim):
            self._b[i] += inv_noise * y_rpe * x[i]

    def predict(self, x: List[float]) -> Tuple[float, float]:
        """
        Returns (predicted_rpe, uncertainty_95_halfwidth).
        uncertainty_95 = 1.96 * sqrt(predictive_variance).
        """
        m = _solve(self._S_inv, self._b)
        mean = _dot(m, x)

        # Predictive variance: sigma^2 + x^T (S_inv^{-1}) x
        # We need to solve S_inv @ v = x, then dot(x, v)
        v = _solve(self._S_inv, x)
        pred_var = self.noise_variance + _dot(x, v)
        uncertainty_95 = 1.96 * math.sqrt(max(0.0, pred_var))

        # Clamp mean to valid RPE range
        mean = max(1.0, min(10.0, mean))
        return mean, uncertainty_95

    def predict_mean(self, x: List[float]) -> float:
        """Convenience: just the mean. Matches OnlineLinearRegressor.predict() interface."""
        mean, _ = self.predict(x)
        return mean

    def to_dict(self) -> dict:
        return {
            "dim": self.dim,
            "prior_precision": self.prior_precision,
            "noise_variance": self.noise_variance,
            "S_inv": self._S_inv,
            "b": self._b,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "BayesianRPEPredictor":
        obj = cls(
            dim=d["dim"],
            prior_precision=d["prior_precision"],
            noise_variance=d["noise_variance"],
        )
        obj._S_inv = d["S_inv"]
        obj._b = d["b"]
        return obj
