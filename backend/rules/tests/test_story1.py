"""Story 1 acceptance and regression cases grounded in UZA v2 pages 1–2."""

import json
from pathlib import Path

import pytest
from aimesis_rules import (
    ChemoDrugInput,
    classify_regimen_uza_v2,
    classify_single_drug_uza_v2,
)


@pytest.mark.parametrize(
    "name,dose,expected",
    [
        ("cyclophosphamide", 1500, "Moderate"),
        ("cyclophosphamide", 1500.01, "High"),
        ("cytarabine", 199.99, "Low"),
        ("cytarabine", 200.01, "Moderate"),
        ("cytarabine", 2999.99, "Moderate"),
        ("cytarabine", 3000, "High"),
        ("methotrexate", 49.99, "Minimal"),
        ("methotrexate", 50, "Low"),
        ("methotrexate", 249.99, "Low"),
        ("methotrexate", 250, "Moderate"),
        ("methotrexate", 11999.99, "Moderate"),
        ("methotrexate", 12000, "High"),
        ("dactinomycin", 1.349, "Moderate"),
        ("dactinomycin", 1.35, "High"),
        ("thiotepa", 299.99, "Low"),
        ("thiotepa", 300, "High"),
    ],
)
def test_uza_dose_boundaries(name, dose, expected):
    result = classify_regimen_uza_v2([ChemoDrugInput(drug=name, dose_mg_m2=dose)])
    assert not result.refused
    assert result.overall_tier == expected
    assert "UZA v2 p.1" in result.per_drug[0].rule_citation
    assert result.baseline_prophylaxis_summary


@pytest.mark.parametrize(
    "name,expected",
    [
        ("Carboplatine", "High"),
        ("Doxorubicine", "High"),
        ("Ifosfamide", "Moderate"),
        ("Dauno", "Moderate"),
        ("Vincristine", "Low"),
        ("Bleomycine", "Minimal"),
        ("  DOXORUBICIN   LIPOSOMAL  ", "Low"),
        ("pegasparaginase", "Low"),
    ],
)
def test_local_classification_and_aliases(name, expected):
    result = classify_regimen_uza_v2([ChemoDrugInput(drug=name)])
    assert result.overall_tier == expected


@pytest.mark.parametrize(
    "name",
    [
        "carmustine",
        "epirubicin",
        "oxaliplatin",
        "paclitaxel",
        "fluorouracil",
        "mercaptopurine",
        "experimental_drug",
    ],
)
def test_external_only_or_unknown_drugs_do_not_get_a_uza_tier(name):
    result = classify_regimen_uza_v2([ChemoDrugInput(drug=name)])
    assert result.refused
    assert result.overall_tier is None
    assert not result.baseline_prophylaxis_summary


@pytest.mark.parametrize("strict", [True, False])
@pytest.mark.parametrize(
    "name",
    ["cyclophosphamide", "cytarabine", "methotrexate", "dactinomycin", "thiotepa"],
)
def test_missing_doses_cannot_be_bypassed(name, strict):
    result = classify_regimen_uza_v2(
        [ChemoDrugInput(drug=name)], strict_missing_dose=strict
    )
    assert result.refused
    assert result.refusal_reasons[0].field == f"drug_doses_mg_m2.{name}"


def test_ambiguous_cytarabine_boundary_needs_clinical_review():
    result = classify_regimen_uza_v2(
        [ChemoDrugInput(drug="cytarabine", dose_mg_m2=200)]
    )
    assert result.refused
    assert "ambiguous" in result.refusal_reasons[0].message
    assert result.overall_tier is None


def test_non_overlapping_drugs_do_not_trigger_combination_escalation():
    result = classify_regimen_uza_v2(
        [
            ChemoDrugInput(drug="ifosfamide", days=[1]),
            ChemoDrugInput(drug="etoposide", days=[2]),
        ]
    )
    assert result.overall_tier == "Moderate"
    assert not result.combination_elevated
    assert result.per_day_tier == {1: "Moderate", 2: "Low"}
    assert result.per_day_combination_rules == {}
    assert "2x/d" in result.per_day_baseline_prophylaxis[1]
    assert "1x/d" in result.per_day_baseline_prophylaxis[2]


def test_combination_rules_are_traced_to_the_actual_overlap_day():
    result = classify_regimen_uza_v2(
        [
            ChemoDrugInput(drug="ifosfamide", days=[1, 2]),
            ChemoDrugInput(drug="etoposide", days=[2, 3]),
        ]
    )
    assert result.per_day_tier == {1: "Moderate", 2: "High", 3: "Low"}
    assert list(result.per_day_combination_rules) == [2]
    assert result.combination_elevated
    assert "Day 2" in result.combination_rule_applied
    assert result.overall_tier == "High"


@pytest.mark.parametrize(
    "drugs",
    [
        [ChemoDrugInput(drug="ifosfamide"), ChemoDrugInput(drug="etoposide")],
        [
            ChemoDrugInput(drug="cytarabine", dose_mg_m2=300),
            ChemoDrugInput(drug="daunorubicin"),
        ],
        [
            ChemoDrugInput(drug="cytarabine", dose_mg_m2=300),
            ChemoDrugInput(drug="etoposide"),
        ],
        [
            ChemoDrugInput(drug="cyclophosphamide", dose_mg_m2=600),
            ChemoDrugInput(drug="daunorubicin"),
        ],
        [
            ChemoDrugInput(drug="cyclophosphamide", dose_mg_m2=600),
            ChemoDrugInput(drug="daunorubicin"),
            ChemoDrugInput(drug="etoposide"),
        ],
    ],
)
def test_named_uza_combination_exceptions(drugs):
    result = classify_regimen_uza_v2(drugs)
    assert result.overall_tier == "High"
    assert result.combination_elevated
    assert "UZA v2 p.1" in result.combination_rule_applied


def test_two_moderate_drugs_are_not_a_generic_high_risk_exception():
    result = classify_regimen_uza_v2(
        [ChemoDrugInput(drug="ifosfamide"), ChemoDrugInput(drug="daunorubicin")]
    )
    assert result.overall_tier == "Moderate"
    assert not result.combination_elevated


@pytest.mark.parametrize(
    "dose,route,expected",
    [
        (None, "IT", "Low"),
        (None, "ITT", "Low"),
        (40, "PO", "Minimal"),
        (150, "PO", "Low"),
    ],
)
def test_supported_methotrexate_routes(dose, route, expected):
    result = classify_regimen_uza_v2(
        [ChemoDrugInput(drug="methotrexate", dose_mg_m2=dose, route=route)]
    )
    assert result.overall_tier == expected


@pytest.mark.parametrize(
    "drug,route,dose",
    [
        ("melphalan", "PO", None),
        ("cyclophosphamide", "PO", 1000),
        ("methotrexate", "PO", 12000),
        ("cisplatin", "IT", None),
        ("cisplatin", "unknown", None),
        ("triple_it", "IV", None),
    ],
)
def test_uncovered_routes_are_refused(drug, route, dose):
    result = classify_regimen_uza_v2(
        [ChemoDrugInput(drug=drug, route=route, dose_mg_m2=dose)]
    )
    assert result.refused
    assert result.overall_tier is None


@pytest.mark.parametrize("dose", [0, -1, float("nan"), float("inf"), True])
def test_numeric_validation_also_works_without_pydantic(dose):
    classified, refusal = classify_single_drug_uza_v2(
        "cyclophosphamide", dose_mg_m2=dose
    )
    assert classified is None
    assert refusal is not None


@pytest.mark.parametrize("days", [[], [0], [-1], [True], [1.5]])
def test_invalid_days_never_default_to_day_one(days):
    classified, refusal = classify_single_drug_uza_v2("cisplatin", days=days)
    assert classified is None
    assert refusal is not None


def test_empty_or_partly_unknown_regimen_has_no_final_strategy():
    for inputs in [
        [],
        [ChemoDrugInput(drug="cisplatin"), ChemoDrugInput(drug="unknown")],
    ]:
        result = classify_regimen_uza_v2(inputs)
        assert result.refused
        assert result.overall_tier is None
        assert not result.per_day_tier
        assert not result.baseline_prophylaxis_summary


def test_official_three_cases_classify_without_biometrics():
    path = Path(__file__).resolve().parents[3] / "contracts/golden/cases.json"
    cases = json.loads(path.read_text())["cases"]
    for case, expected in zip(cases, ["High", "Moderate", "High"]):
        days = list(range(1, case["chemo_duration_days"] + 1))
        result = classify_regimen_uza_v2(
            [
                ChemoDrugInput(
                    drug=name, dose_mg_m2=case["drug_doses_mg_m2"][name], days=days
                )
                for name in case["drug_list"]
            ]
        )
        assert result.overall_tier == expected
        assert all(value == expected for value in result.per_day_tier.values())
        assert result.baseline_prophylaxis_summary
