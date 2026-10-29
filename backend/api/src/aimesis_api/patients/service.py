"""Record-backed Story 2 workflow, shared by HTTP and the ADK tool."""

from __future__ import annotations

from typing import Any

from aimesis_rules import (
    ADVISORY_LABEL,
    UZA_POLICY_CITATION,
    ChemoDrugInput,
    calculate_uza_dosing,
    classify_regimen_uza_v2,
)

from .store import PatientValidationError, latest_bsa, patient_store


def calculate_patient_dosing(
    patient_id: str,
    *,
    store=None,
    antiemetic_route: str = "PO",
    aprepitant_route: str = "PO",
    fosaprepitant_schedule: str = "multi_day",
    use_palonosetron_switch: bool = False,
    mec_prefer_aprepitant: bool = False,
) -> dict[str, Any]:
    """Fetch the current patient record on every request; never accept a BSA override."""
    repository = store if store is not None else patient_store
    record = repository.get(patient_id)
    result = {
        "patient_id": patient_id,
        "patient_found": record is not None,
        "refused": True,
        "refusal_reasons": [],
        "biometrics_used": None,
        "classification": None,
        "dosing": None,
        "policy_version": UZA_POLICY_CITATION,
        "advisory_status": ADVISORY_LABEL,
        "storage_mode": repository.storage_mode,
    }

    def refuse(field, message):
        result["refusal_reasons"] = [
            {
                "field": field,
                "message": message,
                "citation": f"{UZA_POLICY_CITATION} p.2",
            }
        ]
        return result

    if record is None:
        return refuse(
            "patient_id",
            "Patient record not found. Save or select a pseudonymous patient first.",
        )
    try:
        observation = latest_bsa(record)
    except PatientValidationError as exc:
        return refuse("bsa_m2", str(exc))
    indication = " / ".join(
        value
        for value in (record.get("diagnosis"), record.get("diagnosis_group"))
        if isinstance(value, str) and value.strip()
    )
    if not isinstance(indication, str) or not indication.strip():
        return refuse(
            "diagnosis",
            "The patient record needs a diagnosis to check the dexamethasone exclusion rules.",
        )
    try:
        drugs = [
            ChemoDrugInput(
                drug=item["drug_name"],
                dose_mg_m2=item.get("dose_mg_per_m2"),
                route=item.get("route", "IV"),
                days=item.get("day_numbers", []),
            )
            for item in record.get("chemo_regimen", [])
        ]
    except (KeyError, TypeError, ValueError):
        return refuse(
            "chemo_regimen",
            "The recorded chemotherapy regimen has missing or invalid names, doses, routes or days.",
        )
    classification = classify_regimen_uza_v2(drugs)
    result["classification"] = classification.model_dump()
    if classification.refused:
        result["refusal_reasons"] = [
            item.model_dump() for item in classification.refusal_reasons
        ]
        return result
    days = [day for item in drugs for day in item.days]
    history = record.get("history_previous_cycles") or {}
    dose_result = calculate_uza_dosing(
        tier=classification.overall_tier,
        patient_age_years=record.get("age_years"),
        patient_weight_kg=record.get("weight_kg"),
        bsa_m2=observation["bsa_m2"],
        indication=indication,
        regimen_drugs=[item.drug for item in drugs],
        concomitant_meds=record.get("active_medications") or [],
        can_swallow_tablets=record.get("preferred_formulation") == "oral_tablet",
        chemo_duration_days=max(days) - min(days) + 1,
        chemo_days=sorted(set(days)),
        prior_breakthrough_cinv=bool(history.get("had_refractory_cinv", False)),
        anticipatory_vomiting=bool(history.get("anticipatory_nausea", False)),
        antiemetic_route=antiemetic_route,
        aprepitant_route=aprepitant_route,
        fosaprepitant_schedule=fosaprepitant_schedule,
        use_palonosetron_switch=use_palonosetron_switch,
        mec_prefer_aprepitant=mec_prefer_aprepitant,
    )
    result.update(
        {
            "refused": dose_result.refused,
            "refusal_reasons": [
                item.model_dump() for item in dose_result.refusal_reasons
            ],
            "record_updated_at": record.get("updated_at"),
            "biometrics_used": {
                "age_years": record.get("age_years"),
                "weight_kg": record.get("weight_kg"),
                "bsa": observation,
            },
            "dosing": dose_result.model_dump(),
        }
    )
    return result
