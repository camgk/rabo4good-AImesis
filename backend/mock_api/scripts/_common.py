"""Shared CLI plumbing for load_demo_data.py / clear_demo_data.py (not a script itself)."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# Run from a checkout without `pip install -e .`: make backend/mock_api/src importable.
_SRC = Path(__file__).resolve().parents[1] / "src"
if _SRC.is_dir() and str(_SRC) not in sys.path:
    sys.path.insert(0, str(_SRC))


def parser(description: str) -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=description)
    p.add_argument("--project", default=os.environ.get("GOOGLE_CLOUD_PROJECT"),
                   help="GCP project (default: env GOOGLE_CLOUD_PROJECT, else ADC default)")
    p.add_argument("--database", default=os.environ.get("FIRESTORE_DATABASE") or "(default)",
                   help='Firestore database (default: env FIRESTORE_DATABASE, else "(default)")')
    return p


def connect(args):
    """Real google-cloud-firestore client via Application Default Credentials."""
    from aimesis_mock_api.demo_data import firestore_client

    try:
        db = firestore_client(args.project, args.database)
    except Exception as exc:  # noqa: BLE001 — friendly message for missing ADC / package
        sys.exit(f"ERROR: could not create Firestore client: {exc}\n"
                 "Hint: pip install google-cloud-firestore && gcloud auth application-default login")
    print(f"Firestore project: {db.project}   database: {args.database}")
    return db
