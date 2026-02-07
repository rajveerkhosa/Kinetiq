from __future__ import annotations

import math
from dataclasses import dataclass
from typing import List


def dot(a: List[float], b: List[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def sigmoid(z: float) -> float:
    # stable sigmoid
    if z >= 0:
        ez = math.exp(-z)
        return 1.0 / (1.0 + ez)
    ez = math.exp(z)
    return ez / (1.0 + ez)


@dataclass
class OnlineLinearRegressor:
    """
    Online ridge-ish regression via SGD on squared loss.
    y_hat = w·x + b
    """
    dim: int
    lr: float = 0.05
    l2: float = 1e-4

    def __post_init__(self):
        self.w = [0.0] * self.dim
        self.b = 0.0

    def predict(self, x: List[float]) -> float:
        return dot(self.w, x) + self.b

    def update(self, x: List[float], y: float) -> None:
        y_hat = self.predict(x)
        err = (y_hat - y)

        # SGD step with L2
        for i in range(self.dim):
            grad = err * x[i] + self.l2 * self.w[i]
            self.w[i] -= self.lr * grad
        self.b -= self.lr * err


@dataclass
class OnlineLogisticRegressor:
    """
    Online logistic regression via SGD on log loss.
    p = sigmoid(w·x + b)
    """
    dim: int
    lr: float = 0.05
    l2: float = 1e-4

    def __post_init__(self):
        self.w = [0.0] * self.dim
        self.b = 0.0

    def predict_proba(self, x: List[float]) -> float:
        return sigmoid(dot(self.w, x) + self.b)

    def update(self, x: List[float], y01: float) -> None:
        p = self.predict_proba(x)
        err = (p - y01)

        for i in range(self.dim):
            grad = err * x[i] + self.l2 * self.w[i]
            self.w[i] -= self.lr * grad
        self.b -= self.lr * err
