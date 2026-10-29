"""Agent CINV passport: patient record -> passport model.

Builds the Pydantic models in `passport_models` (mirroring
`contracts/schemas/agent_passport.schema.json`, a strict profile of
`passport.schema.json`) straight from a stored `patient_context` record.
Every clinical value comes from the deterministic engine; nothing is taken
from an LLM. The output is either:

- a `DraftPassport` (unsigned; sign-off is a human action in the clinical API)
  with every section a clinician needs to judge the plan, or
- a `RefusalPassport` carrying the inputs, the reasons and the partial
  classification, but no tier and no doses (refuse rather than guess).
"""

from __future__ import annotations

import datetime
import math
import re
from typing import Any, Dict, List, Optional, Tuple, Union

from . import evaluate_uza_cinv_policy_v2
from .models import ADVISORY_LABEL, POGO_CITATION, UZA_POLICY_CITATION, ChemoDrugInput
from .passport_models import DraftPassport, RefusalPassport
from .uza_policy import classify_regimen_uza_v2, classify_single_drug_uza_v2

GENERATOR = "aimesis_rules.passport_contract.build_agent_passport"

# Defaulted inputs that change the plan and must be confirmed by the clinician.
FLAG_IF_DEFAULTED = {"indication", "concomitant_meds", "can_swallow_tablets", "prior_breakthrough_cinv", "anticipatory_vomiting"}

# Dose lines that belong in the family's prophylaxis schedule; the others are rescue/anticipatory.
PROPHYLAXIS_LINES = ("ondansetron", "palonosetron", "aprepitant", "dexamethasone", "olanzapine")

DAY_WORD = {"nl": "Dag", "fr": "Jour", "en": "Day"}
HEADLINE = {
    "nl": "Schema tegen misselijkheid (concept — pas geldig na goedkeuring door arts en apotheker)",
    "fr": "Plan contre les nausées (brouillon — valable après validation par le médecin et le pharmacien)",
    "en": "Anti-nausea schedule (draft — valid only after oncologist and pharmacist sign-off)",
}
IF_VOMITING = {
    "nl": "Geef de noodmedicatie zoals afgesproken met het zorgteam en bel de afdeling als het braken aanhoudt.",
    "fr": "Donnez le médicament de secours convenu avec l'équipe soignante et appelez le service si les vomissements persistent.",
    "en": "Give the rescue medicine agreed with the care team and call the ward if vomiting continues.",
}


def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def passport_id_for(patient_id: str, cycle_number: int) -> str:
    """PAT-2026-0001, cycle 4 -> PSP-2026-0001-C4 (same scheme as backend/mock_api)."""
    number = patient_id[4:] if patient_id.startswith("PAT-") else patient_id
    return f"PSP-{number}-C{cycle_number}"


def _input(inputs: List[Dict[str, Any]], field: str, value: Any, source: str, unit: str = "", note: str = "") -> Any:
    item: Dict[str, Any] = {"field": field, "value": value, "source": source}
    if unit:
        item["unit"] = unit
    if note:
        item["note"] = note
    inputs.append(item)
    return value


def evaluation_inputs_from_patient_context(record: Dict[str, Any]) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    """Map a `patient_context` record to `evaluate_uza_cinv_policy_v2` kwargs.

    Returns (kwargs, inputs) where `inputs` records every value with its source
    (`patient_record`, `derived` or `default`) for the clinician to check.
    """
    inputs: List[Dict[str, Any]] = []
    regimen = record.get("chemo_regimen") or []
    history = record.get("history_previous_cycles") or {}
    risk = record.get("risk_factors") or {}

    drug_list = [r["drug_name"] for r in regimen]
    _input(inputs, "chemo_regimen", [dict(r) for r in regimen], "patient_record")
    doses = {r["drug_name"]: r["dose_mg_per_m2"] for r in regimen if r.get("dose_mg_per_m2") is not None}
    days = {r["drug_name"]: list(r.get("day_numbers") or []) for r in regimen}
    routes = {r["drug_name"]: r.get("route", "IV") for r in regimen}
    all_days = [d for ds in days.values() for d in ds]
    duration = (max(all_days) - min(all_days) + 1) if all_days else 1
    _input(inputs, "chemo_duration_days", duration, "derived", "days", "first to last chemotherapy day")

    age = _input(inputs, "age_years", record.get("age_years"), "patient_record", "years")
    weight = _input(inputs, "weight_kg", record.get("weight_kg"), "patient_record", "kg")
    bsa = record.get("bsa_m2")
    height = record.get("height_cm")
    if bsa is not None:
        _input(inputs, "bsa_m2", bsa, "patient_record", "m²")
    elif height and weight:
        bsa = round(math.sqrt((height * weight) / 3600.0), 2)
        _input(inputs, "bsa_m2", bsa, "derived", "m²", f"Mosteller from height {height} cm and weight {weight} kg")
    else:
        _input(inputs, "bsa_m2", None, "patient_record", "m²", "missing")

    indication_parts = [str(record[k]) for k in ("diagnosis_group", "diagnosis", "protocol_name") if record.get(k)]
    if indication_parts:
        indication = _input(
            inputs, "indication", " · ".join(indication_parts), "derived",
            note="diagnosis group, diagnosis and protocol (used for the dexamethasone contraindication check)",
        )
    else:
        indication = _input(inputs, "indication", "solid_tumor", "default", note="no diagnosis on record")

    meds = record.get("active_medications")
    if meds is not None:
        concomitant = _input(inputs, "concomitant_meds", list(meds), "patient_record")
    else:
        concomitant = _input(inputs, "concomitant_meds", [], "default", note="no active medication list on record")

    if "can_swallow_tablets" in risk:
        can_swallow = _input(inputs, "can_swallow_tablets", bool(risk["can_swallow_tablets"]), "patient_record")
    elif record.get("preferred_formulation"):
        can_swallow = _input(
            inputs, "can_swallow_tablets", record["preferred_formulation"] == "oral_tablet", "derived",
            note=f"from preferred_formulation '{record['preferred_formulation']}'",
        )
    else:
        can_swallow = _input(inputs, "can_swallow_tablets", True, "default")

    if "had_refractory_cinv" in history:
        prior_bt = _input(inputs, "prior_breakthrough_cinv", bool(history["had_refractory_cinv"]), "patient_record")
    else:
        prior_bt = _input(inputs, "prior_breakthrough_cinv", False, "default", note="no previous-cycle history on record")

    if "anticipatory_nausea" in history:
        anticipatory = _input(inputs, "anticipatory_vomiting", bool(history["anticipatory_nausea"]), "patient_record")
    elif "anticipatory" in risk:
        anticipatory = _input(inputs, "anticipatory_vomiting", bool(risk["anticipatory"]), "patient_record")
    else:
        anticipatory = _input(inputs, "anticipatory_vomiting", False, "default")

    previous = record.get("previous_cycles") or []
    last_antiemetics = (previous[-1].get("antiemetics") or "") if previous else ""
    ond_2xd = bool(re.search(r"ondansetron\s*2x/d", last_antiemetics, re.IGNORECASE))
    if last_antiemetics:
        _input(inputs, "prior_ondansetron_2xd_on_hec", ond_2xd, "derived", note=f"previous cycle: '{last_antiemetics}'")
    else:
        _input(inputs, "prior_ondansetron_2xd_on_hec", False, "default")

    kwargs = {
        "drug_list": drug_list,
        "patient_age_years": age,
        "patient_weight_kg": weight,
        "bsa_m2": bsa,
        "drug_doses_mg_m2": doses,
        "drug_days": days,
        "drug_routes": routes,
        "indication": indication,
        "can_swallow_tablets": can_swallow,
        "prior_breakthrough_cinv": prior_bt,
        "prior_ondansetron_2xd_on_hec": ond_2xd,
        "anticipatory_vomiting": anticipatory,
        "chemo_duration_days": duration,
        "concomitant_meds": concomitant,
    }
    return kwargs, inputs


def _tier(value: Any) -> str:
    return str(getattr(value, "value", value)).upper()


def _classification(regimen: List[Dict[str, Any]]) -> Tuple[Dict[str, Any], List[Dict[str, str]]]:
    """Classification block, also for refused plans (known drugs are still shown)."""
    block: Dict[str, Any] = {"overall_tier": None, "drugs": [], "days": [], "combination_rules": []}
    try:
        inputs = [
            ChemoDrugInput(
                drug=r["drug_name"],
                dose_mg_m2=r.get("dose_mg_per_m2"),
                route=r.get("route", "IV"),
                days=list(r.get("day_numbers") or [1]),
            )
            for r in regimen
        ]
    except ValueError:
        return block, [{
            "field": "chemo_regimen",
            "message": "Provide finite positive doses and non-empty lists of positive integer treatment days.",
            "citation": f"{UZA_POLICY_CITATION} p.1",
        }]
    known: List[ChemoDrugInput] = []
    refusals: List[Dict[str, str]] = []
    for item in inputs:
        _, refusal = classify_single_drug_uza_v2(
            drug_name=item.drug, dose_mg_m2=item.dose_mg_m2, route=item.route, days=item.days, strict_missing_dose=True
        )
        if refusal is None:
            known.append(item)
        else:
            refusals.append(refusal.model_dump())

    if not inputs:
        refusals.append(
            {"field": "chemo_regimen", "message": "No chemotherapy agents on record.", "citation": UZA_POLICY_CITATION}
        )
    if not known:
        return block, refusals

    cls = classify_regimen_uza_v2(drugs=known, strict_missing_dose=True)
    block["drugs"] = [
        {"drug": d.input_name, "dose_mg_m2": d.dose_mg_m2, "days": list(d.days), "tier": _tier(d.tier),
         "rule_citation": d.rule_citation}
        for d in cls.per_drug
    ]
    block["days"] = [
        {"day": int(day), "tier": _tier(cls.per_day_tier[day]),
         "drugs": [d.input_name for d in cls.per_drug if day in d.days]}
        for day in sorted(cls.per_day_tier)
    ]
    if cls.combination_rule_applied:
        block["combination_rules"] = [cls.combination_rule_applied]
    if not refusals:
        block["overall_tier"] = _tier(cls.overall_tier)
    return block, refusals


def _route_options(route_text: str) -> List[str]:
    up = route_text.upper()
    options = []
    if "PO" in up:
        options.append("oral")
    if "IV" in up:
        options.append("iv")
    return options


def _choose_route(route_text: str, preferred: Optional[str], can_swallow: bool) -> str:
    options = _route_options(route_text)
    oral = "oral_tablet" if can_swallow else "oral_liquid"
    if preferred == "orodispersible":
        oral = "orodispersible"
    elif preferred in ("oral_tablet", "oral_liquid"):
        oral = preferred if (preferred != "oral_tablet" or can_swallow) else "oral_liquid"
    if preferred == "iv" and "iv" in options:
        return "iv"
    if "oral" in options:
        return oral
    return "iv"


def _generation() -> Dict[str, str]:
    return {
        "generated_at": _now_iso(),
        "generator": GENERATOR,
        "policy_version": UZA_POLICY_CITATION,
        "benchmark_version": POGO_CITATION,
        "advisory_status": ADVISORY_LABEL,
    }


def _input_flags(inputs: List[Dict[str, Any]]) -> List[Dict[str, str]]:
    flags = []
    for i in inputs:
        if i["source"] == "default" and i["field"] in FLAG_IF_DEFAULTED:
            flags.append({"severity": "warning", "code": "input_defaulted",
                          "message": f"'{i['field']}' not on record; assumed {i['value']!r}. {i.get('note', '')}".strip()})
        elif i["field"] == "bsa_m2" and i["source"] == "derived":
            flags.append({"severity": "info", "code": "bsa_derived", "message": i.get("note", "BSA derived")})
    return flags


def refusal_document(
    patient_id: str,
    reasons: List[Dict[str, str]],
    inputs: Optional[List[Dict[str, Any]]] = None,
    classification: Optional[Dict[str, Any]] = None,
    cycle_number: Optional[int] = None,
) -> RefusalPassport:
    inputs = inputs or []
    doc: Dict[str, Any] = {
        "patient_id": patient_id,
        "generation": _generation(),
        "inputs": inputs,
        "refusal": {"refused": True, "reasons": reasons},
        "review_flags": [
            {"severity": "critical", "code": "refused", "message": r["message"], "citation": r["citation"]}
            for r in reasons
        ] + _input_flags(inputs),
    }
    if cycle_number is not None:
        doc["cycle_number"] = cycle_number
    if classification is not None:
        doc["classification"] = classification
    return RefusalPassport.model_validate(doc)


def build_agent_passport(record: Dict[str, Any]) -> Union[DraftPassport, RefusalPassport]:
    """Patient context record -> `DraftPassport`, or `RefusalPassport` (refuse rather than guess).

    Raises `pydantic.ValidationError` if the engine output does not fit the contract.
    """
    patient_id = record["patient_id"]
    cycle = int(record.get("current_cycle") or 1)
    kwargs, inputs = evaluation_inputs_from_patient_context(record)
    classification, cls_refusals = _classification(record.get("chemo_regimen") or [])

    ev = evaluate_uza_cinv_policy_v2(**kwargs, strict_validation=True)
    if cls_refusals or ev.get("refused"):
        reasons = cls_refusals or [
            {"field": r["field"], "message": r["message"], "citation": r["citation"]} for r in ev["refusal_reasons"]
        ]
        return refusal_document(patient_id, reasons, inputs, classification, cycle)

    preferred = record.get("preferred_formulation")
    can_swallow = kwargs["can_swallow_tablets"]
    lines: Dict[str, Dict[str, Any]] = ev["dosing_lines"]
    flags: List[Dict[str, str]] = []

    # --- prophylaxis schedule: one row per administration of each indicated line
    schedule = []
    for key in PROPHYLAXIS_LINES:
        line = lines.get(key)
        if not line or not line["indicated"]:
            continue
        for adm in line["administrations"]:
            schedule.append({
                "drug_name": line["drug"],
                "dose_amount": adm["dose_amount"],
                "dose_unit": adm["dose_unit"],
                "formula_used": line["formula_shown"],
                "route": _choose_route(line["route"], preferred, can_swallow),
                "frequency": line["frequency"],
                "cycle_days": adm["cycle_days"],
                "rule_citation": line["citation"],
                "day_label": adm["day_label"],
                "duration": line["duration"],
                "route_options": _route_options(line["route"]),
                "warnings": list(line["warnings"]),
            })

    lora = lines.get("lorazepam")
    if lora and lora["indicated"]:
        flags.append({"severity": "warning", "code": "dose_range_needs_choice",
                      "message": f"{lora['dose_text']} — the clinician must choose a dose within the range.",
                      "citation": lora["citation"]})

    # --- dexamethasone
    dex = lines["dexamethasone"]
    aprep = lines["aprepitant"]
    dex_reasons = list(ev["dexamethasone_reasons"])
    dexamethasone_rules = {
        "is_blocked": bool(ev["dexamethasone_contraindicated"]),
        "rationale": "; ".join(dex_reasons) if dex_reasons else (
            dex["formula_shown"] if dex["indicated"] else dex["dose_text"]
        ),
        "reasons": dex_reasons,
        "aprepitant_dose_reduction": bool(dex["indicated"] and aprep["indicated"]),
        "citation": dex["citation"],
    }
    if dex_reasons:
        flags.append({"severity": "info", "code": "dexamethasone_blocked", "message": "; ".join(dex_reasons),
                      "citation": dex["citation"]})

    # --- breakthrough
    steps = ev.get("breakthrough_steps") or []
    rescue = [
        {"step_number": i, "drug_name": s.get("drug", ""), "dose": s["action"], "route": s.get("route", ""),
         "rule_citation": s["citation"], "action": s["step"]}
        for i, s in enumerate(steps, start=1)
    ]
    if not rescue:
        flags.append({"severity": "warning", "code": "no_rescue_plan",
                      "message": "The rules engine only builds the UZA v2 breakthrough ladder after a prior breakthrough; "
                                 "define the rescue medication before discharge."})
    breakthrough_plan = {
        "rescue_steps": rescue,
        "instructions": IF_VOMITING["en"] if rescue else
        "No rescue ladder computed — rescue medication to be specified by the care team.",
    }

    # --- safety
    ddi = ev["ddi_screening"]
    qtc = ddi.get("qtc_assessment") or {}
    interactions = [
        {k: str(a.get(k, "")) for k in
         ("interacting_pair", "severity", "kind", "mechanism", "clinical_action", "safe_alternative", "citation")}
        for a in ddi.get("interactions_found", [])
    ]
    for a in interactions:
        critical = a["severity"].upper().startswith("CRITICAL")
        flags.append({"severity": "critical" if critical else "warning", "code": "ddi",
                      "message": f"{a['interacting_pair']}: {a['severity']}. {a['clinical_action']}",
                      "citation": a["citation"]})
    qtc_block = {
        "risk_tier": str(qtc.get("risk_tier", "LOW")),
        "cumulative_score": qtc.get("cumulative_score", 0),
        "baseline_qtc_ms": qtc.get("baseline_qtc_ms"),
        "contributors": [
            {"drug": drug, "category": v.get("category", ""), "score": v.get("score", 0), "note": v.get("note", "")}
            for drug, v in (qtc.get("risk_breakdown") or {}).items()
        ],
    }
    for k in ("clinical_alert", "citation"):
        if qtc.get(k):
            qtc_block[k] = qtc[k]
    if qtc_block["risk_tier"].upper() == "HIGH":
        flags.append({"severity": "critical", "code": "qtc_high",
                      "message": qtc_block.get("clinical_alert", "High cumulative QTc risk"),
                      "citation": qtc_block.get("citation", "")})
    safety = {
        "interactions": interactions,
        "highest_severity": str(ddi.get("highest_severity", "NONE")),
        "safe_to_proceed_without_modification": bool(ddi.get("safe_to_proceed_without_modification", True)),
        "recommended_modifications": [str(m) for m in ddi.get("recommended_modifications", [])],
        "qtc": qtc_block,
    }

    # --- POGO benchmark
    pogo = ev["pogo_comparison"]
    pogo_block = {
        "has_differences": bool(pogo.get("has_differences")),
        "drugs": [
            {"drug": p["drug"], "dose_mg_m2": p.get("dose_mg_m2"), "uza_tier": p["uza_v2_tier"], "pogo_tier": p["pogo_tier"],
             "differs": p["differs"], "explanation": p["explanation"], "uza_citation": p["uza_citation"],
             "pogo_citation": p["pogo_citation"]}
            for p in pogo.get("per_drug_comparison", [])
        ],
        "combination_notes": list(pogo.get("combination_notes", [])),
        "prophylaxis_comparison": dict(pogo.get("prophylaxis_comparison") or {}),
    }
    for p in pogo_block["drugs"]:
        if p["differs"]:
            flags.append({"severity": "info", "code": "pogo_differs", "message": f"{p['drug']}: {p['explanation']}",
                          "citation": p["uza_citation"]})

    personalization = [str(o) for o in ev.get("personalization_overrides", [])]
    for o in personalization:
        flags.append({"severity": "info", "code": "personalization", "message": o})

    rationale = [f"{d['drug']} {d['dose_mg_m2']:g} mg/m²: {d['tier']} — {d['rule_citation']}"
                 if d["dose_mg_m2"] is not None else f"{d['drug']}: {d['tier']} — {d['rule_citation']}"
                 for d in classification["drugs"]]
    rationale += classification["combination_rules"]

    family = {}
    sched_days = sorted({d for row in schedule for d in row["cycle_days"]})
    for lang in ("nl", "fr", "en"):
        family[lang] = {
            "headline": HEADLINE[lang],
            "daily_steps": [
                f"{DAY_WORD[lang]} {day}: " + "; ".join(
                    f"{r['drug_name']} {r['dose_amount']:g} {r['dose_unit']} ({r['frequency']})"
                    for r in schedule if day in r["cycle_days"]
                )
                for day in sched_days
            ],
            "what_to_do_if_vomiting": IF_VOMITING[lang],
        }

    severity_rank = {"critical": 0, "warning": 1, "info": 2}
    review_flags = sorted(flags + _input_flags(inputs), key=lambda f: severity_rank[f["severity"]])

    return DraftPassport.model_validate({
        "passport_id": passport_id_for(patient_id, cycle),
        "patient_id": patient_id,
        "cycle_number": cycle,
        "status": "draft",
        "emetogenicity_tier": classification["overall_tier"],
        "classification_rationale": "; ".join(rationale),
        "antiemetic_schedule": schedule,
        "dexamethasone_rules": dexamethasone_rules,
        "breakthrough_plan": breakthrough_plan,
        "signoffs": {
            "requires_dual_signoff": True,
            "advisory_notice": ADVISORY_LABEL,
            "oncologist": {"signed": False},
            "clinical_pharmacist": {"signed": False},
        },
        "family_schedule_multilingual": family,
        "generation": _generation(),
        "inputs": inputs,
        "refusal": {"refused": False, "reasons": []},
        "classification": classification,
        "dose_review": [
            {"drug": ln["drug"], "indicated": ln["indicated"], "dose_text": ln["dose_text"], "frequency": ln["frequency"],
             "duration": ln["duration"], "route": ln["route"], "formula": ln["formula_shown"], "citation": ln["citation"],
             "warnings": list(ln["warnings"]), "administrations": list(ln["administrations"])}
            for ln in lines.values()
        ],
        "personalization": personalization,
        "safety": safety,
        "pogo_comparison": pogo_block,
        "review_flags": review_flags,
    })
