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
    RefusalReason,
    RegimenClassification,
    calculate_uza_dosing,
    check_ddi_interactions as _check_ddi_interactions,
    classify_regimen_uza_v2,
    compare_regimen_uza_vs_pogo,
    evaluate_uza_cinv_policy_v2 as _evaluate_uza_cinv_policy_v2,
    normalize_drug_name,
)
from aimesis_rules.passport_contract import (
    build_agent_passport,
    evaluation_inputs_from_patient_context,
    refusal_document,
)
from pydantic import ValidationError

from aimesis_agent.a2ui.surfaces import build_clinical_plan_surfaces
from aimesis_agent.notes_extraction import extract_prior_cycle_signals_from_note
from aimesis_agent.patient_store import (
    PatientValidationError,
    latest_bsa,
    mosteller_bsa,
    patient_store,
)


def classify_regimen_emetogenicity(
    chemo_drugs_list: List[str],
    drug_doses_mg_m2: Optional[Dict[str, float]] = None,
    drug_routes: Optional[Dict[str, str]] = None,
    strict_missing_dose: bool = True,
    drug_days: Optional[Dict[str, List[int]]] = None,
) -> Dict[str, Any]:
    """Classify the acute emetogenic risk of a pediatric chemotherapy regimen
    per UZA July 2026 v2 page 1. Supply doses for dose-dependent drugs and
    the actual route and treatment days. Returns baseline strategy and source
    rules without requiring age, weight or BSA. Refuses rather than guessing.
    """
    doses = {
        normalize_drug_name(k): v
        for k, v in (drug_doses_mg_m2 or {}).items()
        if v is not None
    }
    routes = {
        normalize_drug_name(k): str(v)
        for k, v in (drug_routes or {}).items()
    }
    days = {normalize_drug_name(k): v for k, v in (drug_days or {}).items()}
    try:
        inputs = [
            ChemoDrugInput(
                drug=d,
                dose_mg_m2=doses.get(normalize_drug_name(d)),
                route=routes.get(normalize_drug_name(d), "IV"),
                days=days.get(normalize_drug_name(d), [1]),
            )
            for d in chemo_drugs_list
        ]
    except ValueError:
        return RegimenClassification(
            refused=True,
            refusal_reasons=[RefusalReason(
                field="regimen",
                message="Provide finite positive doses and non-empty lists of positive integer treatment days.",
            )],
        ).model_dump()

    cls = classify_regimen_uza_v2(inputs, strict_missing_dose=strict_missing_dose)
    return cls.model_dump()


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
    drug_routes: Optional[Dict[str, str]] = None,
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
        drug_routes=drug_routes,
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


def generate_cinv_patient_passport(patient_id: str) -> Dict[str, Any]:
    """Build the CINV Patient Passport for a stored patient (call
    `save_patient_context` first if the data is new or corrected).

    Runs every deterministic rule (classification, dosing, dexamethasone,
    breakthrough, DDI/QTc, POGO comparison) on the stored record and returns
    the contract document (`aimesis_rules.passport_models`, contract
    contracts/schemas/agent_passport.schema.json):
    an unsigned draft with all clinician-review sections, or a refusal with
    its reasons and no doses. Present it as is; never change its values.
    `review_flags` lists what the clinician must judge before sign-off.
    """
    record = patient_store.get(patient_id)
    try:
        if record is None:
            passport = refusal_document(
                patient_id,
                [{"field": "patient_id", "message": f"No patient record for '{patient_id}'.",
                  "citation": "AImesis patient store"}],
            )
        else:
            passport = build_agent_passport(record)
    except ValidationError as exc:
        return {
            "contract_valid": False,
            "patient_id": patient_id,
            "errors": [f"{'/'.join(map(str, e['loc']))}: {e['msg']}" for e in exc.errors()],
            "message": "Passport failed contract validation and was withheld. Do not improvise a plan.",
        }
    return passport.to_contract()


def get_patient_dosing(
    patient_id: str,
    antiemetic_route: str = "PO",
    aprepitant_route: str = "PO",
    fosaprepitant_schedule: str = "multi_day",
    use_palonosetron_switch: bool = False,
    mec_prefer_aprepitant: bool = False,
) -> Dict[str, Any]:
    """Story 2: calculate doses using the patient's latest recorded BSA.

    Fetches fresh age, weight, diagnosis and regimen from the shared record.
    Returns BSA provenance and numerical calculations/formulas, caps and rules.
    Never provide guessed measurements; save corrected patient context first.
    """
    from aimesis_api.patients.service import calculate_patient_dosing

    try:
        return calculate_patient_dosing(
            patient_id, store=patient_store, antiemetic_route=antiemetic_route,
            aprepitant_route=aprepitant_route, fosaprepitant_schedule=fosaprepitant_schedule,
            use_palonosetron_switch=use_palonosetron_switch, mec_prefer_aprepitant=mec_prefer_aprepitant,
        )
    except Exception:
        return {"refused": True, "patient_id": patient_id, "refusal_reasons": [{"field": "patient_record", "message": "Patient storage is unavailable. Do not guess measurements."}]}


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

    try:
        observation = latest_bsa(record)
        record = {**record, "bsa_m2": observation["bsa_m2"], "latest_bsa": observation}
    except PatientValidationError as exc:
        return {"found": True, "patient": record, "refused": True, "errors": str(exc)}
    evaluation_inputs, inputs = evaluation_inputs_from_patient_context(record)
    defaulted = [i["field"] for i in inputs if i["source"] == "default"]
    return {
        "found": True,
        "patient": record,
        "evaluation_inputs": evaluation_inputs,
        "defaulted_inputs": defaulted,
    }


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
    diagnosis_group: Optional[str] = None,
    bsa_measured_at: Optional[str] = None,
    bsa_measurements: Optional[List[Dict[str, Any]]] = None,
    active_medications: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """Create or update a pseudonymised patient's clinical context. Only the
    provided fields are changed; omitted fields keep their stored value.

    `chemo_regimen` items: {"drug_name": str, "dose_mg_per_m2": float,
    "day_numbers": [int], "infusion_duration_hours": float (optional)}.
    `history_previous_cycles`: {"had_refractory_cinv": bool,
    "prior_episode_count": int, "anticipatory_nausea": bool, "notes": str}.
    `preferred_formulation`: oral_liquid | oral_tablet | iv | orodispersible.
    `diagnosis_group` (e.g. solid, ALL, brain_tumour) and `diagnosis` drive the
    dexamethasone contraindication check; `active_medications` (e.g.
    voriconazole) drive the interaction check.
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
        "bsa_measured_at": bsa_measured_at,
        "bsa_measurements": bsa_measurements,
        "chemo_regimen": chemo_regimen,
        "display_pseudonym": display_pseudonym,
        "diagnosis": diagnosis,
        "protocol_name": protocol_name,
        "current_cycle": current_cycle,
        "history_previous_cycles": history_previous_cycles,
        "allergies_and_contraindications": allergies_and_contraindications,
        "preferred_formulation": preferred_formulation,
        "diagnosis_group": diagnosis_group,
        "active_medications": active_medications,
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
    "get_patient_dosing",
    "get_pogo_guideline_recommendation",
    "save_patient_context",
]
