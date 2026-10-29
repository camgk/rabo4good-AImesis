"""Storage for the mock API: the shared Firestore `(default)` database layout.

One implementation over a Firestore-like client:
- FirestoreStore: google.cloud.firestore.Client (env GOOGLE_CLOUD_PROJECT, FIRESTORE_DATABASE default "(default)").
- MemoryStore: the same code over aimesis_mock_api.fake_firestore.FakeFirestore (env STORE=memory; tests,
  local dev). Starts empty; set LOAD_DEMO_ON_START=true (memory only) to load the demo dataset on start.

Documents are snake_case (see docs.py and contracts/schemas/*.schema.json). Queries use a single equality
(or array_contains) filter only and sort in Python, so no composite indexes are needed.
"""

from __future__ import annotations

import os
from typing import Any

from .docs import DEMO_TAG, account_internal

DEFAULT_DATABASE = "(default)"


def _where(col, field: str, op: str, value: Any):
    from google.cloud.firestore_v1.base_query import FieldFilter

    return col.where(filter=FieldFilter(field, op, value))


class Store:
    """Domain-level reads/writes against a Firestore(-like) client `db`."""

    def __init__(self, db) -> None:
        self.db = db

    # ---- generic
    def get(self, collection: str, doc_id: str) -> dict | None:
        snap = self.db.collection(collection).document(doc_id).get()
        return snap.to_dict() if snap.exists else None

    def set(self, collection: str, doc_id: str, data: dict, merge: bool = False) -> None:
        self.db.collection(collection).document(doc_id).set(data, merge=merge)

    def update(self, collection: str, doc_id: str, data: dict) -> None:
        self.db.collection(collection).document(doc_id).update(data)

    def stream(self, collection: str) -> list[dict]:
        return [s.to_dict() for s in self.db.collection(collection).stream()]

    def where(self, collection: str, field: str, op: str, value: Any) -> list[dict]:
        return [s.to_dict() for s in _where(self.db.collection(collection), field, op, value).stream()]

    # ---- accounts (internal camelCase dicts, see docs.account_internal)
    def account(self, account_id: str) -> dict | None:
        doc = self.get("accounts", account_id)
        return account_internal(doc) if doc else None

    def account_by_email(self, email: str) -> dict | None:
        hits = self.where("accounts", "email", "==", email.strip().lower())
        return account_internal(hits[0]) if hits else None

    def demo_accounts(self) -> list[dict]:
        return [account_internal(d) for d in self.where("accounts", "tags", "array_contains", DEMO_TAG)]

    def set_account_patients(self, account_id: str, patient_ids: list[str]) -> None:
        self.update("accounts", account_id, {"patient_ids": list(patient_ids)})

    # ---- patients (snake_case docs)
    def patient(self, patient_id: str) -> dict | None:
        return self.get("patients", patient_id)

    def patients(self, tag: str | None = None) -> list[dict]:
        rows = self.where("patients", "tags", "array_contains", tag) if tag else self.stream("patients")
        return sorted(rows, key=lambda d: d.get("patient_id", ""))

    def patient_ids(self) -> list[str]:
        return [d["patient_id"] for d in self.patients()]

    # ---- passports
    def passport(self, passport_id: str) -> dict | None:
        return self.get("passports", passport_id)

    def save_passport(self, doc: dict) -> None:
        # Keep top-level fields other services may have added; replace every field we own as a whole
        # (a deep merge would leave stale sign-off names behind when a sign-off is withdrawn).
        existing = self.passport(doc["passport_id"]) or {}
        self.set("passports", doc["passport_id"], {**existing, **doc})

    # ---- episodes
    def episodes(self, patient_id: str) -> list[dict]:
        rows = self.where("episodes", "patient_id", "==", patient_id)
        return sorted(rows, key=lambda d: d.get("timestamp", ""), reverse=True)

    def add_episode(self, doc: dict) -> None:
        self.set("episodes", doc["episode_id"], doc)

    # ---- reference data
    def resources(self) -> list[dict]:
        return sorted(self.stream("reference_resources"), key=lambda d: d.get("resource_id", ""))


class MemoryStore(Store):
    def __init__(self) -> None:
        from .fake_firestore import FakeFirestore

        super().__init__(FakeFirestore())


class FirestoreStore(Store):
    def __init__(self, project: str | None = None, database: str | None = None) -> None:
        from google.cloud import firestore  # imported lazily so memory mode needs no credentials

        super().__init__(
            firestore.Client(
                project=project or os.environ.get("GOOGLE_CLOUD_PROJECT") or None,
                database=database or os.environ.get("FIRESTORE_DATABASE") or DEFAULT_DATABASE,
            )
        )


def is_memory() -> bool:
    return os.environ.get("STORE", "").lower() == "memory"


def make_store() -> Store:
    return MemoryStore() if is_memory() else FirestoreStore()
