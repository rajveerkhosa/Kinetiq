from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict

from .calibration import RPECalibration
from .online_models import OnlineLinearRegressor, OnlineLogisticRegressor
from .bandit import LinUCBBandit
from .embeddings import EmbeddingTable


@dataclass
class MLState:
    """
    Persistent learning state (per user).
    In an app, you'd load/save this (json) per user.
    """
    # Predict RPE of a proposed next set
    rpe_model: OnlineLinearRegressor = field(default_factory=lambda: OnlineLinearRegressor(dim=16, lr=0.05, l2=1e-4))

    # Predict readiness/fatigue (0=ready, 1=fatigued)
    readiness_model: OnlineLogisticRegressor = field(default_factory=lambda: OnlineLogisticRegressor(dim=16, lr=0.05, l2=1e-4))

    # Bandit over actions
    bandit: LinUCBBandit = field(default_factory=lambda: LinUCBBandit(dim=16, alpha=1.5))

    # Calibration stats (bias/variance) per exercise
    calibration_by_ex: Dict[str, RPECalibration] = field(default_factory=dict)

    # Embeddings
    user_embed: EmbeddingTable = field(default_factory=lambda: EmbeddingTable(dim=4))
    ex_embed: EmbeddingTable = field(default_factory=lambda: EmbeddingTable(dim=4))
