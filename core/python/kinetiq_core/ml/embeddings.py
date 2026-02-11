from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Dict, List


@dataclass
class EmbeddingTable:
    dim: int
    lr: float = 0.05
    table: Dict[str, List[float]] = field(default_factory=dict)

    def get(self, key: str) -> List[float]:
        if key not in self.table:
            self.table[key] = [(random.random() - 0.5) * 0.1 for _ in range(self.dim)]
        return self.table[key]
