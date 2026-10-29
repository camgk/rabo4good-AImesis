"""Firestore store implementations for episodes, patients, and passports."""

from __future__ import annotations

import datetime
from typing import Any, Dict, List, Optional

from aimesis_api.firestore_client import get_firestore_client


class EpisodeStore:
    """Manages CINV nausea/vomiting episode logging in Firestore."""

    COLLECTION_NAME = "episodes"

    def __init__(self, client: Any = None) -> None:
        self._client = client

    @property
    def client(self) -> Any:
        if self._client is None:
            self._client = get_firestore_client()
        return self._client

    def create_episode(self, episode_data: Dict[str, Any]) -> str:
        """Create and persist an episode document.

        Returns:
            The created episode document ID.
        """
        episode_id = episode_data.get("episode_id")
        data = dict(episode_data)

        if "created_at" not in data:
            data["created_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

        if episode_id:
            doc_ref = self.client.collection(self.COLLECTION_NAME).document(episode_id)
            doc_ref.set(data)
            return episode_id

        _, doc_ref = self.client.collection(self.COLLECTION_NAME).add(data)
        doc_ref.update({"episode_id": doc_ref.id})
        return doc_ref.id

    def list_episodes_for_patient(
        self, patient_id: str, limit: int = 100
    ) -> List[Dict[str, Any]]:
        """List all episodes for a patient ordered by timestamp descending."""
        query = (
            self.client.collection(self.COLLECTION_NAME)
            .where("patient_id", "==", patient_id)
            .order_by("timestamp", direction="DESCENDING")
            .limit(limit)
        )
        return [doc.to_dict() for doc in query.stream()]

    def list_episodes_for_passport(
        self, passport_id: str, limit: int = 100
    ) -> List[Dict[str, Any]]:
        """List all episodes logged against a specific Passport cycle."""
        query = (
            self.client.collection(self.COLLECTION_NAME)
            .where("passport_id", "==", passport_id)
            .order_by("timestamp", direction="DESCENDING")
            .limit(limit)
        )
        return [doc.to_dict() for doc in query.stream()]


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
