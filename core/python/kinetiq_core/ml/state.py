from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict

from .calibration import RPECalibration
from .online_models import OnlineLinearRegressor, OnlineLogisticRegressor
from .bandit import LinUCBBandit
from .embeddings import EmbeddingTable


@dataclass
class MLState:
    rpe_model: OnlineLinearRegressor = field(default_factory=lambda: OnlineLinearRegressor(dim=16, lr=0.05, l2=1e-4))
    readiness_model: OnlineLogisticRegressor = field(default_factory=lambda: OnlineLogisticRegressor(dim=16, lr=0.05, l2=1e-4))
    bandit: LinUCBBandit = field(default_factory=lambda: LinUCBBandit(dim=16, alpha=1.5))
    calibration_by_ex: Dict[str, RPECalibration] = field(default_factory=dict)
    user_embed: EmbeddingTable = field(default_factory=lambda: EmbeddingTable(dim=4))
    ex_embed: EmbeddingTable = field(default_factory=lambda: EmbeddingTable(dim=4))
