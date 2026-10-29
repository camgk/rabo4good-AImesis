# Frontend

Flutter pub workspace (`pubspec.yaml` here) with four members:

| Package | What |
|---|---|
| `web/` | Care-team web app (oncologist, nurse, pharmacist) |
| `ios/` | Family app (parent, teen) — iOS, also runs in Chrome at phone size |
| `shared/aimesis_client/` | REST client + models (contract: `contracts/mock-api.openapi.yaml`) |
| `shared/aimesis_a2ui_catalog/` | Theme and shared widgets |

## Local development (hot reload)

```bash
frontend/scripts/dev.sh                     # web app on http://localhost:8090 + local API on :8080
frontend/scripts/dev.sh --app family        # family app, phone-size Chrome, http://localhost:8091
frontend/scripts/dev.sh --app both          # both
frontend/scripts/dev.sh --api live          # against the Cloud Run API (shared Firestore — real records!)
frontend/scripts/dev.sh --api http://localhost:9000
```

- In the terminal: `r` hot reload, `R` hot restart, `q` quit. Save in your editor, press `r`.
- **Local API (default):** `backend/mock_api` in memory with the demo patients and accounts loaded
  (`STORE=memory LOAD_DEMO_ON_START=true`). It auto-reloads on backend changes and never touches
  Firestore. Restart it (`pkill -f "uvicorn aimesis_mock_api"`) for a fresh demo. The first run
  creates `backend/mock_api/.venv` (needs Python 3.12+). Log: `/tmp/aimesis-local-api.log`.
- Demo accounts (password `aimesis-demo`): `oncologist@`, `nurse@`, `pharmacist@`,
  `teen.casus1@`, `parent.casus2@`, `parent.casus3@demo.aimesis.app` — the login screens offer them as quick-picks.
- Ports: `WEB_PORT`, `FAMILY_PORT`, `API_PORT` env vars. Flutter path: `FLUTTER=…` (defaults to `flutter` on PATH,
  then `~/development/flutter/bin/flutter`).

Only deploy when you need a shareable link: `infra/scripts/deploy.sh --only web` (≈ 4 min).

## Checks

```bash
cd frontend && flutter pub get
flutter analyze web ios shared
(cd web && flutter test) && (cd ios && flutter test) && (cd shared/aimesis_client && flutter test)
```
