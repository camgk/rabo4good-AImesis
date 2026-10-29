"""Golden dataset regression tests verifying contracts/golden/*.json against aimesis_rules."""

from __future__ import annotations

import json
from pathlib import Path

from aimesis_rules import evaluate_uza_cinv_policy_v2

_REPO_ROOT = Path(__file__).resolve().parents[3]
_GOLDEN_DIR = _REPO_ROOT / "contracts" / "golden"


def test_all_golden_cases_and_edge_cases_match_expected() -> None:
    cases = json.loads((_GOLDEN_DIR / "cases.json").read_text(encoding="utf-8"))["cases"]
    edge_cases = json.loads((_GOLDEN_DIR / "edge_cases.json").read_text(encoding="utf-8"))["edge_cases"]
    expected_map = json.loads((_GOLDEN_DIR / "expected.json").read_text(encoding="utf-8"))["expected"]

    for case in cases:
        cid = case["case_id"]
        exp = expected_map[cid]

        result = evaluate_uza_cinv_policy_v2(
            drug_list=case["drug_list"],
            patient_age_years=case["patient_age_years"],
            patient_weight_kg=case["patient_weight_kg"],
            bsa_m2=case["bsa_m2"],
            drug_doses_mg_m2=case.get("drug_doses_mg_m2"),
            indication=case.get("indication", "solid_tumor"),
            can_swallow_tablets=case.get("can_swallow_tablets", True),
            prior_breakthrough_cinv=case.get("prior_breakthrough_cinv", False),
            prior_ondansetron_2xd_on_hec=case.get("prior_ondansetron_2xd_on_hec", False),
            anticipatory_vomiting=case.get("anticipatory_vomiting", False),
            chemo_duration_days=case.get("chemo_duration_days", 1),
            concomitant_meds=case.get("concomitant_meds", []),
        )

        assert result["refused"] is False, f"Case {cid} unexpectedly refused"
        assert result["overall_tier"] == exp["overall_tier"], f"Case {cid} tier mismatch"
        assert result["combination_elevated"] == exp["combination_elevated"], f"Case {cid} combo mismatch"
        assert result["dexamethasone_contraindicated"] == exp["dexamethasone_contraindicated"]
        assert result["dosing_lines"]["ondansetron"]["indicated"] == exp["ondansetron_indicated"]
        assert result["dosing_lines"]["aprepitant"]["indicated"] == exp["aprepitant_indicated"]
        assert result["dosing_lines"]["dexamethasone"]["indicated"] == exp["dexamethasone_indicated"]
        assert result["dosing_lines"]["olanzapine"]["indicated"] == exp["olanzapine_indicated"]

    for ec in edge_cases:
        ec_id = ec["case_id"]
        res = evaluate_uza_cinv_policy_v2(
            drug_list=ec["drug_list"],
            patient_age_years=ec.get("patient_age_years"),
            patient_weight_kg=ec.get("patient_weight_kg"),
            bsa_m2=ec.get("bsa_m2"),
            drug_doses_mg_m2=ec.get("drug_doses_mg_m2"),
            indication=ec.get("indication", "solid_tumor"),
            strict_validation=ec.get("strict_validation", False),
        )
        if ec.get("expected_refused"):
            assert res["refused"] is True, f"Edge case {ec_id} should have been refused"
            continue

        if "expected_tier" in ec:
            assert res["overall_tier"] == ec["expected_tier"]
        if "expected_dexamethasone_contraindicated" in ec:
            assert res["dexamethasone_contraindicated"] == ec["expected_dexamethasone_contraindicated"]
        if "expected_olanzapine_mg" in ec:
            assert f"{ec['expected_olanzapine_mg']:.1f} mg" in res["dosing_schedule"]["olanzapine"]
