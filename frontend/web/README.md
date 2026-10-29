# AImesis — Care team (Flutter web)

Care-team app for oncologists, nurse specialists and hospital pharmacists.
Hackathon prototype: **advisory only, demo data, mock rules.** Every page shows the advisory banner.

## Pages

| Route | Page | User story |
|---|---|---|
| `/login` | Login with demo-account quick-pick (clinician roles only; family roles are told to use the Family app) | — |
| `/worklist` | Patients: alias, age, diagnosis, protocol, cycle, overall tier, plan status | — |
| `/pharmacist` | Pharmacist queue: plans awaiting pharmacist first (read-only for other roles) | sign-off |
| `/about` | What is mock, demo accounts, story map | — |
| `/patients/:id/regimen` | Regimen & tier: per-drug tier + rule + source, per-day tier strip, combination rules | 1 |
| `/patients/:id/risk` | Risk factors (swallow tablets, route, anticipatory), previous cycles, companion-app log; save recalculates | 3 |
| `/patients/:id/safety` | Safety gates: dexamethasone block + interactions (critical/warning/info) | 6 |
| `/patients/:id/plan` | Plan & doses: dose table with "How was this calculated?", step-ups, alternatives, breakthrough; refusal screen | 2, 3 |
| `/patients/:id/evidence` | UZA v2 vs POGO, "only differences" toggle | 5 |
| `/patients/:id/signoff` | Timeline, comments, submit (oncologist) / approve or return (pharmacist) | dual sign-off |
| `/patients/:id/passport` | Printable one-page Passport in NL/FR/EN with QR pairing code | 4 |

Demo accounts (password `aimesis-demo`): `oncologist@demo.aimesis.app`, `nurse@demo.aimesis.app`, `pharmacist@demo.aimesis.app`.

## Configuration

At startup the app fetches `config.json` next to `index.html` (`{"apiUrl": "https://mock-api-…run.app"}`).
If it is missing, it falls back to `--dart-define=API_URL=…`, then `http://localhost:8080`.
In the container, `docker/40-write-config-json.sh` writes `config.json` from env `API_URL` at start.

The login token is kept in `sessionStorage`, so a page refresh keeps you logged in (closing the tab logs you out).

## Run locally

```bash
# from frontend/ (pub workspace root)
flutter pub get

# backend: the demo API on :8080 (see backend/mock_api)
cd web
flutter run -d chrome --dart-define=API_URL=http://localhost:8080
```

## Check

```bash
cd frontend/web
flutter analyze
flutter test
flutter build web --release      # → build/web
```

Serve the build locally:

```bash
echo '{"apiUrl": "http://localhost:8080"}' > build/web/config.json
python3 -m http.server 8090 -d build/web     # http://localhost:8090 (deep links need nginx)
```

## Docker / Cloud Run

The image only packages the prebuilt `build/web` (no Flutter inside the image).

```bash
flutter build web --release
docker build -t aimesis-web .
docker run --rm -p 8081:8080 -e API_URL=http://localhost:8080 aimesis-web   # http://localhost:8081
```

nginx listens on `$PORT` (default 8080, Cloud Run sets it), falls back to `index.html` for SPA routes,
and sends `no-cache` for `index.html`, `config.json` and `flutter_service_worker.js`.
`.gcloudignore` / `.dockerignore` keep `build/web` and drop everything else heavy.

## Code map

```
lib/
  main.dart, app.dart        bootstrap: load config, restore session, MaterialApp.router
  config.dart                config.json → dart-define → localhost
  router.dart                go_router, login redirect, WorkspaceTab enum
  state/                     AppState (session, api), PatientWorkspace (patient + plan cache)
  shell/app_shell.dart       app bar, role-aware navigation rail, advisory banner
  pages/                     login, worklist, pharmacist_queue, about, patient (workspace + header),
                             risk_tier, personalise, interactions, doses, uza_vs_pogo, signoff, passport
  agent/                     AG-UI / A2UI stubs — switch from REST mock when backend/agent is deployed
  platform/                  sessionStorage / window.open / print via package:web (VM stub for tests)
  widgets/                   shared UI bits (tables, status chips, empty/error states)
```

Shared code: `package:aimesis_client` (REST client + models) and `package:aimesis_a2ui_catalog`
(theme, `TierBadge`, `AdvisoryBanner`, `DexStatusBanner`) in `frontend/shared/`.
