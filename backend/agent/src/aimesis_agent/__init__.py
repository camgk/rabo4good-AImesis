"""AImesis ADK agent package wrapping the deterministic rules engine."""

from __future__ import annotations

from typing import Any

__all__ = ["app", "root_agent"]


def __getattr__(name: str) -> Any:
    if name in {"app", "root_agent"}:
        from aimesis_agent import agent as _agent_mod

        return getattr(_agent_mod, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
