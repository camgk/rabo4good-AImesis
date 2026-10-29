"""Storage for the mock API.

Two implementations of the same small interface:
- FirestoreStore: named Firestore database (env FIRESTORE_DATABASE, default "aimesis-demo"),
  project from env GOOGLE_CLOUD_PROJECT. Collections: accounts, patients, plan_state,
  episodes (field patientId), resources.
- MemoryStore: dicts in memory, used when env STORE=memory (local dev, tests).

Documents are plain camelCase dicts (the wire format).
"""

from __future__ import annotations

import copy
import os
import threading
from abc import ABC, abstractmethod

from . import seed

COLLECTIONS = ("accounts", "patients", "plan_state", "episodes", "resources")


class Store(ABC):
    @abstractmethod
    def get(self, collection: str, doc_id: str) -> dict | None: ...

    @abstractmethod
    def put(self, collection: str, doc_id: str, data: dict) -> None: ...

    @abstractmethod
    def list(self, collection: str) -> list[dict]: ...

    @abstractmethod
    def query(self, collection: str, field: str, value) -> list[dict]: ...

    @abstractmethod
    def wipe(self, collection: str) -> None: ...

    @abstractmethod
    def is_empty(self, collection: str) -> bool: ...

    # ---- convenience
    def find_account_by_email(self, email: str) -> dict | None:
        hits = self.query("accounts", "email", email.strip().lower())
        return hits[0] if hits else None

    def seed(self) -> None:
        """Wipe everything and write the demo seed."""
        for c in COLLECTIONS:
            self.wipe(c)
        for a in seed.accounts():
            self.put("accounts", a["id"], a)
        for p in seed.patients():
            self.put("patients", p["id"], p)
        for s in seed.plan_states():
            self.put("plan_state", s["patientId"], s)
        for r in seed.resources():
            self.put("resources", r["id"], r)


class MemoryStore(Store):
    def __init__(self) -> None:
        self._data: dict[str, dict[str, dict]] = {c: {} for c in COLLECTIONS}
        self._lock = threading.Lock()

    def get(self, collection, doc_id):
        with self._lock:
            d = self._data.setdefault(collection, {}).get(doc_id)
            return copy.deepcopy(d) if d is not None else None

    def put(self, collection, doc_id, data):
        with self._lock:
            self._data.setdefault(collection, {})[doc_id] = copy.deepcopy(data)

    def list(self, collection):
        with self._lock:
            return [copy.deepcopy(v) for v in self._data.setdefault(collection, {}).values()]

    def query(self, collection, field, value):
        return [d for d in self.list(collection) if d.get(field) == value]

    def wipe(self, collection):
        with self._lock:
            self._data[collection] = {}

    def is_empty(self, collection):
        with self._lock:
            return not self._data.setdefault(collection, {})


class FirestoreStore(Store):
    def __init__(self, project: str | None = None, database: str | None = None) -> None:
        from google.cloud import firestore  # imported lazily so memory mode needs no credentials

        self._db = firestore.Client(
            project=project or os.environ.get("GOOGLE_CLOUD_PROJECT") or None,
            database=database or os.environ.get("FIRESTORE_DATABASE", "aimesis-demo"),
        )

    def get(self, collection, doc_id):
        snap = self._db.collection(collection).document(doc_id).get()
        return snap.to_dict() if snap.exists else None

    def put(self, collection, doc_id, data):
        self._db.collection(collection).document(doc_id).set(data)

    def list(self, collection):
        return [s.to_dict() for s in self._db.collection(collection).stream()]

    def query(self, collection, field, value):
        from google.cloud.firestore_v1.base_query import FieldFilter

        q = self._db.collection(collection).where(filter=FieldFilter(field, "==", value))
        return [s.to_dict() for s in q.stream()]

    def wipe(self, collection):
        col = self._db.collection(collection)
        while True:
            docs = list(col.limit(400).stream())
            if not docs:
                break
            batch = self._db.batch()
            for d in docs:
                batch.delete(d.reference)
            batch.commit()

    def is_empty(self, collection):
        return not list(self._db.collection(collection).limit(1).stream())


def make_store() -> Store:
    if os.environ.get("STORE", "").lower() == "memory":
        return MemoryStore()
    return FirestoreStore()
