"""Real-engine classification vs the frontend Plan contract and the demo cases
the Flutter app was built against (frontend/web/test/fixtures/demo_cases.json)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from aimesis_api.plan import classify_for_plan
from aimesis_api.plan.classification import split_citation

REPO = Path(__file__).resolve().parents[3]
DEMO_CASES = json.loads((REPO / "frontend/web/test/fixtures/demo_cases.json").read_text())
TIERS = {"minimal", "low", "moderate", "high"}


def _regimen(patient: dict) -> list[dict]:
    return [
        {"drug_name": c["drug"], "dose_mg_per_m2": c["doseMgM2"], "day_numbers": c["days"]}
        for c in patient["chemo"]
    ]


def _assert_contract(res: dict) -> None:
    for key in ("drugTiers", "dayTiers", "overallTier", "combinationRules", "unknownDrugs", "refused", "refusalReasons"):
        assert key in res
    for t in res["drugTiers"]:
        assert set(t) == {"drug", "doseMgM2", "tier", "rule", "source"}
        assert t["tier"] in TIERS and t["rule"] and t["source"]
    for d in res["dayTiers"]:
        assert set(d) == {"day", "tier", "drugs"}
        assert isinstance(d["day"], int) and d["tier"] in TIERS
    for r in res["combinationRules"]:
        assert set(r) == {"rule", "source"}
    assert res["overallTier"] is None or res["overallTier"] in TIERS
    assert all(isinstance(r, str) for r in res["refusalReasons"])


@pytest.mark.parametrize("patient_id", sorted(DEMO_CASES))
def test_demo_case_matches_frontend_fixture(patient_id: str) -> None:
    case = DEMO_CASES[patient_id]
    expected = case["plan"]
    res = classify_for_plan(_regimen(case["patient"]))

    _assert_contract(res)
    assert res["overallTier"] == expected["overallTier"]
    assert res["unknownDrugs"] == expected["unknownDrugs"]
    assert {(t["drug"].lower(), t["tier"]) for t in res["drugTiers"]} == {
        (t["drug"].lower(), t["tier"]) for t in expected["drugTiers"]
    }
    assert [(d["day"], d["tier"], sorted(x.lower() for x in d["drugs"])) for d in res["dayTiers"]] == [
        (d["day"], d["tier"], sorted(x.lower() for x in d["drugs"])) for d in expected["dayTiers"]
    ]
    assert len(res["combinationRules"]) == len(expected["combinationRules"])


def test_unknown_drug_refuses_but_keeps_known_tiers() -> None:
    res = classify_for_plan(
        [
            {"drug_name": "Cisplatin", "dose_mg_per_m2": 80, "day_numbers": [1]},
            {"drug_name": "Foobarmab", "dose_mg_per_m2": 10, "day_numbers": [1]},
        ]
    )
    _assert_contract(res)
    assert res["refused"] is True
    assert res["unknownDrugs"] == ["Foobarmab"]
    assert res["overallTier"] is None
    assert [(t["drug"], t["tier"]) for t in res["drugTiers"]] == [("Cisplatin", "high")]


def test_dose_dependent_drug_without_dose_refuses() -> None:
    res = classify_for_plan([{"drug_name": "Cyclophosphamide", "dose_mg_per_m2": None, "day_numbers": [1]}])
    _assert_contract(res)
    assert res["refused"] is True
    assert res["overallTier"] is None
    assert res["unknownDrugs"] == []


def test_empty_regimen_refuses() -> None:
    res = classify_for_plan([])
    assert res["refused"] is True and res["refusalReasons"]


def test_split_citation() -> None:
    assert split_citation("UZA v2 p.1 · HOOG EMETOGEEN: Cisplatine") == ("HOOG EMETOGEEN: Cisplatine", "UZA v2 p.1")
    assert split_citation("plain") == ("plain", "UZA v2 p.1")
