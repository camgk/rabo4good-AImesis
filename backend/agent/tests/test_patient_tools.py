"""Tests for patient context read/write tools (in-memory store fallback)."""

from __future__ import annotations

import pytest

from aimesis_agent import tools
from aimesis_agent.patient_store import AgentPatientStore


@pytest.fixture(autouse=True)
def fresh_store(monkeypatch: pytest.MonkeyPatch) -> AgentPatientStore:
    monkeypatch.delenv("USE_FIRESTORE", raising=False)
    store = AgentPatientStore()
    monkeypatch.setattr(tools, "patient_store", store)
    return store


REGIMEN = [
    {"drug_name": "ifosfamide", "dose_mg_per_m2": 1800, "day_numbers": [1, 2, 3, 4, 5]},
    {"drug_name": "etoposide", "dose_mg_per_m2": 100, "day_numbers": [1, 2, 3, 4, 5]},
]


def test_get_unknown_patient_returns_not_found() -> None:
    assert tools.get_patient_context("PAT-404") == {"found": False, "patient_id": "PAT-404"}


def test_save_then_get_roundtrip_builds_evaluation_inputs() -> None:
    res = tools.save_patient_context(
        patient_id="PAT-2026-0042",
        age_years=15,
        weight_kg=55,
        bsa_m2=1.5,
        chemo_regimen=REGIMEN,
        history_previous_cycles={"had_refractory_cinv": True},
    )
    assert res["saved"] is True
    assert res["patient"]["current_cycle"] == 1
    assert res["patient"]["preferred_formulation"] == "iv"

    got = tools.get_patient_context("PAT-2026-0042")
    assert got["found"] is True
    inputs = got["evaluation_inputs"]
    assert inputs["drug_list"] == ["ifosfamide", "etoposide"]
    assert inputs["chemo_duration_days"] == 5
    assert inputs["prior_breakthrough_cinv"] is True
    assert inputs["drug_doses_mg_m2"]["ifosfamide"] == 1800

    plan = tools.evaluate_uza_cinv_policy_v2(**inputs, include_a2ui_surfaces=False)
    assert plan["overall_tier"] == "High"


def test_partial_update_keeps_existing_fields() -> None:
    tools.save_patient_context(
        patient_id="PAT-1", age_years=6, weight_kg=23, bsa_m2=0.88, chemo_regimen=REGIMEN,
        history_previous_cycles={"had_refractory_cinv": True},
    )
    res = tools.save_patient_context(
        patient_id="PAT-1", weight_kg=24, history_previous_cycles={"anticipatory_nausea": True}
    )
    assert res["saved"] is True
    p = res["patient"]
    assert p["weight_kg"] == 24
    assert p["age_years"] == 6
    assert p["history_previous_cycles"] == {"had_refractory_cinv": True, "anticipatory_nausea": True}


def test_bsa_derived_from_height() -> None:
    res = tools.save_patient_context(
        patient_id="PAT-2", age_years=15, weight_kg=55, height_cm=147, chemo_regimen=REGIMEN
    )
    assert res["saved"] is True
    assert res["patient"]["bsa_m2"] == 1.5


def test_validation_errors_are_returned_not_raised() -> None:
    res = tools.save_patient_context(patient_id="PAT-3", age_years=30, weight_kg=55)
    assert res["saved"] is False
    assert "age_years" in res["errors"]
    assert "bsa_m2" in res["errors"]
    assert tools.get_patient_context("PAT-3")["found"] is False
