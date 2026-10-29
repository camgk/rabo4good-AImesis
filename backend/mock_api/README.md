# aimesis-mock-api

Stand-in backend for the AImesis hackathon prototype (paediatric CINV decision support).

> **Advisory only — requires clinician sign-off.**

It is the API the Flutter apps (`frontend/web`, `frontend/ios`) use. It implements the REST contract in
`contracts/mock-api.openapi.yaml` and computes every plan with the **real UZA v2 rules engine**
(`backend/rules`, package `aimesis_rules`) through the adapter `real_rules.py`:

- `aimesis_rules`: emetogenicity per drug/day, combination rules, dexamethasone contraindication,
  drug interactions, UZA vs POGO comparison.
- `rules_mock.py` (name kept for the API contract): antiemetic doses and day schedules per the UZA v2
  formulas (ondansetron 5 mg/m² max 8 mg, aprepitant, dexamethasone BSA split, olanzapine 0.1 mg/kg
  floored to 0.5 mg, stop days, step-ups). Every line cites `UZA CINV beleid v2 (juli 2026)` or `POGO 250111`.
- `ai_summary.py`: Gemini on Vertex AI writes a clinician summary and a family explanation of the
  **computed** plan for `POST /cycles/evaluate`. It never calculates or adds doses; on any failure the
  endpoint still returns the plan with `aiError`.

`POST /cycles/evaluate` (clinician roles) takes `{"patient": <Patient>}` (same shape as `GET /patients/{id}`;
optional fields may be null, BSA is computed with Mosteller when missing), stores nothing, and returns
`{"plan", "ai", "aiError"}`. The web app's new-cycle flow uses it.

It shares the Firestore **`(default)`** database with `backend/api` (same collections, same snake_case
documents — see below and `docs/firestore-integration.md`).

## Run locally

```bash
cd backend/mock_api
pip install -e ../rules -e '.[dev]'          # the real rules engine is a dependency
gcloud auth application-default login         # once, for Gemini (Vertex AI) locally; optional
STORE=memory LOAD_DEMO_ON_START=true uvicorn aimesis_mock_api.main:app --port 8080
python3 -m pytest -q                                   # rules + API + demo-data tests (memory store)
python3 scripts/e2e_check.py http://localhost:8080     # end-to-end role check against a running API
```

## Environment

| Var | Default | Meaning |
|---|---|---|
| `STORE` | (Firestore) | `memory` = in-memory Firestore look-alike (`fake_firestore.py`; local dev, tests). Anything else = Firestore. |
| `LOAD_DEMO_ON_START` | `false` | **Only honoured with `STORE=memory`**: load the demo dataset on start (same loader as the scripts). Ignored against Firestore. |
| `FIRESTORE_DATABASE` | `(default)` | Firestore database (shared with backend/api). |
| `GOOGLE_CLOUD_PROJECT` | from ADC | GCP project for Firestore. |
| `TOKEN_SECRET` | `dev-secret` | HS256 JWT secret (12 h tokens). Set a real one on Cloud Run. |
| `PORT` | `8080` | Listen port (Docker / Cloud Run). |
| `GOOGLE_CLOUD_LOCATION` | `global` | Vertex AI location for Gemini. |
| `AIMESIS_GEMINI_MODEL` | `gemini-2.5-flash` | Gemini model for the cycle summary. |
| `AIMESIS_AI_DISABLED` | unset | `1` = skip Gemini (tests); the plan is still returned. |

On Cloud Run the service account `aimesis-mock-api` needs `roles/aiplatform.user` (in `infra/terraform/iam.tf`).
The Docker build context is `backend/rules` + `backend/mock_api` (assembled by `infra/scripts/deploy.sh`).

The service never seeds itself and has no reset endpoint. Demo data is loaded / cleared by scripts.

## Demo data (load / clear)

```bash
infra/scripts/demo-data.sh load            # upsert demo patients, draft passports, accounts, resources (idempotent)
infra/scripts/demo-data.sh load --reset    # clear demo data first, then load (fresh demo)
infra/scripts/demo-data.sh clear           # DRY RUN: prints per-collection counts and ids
infra/scripts/demo-data.sh clear --yes     # delete
```

The wrapper picks a Python with `google-cloud-firestore` (`$PYTHON`, else `~/development/mockvenv/bin/python3`,
else `python3`), takes the project from `infra/terraform/env/dev.tfvars` (override with `PROJECT_ID`) and uses
ADC (`gcloud auth application-default login`). Direct use:
`python3 scripts/load_demo_data.py --project P --database "(default)" [--reset]`,
`python3 scripts/clear_demo_data.py --project P --database "(default)" [--yes]`.

Clear deletes **only** documents whose `tags` contain `demo` (array_contains query) in `patients`, `passports`,
`episodes`, `accounts`, plus passports/episodes whose `patient_id` is a demo patient. `reference_resources` and
untagged data of other patients are never touched. Batched deletes (≤ 400 per batch).
The dataset and the load/clear logic live in `src/aimesis_mock_api/demo_data.py` (used by scripts and tests).

## Firestore layout (`(default)` database)

| Collection | Doc id | Shape |
|---|---|---|
| `patients` | `PAT-2026-0001`..`0004` (Casus 1–4) | `patient_context.schema.json` + extensions (`tags`, `sex`, `height_cm`, `diagnosis_group`, `cycle_label`, `cycle_start_date`, `active_medications`, `preferred_language`, `pairing_code`, `previous_cycles`, `risk_factors`) |
| `passports` | `PSP-2026-0001-C4` (`PSP-<n>-C<current_cycle>`) | `passport.schema.json` (`status` `active` once both `signoffs.oncologist` and `signoffs.clinical_pharmacist` are signed, else `draft`) + extensions `plan_status`, `comments`, `risk_factors`, `tags` |
| `episodes` | uuid4 | `episode.schema.json` (`severity` 1–2 mild, 3 moderate, 4–5 severe, none → mild) + `logged_by_account`, `logged_by_role`, `severity_score`, `tags` |
| `accounts` | `acc-onc`, … | mock-API login accounts (`email`, `role`, `display_name`, `patient_ids`, sha256 `password_hash`, `tags`) |
| `reference_resources` | `res-01`..`res-27` | Belgian family resources (reference data, untagged) |

Queries use a single equality / array_contains filter and sort in Python (no composite indexes needed).
The plan itself is recomputed on every request from patient + risk factors + current-cycle episodes; the
passport doc stores the workflow state and a snapshot of the computed schedule for backend/api.

## Endpoints

| Method | Path | Who |
|---|---|---|
| GET | `/healthz`, `/health` | anyone |
| GET | `/auth/demo-accounts` | anyone — accounts tagged `demo` only (empty until demo data is loaded) |
| POST | `/auth/login` `{email,password}` → `{token, account}` | anyone |
| GET | `/me` | logged in |
| GET | `/patients[?tag=demo]` | logged in (family: only own) |
| GET | `/patients/{id}` | clinicians, family for own patient |
| GET | `/patients/{id}/plan` | clinicians |
| PUT | `/patients/{id}/risk-factors` | oncologist, nurse (resets status to draft, clears sign-offs) |
| POST | `/patients/{id}/plan/submit` | oncologist → `awaiting_pharmacist` |
| POST | `/patients/{id}/plan/approve` `{comment?}` | pharmacist → `approved` |
| POST | `/patients/{id}/plan/return` `{comment}` | pharmacist → `returned` |
| GET | `/patients/{id}/passport?lang=nl\|fr\|en` | clinicians, family for own patient |
| GET/POST | `/patients/{id}/episodes` | clinicians, family for own patient |
| POST | `/pairing` `{code}` | family |
| GET | `/resources?lang=nl\|fr\|en\|de` | anyone |

Errors are always `{"error": "message"}` (401 no/invalid token, 403 role or patient not allowed, 404, 409, 422).

## Demo accounts (password `aimesis-demo`, loaded by the demo-data script)

| Email | Role | Patients |
|---|---|---|
| oncologist@demo.aimesis.app | oncologist | all |
| nurse@demo.aimesis.app | nurse | all |
| pharmacist@demo.aimesis.app | pharmacist | all |
| teen.casus1@demo.aimesis.app | patient | PAT-2026-0001 (Casus 1) |
| parent.casus2@demo.aimesis.app | parent | PAT-2026-0002 (Casus 2) |
| parent.casus3@demo.aimesis.app | parent | PAT-2026-0003 (Casus 3) |

Pairing codes: `C1-NBL2`, `C2-ALL8`, `C3-IE03`, `C4-DDI7`. Patients are fictional ("Casus 1–4").

## Files

- `src/aimesis_mock_api/main.py` — FastAPI app, CORS (all origins), endpoints, error handlers
- `store.py` — Firestore / memory store · `fake_firestore.py` — in-memory Firestore look-alike
- `docs.py` — Firestore doc (snake_case) ↔ API model (camelCase) mapping
- `demo_data.py` — demo dataset + `load_demo_data(db, reset=False)` / `clear_demo_data(db, dry_run=True)`
- `auth.py` — JWT + role checks · `rules_mock.py` — mock rules · `passport.py` — NL/FR/EN family passport
- `models.py` — pydantic models (camelCase on the wire)
- `scripts/load_demo_data.py`, `scripts/clear_demo_data.py`, `scripts/e2e_check.py`
