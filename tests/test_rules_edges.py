"""Threshold and safety edge cases. Expected values are written out by hand from
the UZA v2 policy text (page/quote in rules/uza_v2.yaml)."""
from decimal import Decimal

import pytest

from aimesis_engine import (ChemoAgent, ChemoDay, Patient, PriorCycle, Regimen,
                            classify_agent, recommend)

D = Decimal


def one_day(*agents, day=1):
    return Regimen("test", "test", [ChemoDay(day, list(agents))])


def pt(**kw):
    base = dict(age_years=10, weight_kg=30, bsa_m2=1.0, diagnosis="other_solid_tumor")
    base.update(kw)
    return Patient(**base)


# ------------------------------------------------------------ single agents
@pytest.mark.parametrize("name,dose,route,tier", [
    ("cyclophosphamide", 1000, "IV", "moderate"),
    ("cyclophosphamide", 1500, "IV", "moderate"),     # ≤1500 -> moderate
    ("cyclophosphamide", 1500.01, "IV", "high"),      # >1500 -> high
    ("cyclophosphamide", 1600, "IV", "high"),
    ("cytarabine", 199, "IV", "low"),
    ("cytarabine", 201, "IV", "moderate"),
    ("cytarabine", 2999, "IV", "moderate"),
    ("cytarabine", 3000, "IV", "high"),               # "vanaf 3g/m²"
    ("methotrexate", 49, "IV", "minimal"),
    ("methotrexate", 50, "IV", "low"),
    ("methotrexate", 249, "IV", "low"),
    ("methotrexate", 250, "IV", "moderate"),
    ("methotrexate", 11999, "IV", "moderate"),
    ("methotrexate", 12000, "IV", "high"),
    ("methotrexate", None, "IT", "low"),
    ("thiotepa", 299, "IV", "low"),
    ("thiotepa", 300, "IV", "high"),
    ("dactinomycin", 1.0, "IV", "moderate"),
    ("dactinomycin", 1.35, "IV", "high"),
    ("doxorubicin", 37.5, "IV", "high"),               # UZA: high (POGO: moderate)
    ("doxorubicine liposomaal", 20, "IV", "low"),
    ("Cisplatinum", 80, "IV", "high"),                 # alias + case-insensitive
    ("vincristine", 1.5, "IV", "low"),
])
def test_single_agent_tier(rb, name, dose, route, tier):
    _, t, _ = classify_agent(rb, ChemoAgent(name, dose, route))
    assert t == tier


@pytest.mark.parametrize("agent,reason", [
    (ChemoAgent("cytarabine", 200), "UNCLASSIFIED"),     # gap in policy: <200 vs >200 (OQ-2)
    (ChemoAgent("melphalan", 140, "PO"), "UNCLASSIFIED"),  # policy only covers IV
    (ChemoAgent("cyclophosphamide", None), "dose in mg/m² is required"),
    (ChemoAgent("imatinib", 300, "PO"), "not in the UZA v2"),
])
def test_unclassifiable_blocks_recommendation(agent, reason):
    r = recommend(pt(), one_day(agent))
    assert r.status == "BLOCKED_NEEDS_PHYSICIAN"
    assert r.items == [] and any(reason in e for e in r.errors)


# ------------------------------------------------------------ combinations
@pytest.mark.parametrize("agents,tier", [
    ([("cyclophosphamide", 1000), ("daunorubicin", 30)], "high"),   # cyclo + anthracycline
    ([("cytarabine", 100), ("daunorubicin", 30)], "high"),
    ([("cytarabine", 100), ("etoposide", 100)], "high"),
    ([("ifosfamide", 1800), ("etoposide", 100)], "high"),
    ([("cyclophosphamide", 1000), ("etoposide", 100)], "moderate"), # not an UZA combo (POGO: high)
    ([("vincristine", 1.5), ("daunorubicin", 25)], "moderate"),
])
def test_combinations(agents, tier):
    r = recommend(pt(), one_day(*[ChemoAgent(n, d) for n, d in agents]))
    assert r.tier == tier


def test_combination_is_per_day():
    reg = Regimen("t", "t", [ChemoDay(1, [ChemoAgent("ifosfamide", 1800)]),
                             ChemoDay(2, [ChemoAgent("etoposide", 100)])])
    r = recommend(pt(), reg)
    assert r.day_tiers == {1: "moderate", 2: "low"} and r.tier == "moderate"


# ------------------------------------------------------------ dosing
HEC = one_day(ChemoAgent("cisplatin", 80))


def test_ondansetron_capped_at_8mg():
    r = recommend(pt(bsa_m2=2.0, weight_kg=70, age_years=17), HEC)
    assert r.item("ondansetron").dose == D("8")


@pytest.mark.parametrize("bsa,dose", [(0.59, "1"), (0.6, "2"), (1.2, "2")])
def test_dexamethasone_bsa_split_with_aprepitant(bsa, dose):
    r = recommend(pt(bsa_m2=bsa, weight_kg=20, age_years=5), HEC)
    assert r.item("dexamethasone").dose == D(dose)


@pytest.mark.parametrize("wt,dose", [(18.9, "1.5"), (25, "2.5"), (24.9, "2"), (60, "5")])
def test_olanzapine_floor_to_half_mg_and_cap(wt, dose):
    r = recommend(pt(weight_kg=wt, age_years=12 if wt == 60 else 8), HEC)
    assert r.item("olanzapine").dose == D(dose)


def test_aprepitant_under_12_caps():
    r = recommend(pt(age_years=11, weight_kg=50, bsa_m2=1.5), HEC)
    assert r.item("aprepitant_d1").dose == D("125")      # 150 -> max 125
    assert r.item("aprepitant_d2_d3").dose == D("80")    # 100 -> max 80


@pytest.mark.parametrize("kw", [dict(weight_kg=6, age_years=1), dict(weight_kg=7, age_years=0.4)])
def test_aprepitant_not_indicated(kw):
    r = recommend(pt(bsa_m2=0.35, **kw), HEC)
    assert r.item("aprepitant_d1") is None
    assert r.item("dexamethasone").dose == D("2")        # <0,6 m² WITHOUT aprepitant
    assert r.item("olanzapine") is None                  # <2 years


def test_olanzapine_exactly_two_years_is_a_decision():
    r = recommend(pt(age_years=2, weight_kg=12, bsa_m2=0.55), HEC)
    assert r.item("olanzapine") is None and r.decision("OLZ-AGE-2")


def test_moderate_with_both_options_leaves_choice_to_physician():
    r = recommend(pt(), one_day(ChemoAgent("ifosfamide", 1800)))
    assert r.tier == "moderate"
    assert r.decision("MEC-DEX-OR-APREPITANT")
    assert r.item("dexamethasone") is None and r.item("aprepitant_d1") is None


# ------------------------------------------------------------ dexamethasone blocks
@pytest.mark.parametrize("kw,block", [
    (dict(diagnosis="ALL"), "BLK-DEX-ALL"),
    (dict(diagnosis="brain_tumor"), "BLK-DEX-BRAIN"),
    (dict(comedications=["dinutuximab_beta"]), "BLK-DEX-DINU"),
])
def test_dexamethasone_hard_blocks(kw, block):
    r = recommend(pt(**kw), HEC)
    assert r.item("dexamethasone") is None
    assert any(block in b for b in r.blocks)


def test_steroid_in_regimen_blocks_dexamethasone():
    r = recommend(pt(), one_day(ChemoAgent("cisplatin", 80), ChemoAgent("prednisolone")))
    assert r.item("dexamethasone") is None and any("BLK-DEX-STEROID" in b for b in r.blocks)


def test_aml_is_a_warning_not_a_block():
    r = recommend(pt(diagnosis="AML"), HEC)
    assert r.item("dexamethasone") is not None
    assert any("WRN-DEX-AML" in w for w in r.warnings)


# ------------------------------------------------------------ routes & intake
def test_no_oral_route_switches_to_iv():
    r = recommend(pt(oral_route="none", weight_kg=30, age_years=10, bsa_m2=1.0), HEC)
    assert r.item("fosaprepitant_d1").dose == D("90")    # 3 mg/kg × 30, max 115
    dex = r.item("dexamethasone")
    assert dex.route == "IV" and any("Aacidexam" in n for n in dex.notes)
    assert r.item("olanzapine") is None and r.decision("OLZ-NO-ORAL")


@pytest.mark.parametrize("kw,err", [
    (dict(weight_kg=None), "weight_kg"),
    (dict(bsa_m2=0), "bsa_m2"),
    (dict(diagnosis="medullo"), "not a coded diagnosis"),
])
def test_missing_or_free_text_data_blocks(kw, err):
    r = recommend(pt(**kw), HEC)
    assert r.status == "BLOCKED_NEEDS_PHYSICIAN" and any(err in e for e in r.errors)


def test_unconfirmed_history_is_ignored():
    prior = PriorCycle("C1", "moderate", 2, breakthrough_days=[2], confirmed_by_physician=False)
    r = recommend(pt(prior_cycles=[prior]), one_day(ChemoAgent("ifosfamide", 1800)))
    assert r.tier == "moderate" and any("not confirmed" in w for w in r.warnings)


def test_confirmed_breakthrough_escalates_next_cycle():
    prior = PriorCycle("C1", "moderate", 2, breakthrough_days=[2], confirmed_by_physician=True)
    r = recommend(pt(prior_cycles=[prior]), one_day(ChemoAgent("ifosfamide", 1800)))
    assert r.tier == "high" and any("BRK-NEXT" in t for t in r.tier_trace)


def test_anticipatory_adds_lorazepam_evening_before_and_morning():
    r = recommend(pt(anticipatory_nausea=True, weight_kg=30), HEC)
    lz = r.item("lorazepam_anticipatory")
    assert lz.days == [0, 1] and lz.dose == D("1.2") and lz.dose_max == D("2")   # 0,04–0,08 × 30
