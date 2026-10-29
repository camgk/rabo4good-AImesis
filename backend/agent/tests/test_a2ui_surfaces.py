"""Unit tests for A2UI declarative surface builders."""

from __future__ import annotations

from aimesis_rules import evaluate_uza_cinv_policy_v2

from aimesis_agent.a2ui.catalog import validate_surface_component
from aimesis_agent.a2ui.surfaces import build_clinical_plan_surfaces


def test_build_surfaces_from_casus_3_plan_all_valid() -> None:
    plan = evaluate_uza_cinv_policy_v2(
        drug_list=["ifosfamide", "etoposide"],
        patient_age_years=13.0,
        patient_weight_kg=44.0,
        bsa_m2=1.38,
        chemo_duration_days=5,
    )
    surfaces = build_clinical_plan_surfaces(plan)
    assert len(surfaces) >= 6
    for s in surfaces:
        assert validate_surface_component(s) is True


def test_build_surfaces_from_refusal_returns_refusal_alert_card() -> None:
    plan = evaluate_uza_cinv_policy_v2(
        drug_list=["cisplatin"],
        patient_age_years=10.0,
        patient_weight_kg=None,
        bsa_m2=1.1,
        strict_validation=True,
    )
    surfaces = build_clinical_plan_surfaces(plan)
    assert len(surfaces) == 2
    assert surfaces[0]["type"] == "AdvisoryBanner"
    assert surfaces[1]["type"] == "RefusalAlertCard"
