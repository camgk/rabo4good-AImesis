"""A tiny in-memory stand-in for google.cloud.firestore.Client.

Implements only the subset the mock API and the demo-data scripts use, with the same call shapes:

    db.collection(name).document(id).get() / .set(data, merge=False) / .update(data) / .delete()
    db.collection(name).stream()
    db.collection(name).where(filter=FieldFilter(field, "==" | "array_contains", value)).limit(n).stream()
    db.batch().set(ref, data) / .delete(ref) / .commit()

Used by STORE=memory (local dev, tests) so the API, the load/clear logic and the tests all run the
exact same code path as against real Firestore.
"""

from __future__ import annotations

import copy
import threading
from typing import Any


class _Snapshot:
    def __init__(self, ref: "_DocRef", data: dict | None) -> None:
        self.reference = ref
        self.id = ref.id
        self._data = data

    @property
    def exists(self) -> bool:
        return self._data is not None

    def to_dict(self) -> dict | None:
        return copy.deepcopy(self._data) if self._data is not None else None


class _DocRef:
    def __init__(self, db: "FakeFirestore", collection: str, doc_id: str) -> None:
        self._db = db
        self._collection = collection
        self.id = doc_id

    def _docs(self) -> dict:
        return self._db._data.setdefault(self._collection, {})

    def get(self) -> _Snapshot:
        with self._db._lock:
            return _Snapshot(self, copy.deepcopy(self._docs().get(self.id)))

    def set(self, data: dict, merge: bool = False) -> None:
        with self._db._lock:
            docs = self._docs()
            if merge and self.id in docs:
                docs[self.id] = _deep_merge(docs[self.id], copy.deepcopy(data))
            else:
                docs[self.id] = copy.deepcopy(data)

    def update(self, data: dict) -> None:
        with self._db._lock:
            docs = self._docs()
            if self.id not in docs:
                raise KeyError(f"No document to update: {self._collection}/{self.id}")
            for path, value in data.items():
                target = docs[self.id]
                parts = path.split(".")
                for p in parts[:-1]:
                    target = target.setdefault(p, {})
                target[parts[-1]] = copy.deepcopy(value)

    def delete(self) -> None:
        with self._db._lock:
            self._docs().pop(self.id, None)


def _deep_merge(base: dict, extra: dict) -> dict:
    out = dict(base)
    for k, v in extra.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = _deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def _matches(doc: dict, field: str, op: str, value: Any) -> bool:
    cur: Any = doc
    for p in field.split("."):
        if not isinstance(cur, dict) or p not in cur:
            return False
        cur = cur[p]
    if op == "==":
        return cur == value
    if op == "array_contains":
        return isinstance(cur, list) and value in cur
    if op == "in":
        return cur in value
    raise NotImplementedError(f"FakeFirestore does not support operator {op!r}")


class _Query:
    def __init__(self, db: "FakeFirestore", collection: str, filters=None, limit: int | None = None) -> None:
        self._db = db
        self._collection = collection
        self._filters = list(filters or [])
        self._limit = limit

    def where(self, field_path: str | None = None, op_string: str | None = None, value: Any = None, *, filter=None):
        if filter is not None:
            f = (filter.field_path, filter.op_string, filter.value)
        else:
            f = (field_path, op_string, value)
        return _Query(self._db, self._collection, self._filters + [f], self._limit)

    def limit(self, n: int) -> "_Query":
        return _Query(self._db, self._collection, self._filters, n)

    def stream(self):
        with self._db._lock:
            items = sorted(self._db._data.setdefault(self._collection, {}).items())
            hits = [
                (doc_id, copy.deepcopy(doc))
                for doc_id, doc in items
                if all(_matches(doc, *f) for f in self._filters)
            ]
        if self._limit is not None:
            hits = hits[: self._limit]
        for doc_id, doc in hits:
            yield _Snapshot(_DocRef(self._db, self._collection, doc_id), doc)


class _Collection(_Query):
    def document(self, doc_id: str) -> _DocRef:
        return _DocRef(self._db, self._collection, doc_id)


class _Batch:
    def __init__(self, db: "FakeFirestore") -> None:
        self._db = db
        self._ops: list[tuple] = []

    def set(self, ref: _DocRef, data: dict, merge: bool = False) -> None:
        self._ops.append(("set", ref, data, merge))

    def delete(self, ref: _DocRef) -> None:
        self._ops.append(("delete", ref))

    def commit(self) -> None:
        if len(self._ops) > 500:
            raise ValueError("Firestore batches are limited to 500 writes")
        self._db.batch_sizes.append(len(self._ops))
        for op in self._ops:
            if op[0] == "set":
                op[1].set(op[2], merge=op[3])
            else:
                op[1].delete()
        self._ops = []


class FakeFirestore:
    """In-memory Firestore look-alike (single process, thread-safe)."""

    def __init__(self, project: str = "memory", database: str = "(memory)") -> None:
        self.project = project
        self._database = database
        self._data: dict[str, dict[str, dict]] = {}
        self._lock = threading.RLock()
        self.batch_sizes: list[int] = []  # for tests: size of every committed batch

    def collection(self, name: str) -> _Collection:
        return _Collection(self, name)

    def batch(self) -> _Batch:
        return _Batch(self)
