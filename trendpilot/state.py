"""Persistent bot state: high-water mark, halt flag, last decision.

A plain JSON file so users can inspect and reset it by hand.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class State:
    high_water_mark: float = 0.0
    halted: bool = False
    halt_reason: str = ""
    last_target: str = ""
    last_run: str = ""
    last_signal: str = ""

    @classmethod
    def load(cls, path: Path) -> "State":
        if path.exists():
            return cls(**json.loads(path.read_text()))
        return cls()

    def save(self, path: Path) -> None:
        path.write_text(json.dumps(asdict(self), indent=2))
