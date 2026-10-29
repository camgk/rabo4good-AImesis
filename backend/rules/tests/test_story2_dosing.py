"""Numerical UZA p.2 dose acceptance tests, independent of model phrasing."""

import pytest
from aimesis_rules import (
    EmetogenicTier,
    calculate_uza_dosing,
    evaluate_uza_cinv_policy_v2,
)


def dose(tier="High", age=8, weight=25, bsa=1, **options):
    return calculate_uza_dosing(EmetogenicTier(tier), age, weight, bsa, **options)


def amount(result, drug, component=0):
    return result.lines[drug].calculations[component]["final_dose"]


@pytest.mark.parametrize(
    "bsa,raw,expected",
    [
        (0.56, 2.8, 2.8),
        (1.54, 7.7, 7.7),
        (1.6, 8, 8),
        (1.9, 9.5, 8),
        (0.12345, 0.61725, 0.61725),
    ],
)
def test_ondansetron_uses_unrounded_bsa_then_applies_cap(bsa, raw, expected):
    result = dose(bsa=bsa)
    calc = result.lines["ondansetron"].calculations[0]
    assert calc["raw_dose"] == raw
    assert calc["final_dose"] == expected
    assert calc["maximum_dose"] == 8
    assert "5 mg/m²" in calc["formula"]
    assert result.inputs_used["bsa_m2"] == bsa


@pytest.mark.parametrize(
    "bsa,tier,expected",
    [
        (0.59999, "High", 1),
        (0.6, "High", 2),
        (0.59999, "Moderate", 2),
        (0.6, "Moderate", 4),
    ],
)
def test_dexamethasone_bsa_boundary_and_nk1_adjustment_once(bsa, tier, expected):
    result = dose(tier=tier, bsa=bsa, antiemetic_route="IV")
    assert amount(result, "dexamethasone") == expected
    calc = result.lines["dexamethasone"].calculations[0]
    assert calc["aprepitant_adjustment_factor"] == (0.5 if tier == "High" else 1)
    assert calc["volume_ml"] == expected / 4
    assert calc["concentration_mg_ml"] == 4


@pytest.mark.parametrize(
    "weight,expected",
    [(18.9, 1.5), (24.999, 2), (25, 2.5), (49.999, 4.5), (50, 5), (100, 5)],
)
def test_olanzapine_is_never_rounded_up_before_flooring(weight, expected):
    result = dose(weight=weight)
    assert amount(result, "olanzapine") == expected
    assert (
        result.lines["olanzapine"].calculations[0]["rounding_rule"] == "floor to 0.5 mg"
    )


@pytest.mark.parametrize(
    "route,age,weight,day1,day2",
    [
        ("PO", 8, 50, 125, 80),
        ("IV", 8, 50, 115, 80),
        ("IV", 16, 50, 115, 80),
        ("PO", 12, 12, 125, 80),
    ],
)
def test_aprepitant_route_and_age_specific_caps(route, age, weight, day1, day2):
    result = dose(
        age=age, weight=weight, aprepitant_route=route, can_swallow_tablets=False
    )
    assert amount(result, "aprepitant", 0) == day1
    assert amount(result, "aprepitant", 1) == day2
    assert result.lines["aprepitant"].route == route


@pytest.mark.parametrize(
    "age,weight,expected",
    [(0.75, 10, 50), (1.999, 10, 50), (2, 10, 40), (11.99, 50, 150), (12, 20, 150)],
)
def test_single_dose_iv_fosaprepitant_for_one_day_chemo(age, weight, expected):
    result = dose(
        age=age,
        weight=weight,
        aprepitant_route="IV",
        fosaprepitant_schedule="single_dose",
    )
    assert not result.refused
    assert amount(result, "aprepitant") == expected
    assert len(result.lines["aprepitant"].calculations) == 1


def test_single_iv_schedule_is_not_applied_to_five_day_chemo():
    result = dose(
        aprepitant_route="IV",
        fosaprepitant_schedule="single_dose",
        chemo_duration_days=5,
    )
    assert result.refused
    assert not result.lines


@pytest.mark.parametrize("age,weight", [(0.499, 10), (0.5, 6)])
def test_nk1_ineligible_patients_have_no_nk1_dose(age, weight):
    result = dose(age=age, weight=weight)
    assert not result.lines["aprepitant"].indicated
    assert not result.lines["aprepitant"].calculations
    assert not result.lines["olanzapine"].indicated


def test_all_mec_substitutes_nk1_and_excludes_dexamethasone():
    result = dose(tier="Moderate", age=2, weight=12.5, bsa=0.56, indication="ALL")
    assert result.lines["aprepitant"].indicated
    assert amount(result, "aprepitant") == 37.5
    assert not result.lines["dexamethasone"].indicated
    assert not result.lines["dexamethasone"].calculations


@pytest.mark.parametrize("tier", ["Low", "Minimal"])
def test_unselected_medicines_do_not_emit_doses(tier):
    result = dose(tier=tier)
    for line in result.lines.values():
        if not line.indicated:
            assert not line.calculations
    assert result.lines["ondansetron"].indicated == (tier == "Low")


def test_rescue_ranges_are_capped_and_labelled_as_options():
    result = dose(weight=100, prior_breakthrough_cinv=True)
    assert [c["final_dose"] for c in result.lines["lorazepam"].calculations] == [2, 2]
    assert amount(result, "alizapride") == 50
    assert result.lines["lorazepam"].purpose == "rescue option"


@pytest.mark.parametrize("age,weight,expected", [(16.999, 100, 1500), (17, 100, 250)])
def test_palonosetron_age_boundary_and_microgram_units(age, weight, expected):
    result = dose(age=age, weight=weight, use_palonosetron_switch=True)
    assert not result.lines["ondansetron"].indicated
    assert amount(result, "palonosetron") == expected
    assert result.lines["palonosetron"].calculations[0]["unit"] == "micrograms"


@pytest.mark.parametrize(
    "field,value",
    [
        ("age", None),
        ("weight", None),
        ("bsa", None),
        ("age", True),
        ("bsa", float("nan")),
        ("weight", float("inf")),
        ("bsa", 0),
        ("weight", -1),
    ],
)
def test_missing_nonfinite_or_invalid_biometrics_produce_no_doses(field, value):
    result = dose(**{field: value})
    assert result.refused
    assert not result.lines
    assert result.refusal_reasons


def test_legacy_non_strict_mode_no_longer_invents_patient_measurements():
    result = evaluate_uza_cinv_policy_v2(["cisplatin"], strict_validation=False)
    assert result["refused"]
    assert "dosing_lines" not in result
