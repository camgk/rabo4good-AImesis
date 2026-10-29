"""A2UI component catalog loader and allowlist validator."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Set

CATALOG_PATH = (
    Path(__file__).resolve().parents[5] / "contracts" / "a2ui" / "catalog.json"
)

ALLOWED_COMPONENT_TYPES: Set[str] = {
    "AdvisoryBanner",
    "RefusalAlertCard",
    "RiskTierCard",
    "ContraindicationBanner",
    "DoseScheduleCard",
    "PersonalizationCard",
    "PogoComparisonTable",
    "DdiAlertList",
    "PatientPassportPreview",
}


def load_catalog() -> Dict[str, Any]:
    if CATALOG_PATH.exists():
        return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    return {
        "version": "0.9",
        "catalog_id": "aimesis_a2ui_catalog_v1",
        "components": [{"type": t, "required_props": []} for t in sorted(ALLOWED_COMPONENT_TYPES)],
    }


def validate_surface_component(component: Dict[str, Any]) -> bool:
    comp_type = component.get("type")
    if comp_type not in ALLOWED_COMPONENT_TYPES:
        raise ValueError(
            f"Disallowed A2UI component type '{comp_type}'. Must be in {sorted(ALLOWED_COMPONENT_TYPES)}."
        )
    catalog = load_catalog()
    for spec in catalog.get("components", []):
        if spec["type"] == comp_type:
            props = component.get("props", {})
            for req in spec.get("required_props", []):
                if req not in props:
                    raise ValueError(f"Component '{comp_type}' missing required prop '{req}'.")
    return True
