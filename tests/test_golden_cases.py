"""Golden cases from casus_voorbeelden.docx. Expected values live in golden/*.yaml
so pharmacists can review them without reading Python. Doses must match EXACTLY."""
from decimal import Decimal
from pathlib import Path

import pytest
import yaml

from aimesis_engine import (ChemoAgent, ChemoDay, Patient, PriorCycle, Regimen,
                            recommend)

GOLDEN = sorted((Path(__file__).resolve().parents[1] / "golden").glob("*.yaml"))


def load_case(path):
    c = yaml.safe_load(path.read_text(encoding="utf-8"))
    p = dict(c["patient"])
    p["prior_cycles"] = [PriorCycle(**pc) for pc in p.get("prior_cycles", [])]
    patient = Patient(**p)
    reg = c["regimen"]
    regimen = Regimen(reg["protocol"], reg["course"],
                      [ChemoDay(d["day"], [ChemoAgent(**a) for a in d["agents"]]) for d in reg["days"]])
    return patient, regimen, c["expected"]


def exact(x) -> Decimal:
    return Decimal(str(x))


@pytest.mark.parametrize("path", GOLDEN, ids=[p.stem for p in GOLDEN])
def test_golden_case(path, rb):
    patient, regimen, exp = load_case(path)
    r = recommend(patient, regimen, rb)

    assert r.status == exp["status"], r.errors
    assert r.tier == exp["tier"]
    if "day_tiers" in exp:
        assert r.day_tiers == exp["day_tiers"]

    for drug, e in exp["items"].items():
        item = r.item(drug)
        assert item is not None, f"{drug} missing from recommendation"
        assert item.dose == exact(e["dose"]), f"{drug}: {item.dose} != {e['dose']} ({item.calc})"
        if "times_per_day" in e:
            assert item.times_per_day == e["times_per_day"], drug
        assert item.days == e["days"], f"{drug} days {item.days}"
        assert item.rule_ids, f"{drug} has no rule trace"
        assert item.calc, f"{drug} has no visible calculation (Story 2)"

    # nothing extra: every recommended drug must be expected
    assert {i.drug for i in r.items} == set(exp["items"]), "unexpected extra items"
    for drug in exp.get("absent", []):
        assert all(not i.drug.startswith(drug) for i in r.items), f"{drug} should be absent"

    for drug, e in exp.get("rescue", {}).items():
        item = r.rescue_item(drug)
        assert item is not None and item.prn
        assert item.dose == exact(e["dose"])
        if "dose_max" in e:
            assert item.dose_max == exact(e["dose_max"])

    if "blocks" in exp:
        assert r.blocks == exp["blocks"]
    for b in exp.get("blocks_contain", []):
        assert any(b in x for x in r.blocks), f"block {b} missing: {r.blocks}"

    assert sorted(d.id for d in r.decisions) == sorted(exp["decisions"])
    for did, text in exp.get("decision_text_contains", {}).items():
        d = r.decision(did)
        assert text in (d.question + " ".join(d.options)), f"{did}: '{text}' not in {d}"
    for w in exp.get("warnings_contain", []):
        assert any(w in x for x in r.warnings), f"warning '{w}' missing: {r.warnings}"


@pytest.mark.parametrize("path", GOLDEN, ids=[p.stem for p in GOLDEN])
def test_golden_case_is_deterministic(path, rb):
    patient, regimen, _ = load_case(path)
    assert recommend(patient, regimen, rb) == recommend(patient, regimen, rb)
