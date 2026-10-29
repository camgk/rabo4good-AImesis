"""Pins the Casus 1–4 expectations of the MOCK rules (backend/rules is the real engine)."""

import pytest

from aimesis_mock_api import demo_data, docs, rules_mock
from aimesis_mock_api.models import Episode, Patient


def patient(casus: str, **overrides) -> Patient:
    """Internal Patient for "casus-N", built from the demo patient doc exactly like the API does."""
    pid = demo_data.CASUS_IDS[int(casus.rsplit("-", 1)[1])]
    doc = next(p for p in demo_data.patients() if p["patient_id"] == pid)
    data = {**docs.patient_internal(doc), "overallTier": "minimal", "planStatus": "draft", **overrides}
    return Patient.model_validate(data)


def line(plan, drug, day=None):
    hits = [a for a in plan.antiemetics if a.drug == drug and (day is None or day in a.days)]
    assert hits, f"{drug} missing"
    return hits[0]


def test_casus1_high_ondansetron_stepup_dex_halved_olanzapine():
    plan = rules_mock.compute_plan(patient("casus-1"))
    assert plan.overall_tier == "high"
    assert not plan.refused
    ond = line(plan, "ondansetron")
    assert ond.frequency == "3x/d"
    assert ond.dose_mg == 7.6  # 1.52 × 5 = 7.6
    assert ond.route == "oral_tablet"
    assert any("step-up: prior nausea day 2 on ondansetron 2x/d" in n for n in ond.notes)
    assert plan.step_ups and "prior nausea day 2" in plan.step_ups[0].reason
    assert any("Palonosetron" in a.title for a in plan.alternatives)
    assert plan.dexamethasone.blocked is False
    dex = line(plan, "dexamethasone")
    assert dex.dose_mg == 2.0  # 4 mg (BSA > 0.6) halved with aprepitant
    assert any("CYP3A4: dose halved with aprepitant" in s for s in dex.steps)
    assert line(plan, "aprepitant", 1).dose_mg == 125
    assert line(plan, "aprepitant", 2).dose_mg == 80
    olz = line(plan, "olanzapine")
    assert olz.dose_mg == 5.0
    assert "52 kg × 0.1 = 5.2 mg → 5.0 mg" in olz.steps[0]
    assert plan.episodes_summary.prior_nausea_days == [2]
    assert any(i.severity == "info" for i in plan.interactions)
    assert all("mock" in a.source for a in plan.antiemetics)


def test_casus2_moderate_dex_blocked_all_liquid():
    plan = rules_mock.compute_plan(patient("casus-2"))
    assert plan.overall_tier == "moderate"
    assert plan.dexamethasone.blocked is True
    assert "ALL" in plan.dexamethasone.reason
    assert not [a for a in plan.antiemetics if a.drug == "dexamethasone"]
    ond = line(plan, "ondansetron")
    assert ond.frequency == "2x/d"
    assert ond.dose_mg == 2.8  # 0.55 × 5 = 2.75 → 2.8
    assert ond.route == "oral_liquid"
    apr1 = line(plan, "aprepitant", 1)
    assert apr1.route == "oral_liquid"
    assert apr1.dose_mg == 37.5  # 12.5 kg × 3 mg/kg
    assert line(plan, "aprepitant", 2).dose_mg == 25.0
    assert not [a for a in plan.antiemetics if a.drug == "olanzapine"]
    assert plan.step_ups == []


def test_casus3_combination_high_aprepitant_extended():
    plan = rules_mock.compute_plan(patient("casus-3"))
    assert plan.overall_tier == "high"
    assert any("Ifosfamide + Etoposide = HEC" in c.rule for c in plan.combination_rules)
    assert [d.day for d in plan.day_tiers] == [1, 2, 3, 4, 5]
    assert all(d.tier == "high" for d in plan.day_tiers)
    apr_later = line(plan, "aprepitant", 2)
    assert apr_later.days == [2, 3, 4, 5]
    assert any("extend aprepitant to days 4–5, prior nausea day 4" in n for n in apr_later.notes)
    assert line(plan, "ondansetron").days == [1, 2, 3, 4, 5, 6]
    assert line(plan, "olanzapine").dose_mg == 4.5
    assert any(r.item.startswith("ifosfamide + etoposide") and r.uza_tier == "high" for r in plan.uza_vs_pogo)


def test_casus4_cyclophosphamide_high_dex_blocked_critical_interaction():
    p = patient("casus-4")
    assert p.bsa_m2 == 0.85
    plan = rules_mock.compute_plan(p)
    assert plan.overall_tier == "high"
    cyc = next(d for d in plan.drug_tiers if d.drug == "cyclophosphamide")
    assert cyc.tier == "high"
    assert plan.dexamethasone.blocked is True
    crit = [i for i in plan.interactions if i.severity == "critical"]
    assert crit and set(crit[0].drugs) == {"voriconazole", "vincristine"}
    assert "echinocandin" in crit[0].alternative
    assert all(i.source == "BCFI/CBIP (mock)" for i in plan.interactions)
    ond = line(plan, "ondansetron")
    assert ond.dose_mg == 4.3  # 0.85 × 5 = 4.25 → 4.3
    assert ond.route == "oral_liquid"


@pytest.mark.parametrize(
    "dose,tier", [(1600, "high"), (1500, "moderate"), (1200, "moderate")]
)
def test_cyclophosphamide_threshold_and_pogo(dose, tier):
    p = patient("casus-4", chemo=[{"drug": "cyclophosphamide", "doseMgM2": dose, "days": [1]}])
    plan = rules_mock.compute_plan(p)
    assert plan.overall_tier == tier
    row = plan.uza_vs_pogo[0]
    assert row.pogo_tier == "high"
    assert row.differs is (tier != "high")


def test_missing_bsa_refuses():
    plan = rules_mock.compute_plan(patient("casus-1", bsaM2=None))
    assert plan.refused is True
    assert plan.refusal_reasons == ["BSA missing"]
    assert plan.antiemetics == []


def test_unknown_drug_refuses():
    p = patient("casus-1", chemo=[{"drug": "madeupmab", "doseMgM2": 10, "days": [1]}])
    plan = rules_mock.compute_plan(p)
    assert plan.refused and plan.unknown_drugs == ["madeupmab"]


def test_two_moderates_same_day_is_high():
    p = patient(
        "casus-3",
        chemo=[
            {"drug": "daunorubicin", "doseMgM2": 30, "days": [1]},
            {"drug": "ifosfamide", "doseMgM2": 1800, "days": [1]},
        ],
    )
    assert rules_mock.compute_plan(p).overall_tier == "high"


def test_current_cycle_episode_triggers_stepup():
    p = patient("casus-2")
    ep = Episode(
        id="e1", patient_id="PAT-2026-0002", type="vomiting", at="2026-10-30T10:00:00Z",
        cycle_day=2, logged_by="acc-parent2", logged_by_role="parent",
    )
    plan = rules_mock.compute_plan(p, [ep])
    assert plan.episodes_summary.current_cycle[0].day == 2
    assert plan.episodes_summary.current_cycle[0].vomiting == 1
    assert line(plan, "ondansetron").frequency == "3x/d"
    # moderate + prior nausea would add dex, but ALL blocks it
    assert not [a for a in plan.antiemetics if a.drug == "dexamethasone"]


def test_tablet_to_liquid_when_cannot_swallow():
    p = patient("casus-1", riskFactors={"canSwallowTablets": False, "preferredRoute": "oral_tablet", "anticipatory": True})
    plan = rules_mock.compute_plan(p)
    ond = line(plan, "ondansetron")
    assert ond.route == "oral_liquid"
    assert any("oral liquid" in n for n in ond.notes)
    assert any(b.drug == "lorazepam" for b in plan.breakthrough)
