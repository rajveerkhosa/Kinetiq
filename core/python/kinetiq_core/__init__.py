from .models import (
    Unit,
    UserSettings,
    ExerciseConfig,
    SetLog,
    Suggestion,
)

from .engine import suggest_next_set
from .presets import make_exercise, common_presets
from .progression import (
    jump_from_rpe,
    jump_from_rpe_lb,
    rep_delta_from_rpe,
)

# Optional ML (safe to import even if unused)
try:
    from .ml import MLState
except ImportError:
    MLState = None  # ML layer optional


__all__ = [
    "Unit",
    "UserSettings",
    "ExerciseConfig",
    "SetLog",
    "Suggestion",
    "suggest_next_set",
    "make_exercise",
    "common_presets",
    "jump_from_rpe",
    "jump_from_rpe_lb",
    "rep_delta_from_rpe",
    "MLState",
]
