from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import List, Dict, Any

from .models import SetLog


def default_log_path() -> Path:
    return Path("data") / "set_logs.json"


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def load_logs(path: Path | None = None) -> Dict[str, List[Dict[str, Any]]]:
    """
    Returns:
      {
        "bench_press": [{"weight":..., "reps":..., "rpe":..., "ts":...}, ...],
        ...
      }
    """
    path = path or default_log_path()
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def append_log(exercise: str, entry: Dict[str, Any], path: Path | None = None) -> None:
    path = path or default_log_path()
    ensure_parent(path)
    data = load_logs(path)
    data.setdefault(exercise, []).append(entry)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def setlog_to_entry(log: SetLog, ts: str) -> Dict[str, Any]:
    d = asdict(log)
    d["ts"] = ts
    return d
