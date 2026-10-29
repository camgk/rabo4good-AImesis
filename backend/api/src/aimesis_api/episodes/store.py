"""Episode and cycle outcome store with Firestore and automatic in-memory fallback.

Allows local development and pytest execution without requiring active GCP
credentials, while supporting Cloud Firestore when `USE_FIRESTORE=true`.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone
from typing import Any


class EpisodeStore:
    """Repository for patient CINV episodes, cycle outcomes, and dual sign-offs."""

    def __init__(self) -> None:
        self._memory_episodes: dict[str, dict[str, Any]] = {}
        self._use_firestore = os.getenv("USE_FIRESTORE", "false").lower() == "true"
        self._fs_client = None
        if self._use_firestore:
            try:
                from google.cloud import firestore  # type: ignore

                self._fs_client = firestore.Client(
                    project=os.getenv("GOOGLE_CLOUD_PROJECT")
                )
            except Exception:
                self._use_firestore = False

    def create_episode(self, payload: dict[str, Any]) -> dict[str, Any]:
        episode_id = payload.get("episode_id") or f"ep-{uuid.uuid4().hex[:10]}"
        now_iso = datetime.now(timezone.utc).isoformat()
        record: dict[str, Any] = {
            "episode_id": episode_id,
            "patient_id": payload.get("patient_id", "anon-patient"),
            "cycle_number": payload.get("cycle_number", 1),
            "regimen_agents": payload.get("regimen_agents", []),
            "uza_evaluation": payload.get("uza_evaluation", {}),
            "breakthrough_events": payload.get("breakthrough_events", []),
            "nursing_notes": payload.get("nursing_notes", []),
            "sign_off": {
                "oncologist_signed": bool(payload.get("oncologist_signed", False)),
                "oncologist_name": payload.get("oncologist_name"),
                "pharmacist_signed": bool(payload.get("pharmacist_signed", False)),
                "pharmacist_name": payload.get("pharmacist_name"),
                "export_unlocked": bool(
                    payload.get("oncologist_signed", False)
                    and payload.get("pharmacist_signed", False)
                ),
            },
            "created_at": now_iso,
            "updated_at": now_iso,
        }

        if self._use_firestore and self._fs_client is not None:
            self._fs_client.collection("cinv_episodes").document(episode_id).set(record)
        else:
            self._memory_episodes[episode_id] = record

        return record

    def get_episode(self, episode_id: str) -> dict[str, Any] | None:
        if self._use_firestore and self._fs_client is not None:
            doc = self._fs_client.collection("cinv_episodes").document(episode_id).get()
            return doc.to_dict() if doc.exists else None
        return self._memory_episodes.get(episode_id)

    def list_episodes(self, patient_id: str | None = None) -> list[dict[str, Any]]:
        if self._use_firestore and self._fs_client is not None:
            query = self._fs_client.collection("cinv_episodes")
            if patient_id:
                query = query.where("patient_id", "==", patient_id)
            return [doc.to_dict() for doc in query.stream()]

        items = list(self._memory_episodes.values())
        if patient_id:
            items = [ep for ep in items if ep.get("patient_id") == patient_id]
        return sorted(items, key=lambda x: x.get("created_at", ""), reverse=True)

    def log_breakthrough_event(
        self,
        episode_id: str,
        event: dict[str, Any],
    ) -> dict[str, Any] | None:
        record = self.get_episode(episode_id)
        if not record:
            return None
        event_with_ts = {
            "event_id": f"bt-{uuid.uuid4().hex[:8]}",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            **event,
        }
        record.setdefault("breakthrough_events", []).append(event_with_ts)
        record["updated_at"] = datetime.now(timezone.utc).isoformat()
        if self._use_firestore and self._fs_client is not None:
            self._fs_client.collection("cinv_episodes").document(episode_id).set(record)
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
        record["updated_at"] = datetime.now(timezone.utc).isoformat()
        if self._use_firestore and self._fs_client is not None:
            self._fs_client.collection("cinv_episodes").document(episode_id).set(record)
        else:
            self._memory_episodes[episode_id] = record
        return record


episode_store = EpisodeStore()
