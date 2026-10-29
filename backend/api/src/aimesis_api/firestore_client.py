"""Firestore database client initialization for rabo4good-AImesis."""

from __future__ import annotations

import os
from functools import lru_cache
from typing import Any

try:
    from google.cloud import firestore  # type: ignore[import-untyped]
except ImportError:
    firestore = None  # Fallback for environments where google-cloud-firestore is not yet installed


DEFAULT_PROJECT_ID = os.getenv("GCP_PROJECT", "qwiklabs-gcp-00-cc29ec8bfdd9")
DEFAULT_DATABASE_NAME = os.getenv("FIRESTORE_DATABASE", "(default)")


@lru_cache(maxsize=1)
def get_firestore_client() -> Any:
    """Return a singleton Google Cloud Firestore client.

    Uses application default credentials or connects to the local emulator
    if FIRESTORE_EMULATOR_HOST is set.
    """
    if firestore is None:
        raise RuntimeError(
            "google-cloud-firestore is not installed. "
            "Please run: pip install google-cloud-firestore"
        )

    project_id = os.getenv("GCP_PROJECT", DEFAULT_PROJECT_ID)
    database = os.getenv("FIRESTORE_DATABASE", DEFAULT_DATABASE_NAME)

    return firestore.Client(project=project_id, database=database)
