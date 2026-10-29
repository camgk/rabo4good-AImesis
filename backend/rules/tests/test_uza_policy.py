"""Unit tests for UZA July 2026 v2 emetogenicity classification (Table 1 & modifiers)."""

from __future__ import annotations

from aimesis_rules import (
    ChemoDrugInput,
    EmetogenicTier,
    classify_regimen_uza_v2,
)


def test_single_agent_ifosfamide_is_moderate_not_high() -> None:
    """Per UZA July 2026 v2 Table 1 p.1, Ifosfamide alone is MATIG EMETOGEEN."""
    res = classify_regimen_uza_v2([ChemoDrugInput(drug="ifosfamide")])
    assert res.refused is False
    assert res.overall_tier == EmetogenicTier.MODERATE
    assert res.combination_elevated is False


def test_combination_ifosfamide_etoposide_escalates_to_high() -> None:
    """Casus 3: Ifosfamide + Etoposide combination escalates to HOOG EMETOGEEN."""
    res = classify_regimen_uza_v2(
        [ChemoDrugInput(drug="ifosfamide"), ChemoDrugInput(drug="etoposide")]
    )
    assert res.refused is False
    assert res.overall_tier == EmetogenicTier.HIGH
    assert res.combination_elevated is True


def test_combination_cyclophosphamide_anthracycline_escalates_to_high() -> None:
    """Cyclophosphamide + Doxorubicin escalates to HOOG EMETOGEEN."""
    res = classify_regimen_uza_v2(
        [
            ChemoDrugInput(drug="cyclophosphamide", dose_mg_m2=600.0),
            ChemoDrugInput(drug="doxorubicin", dose_mg_m2=50.0),
        ]
    )
    assert res.refused is False
    assert res.overall_tier == EmetogenicTier.HIGH
    assert res.combination_elevated is True


def test_dose_dependent_methotrexate_cutoffs() -> None:
    """Methotrexate: <50 Minimal, >=50-<250 Low, >=250-<12000 Moderate, >=12000 High."""
    assert (
        classify_regimen_uza_v2([ChemoDrugInput(drug="methotrexate", dose_mg_m2=40.0)]).overall_tier
        == EmetogenicTier.MINIMAL
    )
    assert (
        classify_regimen_uza_v2([ChemoDrugInput(drug="methotrexate", dose_mg_m2=150.0)]).overall_tier
        == EmetogenicTier.LOW
    )
    assert (
        classify_regimen_uza_v2([ChemoDrugInput(drug="methotrexate", dose_mg_m2=5000.0)]).overall_tier
        == EmetogenicTier.MODERATE
    )
    assert (
        classify_regimen_uza_v2([ChemoDrugInput(drug="methotrexate", dose_mg_m2=12000.0)]).overall_tier
        == EmetogenicTier.HIGH
    )


def test_strict_missing_dose_flags_dose_dependent_agents() -> None:
    """Ground Rule #3: Refuse rather than guess when strict_missing_dose=True."""
    res = classify_regimen_uza_v2(
        [ChemoDrugInput(drug="methotrexate", dose_mg_m2=None)],
        strict_missing_dose=True,
    )
    assert res.refused is True
    assert any("methotrexate" in r.field for r in res.refusal_reasons)
