"""A2UI component catalog loader and allowlist validator."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, Set


def _resolve_catalog_path() -> Path:
    env_path = os.getenv("A2UI_CATALOG_PATH")
    if env_path:
        return Path(env_path)
    for parent in Path(__file__).resolve().parents:
        candidate = parent / "contracts" / "a2ui" / "catalog.json"
        if candidate.exists():
            return candidate
    return Path("/app/contracts/a2ui/catalog.json")


CATALOG_PATH = _resolve_catalog_path()

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
        "description": "Allowlisted A2UI components that backend/agent may emit and frontend/web renders.",
        "components": [
            {"type": "AdvisoryBanner", "required_props": ["label", "policy_version"]},
            {"type": "RefusalAlertCard", "required_props": ["reasons"]},
            {
                "type": "RiskTierCard",
                "required_props": ["overall_tier", "per_drug_details", "combination_elevated", "citation"],
            },
            {
                "type": "ContraindicationBanner",
                "required_props": ["contraindicated", "reasons", "citation"],
            },
            {"type": "DoseScheduleCard", "required_props": ["lines", "citation"]},
            {"type": "PersonalizationCard", "required_props": ["overrides", "breakthrough_steps"]},
            {
                "type": "PogoComparisonTable",
                "required_props": ["per_drug_comparison", "prophylaxis_comparison"],
            },
            {
                "type": "DdiAlertList",
                "required_props": ["highest_severity", "qtc_prolongation_risk", "interactions_found"],
            },
            {
                "type": "PatientPassportPreview",
                "required_props": [
                    "passport_id",
                    "emetogenicity_tier",
                    "active_orders",
                    "sign_off",
                    "belgian_family_resources",
                ],
            },
        ],
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
