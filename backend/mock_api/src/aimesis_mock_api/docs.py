"""Mapping between the shared Firestore documents (snake_case) and the mock API's models (camelCase).

The `(default)` Firestore database is shared with backend/api. Documents follow
contracts/schemas/{patient_context,episode,passport}.schema.json plus optional extension fields
(documented in those schemas). The REST API keeps its camelCase shapes; this module translates.

Collections:
    patients/{patient_id}            patient_context.schema.json (+ tags, sex, cycle_label, risk_factors, ...)
    passports/{passport_id}          passport.schema.json (+ plan_status, comments, risk_factors, tags)
    episodes/{episode_id}            episode.schema.json (+ logged_by_account, severity_score, tags)
    accounts/{account_id}            login accounts (mock API only)
    reference_resources/{res-NN}     Belgian family resources (reference data, never tagged demo)
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from .models import ADVISORY, Episode, Patient, Plan, Resource, RiskFactors
from .passport import TEXT, WARD_PHONE, build_passport

DEMO_TAG = "demo"
LANGS = ("nl", "fr", "en")


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def to_utc_iso(at: str) -> str:
    """Normalise an ISO-8601 timestamp to UTC 'YYYY-MM-DDTHH:MM:SSZ' (naive = UTC). Raises ValueError."""
    dt = datetime.fromisoformat(at.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


# --------------------------------------------------------------------------- ids
def passport_id_for(patient_doc: dict) -> str:
    """PSP-<patient number>-C<current_cycle>, e.g. PAT-2026-0001 cycle 4 -> PSP-2026-0001-C4."""
    pid = patient_doc["patient_id"]
    number = pid[4:] if pid.startswith("PAT-") else pid
    return f"PSP-{number}-C{int(patient_doc.get('current_cycle') or 1)}"


# --------------------------------------------------------------------------- patients
_ROUTE_TO_FORMULATION = {"oral_tablet": "oral_tablet", "oral_liquid": "oral_liquid", "ng_tube": "oral_liquid", "iv": "iv"}
_SCHEDULE_ROUTE = {"oral_tablet": "oral_tablet", "oral_liquid": "oral_liquid", "ng_tube": "oral_liquid", "iv": "iv"}


def formulation_for_route(route: str) -> str:
    return _ROUTE_TO_FORMULATION.get(route, "oral_liquid")


def risk_factors_to_doc(rf: dict) -> dict:
    """camelCase RiskFactors wire dict -> snake_case doc dict."""
    out = {
        "can_swallow_tablets": bool(rf.get("canSwallowTablets", True)),
        "preferred_route": rf.get("preferredRoute", "oral_tablet"),
        "anticipatory": bool(rf.get("anticipatory", False)),
    }
    if rf.get("priorNauseaNote"):
        out["prior_nausea_note"] = rf["priorNauseaNote"]
    return out


def risk_factors_from_doc(rf: dict | None, patient_doc: dict | None = None) -> dict:
    """snake_case doc dict -> camelCase wire dict. Falls back to preferred_formulation when absent."""
    if not rf:
        form = (patient_doc or {}).get("preferred_formulation")
        hist = (patient_doc or {}).get("history_previous_cycles") or {}
        route = {"oral_tablet": "oral_tablet", "oral_liquid": "oral_liquid", "iv": "iv", "orodispersible": "oral_liquid"}.get(
            form or "", "oral_liquid"
        )
        return RiskFactors(
            can_swallow_tablets=route == "oral_tablet",
            preferred_route=route,
            anticipatory=bool(hist.get("anticipatory_nausea", False)),
        ).wire()
    out = {
        "canSwallowTablets": bool(rf.get("can_swallow_tablets", True)),
        "preferredRoute": rf.get("preferred_route", "oral_tablet"),
        "anticipatory": bool(rf.get("anticipatory", False)),
    }
    if rf.get("prior_nausea_note"):
        out["priorNauseaNote"] = rf["prior_nausea_note"]
    return out


def history_summary(previous_cycles: list[dict], anticipatory: bool) -> dict:
    """history_previous_cycles (schema object) derived from the most recent previous cycle."""
    last = previous_cycles[-1] if previous_cycles else {}
    n = len(last.get("nausea_days", [])) + len(last.get("vomiting_days", []))
    return {
        "had_refractory_cinv": n > 0,
        "prior_episode_count": n,
        "anticipatory_nausea": anticipatory,
        "notes": last.get("note", ""),
    }


def _diagnosis_group(doc: dict) -> str:
    if doc.get("diagnosis_group"):
        return doc["diagnosis_group"]
    dx = (doc.get("diagnosis") or "").lower()
    if "lymphoblastic" in dx or " all" in f" {dx}" or "all " in dx:
        return "ALL"
    if any(k in dx for k in ("medulloblastoma", "glioma", "brain", "ependymoma")):
        return "brain_tumour"
    return "solid"


def patient_internal(doc: dict) -> dict:
    """Patient doc -> camelCase dict accepted by models.Patient (without overallTier/planStatus)."""
    lang = doc.get("preferred_language") or "nl"
    if lang not in LANGS:
        lang = "en"
    age = doc.get("age_years")
    return {
        "id": doc["patient_id"],
        "alias": doc.get("display_pseudonym") or doc["patient_id"],
        "tags": list(doc.get("tags") or []),
        "age": int(age) if age is not None else 0,
        "sex": doc.get("sex") or "—",
        "weightKg": doc.get("weight_kg"),
        "heightCm": doc.get("height_cm"),
        "bsaM2": doc.get("bsa_m2"),
        "diagnosis": doc.get("diagnosis") or "",
        "diagnosisGroup": _diagnosis_group(doc),
        "protocol": doc.get("protocol_name") or "",
        "cycle": doc.get("cycle_label") or f"C{int(doc.get('current_cycle') or 1)}",
        "cycleStart": doc.get("cycle_start_date") or "",
        "chemo": [
            {
                "drug": " ".join(str(r.get("drug_name", "")).strip().lower().split()),
                "doseMgM2": r.get("dose_mg_per_m2", 0),
                "days": list(r.get("day_numbers") or []),
            }
            for r in doc.get("chemo_regimen") or []
        ],
        "activeMeds": list(doc.get("active_medications") or []),
        "language": lang,
        "history": [
            {
                k: v
                for k, v in {
                    "cycle": h.get("cycle_label", ""),
                    "date": h.get("date"),
                    "antiemetics": h.get("antiemetics"),
                    "nauseaDays": list(h.get("nausea_days") or []),
                    "vomitingDays": list(h.get("vomiting_days") or []),
                    "note": h.get("note", ""),
                }.items()
                if v is not None
            }
            for h in doc.get("previous_cycles") or []
        ],
        "riskFactors": risk_factors_from_doc(doc.get("risk_factors"), doc),
        "pairingCode": doc.get("pairing_code") or "",
    }


# --------------------------------------------------------------------------- passports (plan workflow state)
def _signoff_from_doc(s: dict | None) -> dict | None:
    if not s or not s.get("signed"):
        return None
    return {"by": s.get("clinician_name") or "—", "at": s.get("timestamp") or ""}


def _signoff_to_doc(s: dict | None) -> dict:
    if not s:
        return {"signed": False}
    return {"signed": True, "clinician_name": s["by"], "timestamp": s["at"], "riziv_inami": ""}


def default_state(patient_doc: dict) -> dict:
    return {
        "status": "draft",
        "riskFactors": risk_factors_from_doc(patient_doc.get("risk_factors"), patient_doc),
        "signoffs": {"oncologist": None, "pharmacist": None},
        "comments": [],
    }


def state_from_passport(passport_doc: dict | None, patient_doc: dict) -> dict:
    """Passport doc -> plan workflow state {status, riskFactors, signoffs, comments} (camelCase)."""
    if not passport_doc:
        return default_state(patient_doc)
    so = passport_doc.get("signoffs") or {}
    onc = _signoff_from_doc(so.get("oncologist"))
    pharm = _signoff_from_doc(so.get("clinical_pharmacist"))
    status = passport_doc.get("plan_status")
    if status not in ("draft", "awaiting_pharmacist", "approved", "returned"):
        # Written by someone else (backend/api): derive from the schema status / sign-offs.
        if passport_doc.get("status") == "active" or (onc and pharm):
            status = "approved"
        elif passport_doc.get("status") == "pending_pharmacist" or onc:
            status = "awaiting_pharmacist"
        else:
            status = "draft"
    rf = passport_doc.get("risk_factors")
    return {
        "status": status,
        "riskFactors": risk_factors_from_doc(rf, patient_doc) if rf else default_state(patient_doc)["riskFactors"],
        "signoffs": {"oncologist": onc, "pharmacist": pharm},
        "comments": [dict(c) for c in passport_doc.get("comments") or []],
    }


_VOMIT_TEXT = {
    "nl": "Geef de extra medicatie tegen misselijkheid zoals afgesproken. Bel de afdeling als uw kind niets binnenhoudt.",
    "fr": "Donnez le médicament supplémentaire contre les nausées comme convenu. Appelez le service si votre enfant ne garde rien.",
    "en": "Give the extra anti-sickness medicine as agreed. Call the ward if your child cannot keep anything down.",
}


def _family_schedule(patient: Patient, plan: Plan) -> dict:
    out = {}
    for lang in LANGS:
        pp = build_passport(patient, plan, lang, [])
        steps = []
        for d in pp.days:
            items = "; ".join(f"{i.time} {i.medicine} {i.amount} ({i.route})" for i in d.items)
            steps.append(f"{d.label}{' · ' + d.date if d.date else ''}: {items}")
        out[lang] = {"headline": pp.title, "daily_steps": steps, "what_to_do_if_vomiting": _VOMIT_TEXT[lang]}
    return out


def passport_doc(
    patient_doc: dict,
    patient: Patient,
    plan: Plan,
    state: dict,
    existing: dict | None = None,
) -> dict:
    """Build the passports/{passport_id} doc (passport.schema.json + workflow extensions)."""
    ts = now_iso()
    onc = state["signoffs"].get("oncologist")
    pharm = state["signoffs"].get("pharmacist")
    rationale = [f"{t.drug} {t.dose_mg_m2:g} mg/m²: {t.tier} — {t.rule}" for t in plan.drug_tiers]
    rationale += [c.rule for c in plan.combination_rules]
    if plan.refused:
        rationale.append("Refused: " + "; ".join(plan.refusal_reasons))
    schedule = [
        {
            "drug_name": a.drug.capitalize(),
            "dose_amount": a.dose_mg,
            "dose_unit": a.unit,
            "formula_used": a.formula + (" · " + " · ".join(a.steps) if a.steps else ""),
            "route": _SCHEDULE_ROUTE.get(a.route, "oral_liquid"),
            "frequency": a.frequency,
            "cycle_days": list(a.days),
            "rule_citation": a.source,
        }
        for a in plan.antiemetics
        if a.dose_mg is not None
    ]
    rescue = [
        {
            "step_number": i,
            "drug_name": b.drug.capitalize(),
            "dose": f"{b.dose_mg:g} {b.unit}" if b.dose_mg is not None else "—",
            "route": b.route,
            "max_daily_frequency": b.frequency,
            "rule_citation": f"{b.source} · {b.formula}",
        }
        for i, b in enumerate(plan.breakthrough, start=1)
    ]
    doc = {
        "passport_id": passport_id_for(patient_doc),
        "patient_id": patient_doc["patient_id"],
        "cycle_number": int(patient_doc.get("current_cycle") or 1),
        "status": "active" if (onc and pharm) else "draft",
        "emetogenicity_tier": plan.overall_tier.upper(),
        "classification_rationale": "; ".join(rationale),
        "antiemetic_schedule": schedule,
        "dexamethasone_rules": {
            "is_blocked": plan.dexamethasone.blocked,
            "rationale": plan.dexamethasone.reason or f"Dexamethasone allowed ({plan.dexamethasone.source})",
        },
        "breakthrough_plan": {
            "rescue_steps": rescue,
            "instructions": "If nausea or vomiting breaks through, give the rescue medicine as listed and call the ward "
            f"({WARD_PHONE}) if it continues.",
        },
        "signoffs": {
            "requires_dual_signoff": True,
            "advisory_notice": ADVISORY,
            "oncologist": _signoff_to_doc(onc),
            "clinical_pharmacist": _signoff_to_doc(pharm),
        },
        "family_schedule_multilingual": _family_schedule(patient, plan),
        "emergency_contacts": [
            {"role": "Paediatric oncology ward", "ward": "Paediatric haemato-oncology", "phone_number": WARD_PHONE}
        ],
        # ---- extensions (mock API workflow state)
        "plan_status": state["status"],
        "comments": [dict(c) for c in state.get("comments", [])],
        "risk_factors": risk_factors_to_doc(state["riskFactors"]),
        "tags": list(patient_doc.get("tags") or []),
        "created_at": (existing or {}).get("created_at") or ts,
        "updated_at": ts,
    }
    return doc


# --------------------------------------------------------------------------- episodes
def severity_label(score: int | None) -> str:
    if score is None or score <= 2:
        return "mild"
    if score == 3:
        return "moderate"
    return "severe"


_LABEL_SCORE = {"mild": 2, "moderate": 3, "severe": 4}
_REPORTED_BY = {"parent": "parent", "patient": "patient", "nurse": "nurse", "oncologist": "clinician", "pharmacist": "clinician"}
_ROLE_FROM_REPORTED = {"parent": "parent", "patient": "patient", "nurse": "nurse", "clinician": "oncologist"}


def episode_doc(
    patient_doc: dict, account: dict, symptom: str, severity: int | None, at: str, cycle_day: int
) -> dict:
    ts = now_iso()
    return {
        "episode_id": str(uuid.uuid4()),
        "patient_id": patient_doc["patient_id"],
        "passport_id": passport_id_for(patient_doc),
        "cycle_day": cycle_day,
        "timestamp": at,
        "symptom_type": symptom,
        "severity": severity_label(severity),
        "vomiting_count": 1 if symptom == "vomiting" else 0,
        "reported_by": _REPORTED_BY.get(account["role"], "clinician"),
        "created_at": ts,
        # ---- extensions
        "logged_by_account": account["id"],
        "logged_by_role": account["role"],
        "severity_score": severity,
        "tags": list(patient_doc.get("tags") or []),
    }


def episode_internal(doc: dict) -> Episode:
    symptom = doc.get("symptom_type", "nausea")
    score = doc.get("severity_score")
    if score is None and "severity_score" not in doc:
        score = _LABEL_SCORE.get(doc.get("severity", ""), None)
    role = doc.get("logged_by_role") or _ROLE_FROM_REPORTED.get(doc.get("reported_by", ""), "parent")
    return Episode(
        id=doc.get("episode_id", ""),
        patient_id=doc["patient_id"],
        type="nausea" if symptom == "nausea" else "vomiting",
        severity=score,
        at=doc.get("timestamp") or doc.get("created_at") or "",
        cycle_day=int(doc.get("cycle_day") or 1),
        logged_by=doc.get("logged_by_account") or doc.get("reported_by") or "unknown",
        logged_by_role=role,
    )


# --------------------------------------------------------------------------- accounts / resources
def account_internal(doc: dict) -> dict:
    return {
        "id": doc["account_id"],
        "email": doc["email"],
        "role": doc["role"],
        "displayName": doc.get("display_name") or doc["email"],
        "patientIds": list(doc.get("patient_ids") or []),
        "passwordHash": doc.get("password_hash", ""),
        "tags": list(doc.get("tags") or []),
    }


def resource_internal(doc: dict) -> Resource:
    return Resource(
        institution=doc["institution"],
        title=doc["title"],
        format=doc["format"],
        language=doc["language"],
        url=doc["url"],
        effort=doc["effort"],
        effort_note=doc.get("effort_note", ""),
    )


__all__ = [
    "DEMO_TAG",
    "TEXT",
    "account_internal",
    "default_state",
    "episode_doc",
    "episode_internal",
    "formulation_for_route",
    "history_summary",
    "passport_doc",
    "passport_id_for",
    "patient_internal",
    "resource_internal",
    "risk_factors_from_doc",
    "risk_factors_to_doc",
    "severity_label",
    "state_from_passport",
    "to_utc_iso",
]
