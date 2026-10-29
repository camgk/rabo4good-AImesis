#!/usr/bin/env python3
"""Clear AImesis demo data from Firestore. DRY RUN unless --yes.

Deletes ONLY: documents whose `tags` array contains "demo" in patients, passports, episodes, accounts,
plus passports/episodes whose `patient_id` is a demo-tagged patient. Never touches reference_resources or
any untagged document of a non-demo patient.

    python3 scripts/clear_demo_data.py [--project P] [--database "(default)"]        # dry run
    python3 scripts/clear_demo_data.py [--project P] [--database "(default)"] --yes  # delete
"""

from __future__ import annotations

import _common


def main() -> None:
    p = _common.parser(__doc__.splitlines()[0])
    p.add_argument("--yes", action="store_true", help="actually delete (default: dry run)")
    args = p.parse_args()
    db = _common.connect(args)
    from aimesis_mock_api.demo_data import clear_demo_data

    print("DRY RUN — nothing will be deleted (pass --yes to delete)" if not args.yes else "Deleting demo data")
    clear_demo_data(db, dry_run=not args.yes)
    print("Done." if args.yes else "Dry run done. Re-run with --yes to delete.")


if __name__ == "__main__":
    main()
