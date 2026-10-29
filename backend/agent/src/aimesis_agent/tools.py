"""ADK FunctionTool wrappers over the deterministic aimesis_rules package.

All clinical numbers, risk categories, dose schedules, and alerts come strictly
from `aimesis_rules`.
"""

from __future__ import annotations

import math
from typing import Any, Dict, List, Optional

from aimesis_rules import (
    ChemoDrugInput,
    EmetogenicTier,
    calculate_uza_dosing,
    check_ddi_interactions as _check_ddi_interactions,
    classify_regimen_uza_v2,
    compare_regimen_uza_vs_pogo,
    evaluate_uza_cinv_policy_v2 as _evaluate_uza_cinv_policy_v2,
    generate_cinv_patient_passport as _generate_cinv_patient_passport,
    normalize_drug_name,
)

from aimesis_agent.a2ui.surfaces import build_clinical_plan_surfaces
from aimesis_agent.notes_extraction import extract_prior_cycle_signals_from_note
from aimesis_agent.patient_store import (
    PatientValidationError,
    mosteller_bsa,
    patient_store,
)


def classify_regimen_emetogenicity(
    chemo_drugs_list: List[str],
    drug_doses_mg_m2: Optional[Dict[str, float]] = None,
    drug_routes: Optional[Dict[str, str]] = None,
    strict_missing_dose: bool = False,
) -> Dict[str, Any]:
    """Classify the acute emetogenic risk of a pediatric chemotherapy regimen
    per UZA July 2026 v2 Table 1 and compare against POGO 250111.
    """
    doses = {
        normalize_drug_name(k): float(v)
        for k, v in (drug_doses_mg_m2 or {}).items()
        if v is not None
    }
    routes = {
        normalize_drug_name(k): str(v)
        for k, v in (drug_routes or {}).items()
    }
    inputs = [
        ChemoDrugInput(
            drug=d,
            dose_mg_m2=doses.get(normalize_drug_name(d)),
            route=routes.get(normalize_drug_name(d), "IV"),
        )
        for d in chemo_drugs_list
    ]
    cls = classify_regimen_uza_v2(inputs, strict_missing_dose=strict_missing_dose)
    pogo_comp = compare_regimen_uza_vs_pogo(inputs)
    res = cls.model_dump()
    res["pogo_comparison"] = pogo_comp
    return res


def check_ddi_interactions(
    primary_drugs: List[str],
    proposed_antiemetics: List[str],
    baseline_qtc_ms: Optional[float] = None,
) -> Dict[str, Any]:
    """Screen a combined medication list for CYP3A4 / aprepitant interactions,
    vinca-azole neurotoxicity, duplicate 5-HT3 blockade, and additive QTc prolongation.
    """
    return _check_ddi_interactions(
        primary_drugs=primary_drugs,
        proposed_antiemetics=proposed_antiemetics,
        baseline_qtc_ms=baseline_qtc_ms,
    )


def get_pogo_guideline_recommendation(
    emetogenic_tier: str,
    age: float = 9.0,
    route: str = "IV",
    chemo_drugs_list: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """Compare UZA July 2026 v2 and POGO 250111 pediatric CINV recommendations."""
    drugs = chemo_drugs_list or []
    if not drugs:
        tier_norm = emetogenic_tier.strip().upper()
        if tier_norm in {"HIGH", "HEC"}:
            drugs = ["cisplatin"]
        elif tier_norm in {"MODERATE", "MEC"}:
            drugs = ["daunorubicin"]
        elif tier_norm in {"LOW", "LEC"}:
            drugs = ["vincristine"]
        else:
            drugs = ["fludarabine"]
    inputs = [ChemoDrugInput(drug=d, route=route) for d in drugs]
    comp = compare_regimen_uza_vs_pogo(inputs)
    comp["patient_age_years"] = age
    return comp


def calculate_risk_adjusted_regimen(
    base_emetogenic_tier: str,
    patient_age_years: float,
    patient_weight_kg: float,
    bsa_m2: Optional[float] = None,
    height_cm: Optional[float] = None,
    indication: str = "solid_tumor",
    regimen_drugs: Optional[List[str]] = None,
    concomitant_meds: Optional[List[str]] = None,
    can_swallow_tablets: bool = True,
    chemo_duration_days: int = 1,
    prior_breakthrough_cinv: bool = False,
    anticipatory_vomiting: bool = False,
) -> Dict[str, Any]:
    """Calculate exact UZA v2 pediatric antiemetic doses, steroid contraindications,
    and risk adjustments.
    """
    if bsa_m2 is None and height_cm is not None and height_cm > 0 and patient_weight_kg > 0:
        bsa_m2 = round(math.sqrt((height_cm * patient_weight_kg) / 3600.0), 2)

    tier_map = {
        "HIGH": EmetogenicTier.HIGH,
        "HEC": EmetogenicTier.HIGH,
        "MODERATE": EmetogenicTier.MODERATE,
        "MEC": EmetogenicTier.MODERATE,
        "LOW": EmetogenicTier.LOW,
        "LEC": EmetogenicTier.LOW,
        "MINIMAL": EmetogenicTier.MINIMAL,
    }
    tier = tier_map.get(base_emetogenic_tier.strip().upper(), EmetogenicTier.MODERATE)

    dosing = calculate_uza_dosing(
        tier=tier,
        patient_age_years=patient_age_years,
        patient_weight_kg=patient_weight_kg,
        bsa_m2=bsa_m2,
        indication=indication,
        regimen_drugs=regimen_drugs or [],
        concomitant_meds=concomitant_meds or [],
        can_swallow_tablets=can_swallow_tablets,
        chemo_duration_days=chemo_duration_days,
        prior_breakthrough_cinv=prior_breakthrough_cinv,
        anticipatory_vomiting=anticipatory_vomiting,
    )
    return dosing.model_dump()


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
    include_a2ui_surfaces: bool = True,
) -> Dict[str, Any]:
    """Evaluate a complete pediatric CINV case under the UZA July 2026 v2 policy
    and POGO 250111 benchmark, including declarative A2UI surfaces.
    """
    res = _evaluate_uza_cinv_policy_v2(
        drug_list=drug_list,
        patient_age_years=patient_age_years,
        patient_weight_kg=patient_weight_kg,
        bsa_m2=bsa_m2,
        drug_doses_mg_m2=drug_doses_mg_m2,
        drug_days=drug_days,
        indication=indication,
        can_swallow_tablets=can_swallow_tablets,
        prior_breakthrough_cinv=prior_breakthrough_cinv,
        prior_ondansetron_2xd_on_hec=prior_ondansetron_2xd_on_hec,
        anticipatory_vomiting=anticipatory_vomiting,
        chemo_duration_days=chemo_duration_days,
        concomitant_meds=concomitant_meds,
        strict_validation=strict_validation,
    )
    if include_a2ui_surfaces:
        res["a2ui_surfaces"] = build_clinical_plan_surfaces(res)
    return res


def generate_cinv_patient_passport(
    patient_alias: str,
    uza_evaluation: Dict[str, Any],
    language: str = "NL",
    oncologist_signed_by: Optional[str] = None,
    pharmacist_signed_by: Optional[str] = None,
) -> Dict[str, Any]:
    """Generate a family-friendly multilingual (NL/FR/EN) CINV Patient Passport
    with dual sign-off status.
    """
    return _generate_cinv_patient_passport(
        patient_alias=patient_alias,
        uza_evaluation=uza_evaluation,
        language=language,
        oncologist_signed_by=oncologist_signed_by,
        pharmacist_signed_by=pharmacist_signed_by,
    )


def get_patient_context(patient_id: str) -> Dict[str, Any]:
    """Load a pseudonymised patient's clinical context (age, weight, BSA,
    diagnosis, planned chemo regimen, prior-cycle CINV history, allergies,
    preferred formulation) from the patient database.

    Also returns `evaluation_inputs`: arguments ready to pass to
    `evaluate_uza_cinv_policy_v2`.
    """
    record = patient_store.get(patient_id)
    if record is None:
        return {"found": False, "patient_id": patient_id}

    regimen = record.get("chemo_regimen") or []
    history = record.get("history_previous_cycles") or {}
    all_days = [d for item in regimen for d in item.get("day_numbers") or []]
    evaluation_inputs = {
        "drug_list": [item["drug_name"] for item in regimen],
        "patient_age_years": record.get("age_years"),
        "patient_weight_kg": record.get("weight_kg"),
        "bsa_m2": record.get("bsa_m2"),
        "drug_doses_mg_m2": {
            item["drug_name"]: item["dose_mg_per_m2"]
            for item in regimen
            if item.get("dose_mg_per_m2") is not None
        },
        "drug_days": {item["drug_name"]: item.get("day_numbers") or [] for item in regimen},
        "chemo_duration_days": (max(all_days) - min(all_days) + 1) if all_days else 1,
        "can_swallow_tablets": record.get("preferred_formulation") == "oral_tablet",
        "prior_breakthrough_cinv": bool(history.get("had_refractory_cinv", False)),
        "anticipatory_vomiting": bool(history.get("anticipatory_nausea", False)),
    }
    return {"found": True, "patient": record, "evaluation_inputs": evaluation_inputs}


def save_patient_context(
    patient_id: str,
    age_years: Optional[float] = None,
    weight_kg: Optional[float] = None,
    bsa_m2: Optional[float] = None,
    height_cm: Optional[float] = None,
    chemo_regimen: Optional[List[Dict[str, Any]]] = None,
    display_pseudonym: Optional[str] = None,
    diagnosis: Optional[str] = None,
    protocol_name: Optional[str] = None,
    current_cycle: Optional[int] = None,
    history_previous_cycles: Optional[Dict[str, Any]] = None,
    allergies_and_contraindications: Optional[List[str]] = None,
    preferred_formulation: Optional[str] = None,
) -> Dict[str, Any]:
    """Create or update a pseudonymised patient's clinical context. Only the
    provided fields are changed; omitted fields keep their stored value.

    `chemo_regimen` items: {"drug_name": str, "dose_mg_per_m2": float,
    "day_numbers": [int], "infusion_duration_hours": float (optional)}.
    `history_previous_cycles`: {"had_refractory_cinv": bool,
    "prior_episode_count": int, "anticipatory_nausea": bool, "notes": str}.
    `preferred_formulation`: oral_liquid | oral_tablet | iv | orodispersible.
    BSA is derived via Mosteller when `height_cm` and weight are given.
    Never store names or other direct identifiers.
    """
    if bsa_m2 is None and height_cm and height_cm > 0:
        weight = weight_kg or (patient_store.get(patient_id) or {}).get("weight_kg")
        if weight:
            bsa_m2 = mosteller_bsa(height_cm, weight)

    updates = {
        "patient_id": patient_id,
        "age_years": age_years,
        "weight_kg": weight_kg,
        "bsa_m2": bsa_m2,
        "chemo_regimen": chemo_regimen,
        "display_pseudonym": display_pseudonym,
        "diagnosis": diagnosis,
        "protocol_name": protocol_name,
        "current_cycle": current_cycle,
        "history_previous_cycles": history_previous_cycles,
        "allergies_and_contraindications": allergies_and_contraindications,
        "preferred_formulation": preferred_formulation,
    }
    try:
        record = patient_store.upsert(updates)
    except PatientValidationError as exc:
        return {"saved": False, "patient_id": patient_id, "errors": str(exc)}
    return {"saved": True, "patient": record}


__all__ = [
    "calculate_risk_adjusted_regimen",
    "check_ddi_interactions",
    "classify_regimen_emetogenicity",
    "evaluate_uza_cinv_policy_v2",
    "extract_prior_cycle_signals_from_note",
    "generate_cinv_patient_passport",
    "get_patient_context",
    "get_pogo_guideline_recommendation",
    "save_patient_context",
]
