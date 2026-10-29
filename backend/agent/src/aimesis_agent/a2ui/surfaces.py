"""Declarative A2UI surface generator from deterministic `aimesis_rules` outputs."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from aimesis_rules import ADVISORY_LABEL, UZA_POLICY_CITATION
from .catalog import validate_surface_component


def build_clinical_plan_surfaces(
    uza_eval: Dict[str, Any],
    passport: Optional[Dict[str, Any]] = None,
) -> List[Dict[str, Any]]:
    """Turns deterministic rules output into validated A2UI v0.9 surface messages."""
    surfaces: List[Dict[str, Any]] = []

    banner = {
        "type": "AdvisoryBanner",
        "id": "advisory-banner",
        "props": {
            "label": uza_eval.get("advisory_status", ADVISORY_LABEL),
            "policy_version": uza_eval.get("policy_version", UZA_POLICY_CITATION),
        },
    }
    validate_surface_component(banner)
    surfaces.append(banner)

    if uza_eval.get("refused"):
        refusal_card = {
            "type": "RefusalAlertCard",
            "id": "refusal-alert",
            "props": {
                "reasons": uza_eval.get("refusal_reasons", []),
            },
        }
        validate_surface_component(refusal_card)
        surfaces.append(refusal_card)
        return surfaces

    risk_card = {
        "type": "RiskTierCard",
        "id": "story-1-risk-tier",
        "props": {
            "overall_tier": uza_eval["overall_tier"],
            "per_day_tier": uza_eval.get("per_day_tier", {}),
            "per_drug_details": uza_eval.get("per_drug_details", []),
            "combination_elevated": uza_eval.get("combination_elevated", False),
            "combination_rule_applied": uza_eval.get("combination_rule_applied"),
            "baseline_prophylaxis_summary": uza_eval.get("baseline_prophylaxis_summary", ""),
            "citation": f"{UZA_POLICY_CITATION} p.1",
        },
    }
    validate_surface_component(risk_card)
    surfaces.append(risk_card)

    contra_banner = {
        "type": "ContraindicationBanner",
        "id": "story-2-dexamethasone-guard",
        "props": {
            "contraindicated": uza_eval.get("dexamethasone_contraindicated", False),
            "reasons": uza_eval.get("dexamethasone_reasons", []),
            "citation": f"{UZA_POLICY_CITATION} p.2 · GEEN dexamethasone",
        },
    }
    validate_surface_component(contra_banner)
    surfaces.append(contra_banner)

    dose_card = {
        "type": "DoseScheduleCard",
        "id": "story-2-dosing",
        "props": {
            "lines": uza_eval.get("dosing_lines", {}),
            "dosing_schedule": uza_eval.get("dosing_schedule", {}),
            "citation": f"{UZA_POLICY_CITATION} p.2",
        },
    }
    validate_surface_component(dose_card)
    surfaces.append(dose_card)

    personalise_card = {
        "type": "PersonalizationCard",
        "id": "story-3-personalization",
        "props": {
            "overrides": uza_eval.get("personalization_overrides", []),
            "breakthrough_steps": uza_eval.get("breakthrough_steps", []),
        },
    }
    validate_surface_component(personalise_card)
    surfaces.append(personalise_card)

    if "pogo_comparison" in uza_eval:
        pogo_comp = uza_eval["pogo_comparison"]
        pogo_card = {
            "type": "PogoComparisonTable",
            "id": "story-5-uza-vs-pogo",
            "props": {
                "per_drug_comparison": pogo_comp.get("per_drug_comparison", []),
                "has_differences": pogo_comp.get("has_differences", False),
                "combination_notes": pogo_comp.get("combination_notes", []),
                "prophylaxis_comparison": pogo_comp.get("prophylaxis_comparison", {}),
            },
        }
        validate_surface_component(pogo_card)
        surfaces.append(pogo_card)

    if "ddi_screening" in uza_eval:
        ddi = uza_eval["ddi_screening"]
        ddi_card = {
            "type": "DdiAlertList",
            "id": "story-6-ddi-alerts",
            "props": {
                "highest_severity": ddi.get("highest_severity", "NONE"),
                "qtc_prolongation_risk": ddi.get("qtc_prolongation_risk", "MINIMAL"),
                "interactions_found": ddi.get("interactions_found", []),
                "recommended_modifications": ddi.get("recommended_modifications", []),
            },
        }
        validate_surface_component(ddi_card)
        surfaces.append(ddi_card)

    if passport and not passport.get("refused"):
        passport_card = {
            "type": "PatientPassportPreview",
            "id": "story-4-passport",
            "props": {
                "passport_id": passport["passport_id"],
                "emetogenicity_tier": passport["emetogenicity_tier"],
                "active_orders": passport["active_orders"],
                "sign_off": passport["sign_off"],
                "belgian_family_resources": passport["belgian_family_resources"],
            },
        }
        validate_surface_component(passport_card)
        surfaces.append(passport_card)

    return surfaces
