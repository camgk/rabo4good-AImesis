"""Story 5: Deterministic UZA July 2026 v2 vs. POGO 250111 Guideline Comparison.

Compares UZA v2 (`Anti-emetica beleid CINV - V2.pdf`) with the POGO Emetogenicity
Classification Guideline (`POGO Emetogenicity Classification Guideline Final-rev- 250111.pdf`).
Source of truth for clinical plans is always UZA v2 (Ground Rule #6).
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from .models import (
    ADVISORY_LABEL,
    ChemoDrugInput,
    POGO_CITATION,
    PogoComparisonItem,
    UZA_POLICY_CITATION,
)
from .uza_policy import classify_single_drug_uza_v2, normalize_drug_name

# POGO 250111 baseline reference tiers and dose cutoffs
POGO_SINGLE_AGENT_TIERS: Dict[str, str] = {
    "cisplatin": "High",
    "dacarbazine": "High",
    "carmustine": "High",
    "melphalan": "High",
    "carboplatin": "Moderate (High at AUC ≥4 / high pediatric doses)",
    "doxorubicin": "Moderate",
    "daunorubicin": "Moderate",
    "idarubicin": "Moderate",
    "epirubicin": "Moderate",
    "ifosfamide": "Moderate",
    "irinotecan": "Moderate",
    "lomustine": "Moderate",
    "arsenic_trioxide": "Moderate",
    "azacitidine": "Moderate",
    "bendamustine": "Moderate",
    "busulfan": "Moderate",
    "clofarabine": "Moderate",
    "temozolomide": "Moderate",
    "etoposide": "Low",
    "gemcitabine": "Low",
    "mitoxantrone": "Low",
    "topotecan": "Low",
    "vincristine": "Minimal",
    "vinblastine": "Minimal",
    "vinorelbine": "Minimal",
    "asparaginase": "Minimal",
    "pegaspargase": "Minimal",
    "blinatumomab": "Minimal",
    "bleomycin": "Minimal",
    "fludarabine": "Minimal",
    "rituximab": "Minimal",
    "thioguanine": "Minimal",
    "cladribine": "Minimal",
    "nelarabine": "Minimal",
}


def compare_drug_uza_vs_pogo(
    drug_name: str,
    dose_mg_m2: Optional[float] = None,
    route: str = "IV",
) -> PogoComparisonItem:
    """Compares a single drug's classification between UZA v2 (2026) and POGO (250111)."""
    norm = normalize_drug_name(drug_name)
    uza_cls, _ = classify_single_drug_uza_v2(
        drug_name=drug_name,
        dose_mg_m2=dose_mg_m2,
        route=route,
        strict_missing_dose=False,
    )
    uza_tier = uza_cls.tier.value if uza_cls else "Unlisted"
    uza_cite = uza_cls.rule_citation if uza_cls else f"{UZA_POLICY_CITATION} p.1"

    # Determine POGO tier and explanation of differences
    if norm == "cyclophosphamide":
        if dose_mg_m2 is not None:
            pogo_tier = "High" if dose_mg_m2 >= 1000.0 else "Moderate"
        else:
            pogo_tier = "High (≥1000 mg/m²) / Moderate (<1000 mg/m²)"
        differs = uza_tier != pogo_tier
        explanation = (
            "UZA v2 sets the High threshold at >1500 mg/m² (≤1500 mg/m² is Moderate), "
            "whereas POGO 250111 classifies Cyclophosphamide ≥1000 mg/m² as High."
        )
    elif norm == "doxorubicin":
        pogo_tier = "Moderate"
        differs = True
        explanation = (
            "UZA v2 classifies all IV Doxorubicine as High (HOOG EMETOGEEN), "
            "whereas POGO 250111 classifies single-agent Doxorubicin as Moderate (escalating to High with Cyclophosphamide)."
        )
    elif norm == "carboplatin":
        pogo_tier = "Moderate"
        differs = True
        explanation = (
            "UZA v2 classifies Carboplatine unconditionally as High (HOOG EMETOGEEN), "
            "whereas POGO 250111 lists Carboplatin under Moderate (30–90%) in standard tables."
        )
    elif norm == "dactinomycin":
        pogo_tier = "High"
        differs = uza_tier != "High"
        explanation = (
            "UZA v2 stratifies Dactinomycine by dose (≥1.35 mg/m² = High; <1.35 mg/m² = Moderate), "
            "whereas POGO 250111 classifies IV Dactinomycin as High."
        )
    elif norm == "temozolomide":
        pogo_tier = "Moderate"
        differs = True
        explanation = (
            "UZA v2 classifies Temozolomide as Low (LAAG EMETOGEEN), "
            "whereas POGO 250111 classifies Temozolomide as Moderate."
        )
    elif norm in {"vincristine", "vinblastine", "vinorelbine", "asparaginase", "pegaspargase", "blinatumomab"}:
        pogo_tier = "Minimal"
        differs = True
        explanation = (
            f"UZA v2 classifies {drug_name} as Low (LAAG EMETOGEEN → Ondansetron 1x/d), "
            "whereas POGO 250111 classifies it as Minimal (<10% → no routine prophylaxis)."
        )
    elif norm == "cytarabine":
        if dose_mg_m2 is not None:
            pogo_tier = "High" if dose_mg_m2 >= 3000.0 else ("Moderate" if dose_mg_m2 > 200.0 else "Low")
        else:
            pogo_tier = "Moderate (>200 mg/m²) / High (≥3 g/m²)"
        differs = uza_tier != pogo_tier
        explanation = "Both UZA v2 and POGO use ≥3 g/m² for High and ≤200 mg/m² for Low."
    elif norm == "methotrexate":
        if dose_mg_m2 is not None:
            pogo_tier = "High" if dose_mg_m2 >= 12000.0 else ("Moderate" if dose_mg_m2 >= 250.0 else "Low")
        else:
            pogo_tier = "High (≥12 g/m²) / Moderate (250 mg/m²–<12 g/m²)"
        differs = uza_tier != pogo_tier
        explanation = "Both UZA v2 and POGO classify Methotrexate ≥12 g/m² as High; UZA v2 splits <250 mg/m² (Low) and <50 mg/m² (Minimal)."
    else:
        pogo_tier = POGO_SINGLE_AGENT_TIERS.get(norm, uza_tier)
        differs = not pogo_tier.startswith(uza_tier)
        explanation = (
            "Concordant classification between UZA v2 (2026) and POGO 250111."
            if not differs
            else f"UZA v2 classifies as {uza_tier}; POGO 250111 classifies as {pogo_tier}."
        )

    return PogoComparisonItem(
        drug=drug_name,
        dose_mg_m2=dose_mg_m2,
        uza_v2_tier=uza_tier,
        pogo_tier=pogo_tier,
        differs=differs,
        explanation=explanation,
        uza_citation=uza_cite,
        pogo_citation=f"{POGO_CITATION} · Table 1–4",
    )


def compare_regimen_uza_vs_pogo(drugs: List[ChemoDrugInput]) -> Dict[str, Any]:
    """Produces a complete Story 5 side-by-side comparison table for a regimen."""
    rows = [
        compare_drug_uza_vs_pogo(d.drug, d.dose_mg_m2, d.route)
        for d in drugs
    ]
    norm_set = {normalize_drug_name(d.drug) for d in drugs}
    combo_notes: List[str] = []
    if {"ifosfamide", "etoposide"}.issubset(norm_set):
        combo_notes.append(
            "Both UZA v2 p.1 ('Combinatie: Ifosfamide/Etoposide') and POGO 250111 escalate "
            "Ifosfamide (MEC) + Etoposide (LEC) to High Emetogenic Risk (HEC, Casus 3)."
        )

    prophylaxis_diff = {
        "uza_v2_hec_backbone": (
            "Quadruple therapy: Ondansetron (5 mg/m² max 8 mg 3x/d) + Dexamethasone + "
            "Aprepitant + Olanzapine (0.1 mg/kg rounded down to 0.5 mg, if ≥2y) [UZA v2 p.1–2]"
        ),
        "pogo_hec_backbone": (
            "Triple therapy: 5-HT3 antagonist (Ondansetron 0.15 mg/kg q8h) + Dexamethasone + "
            "Aprepitant (if ≥6 months); Olanzapine reserved for refractory/breakthrough CINV [POGO]"
        ),
        "source_of_truth_rule": "UZA Anti-emetica beleid CINV v2 (Juli 2026) is the active clinical source of truth (Ground Rule #6).",
    }

    return {
        "per_drug_comparison": [r.model_dump() for r in rows],
        "has_differences": any(r.differs for r in rows),
        "combination_notes": combo_notes,
        "prophylaxis_comparison": prophylaxis_diff,
        "advisory_status": ADVISORY_LABEL,
    }
