"""Patient context repository for the agent (Firestore `patients` collection).

Documents follow `contracts/schemas/patient_context.schema.json` and share the
collection used by `aimesis_api.episodes.store.PatientStore`. Falls back to an
in-memory dict when `USE_FIRESTORE` is not `true` or Firestore is unavailable,
so local dev and pytest run without GCP credentials.
"""

from __future__ import annotations

import datetime
import math
import os
from datetime import timezone
from typing import Any, Dict, List, Optional

try:
    from google.cloud import firestore  # type: ignore[import-untyped]
except ImportError:
    firestore = None

COLLECTION_NAME = "patients"

PREFERRED_FORMULATIONS = {"oral_liquid", "oral_tablet", "iv", "orodispersible"}
REQUIRED_FIELDS = ("patient_id", "age_years", "weight_kg", "bsa_m2", "chemo_regimen")


class PatientValidationError(ValueError):
    """Raised when a patient payload violates the PatientContext contract."""


def _now_iso() -> str:
    return datetime.datetime.now(timezone.utc).isoformat()


def mosteller_bsa(height_cm: float, weight_kg: float) -> float:
    return round(math.sqrt((height_cm * weight_kg) / 3600.0), 2)


def validate_patient_context(record: Dict[str, Any]) -> List[str]:
    """Return a list of contract violations (empty when valid)."""
    errors: List[str] = []
    for field in REQUIRED_FIELDS:
        if record.get(field) in (None, ""):
            errors.append(f"missing required field '{field}'")

    def _range(field: str, lo: float, hi: float) -> None:
        val = record.get(field)
        if val is None:
            return
        if not isinstance(val, (int, float)) or not lo <= val <= hi:
            errors.append(f"'{field}' must be a number in [{lo}, {hi}], got {val!r}")

    _range("age_years", 0, 21)
    _range("weight_kg", 1.0, 150.0)
    _range("bsa_m2", 0.1, 3.0)

    cycle = record.get("current_cycle")
    if cycle is not None and (not isinstance(cycle, int) or cycle < 1):
        errors.append(f"'current_cycle' must be an integer >= 1, got {cycle!r}")

    formulation = record.get("preferred_formulation")
    if formulation is not None and formulation not in PREFERRED_FORMULATIONS:
        errors.append(
            f"'preferred_formulation' must be one of {sorted(PREFERRED_FORMULATIONS)}, got {formulation!r}"
        )

    regimen = record.get("chemo_regimen")
    if regimen is not None:
        if not isinstance(regimen, list):
            errors.append("'chemo_regimen' must be a list")
        else:
            for i, item in enumerate(regimen):
                if not isinstance(item, dict):
                    errors.append(f"chemo_regimen[{i}] must be an object")
                    continue
                for f in ("drug_name", "dose_mg_per_m2", "day_numbers"):
                    if item.get(f) is None:
                        errors.append(f"chemo_regimen[{i}] missing '{f}'")
                days = item.get("day_numbers")
                if days is not None and (
                    not isinstance(days, list) or not all(isinstance(d, int) for d in days)
                ):
                    errors.append(f"chemo_regimen[{i}].day_numbers must be a list of integers")
    return errors


class AgentPatientStore:
    """Read/write PatientContext documents with in-memory fallback."""

    def __init__(self, client: Any = None) -> None:
        self._client = client
        self._memory: Dict[str, Dict[str, Any]] = {}
        self._use_firestore = (
            client is not None
            or os.getenv("USE_FIRESTORE", "false").lower() == "true"
        )
        if self._use_firestore and self._client is None:
            try:
                if firestore is None:
                    raise RuntimeError("google-cloud-firestore is not installed")
                self._client = firestore.Client(
                    project=os.getenv("GCP_PROJECT"),
                    database=os.getenv("FIRESTORE_DATABASE", "(default)"),
                )
            except Exception:
                self._use_firestore = False

    def get(self, patient_id: str) -> Optional[Dict[str, Any]]:
        if self._use_firestore:
            doc = self._client.collection(COLLECTION_NAME).document(patient_id).get()
            return doc.to_dict() if doc.exists else None
        record = self._memory.get(patient_id)
        return dict(record) if record else None

    def upsert(self, updates: Dict[str, Any]) -> Dict[str, Any]:
        """Merge `updates` into the stored record, validate, persist, and return it."""
        patient_id = updates["patient_id"]
        existing = self.get(patient_id) or {}
        record = {**existing, **{k: v for k, v in updates.items() if v is not None}}
        if "history_previous_cycles" in updates and existing.get("history_previous_cycles"):
            record["history_previous_cycles"] = {
                **existing["history_previous_cycles"],
                **(updates["history_previous_cycles"] or {}),
            }
        record.setdefault("current_cycle", 1)
        record.setdefault("preferred_formulation", "iv")
        record.setdefault("created_at", _now_iso())
        record["updated_at"] = _now_iso()

        errors = validate_patient_context(record)
        if errors:
            raise PatientValidationError("; ".join(errors))

        if self._use_firestore:
            self._client.collection(COLLECTION_NAME).document(patient_id).set(record)
        else:
            self._memory[patient_id] = dict(record)
        return record


patient_store = AgentPatientStore()
