"""Pure-Python deterministic rules engine for AImesis (UZA July 2026 v2 & POGO 250111).

No LLM, no HTTP framework, no database dependencies.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from .breakthrough import evaluate_breakthrough_and_personalization
from .dexamethasone import evaluate_dexamethasone_contraindication
from .dosing import calculate_uza_dosing, round_down_to_half_mg
from .interactions import (
     QTC_RISK_REGISTRY,
    assess_qtc_risk,
    check_antimicrobial_ddi,
    check_ddi_interactions,
)
from .models import (
    ADVISORY_LABEL,
    BCFI_CITATION,
    ChemoDrugInput,
    DdiAlert,
    DexamethasoneEvaluation,
    DoseLine,
    DosingScheduleResult,
    DrugClassification,
    EmetogenicTier,
    POGO_CITATION,
    PogoComparisonItem,
    RefusalReason,
    RegimenClassification,
    UZA_POLICY_CITATION,
)
from .pogo_compare import compare_drug_uza_vs_pogo, compare_regimen_uza_vs_pogo
from .uza_policy import (
    classify_regimen_uza_v2,
    classify_single_drug_uza_v2,
    evaluate_combination_rule,
    normalize_drug_name,
)

# Curated Belgian Hospital CINV Patient Resources from `CINV resources in Belgium.xlsx`
BELGIAN_CINV_PATIENT_RESOURCES: List[Dict[str, str]] = [
    {
        "hospital": "UZA (Koningin Mathilde Moeder- en kindcentrum)",
        "title": "Anti-emetica beleid CINV v2 (Juli 2026) & Kinderoncologie Portal",
        "lang": "NL",
        "url": "https://www.uza.be/oncologie-hematologie-kinderen",
        "access_tier": "GREEN_CLINICAL_BASELINE",
    },
    {
        "hospital": "ZAS (Antwerp Shared-Care Network with UZA)",
        "title": "Chemotherapie: Informatie voor patiënten (PDF)",
        "lang": "NL",
        "url": "https://media.zas.be/m/1be42769d38ec4ee/original/Chemotherapie.pdf",
        "access_tier": "GREEN_DIRECT_PDF",
    },
    {
        "hospital": "CHU de Liège",
        "title": "Les nausées et les vomissements (Brochure A5 2024)",
        "lang": "FR",
        "url": "https://www.chuliege.be/cms/c_60648/fr/broch-a5-les-nausees-et-les-vomissements-2024-pp",
        "access_tier": "GREEN_DIRECT_PDF",
    },
    {
        "hospital": "Stichting tegen Kanker / Fondation contre le Cancer",
        "title": "Misselijkheid en braken / Nausées et vomissements",
        "lang": "NL/FR/DE",
        "url": "https://www.cancer.be/kanker/bijwerkingen/misselijkheid-en-braken",
        "access_tier": "GREEN_TRILINGUAL",
    },
    {
        "hospital": "KickCancer Foundation",
        "title": "Family Support & Research Hub",
        "lang": "EN/FR/NL",
        "url": "https://kickcancer.org/en",
        "access_tier": "GREEN_TRILINGUAL",
    },
    {
        "hospital": "UZ Leuven (KIDZ)",
        "title": "Misselijkheid en braken bij chemotherapie",
        "lang": "NL",
        "url": "https://www.uzleuven.be/nl/chemotherapie/bijwerkingen/misselijkheid-en-braken",
        "access_tier": "AMBER_LANGUAGE_RESET_NOTE",
    },
]


def evaluate_uza_cinv_policy_v2(
    drug_list: List[str],
    patient_age_years: Optional[float] = None,
    patient_weight_kg: Optional[float] = None,
    bsa_m2: Optional[float] = None,
    drug_doses_mg_m2: Optional[Dict[str, float]] = None,
    drug_days: Optional[Dict[str, List[int]]] = None,
    indication: str = "solid_tumor",
    can_swallow_tablets: bool = True,
    prior_breakthrough_cinv: bool = False,
    prior_ondansetron_2xd_on_hec: bool = False,
    anticipatory_vomiting: bool = False,
    chemo_duration_days: int = 1,
    concomitant_meds: Optional[List[str]] = None,
    strict_validation: bool = False,
) -> Dict[str, Any]:
    """High-level deterministic pipeline combining Stories 1, 2, 3, 5, and 6.

    When `strict_validation=True`, refuses to calculate if BSA, weight, age, or a
    required dose-dependent cytostatic dose is missing, or if an unknown drug is passed.
    """
    doses_norm = {
        normalize_drug_name(k): float(v)
        for k, v in (drug_doses_mg_m2 or {}).items()
        if v is not None
    }
    days_norm = {
        normalize_drug_name(k): v
        for k, v in (drug_days or {}).items()
    }

    chemo_inputs = [
        ChemoDrugInput(
            drug=d,
            dose_mg_m2=doses_norm.get(normalize_drug_name(d)),
            days=days_norm.get(normalize_drug_name(d), list(range(1, chemo_duration_days + 1))),
        )
        for d in drug_list
    ]

    regimen_cls = classify_regimen_uza_v2(
        drugs=chemo_inputs,
        strict_missing_dose=strict_validation,
    )

    if regimen_cls.refused:
        return {
            "refused": True,
            "refusal_reasons": [r.model_dump() for r in regimen_cls.refusal_reasons],
            "policy_version": UZA_POLICY_CITATION,
            "advisory_status": ADVISORY_LABEL,
        }

    # Check biometrics
    if not strict_validation:
        age = 9.0 if patient_age_years is None else patient_age_years
        weight = 28.0 if patient_weight_kg is None else patient_weight_kg
        bsa = 1.02 if bsa_m2 is None else bsa_m2
    else:
        age = patient_age_years
        weight = patient_weight_kg
        bsa = bsa_m2

    assert regimen_cls.overall_tier is not None

    dosing_res = calculate_uza_dosing(
        tier=regimen_cls.overall_tier,
        patient_age_years=age,
        patient_weight_kg=weight,
        bsa_m2=bsa,
        indication=indication,
        regimen_drugs=drug_list,
        concomitant_meds=concomitant_meds or [],
        can_swallow_tablets=can_swallow_tablets,
        chemo_duration_days=chemo_duration_days,
        prior_breakthrough_cinv=prior_breakthrough_cinv,
        anticipatory_vomiting=anticipatory_vomiting,
    )

    if dosing_res.refused:
        return {
            "refused": True,
            "refusal_reasons": [r.model_dump() for r in dosing_res.refusal_reasons],
            "policy_version": UZA_POLICY_CITATION,
            "advisory_status": ADVISORY_LABEL,
        }

    assert age is not None and weight is not None and bsa is not None
    personalization = evaluate_breakthrough_and_personalization(
        baseline_tier=regimen_cls.overall_tier,
        patient_age_years=age,
        patient_weight_kg=weight,
        can_swallow_tablets=can_swallow_tablets,
        prior_breakthrough_cinv=prior_breakthrough_cinv,
        prior_ondansetron_2xd_on_hec=prior_ondansetron_2xd_on_hec,
        chemo_duration_days=chemo_duration_days,
        anticipatory_vomiting=anticipatory_vomiting,
    )

    pogo_diff = compare_regimen_uza_vs_pogo(chemo_inputs)

    proposed_antiemetics = [
        key for key, line in dosing_res.lines.items() if line.indicated
    ]
    ddi_res = check_ddi_interactions(
        primary_drugs=list(drug_list) + list(concomitant_meds or []),
        proposed_antiemetics=proposed_antiemetics,
    )

    uza_tiers_map = {c.canonical_name: c.tier.value for c in regimen_cls.per_drug}
    assert dosing_res.dexamethasone_evaluation is not None

    return {
        "refused": False,
        "refusal_reasons": [],
        "policy_version": f"UZA Koningin Mathilde Moeder- en kindcentrum {UZA_POLICY_CITATION}",
        "overall_tier": regimen_cls.overall_tier.value,
        "per_day_tier": {str(k): v.value for k, v in regimen_cls.per_day_tier.items()},
        "uza_drug_tiers": uza_tiers_map,
        "per_drug_details": [c.model_dump() for c in regimen_cls.per_drug],
        "combination_elevated": regimen_cls.combination_elevated,
        "combination_rule_applied": regimen_cls.combination_rule_applied,
        "baseline_prophylaxis_summary": regimen_cls.baseline_prophylaxis_summary,
        "dexamethasone_contraindicated": dosing_res.dexamethasone_evaluation.contraindicated,
        "dexamethasone_reasons": dosing_res.dexamethasone_evaluation.reasons,
        "dosing_schedule": {
            k: line.dose_text for k, line in dosing_res.lines.items()
        },
        "dosing_lines": {
            k: line.model_dump() for k, line in dosing_res.lines.items()
        },
        "personalization_overrides": personalization["personalization_overrides"],
        "breakthrough_steps": personalization["breakthrough_steps"],
        "pogo_comparison": pogo_diff,
        "ddi_screening": ddi_res,
        "advisory_status": ADVISORY_LABEL,
    }


def generate_cinv_patient_passport(
    patient_alias: str,
    uza_evaluation: Dict[str, Any],
    ddi_alerts: Optional[List[Dict[str, Any]]] = None,
    qtc_assessment: Optional[Dict[str, Any]] = None,
    language: str = "NL",
    oncologist_signed_by: Optional[str] = None,
    pharmacist_signed_by: Optional[str] = None,
) -> Dict[str, Any]:
    """Story 4: Generates a single-page CINV Patient Passport summary with dual sign-off status."""
    if uza_evaluation.get("refused"):
        return {
            "refused": True,
            "refusal_reasons": uza_evaluation.get("refusal_reasons", []),
            "advisory_status": ADVISORY_LABEL,
        }

    sched = uza_evaluation.get("dosing_schedule", {})
    alerts = ddi_alerts if ddi_alerts is not None else uza_evaluation.get("ddi_screening", {}).get("interactions_found", [])
    qtc = qtc_assessment if qtc_assessment is not None else uza_evaluation.get("ddi_screening", {}).get("qtc_assessment", {"risk_tier": "LOW", "cumulative_score": 0})

    dual_signoff_complete = bool(oncologist_signed_by and pharmacist_signed_by)

    return {
        "passport_id": f"UZA-CINV-PASS-{patient_alias.upper().replace(' ', '-').replace('(', '').replace(')', '')}",
        "patient_alias": patient_alias,
        "language": language.upper(),
        "title": "AImesis Pediatric CINV Patient Passport (UZA v2 July 2026)",
        "emetogenicity_tier": uza_evaluation["overall_tier"],
        "dexamethasone_blocked": uza_evaluation["dexamethasone_contraindicated"],
        "active_orders": [
            sched.get("ondansetron", ""),
            sched.get("dexamethasone", ""),
            sched.get("aprepitant", ""),
            sched.get("olanzapine", ""),
        ],
        "personalization_notes": uza_evaluation.get("personalization_overrides", []),
        "safety_gate": {
            "qtc_risk_tier": qtc.get("risk_tier", "LOW"),
            "ddi_alert_count": len(alerts),
        },
        "sign_off": {
            "oncologist_signed_by": oncologist_signed_by,
            "pharmacist_signed_by": pharmacist_signed_by,
            "export_unlocked": dual_signoff_complete,
            "requirement_note": "Dual sign-off required (pediatric oncologist + clinical pharmacist) before export.",
        },
        "belgian_family_resources": BELGIAN_CINV_PATIENT_RESOURCES[:5],
        "navigation_tip": (
            "Brussels Bilingual Redirection Note: Use direct deep-links for HUDERF, Saint-Luc, and UZ Brussel "
            "(toggling EN/FR/NL flags on hospital portals resets to the main homepage)."
        ),
        "advisory_status": ADVISORY_LABEL,
    }


__all__ = [
    "ADVISORY_LABEL",
    "BCFI_CITATION",
    "BELGIAN_CINV_PATIENT_RESOURCES",
    "ChemoDrugInput",
    "DdiAlert",
    "DexamethasoneEvaluation",
    "DoseLine",
    "DosingScheduleResult",
    "DrugClassification",
    "EmetogenicTier",
    "POGO_CITATION",
    "PogoComparisonItem",
    "QTC_RISK_REGISTRY",
    "RefusalReason",
    "RegimenClassification",
    "UZA_POLICY_CITATION",
    "assess_qtc_risk",
    "calculate_uza_dosing",
    "check_antimicrobial_ddi",
    "check_ddi_interactions",
    "classify_regimen_uza_v2",
    "classify_single_drug_uza_v2",
    "compare_drug_uza_vs_pogo",
    "compare_regimen_uza_vs_pogo",
    "evaluate_breakthrough_and_personalization",
    "evaluate_combination_rule",
    "evaluate_dexamethasone_contraindication",
    "evaluate_uza_cinv_policy_v2",
    "generate_cinv_patient_passport",
    "normalize_drug_name",
    "round_down_to_half_mg",
]
