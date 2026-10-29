"""Shared pseudonymous patient records and timestamped BSA observations.

Firestore is used only when requested. An unavailable configured database does
not silently fall back to a separate empty in-memory patient database.
"""

from __future__ import annotations

import copy
import datetime
import math
import os
import threading
from datetime import timezone
from typing import Any, Dict, List, Optional

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
        if (
            isinstance(val, bool)
            or not isinstance(val, (int, float))
            or not math.isfinite(val)
            or not lo <= val <= hi
        ):
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
                    not isinstance(days, list)
                    or not all(isinstance(d, int) for d in days)
                ):
                    errors.append(
                        f"chemo_regimen[{i}].day_numbers must be a list of integers"
                    )
    return errors


def _timestamp(value: str) -> datetime.datetime:
    if not isinstance(value, str):
        raise PatientValidationError(
            "BSA measured_at must be an ISO timestamp with a timezone."
        )
    try:
        parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise PatientValidationError(
            "BSA measured_at must be an ISO timestamp with a timezone."
        ) from exc
    if parsed.tzinfo is None:
        raise PatientValidationError("BSA timestamps must include a timezone.")
    return parsed.astimezone(timezone.utc)


def latest_bsa(record: Dict[str, Any]) -> Dict[str, Any]:
    """Choose by measurement time, not array order or unrelated record updates."""
    history = record.get("bsa_measurements") or []
    if not isinstance(history, list):
        raise PatientValidationError("bsa_measurements must be a list.")
    normalized = []
    by_time = {}
    for item in history:
        if not isinstance(item, dict):
            raise PatientValidationError("Every BSA observation must be an object.")
        value = item.get("bsa_m2")
        if (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not math.isfinite(value)
            or not 0.1 <= value <= 3
        ):
            raise PatientValidationError(
                "Every BSA observation needs a finite value in [0.1, 3] m²."
            )
        when = _timestamp(item.get("measured_at"))
        if when in by_time and by_time[when] != value:
            raise PatientValidationError(
                "Conflicting BSA values have the same timestamp; clinical correction is required."
            )
        by_time[when] = value
        normalized.append(
            {
                "bsa_m2": value,
                "measured_at": when.isoformat(),
                "source": str(item.get("source") or "patient record"),
                "time_basis": item.get("time_basis", "measurement"),
            }
        )
    if normalized:
        return max(normalized, key=lambda item: _timestamp(item["measured_at"]))
    value = record.get("bsa_m2")
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(value)
        or not 0.1 <= value <= 3
    ):
        raise PatientValidationError("No valid BSA is available in the patient record.")
    when = record.get("bsa_measured_at")
    return {
        "bsa_m2": value,
        "measured_at": _timestamp(when).isoformat() if when else None,
        "source": "patient record (legacy BSA field)",
        "time_basis": "measurement" if when else "unknown",
    }


class PatientContextStore:
    """One shared store used by REST endpoints and the ADK patient tools."""

    def __init__(self, client: Any = None):
        self._client = client
        self._memory: Dict[str, Dict[str, Any]] = {}
        self._lock = threading.RLock()
        self._use_firestore = (
            client is not None or os.getenv("USE_FIRESTORE", "false").lower() == "true"
        )

    @property
    def storage_mode(self) -> str:
        return "firestore" if self._use_firestore else "memory"

    @property
    def client(self):
        if self._client is None:
            from aimesis_api.firestore_client import get_firestore_client

            self._client = get_firestore_client()
        return self._client

    def get(self, patient_id: str) -> Optional[Dict[str, Any]]:
        if self._use_firestore:
            doc = self.client.collection(COLLECTION_NAME).document(patient_id).get()
            return doc.to_dict() if doc.exists else None
        with self._lock:
            return copy.deepcopy(self._memory.get(patient_id))

    def upsert(self, updates: Dict[str, Any]) -> Dict[str, Any]:
        with self._lock:
            return self._upsert(updates)

    def _upsert(self, updates: Dict[str, Any]) -> Dict[str, Any]:
        patient_id = updates["patient_id"]
        if (
            not isinstance(patient_id, str)
            or not patient_id.strip()
            or "/" in patient_id
        ):
            raise PatientValidationError(
                "Provide a non-empty pseudonymous patient ID without '/'."
            )
        existing = self.get(patient_id) or {}
        record = {**existing, **{k: v for k, v in updates.items() if v is not None}}
        if "history_previous_cycles" in updates:
            record["history_previous_cycles"] = {
                **existing.get("history_previous_cycles", {}),
                **(updates.get("history_previous_cycles") or {}),
            }
        history = copy.deepcopy(existing.get("bsa_measurements") or [])
        incoming_history = updates.get("bsa_measurements")
        if incoming_history is not None and updates.get("bsa_m2") is not None:
            raise PatientValidationError(
                "Submit either a BSA value/timestamp or a measurement history, not both."
            )
        if incoming_history is not None:
            if not isinstance(incoming_history, list):
                raise PatientValidationError("bsa_measurements must be a list.")
            history.extend(incoming_history)
        if updates.get("bsa_m2") is not None and (
            incoming_history is None or updates.get("bsa_measured_at")
        ):
            if (
                not history
                or updates.get("bsa_measured_at")
                or updates["bsa_m2"] != existing.get("bsa_m2")
            ):
                when = updates.get("bsa_measured_at") or _now_iso()
                history.append(
                    {
                        "bsa_m2": updates["bsa_m2"],
                        "measured_at": when,
                        "source": updates.get("bsa_source") or "patient record",
                        "time_basis": "measurement"
                        if updates.get("bsa_measured_at")
                        else "recorded",
                    }
                )
        if history:
            # Validation includes all observations; do not silently ignore malformed newer values.
            selected = latest_bsa({"bsa_measurements": history})
            record["bsa_measurements"] = list(
                {
                    (_timestamp(item["measured_at"]).isoformat(), item["bsa_m2"]): item
                    for item in history
                }.values()
            )
            record["bsa_m2"] = selected["bsa_m2"]
            record["bsa_measured_at"] = selected["measured_at"]
        record.setdefault("current_cycle", 1)
        record.setdefault("preferred_formulation", "iv")
        record.setdefault("created_at", _now_iso())
        record["updated_at"] = _now_iso()
        errors = validate_patient_context(record)
        if errors:
            raise PatientValidationError("; ".join(errors))
        if self._use_firestore:
            from google.cloud import firestore

            payload = copy.deepcopy(record)
            if history:
                # Concurrent submissions append observations rather than losing history.
                payload["bsa_measurements"] = firestore.ArrayUnion(
                    record["bsa_measurements"]
                )
            self.client.collection(COLLECTION_NAME).document(patient_id).set(
                payload, merge=True
            )
        else:
            self._memory[patient_id] = copy.deepcopy(record)
        return copy.deepcopy(record)


patient_store = PatientContextStore()
