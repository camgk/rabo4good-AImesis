# aimesis-mock-api

Demo backend for the AImesis hackathon prototype (paediatric CINV decision support).

> **Advisory only — requires clinician sign-off. Demo data, not for clinical use.**

This is a **stand-in** so the Flutter apps (`frontend/web`, `frontend/ios`) can run today.
It implements the REST contract in `contracts/mock-api.openapi.yaml` with a small **mock** rules engine
(`rules_mock.py`, every line labelled `UZA v2 (mock rules)`). It will be replaced by
`backend/api` + `backend/agent` (which use the real engine in `backend/rules`) once those are ready.

It is a standalone package: it is **not** part of the `backend/` uv workspace and imports nothing from it.

## Run locally

```bash
cd backend/mock_api
pip install -e '.[dev]'            # or: python -m venv .venv && . .venv/bin/activate && pip install -e '.[dev]'
STORE=memory uvicorn aimesis_mock_api.main:app --port 8080
pytest                             # rules + API tests (memory store)
```

Docker / Cloud Run:

```bash
docker build -t mock-api . && docker run -p 8080:8080 -e STORE=memory mock-api
gcloud run deploy mock-api --source . --region europe-west1 \
  --set-env-vars FIRESTORE_DATABASE=aimesis-demo,TOKEN_SECRET=<secret>
```

## Environment

| Var | Default | Meaning |
|---|---|---|
| `STORE` | (Firestore) | `memory` = in-memory store (local, tests). Anything else = Firestore. |
| `FIRESTORE_DATABASE` | `aimesis-demo` | Named Firestore database. |
| `GOOGLE_CLOUD_PROJECT` | from ADC | GCP project for Firestore. |
| `TOKEN_SECRET` | `dev-secret` | HS256 JWT secret (12 h tokens); also the `X-Demo-Reset` value. Set a real one on Cloud Run. |
| `SEED_ON_START` | `true` | Seed demo data on startup when the `accounts` collection is empty. |
| `PORT` | `8080` | Listen port (Docker / Cloud Run). |

Firestore collections: `accounts`, `patients`, `plan_state` (per patient: status, riskFactors, signoffs,
comments), `episodes` (field `patientId`), `resources`. Plan content is never stored; it is recomputed
on each request from patient + riskFactors + current-cycle episodes.

## Endpoints

| Method | Path | Who |
|---|---|---|
| GET | `/healthz` | anyone |
| GET | `/auth/demo-accounts` | anyone (login quick-pick) |
| POST | `/auth/login` `{email,password}` → `{token, account}` | anyone |
| GET | `/me` | logged in |
| GET | `/patients` | logged in (family: only own) |
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
| POST | `/admin/reset` (header `X-Demo-Reset: <TOKEN_SECRET>`) | demo operator — wipes episodes + plan state, reseeds |

Errors are always `{"error": "message"}` (401 no/invalid token, 403 role or patient not allowed, 404, 409, 422).

## Demo accounts (password `aimesis-demo`)

| Email | Role | Patients |
|---|---|---|
| oncologist@demo.aimesis.app | oncologist | all |
| nurse@demo.aimesis.app | nurse | all |
| pharmacist@demo.aimesis.app | pharmacist | all |
| teen.casus1@demo.aimesis.app | patient | casus-1 |
| parent.casus2@demo.aimesis.app | parent | casus-2 |
| parent.casus3@demo.aimesis.app | parent | casus-3 |

Pairing codes: `C1-NBL2`, `C2-ALL8`, `C3-IE03`, `C4-DDI7`. Patients are fictional ("Casus 1–4").

## Files

- `src/aimesis_mock_api/main.py` — FastAPI app, CORS (all origins), endpoints, error handlers
- `auth.py` — JWT + role checks · `store.py` — Firestore / memory store · `seed.py` — demo data
- `rules_mock.py` — mock rules (tiers, doses, dexamethasone, step-ups, interactions, UZA vs POGO)
- `passport.py` — NL/FR/EN family passport · `models.py` — pydantic models (camelCase on the wire)
