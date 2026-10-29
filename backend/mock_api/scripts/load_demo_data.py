#!/usr/bin/env python3
"""Load (upsert) the AImesis demo dataset into Firestore. Idempotent.

Writes: 4 demo patients (PAT-2026-0001..0004, tags ["demo"]) + a draft passport per patient (only if that
passport does not exist yet), 6 demo accounts (tags ["demo"]), 27 reference_resources (untagged).

    python3 scripts/load_demo_data.py [--project P] [--database "(default)"] [--reset]

--reset first deletes all demo data (same code as clear_demo_data.py --yes) so the demo starts fresh.
"""

from __future__ import annotations

import _common


def main() -> None:
    p = _common.parser(__doc__.splitlines()[0])
    p.add_argument("--reset", action="store_true", help="clear demo data first (episodes, sign-offs, comments)")
    args = p.parse_args()
    db = _common.connect(args)
    from aimesis_mock_api.demo_data import load_demo_data

    if args.reset:
        print("Reset: clearing demo data first")
    print("Loading demo data")
    load_demo_data(db, reset=args.reset)
    print("Done.")


if __name__ == "__main__":
    main()
