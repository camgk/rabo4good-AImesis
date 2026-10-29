"""Agent passport models (aimesis_rules.passport_models) vs the contract
(contracts/schemas/agent_passport.schema.json, profile of passport.schema.json)."""

from __future__ import annotations

import copy
import json
from functools import lru_cache
from pathlib import Path

import jsonschema
import pytest
from aimesis_agent import tools
from aimesis_agent.patient_store import AgentPatientStore
from aimesis_rules import passport_contract
from aimesis_rules.passport_models import (
    DraftPassport,
    RefusalPassport,
    parse_agent_passport,
)
from pydantic import ValidationError
from referencing import Registry, Resource

SCHEMAS = Path(__file__).resolve().parents[3] / "contracts" / "schemas"


@lru_cache(maxsize=1)
def _validator() -> jsonschema.Draft202012Validator:
    registry = Registry()
    for name in ("passport.schema.json", "agent_passport.schema.json"):
        schema = json.loads((SCHEMAS / name).read_text(encoding="utf-8"))
        registry = registry.with_resource(name, Resource.from_contents(schema))
    root = json.loads((SCHEMAS / "agent_passport.schema.json").read_text(encoding="utf-8"))
    return jsonschema.Draft202012Validator(root, registry=registry)


def agent_passport_errors(doc: dict) -> list[str]:
    return [e.message for e in _validator().iter_errors(doc)]


def build_agent_passport(record: dict) -> dict:
    """Builder output as the agent tool returns it (serialised model)."""
    return passport_contract.build_agent_passport(record).to_contract()


@pytest.fixture(autouse=True)
def fresh_store(monkeypatch: pytest.MonkeyPatch) -> AgentPatientStore:
    monkeypatch.delenv("USE_FIRESTORE", raising=False)
    store = AgentPatientStore()
    monkeypatch.setattr(tools, "patient_store", store)
    return store


def _rx(*rows):
    return [{"drug_name": d, "dose_mg_per_m2": dose, "day_numbers": days} for d, dose, days in rows]


CASUS_2 = {  # ALL: dexamethasone must be blocked
    "patient_id": "PAT-2026-0002", "age_years": 2, "weight_kg": 12.5, "bsa_m2": 0.55, "current_cycle": 1,
    "diagnosis": "Acute lymphoblastic leukaemia (ALL)", "diagnosis_group": "ALL", "protocol_name": "ALLTogether1",
    "chemo_regimen": _rx(("Vincristine", 1.5, [1]), ("Daunorubicin", 30, [1])),
    "preferred_formulation": "oral_liquid", "active_medications": [],
    "history_previous_cycles": {"had_refractory_cinv": False, "anticipatory_nausea": False},
}
CASUS_3 = {  # Ifosfamide + etoposide 5 days: combination -> HIGH
    "patient_id": "PAT-2026-0003", "age_years": 14, "weight_kg": 45, "bsa_m2": 1.41, "current_cycle": 3,
    "diagnosis": "Ewing sarcoma", "diagnosis_group": "solid", "protocol_name": "iEuroEwing · IE",
    "chemo_regimen": _rx(("Ifosfamide", 1800, [1, 2, 3, 4, 5]), ("Etoposide", 100, [1, 2, 3, 4, 5])),
    "preferred_formulation": "oral_tablet", "active_medications": [],
    "history_previous_cycles": {"had_refractory_cinv": False, "anticipatory_nausea": False},
}
CASUS_4 = {  # vincristine + voriconazole: critical interaction
    "patient_id": "PAT-2026-0004", "age_years": 7, "weight_kg": 22, "bsa_m2": 0.85, "current_cycle": 1,
    "diagnosis": "ALL", "diagnosis_group": "ALL", "protocol_name": "ALLTogether1 · Consolidation",
    "chemo_regimen": _rx(("Cyclophosphamide", 1600, [1]), ("Vincristine", 1.5, [1])),
    "preferred_formulation": "oral_liquid", "active_medications": ["voriconazole"],
    "history_previous_cycles": {"had_refractory_cinv": False, "anticipatory_nausea": False},
}


def _schedule(doc, drug):
    return [(r["dose_amount"], r["cycle_days"]) for r in doc["antiemetic_schedule"] if r["drug_name"] == drug]


@pytest.mark.parametrize("record", [CASUS_2, CASUS_3, CASUS_4], ids=["casus2", "casus3", "casus4"])
def test_demo_passports_match_contract(record) -> None:
    doc = build_agent_passport(record)
    assert agent_passport_errors(doc) == []
    assert doc["status"] == "draft"
    assert doc["signoffs"]["oncologist"]["signed"] is False
    assert doc["signoffs"]["clinical_pharmacist"]["signed"] is False
    assert doc["refusal"] == {"refused": False, "reasons": []}
    assert doc["emetogenicity_tier"] == doc["classification"]["overall_tier"]
    assert all(r["rule_citation"] for r in doc["antiemetic_schedule"])
    assert {d["drug"] for d in doc["dose_review"]} >= {"Ondansetron", "Dexamethasone", "Aprepitant"}


def test_casus3_combination_and_structured_doses() -> None:
    doc = build_agent_passport(CASUS_3)
    assert doc["emetogenicity_tier"] == "HIGH"
    assert [d["tier"] for d in doc["classification"]["drugs"]] == ["MODERATE", "LOW"]
    assert len(doc["classification"]["combination_rules"]) == 1
    assert [d["day"] for d in doc["classification"]["days"]] == [1, 2, 3, 4, 5]
    assert _schedule(doc, "Aprepitant") == [(125.0, [1]), (80.0, [2, 3])]
    assert _schedule(doc, "Dexamethasone") == [(2.0, [1, 2, 3, 4, 5])]
    assert doc["dexamethasone_rules"]["aprepitant_dose_reduction"] is True
    assert {r["route"] for r in doc["antiemetic_schedule"]} == {"oral_tablet"}


def test_casus2_all_blocks_dexamethasone() -> None:
    doc = build_agent_passport(CASUS_2)
    assert doc["dexamethasone_rules"]["is_blocked"] is True
    assert "ALL" in doc["dexamethasone_rules"]["rationale"]
    assert _schedule(doc, "Dexamethasone") == []
    assert _schedule(doc, "Aprepitant")  # MEC without dexamethasone -> aprepitant
    assert {r["route"] for r in doc["antiemetic_schedule"]} == {"oral_liquid"}


def test_casus4_critical_interaction_is_first_flag() -> None:
    doc = build_agent_passport(CASUS_4)
    first = doc["review_flags"][0]
    assert first["severity"] == "critical"
    assert "voriconazole + vincristine" in first["message"]
    assert any(i["interacting_pair"] == "voriconazole + vincristine" for i in doc["safety"]["interactions"])
    assert doc["safety"]["qtc"]["contributors"]


def test_missing_bsa_refuses_without_doses() -> None:
    record = {**CASUS_3, "bsa_m2": None}
    doc = build_agent_passport(record)
    assert agent_passport_errors(doc) == []
    assert doc["refusal"]["refused"] is True
    assert [r["field"] for r in doc["refusal"]["reasons"]] == ["bsa_m2"]
    assert "antiemetic_schedule" not in doc and "emetogenicity_tier" not in doc
    assert doc["classification"]["overall_tier"] == "HIGH"  # classification needs no BSA


def test_bsa_derived_from_height_is_flagged() -> None:
    doc = build_agent_passport({**CASUS_3, "bsa_m2": None, "height_cm": 158})
    assert doc["refusal"]["refused"] is False
    assert any(f["code"] == "bsa_derived" for f in doc["review_flags"])
    assert next(i for i in doc["inputs"] if i["field"] == "bsa_m2")["source"] == "derived"


def test_unknown_drug_refuses_but_shows_known_tiers() -> None:
    record = {**CASUS_3, "chemo_regimen": _rx(("Cisplatin", 80, [1]), ("Foobarmab", 10, [1]))}
    doc = build_agent_passport(record)
    assert agent_passport_errors(doc) == []
    assert doc["refusal"]["refused"] is True
    assert doc["classification"]["overall_tier"] is None
    assert [d["drug"] for d in doc["classification"]["drugs"]] == ["Cisplatin"]


def test_missing_diagnosis_and_meds_are_flagged_as_defaults() -> None:
    record = {k: v for k, v in CASUS_3.items() if k not in ("diagnosis", "diagnosis_group", "protocol_name", "active_medications")}
    doc = build_agent_passport(record)
    defaulted = {f["message"].split("'")[1] for f in doc["review_flags"] if f["code"] == "input_defaulted"}
    assert defaulted == {"indication", "concomitant_meds"}


def _tampered(doc: dict) -> list[dict]:
    signed = copy.deepcopy(doc)
    signed["signoffs"]["oncologist"]["signed"] = True
    no_safety = {k: v for k, v in doc.items() if k != "safety"}
    text_dose = copy.deepcopy(doc)
    text_dose["antiemetic_schedule"][0]["dose_amount"] = "7 mg"
    bad_route = copy.deepcopy(doc)
    bad_route["antiemetic_schedule"][0]["route"] = "PO / IV"
    extra_field = {**copy.deepcopy(doc), "llm_comment": "looks fine"}
    refusal_with_doses = {**copy.deepcopy(doc), "refusal": {"refused": True, "reasons": []}}
    return [signed, no_safety, text_dose, bad_route, extra_field, refusal_with_doses]


@pytest.mark.parametrize("case", range(6), ids=["signed", "no_safety", "text_dose", "bad_route", "extra", "refusal"])
def test_models_and_contract_reject_tampered_passport(case: int) -> None:
    doc = _tampered(build_agent_passport(CASUS_3))[case]
    with pytest.raises(ValidationError):
        parse_agent_passport(doc)
    assert agent_passport_errors(doc)


def test_builder_returns_typed_models() -> None:
    assert isinstance(passport_contract.build_agent_passport(CASUS_3), DraftPassport)
    assert isinstance(passport_contract.build_agent_passport({**CASUS_3, "bsa_m2": None}), RefusalPassport)


@pytest.mark.parametrize("record", [CASUS_3, {**CASUS_3, "bsa_m2": None}], ids=["draft", "refusal"])
def test_contract_roundtrip(record) -> None:
    doc = build_agent_passport(record)
    assert parse_agent_passport(doc).to_contract() == doc


def test_models_cover_every_contract_section() -> None:
    passport = json.loads((SCHEMAS / "passport.schema.json").read_text(encoding="utf-8"))
    agent = json.loads((SCHEMAS / "agent_passport.schema.json").read_text(encoding="utf-8"))
    draft_required = set(passport["required"]) | set(agent["oneOf"][0]["allOf"][1]["required"])
    assert draft_required <= set(DraftPassport.model_fields)
    assert set(DraftPassport.model_fields) <= set(passport["properties"])
    assert set(DraftPassport.model_fields) == set(agent["oneOf"][0]["propertyNames"]["enum"])
    assert set(agent["oneOf"][1]["required"]) <= set(RefusalPassport.model_fields)
    assert set(RefusalPassport.model_fields) == set(agent["oneOf"][1]["properties"])


def test_tool_reads_stored_patient() -> None:
    saved = tools.save_patient_context(
        patient_id="PAT-T-4", age_years=7, weight_kg=22, bsa_m2=0.85, diagnosis="ALL", diagnosis_group="ALL",
        chemo_regimen=CASUS_4["chemo_regimen"], preferred_formulation="oral_liquid", active_medications=["voriconazole"],
    )
    assert saved["saved"] is True
    ctx = tools.get_patient_context("PAT-T-4")
    assert ctx["evaluation_inputs"]["concomitant_meds"] == ["voriconazole"]
    assert "ALL" in ctx["evaluation_inputs"]["indication"]

    doc = tools.generate_cinv_patient_passport("PAT-T-4")
    assert "contract_valid" not in doc
    assert doc["passport_id"] == "PSP-T-4-C1"
    assert doc["dexamethasone_rules"]["is_blocked"] is True


def test_tool_unknown_patient_returns_valid_refusal() -> None:
    doc = tools.generate_cinv_patient_passport("PAT-404")
    assert agent_passport_errors(doc) == []
    assert doc["refusal"]["refused"] is True
    assert doc["refusal"]["reasons"][0]["field"] == "patient_id"


def test_invalid_treatment_days_refuse() -> None:
    doc = build_agent_passport({**CASUS_3, "chemo_regimen": _rx(("Cisplatin", 80, [0]))})
    assert agent_passport_errors(doc) == []
    assert doc["refusal"]["refused"] is True
    assert doc["refusal"]["reasons"][0]["field"] == "chemo_regimen"
