from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Tuple, Literal, Optional, Dict, Any, List


class Unit(str, Enum):
    LB = "lb"
    KG = "kg"


class FitnessGoal(str, Enum):
    STRENGTH = "strength"
    HYPERTROPHY = "hypertrophy"
    BOTH = "both"


Action = Literal["add_weight", "add_reps", "stay", "lower_weight", "lower_reps"]


@dataclass(frozen=True)
class UserSettings:
    """
    Global user settings.

    Notes:
    - Start with unit=LB for your current plan.
    - You can switch to KG later without changing the core logic.
    """
    unit: Unit = Unit.LB

    # Typical total-weight increments (NOT per side)
    lb_increment: float = 2.5
    kg_increment: float = 1.25

    # Safety cap on how much we change weight between sets
    max_jump_lb: float = 10.0
    max_jump_kg: float = 5.0

    # Training goal affects rep ceiling logic
    goal: FitnessGoal = FitnessGoal.BOTH


@dataclass(frozen=True)
class ExerciseConfig:
    """
    Per-exercise configuration.

    rep_range: any range user wants, e.g. (5, 8), (8, 12), (12, 15)
    target_rpe_range: e.g. (7.0, 9.0) is common
    weight_increment_override: override increment for this lift (optional)
    max_jump_override: override max jump for this lift (optional)
    """
    name: str
    rep_range: Tuple[int, int]
    target_rpe_range: Tuple[float, float] = (7.0, 9.0)
    weight_increment_override: Optional[float] = None
    max_jump_override: Optional[float] = None
    reps_step: int = 1  # typically +1 rep at a time


@dataclass(frozen=True)
class SetLog:
    """
    Single set logged by the user.
    weight is in the user's chosen unit (lb or kg).
    """
    weight: float
    reps: int
    rpe: float  # 1–10


@dataclass
class SetLogWithTs:
    """SetLog with an optional ISO-8601 timestamp string."""
    weight: float
    reps: int
    rpe: float  # 1–10
    ts: Optional[str] = None


@dataclass(frozen=True)
class PlateauResult:
    """Result of plateau detection for an exercise."""
    is_plateau: bool
    weeks_at_same_weight: int
    rpe_trend: float           # positive = RPE rising (getting harder)
    recommendation: str        # "deload" | "vary_reps" | "maintain"
    explanation: str


@dataclass(frozen=True)
class RPEReliabilityResult:
    """How much to trust the user's RPE readings for this exercise."""
    score: float               # 0.0–1.0 (1.0 = very reliable)
    variance: float            # raw RPE variance
    n_observations: int
    weight_in_decisions: float # 0.3–1.0


@dataclass(frozen=True)
class Suggestion:
    action: Action
    next_weight: float
    next_reps: int
    unit: Unit
    explanation: str
    debug: Optional[Dict[str, Any]] = None
    plateau_info: Optional[PlateauResult] = None
    rpe_reliability: Optional[RPEReliabilityResult] = None
