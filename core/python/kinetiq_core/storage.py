from __future__ import annotations

import json
from dataclasses import asdict
from typing import Any, Dict

from .models import Unit, UserSettings, ExerciseConfig, SetLog


def settings_to_json(settings: UserSettings) -> str:
    d = asdict(settings)
    d["unit"] = settings.unit.value
    return json.dumps(d, indent=2)


def settings_from_json(s: str) -> UserSettings:
    d: Dict[str, Any] = json.loads(s)
    d["unit"] = Unit(d["unit"])
    return UserSettings(**d)


def setlog_to_json(setlog: SetLog) -> str:
    return json.dumps(asdict(setlog), indent=2)


def setlog_from_json(s: str) -> SetLog:
    d = json.loads(s)
    return SetLog(**d)


def exercise_to_json(cfg: ExerciseConfig) -> str:
    d = asdict(cfg)
    return json.dumps(d, indent=2)


def exercise_from_json(s: str) -> ExerciseConfig:
    d: Dict[str, Any] = json.loads(s)
    # tuples may deserialize as lists
    d["rep_range"] = tuple(d["rep_range"])
    d["target_rpe_range"] = tuple(d["target_rpe_range"])
    return ExerciseConfig(**d)
