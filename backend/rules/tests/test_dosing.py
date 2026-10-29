"""Unit tests for UZA July 2026 v2 deterministic dosing & Casus 1-3 verification."""

from __future__ import annotations

from aimesis_rules import evaluate_uza_cinv_policy_v2, round_down_to_half_mg


def test_olanzapine_rounds_down_to_nearest_half_mg() -> None:
    """UZA v2 p.2: Olanzapine 0.1 mg/kg rounded DOWN to nearest 0.5 mg."""
    assert round_down_to_half_mg(1.89) == 1.5
    assert round_down_to_half_mg(2.49) == 2.0
    assert round_down_to_half_mg(2.50) == 2.5


def test_casus_1_neuroblastoma_vincristine_cisplatin() -> None:
    """Casus 1: 16yo girl, 52 kg, 1.54 m2, Vincristine + Cisplatin -> High emetogenic."""
    plan = evaluate_uza_cinv_policy_v2(
        drug_list=["vincristine", "cisplatin"],
        patient_age_years=16.0,
        patient_weight_kg=52.0,
        bsa_m2=1.54,
        indication="High-Risk Neuroblastoma",
        prior_breakthrough_cinv=True,
        prior_ondansetron_2xd_on_hec=True,
    )
    assert plan["refused"] is False
    assert plan["overall_tier"] == "High"
    assert plan["dexamethasone_contraindicated"] is False
    assert plan["dosing_lines"]["ondansetron"]["indicated"] is True
    assert plan["dosing_lines"]["aprepitant"]["indicated"] is True
    assert plan["dosing_lines"]["dexamethasone"]["indicated"] is True
    assert plan["dosing_lines"]["olanzapine"]["indicated"] is True


def test_casus_2_all_vincristine_daunorubicin_blocks_dexamethasone() -> None:
    """Casus 2: 2yo boy with ALL, Vincristine + Daunorubicin -> Moderate tier, GEEN Dexamethasone."""
    plan = evaluate_uza_cinv_policy_v2(
        drug_list=["vincristine", "daunorubicin"],
        patient_age_years=2.0,
        patient_weight_kg=12.5,
        bsa_m2=0.56,
        indication="Acute Lymphoblastic Leukemia (ALL - ALLTogether1 Induction B)",
        can_swallow_tablets=False,
    )
    assert plan["refused"] is False
    assert plan["overall_tier"] == "Moderate"
    assert plan["dexamethasone_contraindicated"] is True
    assert plan["dosing_lines"]["dexamethasone"]["indicated"] is False
    assert plan["dosing_lines"]["aprepitant"]["indicated"] is True


def test_casus_3_ewing_sarcoma_ifosfamide_etoposide_5day() -> None:
    """Casus 3: Ifosfamide + Etoposide 5-day IE cycle -> Combination elevates to High."""
    plan = evaluate_uza_cinv_policy_v2(
        drug_list=["ifosfamide", "etoposide"],
        patient_age_years=13.0,
        patient_weight_kg=44.0,
        bsa_m2=1.38,
        chemo_duration_days=5,
        prior_breakthrough_cinv=True,
    )
    assert plan["refused"] is False
    assert plan["overall_tier"] == "High"
    assert plan["combination_elevated"] is True
    assert plan["dosing_lines"]["olanzapine"]["indicated"] is True


def test_refuse_rather_than_guess_when_strict_validation_missing_weight() -> None:
    """Ground Rule #3: Refuse rather than guess when weight_kg is missing under strict_validation."""
    plan = evaluate_uza_cinv_policy_v2(
        drug_list=["cisplatin"],
        patient_age_years=8.0,
        patient_weight_kg=None,
        bsa_m2=1.0,
        strict_validation=True,
    )
    assert plan["refused"] is True
    assert any(r["field"] == "patient_weight_kg" for r in plan["refusal_reasons"])
