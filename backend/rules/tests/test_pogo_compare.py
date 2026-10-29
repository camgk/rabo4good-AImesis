"""Unit tests for POGO 250111 vs UZA July 2026 v2 comparator."""

from __future__ import annotations

from aimesis_rules import ChemoDrugInput, compare_regimen_uza_vs_pogo


def test_pogo_vs_uza_doxorubicin_and_carboplatin_differences() -> None:
    """UZA v2 classifies Doxorubicin and Carboplatin as High, while POGO classifies them as Moderate."""
    res = compare_regimen_uza_vs_pogo(
        [ChemoDrugInput(drug="doxorubicin"), ChemoDrugInput(drug="carboplatin")]
    )
    assert res["has_differences"] is True
    rows = {r["drug"]: r for r in res["per_drug_comparison"]}
    assert rows["doxorubicin"]["uza_v2_tier"] == "High"
    assert rows["doxorubicin"]["pogo_tier"] == "Moderate"
    assert rows["carboplatin"]["uza_v2_tier"] == "High"
    assert rows["carboplatin"]["pogo_tier"] == "Moderate"


def test_pogo_vs_uza_ifosfamide_etoposide_combo_note() -> None:
    """Both UZA v2 and POGO escalate Ifosfamide + Etoposide to High."""
    res = compare_regimen_uza_vs_pogo(
        [ChemoDrugInput(drug="ifosfamide"), ChemoDrugInput(drug="etoposide")]
    )
    assert len(res["combination_notes"]) >= 1
