"""Firestore store implementations for episodes, patients, and passports with automatic in-memory fallback.

Allows local development and pytest execution without requiring active GCP
credentials, while supporting Cloud Firestore via `get_firestore_client()` when
`USE_FIRESTORE=true` or when an explicit Firestore client is injected.
"""

from __future__ import annotations

import datetime
import os
import uuid
from datetime import timezone
from typing import Any, Dict, List, Optional

from aimesis_api.firestore_client import get_firestore_client


class EpisodeStore:
    """Repository for patient CINV episodes, cycle outcomes, and dual sign-offs."""

    COLLECTION_NAME = "episodes"

    def __init__(self, client: Any = None) -> None:
        self._client = client
        self._memory_episodes: dict[str, dict[str, Any]] = {}
        self._use_firestore = (
            client is not None
            or os.getenv("USE_FIRESTORE", "false").lower() == "true"
        )
        if self._use_firestore and self._client is None:
            try:
                self._client = get_firestore_client()
            except Exception:
                self._use_firestore = False

    @property
    def client(self) -> Any:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def create_episode(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Create and persist an episode document and return the created record."""
        episode_id = payload.get("episode_id") or f"ep-{uuid.uuid4().hex[:10]}"
        now_iso = datetime.datetime.now(timezone.utc).isoformat()
        record: dict[str, Any] = {
            **payload,
            "episode_id": episode_id,
            "patient_id": payload.get("patient_id", "anon-patient"),
            "cycle_number": payload.get("cycle_number", 1),
            "regimen_agents": payload.get("regimen_agents", []),
            "uza_evaluation": payload.get("uza_evaluation", {}),
            "breakthrough_events": payload.get("breakthrough_events", []),
            "nursing_notes": payload.get("nursing_notes", []),
            "sign_off": payload.get("sign_off")
            or {
                "oncologist_signed": bool(payload.get("oncologist_signed", False)),
                "oncologist_name": payload.get("oncologist_name"),
                "pharmacist_signed": bool(payload.get("pharmacist_signed", False)),
                "pharmacist_name": payload.get("pharmacist_name"),
                "export_unlocked": bool(
                    payload.get("oncologist_signed", False)
                    and payload.get("pharmacist_signed", False)
                ),
            },
            "created_at": payload.get("created_at", now_iso),
            "updated_at": payload.get("updated_at", now_iso),
        }

        if self._use_firestore:
            doc_ref = self.client.collection(self.COLLECTION_NAME).document(episode_id)
            doc_ref.set(record)
        else:
            self._memory_episodes[episode_id] = record

        return record

    def get_episode(self, episode_id: str) -> dict[str, Any] | None:
        """Retrieve a single episode by ID."""
        if self._use_firestore:
            doc = self.client.collection(self.COLLECTION_NAME).document(episode_id).get()
            return doc.to_dict() if doc.exists else None
        return self._memory_episodes.get(episode_id)

    def list_episodes(self, patient_id: str | None = None) -> list[dict[str, Any]]:
        """List episodes, optionally filtered by patient_id."""
        if self._use_firestore:
            query = self.client.collection(self.COLLECTION_NAME)
            if patient_id:
                query = query.where("patient_id", "==", patient_id)
            return [doc.to_dict() for doc in query.stream()]

        items = list(self._memory_episodes.values())
        if patient_id:
            items = [ep for ep in items if ep.get("patient_id") == patient_id]
        return sorted(items, key=lambda x: x.get("created_at", ""), reverse=True)

    def list_episodes_for_patient(
        self, patient_id: str, limit: int = 100
    ) -> List[Dict[str, Any]]:
        """List all episodes for a patient ordered by timestamp descending."""
        if self._use_firestore:
            query = (
                self.client.collection(self.COLLECTION_NAME)
                .where("patient_id", "==", patient_id)
                .order_by("timestamp", direction="DESCENDING")
                .limit(limit)
            )
            return [doc.to_dict() for doc in query.stream()]

        items = [
            ep
            for ep in self._memory_episodes.values()
            if ep.get("patient_id") == patient_id
        ]
        items.sort(
            key=lambda x: x.get("timestamp") or x.get("created_at", ""),
            reverse=True,
        )
        return items[:limit]

    def list_episodes_for_passport(
        self, passport_id: str, limit: int = 100
    ) -> List[Dict[str, Any]]:
        """List all episodes logged against a specific Passport cycle."""
        if self._use_firestore:
            query = (
                self.client.collection(self.COLLECTION_NAME)
                .where("passport_id", "==", passport_id)
                .order_by("timestamp", direction="DESCENDING")
                .limit(limit)
            )
            return [doc.to_dict() for doc in query.stream()]

        items = [
            ep
            for ep in self._memory_episodes.values()
            if ep.get("passport_id") == passport_id
        ]
        items.sort(
            key=lambda x: x.get("timestamp") or x.get("created_at", ""),
            reverse=True,
        )
        return items[:limit]

    def log_breakthrough_event(
        self,
        episode_id: str,
        event: dict[str, Any],
    ) -> dict[str, Any] | None:
        """Append a breakthrough CINV event to an episode."""
        record = self.get_episode(episode_id)
        if not record:
            return None
        event_with_ts = {
            "event_id": f"bt-{uuid.uuid4().hex[:8]}",
            "timestamp": datetime.datetime.now(timezone.utc).isoformat(),
            **event,
        }
        record.setdefault("breakthrough_events", []).append(event_with_ts)
        record["updated_at"] = datetime.datetime.now(timezone.utc).isoformat()
        if self._use_firestore:
            self.client.collection(self.COLLECTION_NAME).document(episode_id).set(record)
        else:
            self._memory_episodes[episode_id] = record
        return record

    def update_sign_off(
        self,
        episode_id: str,
        oncologist_signed: bool | None = None,
        oncologist_name: str | None = None,
        pharmacist_signed: bool | None = None,
        pharmacist_name: str | None = None,
    ) -> dict[str, Any] | None:
        """Update dual sign-off status for an episode."""
        record = self.get_episode(episode_id)
        if not record:
            return None
        sign_off = record.setdefault(
            "sign_off",
            {
                "oncologist_signed": False,
                "oncologist_name": None,
                "pharmacist_signed": False,
                "pharmacist_name": None,
                "export_unlocked": False,
            },
        )
        if oncologist_signed is not None:
            sign_off["oncologist_signed"] = oncologist_signed
        if oncologist_name is not None:
            sign_off["oncologist_name"] = oncologist_name
        if pharmacist_signed is not None:
            sign_off["pharmacist_signed"] = pharmacist_signed
        if pharmacist_name is not None:
            sign_off["pharmacist_name"] = pharmacist_name

        sign_off["export_unlocked"] = bool(
            sign_off.get("oncologist_signed") and sign_off.get("pharmacist_signed")
        )
        record["updated_at"] = datetime.datetime.now(timezone.utc).isoformat()
        if self._use_firestore:
            self.client.collection(self.COLLECTION_NAME).document(episode_id).set(record)
        else:
            self._memory_episodes[episode_id] = record
        return record


class PassportStore:
    """Manages CINV Patient Passports in Firestore."""

    COLLECTION_NAME = "passports"

    def __init__(self, client: Any = None) -> None:
        self._client = client

    @property
    def client(self) -> Any:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def save_passport(self, passport_data: Dict[str, Any]) -> str:
        """Save or update a Passport document."""
        passport_id = passport_data["passport_id"]
        data = dict(passport_data)
        data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

        doc_ref = self.client.collection(self.COLLECTION_NAME).document(passport_id)
        doc_ref.set(data, merge=True)
        return passport_id

    def get_passport(self, passport_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve a Passport by ID."""
        doc = self.client.collection(self.COLLECTION_NAME).document(passport_id).get()
        return doc.to_dict() if doc.exists else None

    def get_active_passport_for_patient(self, patient_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve the currently active Passport for a patient."""
        query = (
            self.client.collection(self.COLLECTION_NAME)
            .where("patient_id", "==", patient_id)
            .where("status", "==", "active")
            .limit(1)
        )
        results = [doc.to_dict() for doc in query.stream()]
        return results[0] if results else None

    def sign_off_passport(
        self,
        passport_id: str,
        role: str,
        clinician_name: str,
        riziv_inami: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Record dual sign-off (oncologist or clinical pharmacist) for a passport."""
        doc_ref = self.client.collection(self.COLLECTION_NAME).document(passport_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise KeyError(f"Passport {passport_id} not found")

        passport = snapshot.to_dict()
        signoffs = passport.get("signoffs", {})

        now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
        signoff_payload = {
            "signed": True,
            "clinician_name": clinician_name,
            "timestamp": now_iso,
            "riziv_inami": riziv_inami or "",
        }

        if role in ("oncologist", "clinical_pharmacist"):
            signoffs[role] = signoff_payload

        # If both have signed, activate passport
        onco_signed = signoffs.get("oncologist", {}).get("signed", False)
        pharm_signed = signoffs.get("clinical_pharmacist", {}).get("signed", False)

        new_status = "active" if (onco_signed and pharm_signed) else passport.get("status", "draft")

        doc_ref.update({
            f"signoffs.{role}": signoff_payload,
            "status": new_status,
            "updated_at": now_iso,
        })

        passport["signoffs"] = signoffs
        passport["status"] = new_status
        return passport


class PatientStore:
    """Manages patient context records in Firestore."""

    COLLECTION_NAME = "patients"

    def __init__(self, client: Any = None) -> None:
        self._client = client

    @property
    def client(self) -> Any:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def upsert_patient(self, patient_data: Dict[str, Any]) -> str:
        """Create or update a patient context document."""
        patient_id = patient_data["patient_id"]
        data = dict(patient_data)
        data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

        doc_ref = self.client.collection(self.COLLECTION_NAME).document(patient_id)
        doc_ref.set(data, merge=True)
        return patient_id

    def get_patient(self, patient_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve patient context by ID."""
        doc = self.client.collection(self.COLLECTION_NAME).document(patient_id).get()
        return doc.to_dict() if doc.exists else None


episode_store = EpisodeStore()
passport_store = PassportStore()
patient_store = PatientStore()
