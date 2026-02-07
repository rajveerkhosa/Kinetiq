from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List, Tuple


def dot(a: List[float], b: List[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def matvec(A: List[List[float]], x: List[float]) -> List[float]:
    return [dot(row, x) for row in A]


def outer(x: List[float], y: List[float]) -> List[List[float]]:
    return [[xi * yj for yj in y] for xi in x]


def add_inplace(A: List[List[float]], B: List[List[float]], scale: float = 1.0) -> None:
    for i in range(len(A)):
        for j in range(len(A[0])):
            A[i][j] += scale * B[i][j]


def identity(d: int, val: float = 1.0) -> List[List[float]]:
    return [[val if i == j else 0.0 for j in range(d)] for i in range(d)]


def sherman_morrison_inv_update(Ainv: List[List[float]], x: List[float]) -> None:
    """
    Update (A + x x^T)^-1 from A^-1 using Sherman-Morrison.
    """
    # u = Ainv x
    u = matvec(Ainv, x)
    denom = 1.0 + dot(x, u)
    if denom == 0:
        return
    # Ainv <- Ainv - (u u^T)/denom
    uuT = outer(u, u)
    add_inplace(Ainv, uuT, scale=-1.0 / denom)


@dataclass
class LinUCBBandit:
    dim: int
    alpha: float = 1.5

    Ainv: Dict[str, List[List[float]]] = field(default_factory=dict)
    b: Dict[str, List[float]] = field(default_factory=dict)

    def _ensure(self, action: str) -> None:
        if action not in self.Ainv:
            self.Ainv[action] = identity(self.dim, 1.0)  # start with I
            self.b[action] = [0.0] * self.dim

    def score(self, action: str, x: List[float]) -> float:
        self._ensure(action)
        Ainv = self.Ainv[action]
        b = self.b[action]

        theta = matvec(Ainv, b)  # theta = Ainv b
        mean = dot(theta, x)

        Ax = matvec(Ainv, x)
        var = dot(x, Ax)
        ucb = mean + self.alpha * math.sqrt(max(0.0, var))
        return ucb

    def choose(self, actions: List[str], x: List[float]) -> str:
        best_a = actions[0]
        best_s = self.score(best_a, x)
        for a in actions[1:]:
            s = self.score(a, x)
            if s > best_s:
                best_s = s
                best_a = a
        return best_a

    def update(self, action: str, x: List[float], reward: float) -> None:
        self._ensure(action)
        # A <- A + x x^T  => update Ainv
        sherman_morrison_inv_update(self.Ainv[action], x)
        # b <- b + reward * x
        for i in range(self.dim):
            self.b[action][i] += reward * x[i]
