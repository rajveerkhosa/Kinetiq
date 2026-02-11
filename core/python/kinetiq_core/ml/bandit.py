from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List


def dot(a: List[float], b: List[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def matvec(A: List[List[float]], x: List[float]) -> List[float]:
    return [dot(row, x) for row in A]


def identity(d: int) -> List[List[float]]:
    return [[1.0 if i == j else 0.0 for j in range(d)] for i in range(d)]


def outer(x: List[float]) -> List[List[float]]:
    return [[xi * xj for xj in x] for xi in x]


def add_inplace(A: List[List[float]], B: List[List[float]], scale: float = 1.0) -> None:
    for i in range(len(A)):
        for j in range(len(A[0])):
            A[i][j] += scale * B[i][j]


def sherman_morrison_inv_update(Ainv: List[List[float]], x: List[float]) -> None:
    u = matvec(Ainv, x)
    denom = 1.0 + dot(x, u)
    if denom == 0:
        return
    # Ainv = Ainv - (u u^T)/denom
    uuT = [[ui * uj for uj in u] for ui in u]
    add_inplace(Ainv, uuT, scale=-1.0 / denom)


@dataclass
class LinUCBBandit:
    dim: int
    alpha: float = 1.5
    Ainv: Dict[str, List[List[float]]] = field(default_factory=dict)
    b: Dict[str, List[float]] = field(default_factory=dict)

    def _ensure(self, action: str) -> None:
        if action not in self.Ainv:
            self.Ainv[action] = identity(self.dim)
            self.b[action] = [0.0] * self.dim

    def score(self, action: str, x: List[float]) -> float:
        self._ensure(action)
        theta = matvec(self.Ainv[action], self.b[action])
        mean = dot(theta, x)
        Ax = matvec(self.Ainv[action], x)
        var = dot(x, Ax)
        return mean + self.alpha * math.sqrt(max(0.0, var))

    def choose(self, actions: List[str], x: List[float]) -> str:
        best = actions[0]
        best_s = self.score(best, x)
        for a in actions[1:]:
            s = self.score(a, x)
            if s > best_s:
                best, best_s = a, s
        return best

    def update(self, action: str, x: List[float], reward: float) -> None:
        self._ensure(action)
        sherman_morrison_inv_update(self.Ainv[action], x)
        for i in range(self.dim):
            self.b[action][i] += reward * x[i]
