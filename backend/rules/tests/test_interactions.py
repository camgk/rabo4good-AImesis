"""Unit tests for CYP3A4, QTc, and BCFI/CBIP interactions."""

from __future__ import annotations

from aimesis_rules import check_ddi_interactions


def test_vincristine_itraconazole_critical_alert() -> None:
    """Strong CYP3A4 azole + vincristine triggers CRITICAL neurotoxicity alert."""
    res = check_ddi_interactions(
        primary_drugs=["vincristine", "itraconazole"],
        proposed_antiemetics=["ondansetron"],
    )
    assert res["highest_severity"] == "CRITICAL"
    assert any("Neurotoxicity" in i["severity"] for i in res["interactions_found"])


def test_aprepitant_dexamethasone_50pct_reduction_alert() -> None:
    """Aprepitant + dexamethasone triggers UZA v2 50% dose reduction alert."""
    res = check_ddi_interactions(
        primary_drugs=["cisplatin"],
        proposed_antiemetics=["ondansetron", "aprepitant", "dexamethasone"],
    )
    assert any("50% Dose Adjustment" in i["severity"] for i in res["interactions_found"])


def test_additive_qtc_stacking_detected() -> None:
    """Ondansetron + domperidone + olanzapine triggers HIGH cumulative QTc risk."""
    res = check_ddi_interactions(
        primary_drugs=["domperidone"],
        proposed_antiemetics=["ondansetron", "olanzapine"],
    )
    assert res["qtc_assessment"]["risk_tier"] == "HIGH"
    assert res["qtc_prolongation_risk"] == "ELEVATED"
