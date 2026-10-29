# AImesis Backend

Pediatric Oncology Chemotherapy-Induced Nausea and Vomiting (CINV) Decision Support backend for the University Hospital Antwerp (UZA) & POGO 2025 guidelines.

The backend consists of three packages inside a workspace:
- **`rules/` (`aimesis-rules`)**: Deterministic clinical rules engine (antiemetic regimen selection, pediatric dosing formulas, DDI checks, POGO comparison). Pure Python, no external network dependencies.
- **`agent/` (`aimesis-agent`)**: Google ADK Agent service with Gemini 2.5 Flash (`google-genai` / Vertex AI) and AG-UI / A2UI surface endpoints.
- **`api/` (`aimesis-api`)**: Clinical REST API for patient cycle episode logging, breakthrough tracking, dual sign-off governance, and multilingual (NL/FR/EN) Patient Passport generation.

When running `aimesis_agent.main:app`, **all routes** (ADK, AG-UI, Episodes, and Passport) are mounted and served together on a single unified server.

---

## 1. Prerequisites & GCP Authentication

### Prerequisites
- Python 3.12 (or [`uv`](https://docs.astral.sh/uv/))
- [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install)
- Docker (optional, for containerized execution)

### Google Cloud / Vertex AI Setup
Authenticate with Application Default Credentials (ADC) to access Vertex AI (`gemini-2.5-flash`):
```bash
gcloud auth application-default login
```
This saves credentials locally at `~/.config/gcloud/application_default_credentials.json`.

Ensure your environment variables are configured:
```bash
export GOOGLE_GENAI_USE_VERTEXAI=TRUE
export GOOGLE_CLOUD_PROJECT=qwiklabs-gcp-00-cc29ec8bfdd9
export GOOGLE_CLOUD_LOCATION=global
```

---

## 2. Running Locally (Python)

### Setup Virtual Environment
From the `backend` directory:

```bash
cd backend

# Create virtualenv
python3.12 -m venv .venv
source .venv/bin/activate

# Upgrade pip & install all packages in editable mode
pip install --upgrade pip
pip install -e ./rules -e ./api -e ./agent
```

*(Alternatively, if you use `uv`: `uv sync`)*

### Run Option A: Unified Server (Port 8000)
Runs the complete backend with **all** endpoints (Agent, AG-UI, Episodes, Passport, Health) on port 8000:

```bash
# From backend directory with .venv active:
uvicorn aimesis_agent.main:app --host 0.0.0.0 --port 8000 --reload
```

### Run Option B: Split Services (Two Terminals)
If you prefer running the Agent and REST API as separate services:

- **Terminal 1: Agent & AG-UI Service (Port 8000)**
  ```bash
  uvicorn aimesis_agent.main:app --host 0.0.0.0 --port 8000 --reload
  ```
- **Terminal 2: Clinical REST API (Port 8001)**
  ```bash
  uvicorn aimesis_api.main:app --host 0.0.0.0 --port 8001 --reload
  ```

---

## 3. Running with Docker

### Build the Unified Backend Image
From the repository root or the `backend/` directory:

```bash
# From backend/
docker build -t aimesis-backend .

# Or from repository root:
docker build -f backend/Dockerfile -t aimesis-backend ./backend
```

### Run the Docker Container Locally (with GCP ADC)
Mount your local ADC credentials JSON file into the container:

```bash
docker run --rm -p 8000:8000 \
  -e GOOGLE_GENAI_USE_VERTEXAI=TRUE \
  -e GOOGLE_CLOUD_PROJECT=qwiklabs-gcp-00-cc29ec8bfdd9 \
  -e GOOGLE_CLOUD_LOCATION=global \
  -e GOOGLE_APPLICATION_CREDENTIALS=/gcp/creds.json \
  -v "$HOME/.config/gcloud/application_default_credentials.json:/gcp/creds.json:ro" \
  aimesis-backend
```

> **Note on Cloud Run / GKE:** When running in Google Cloud Run, do not mount credentials or set `GOOGLE_APPLICATION_CREDENTIALS`. Vertex AI automatically authenticates via the attached Cloud Run service account.

---

## 4. API Endpoints & Verification

### Health Check
```bash
curl http://localhost:8000/health
```
Response:
```json
{
  "status": "healthy",
  "service": "aimesis-agent",
  "policy_version": "UZA Kinderoncologie CINV Beleid V2 (Juli 2026)",
  "benchmark_version": "POGO 2025 (250111)"
}
```

### AG-UI Component Catalog
```bash
curl http://localhost:8000/agui/catalog
```

### Clinical Episodes & Cycle Tracking
- `POST /episodes`: Create episode & compute UZA v2 protocol
- `GET /episodes`: List episodes
- `GET /episodes/{episode_id}`: Retrieve episode
- `POST /episodes/{episode_id}/breakthrough`: Log breakthrough vomiting/nausea event
- `POST /episodes/{episode_id}/sign-off`: Oncologist & pharmacist dual sign-off

### Multilingual Patient Passport (NL / FR / EN)
- `POST /passport/generate`: Generate passport JSON + HTML
- `POST /passport/export-html`: Export validated printable HTML (requires dual sign-off)

### ADK Agent Routes
- `POST /run`: Run agent prompt / session
- `POST /run_sse`: Stream agent execution via Server-Sent Events (SSE)
- `GET /list-apps`: List registered ADK agent applications
- `GET /dev-ui`: Google ADK Developer Web UI

---

## 5. Running Tests

```bash
# Run all unit and golden dataset tests
python -m pytest rules/tests agent/tests api/tests
```


## Story 1 — Regimen risk assessment

The unified image now includes an independent workbench at **`/regimens`**.
It determines risk and baseline prophylaxis without requiring patient biometrics,
Gemini credentials, Firestore, or the Flutter mock API. The ADK classification
tool uses the same deterministic rules.

From the repository root, build and run on a free host port:

```bash
docker build -f backend/Dockerfile -t aimesis-backend ./backend
docker run --rm --name aimesis-story1 -p 8002:8000 -e USE_FIRESTORE=false aimesis-backend
```

Open <http://localhost:8002/regimens>. Load any of the three official cases or
enter drugs, doses (mg/m²), routes and treatment days. Results show individual,
daily and overall risk, combination rules, baseline strategy and source citations.
The no-credentials launch supports deterministic Story 1; Gemini chat still needs
the credential mount described above. An older running image must be rebuilt and
its container recreated before this page is available.

Programmatic access (also exposed by the standalone API service):

```bash
curl -X POST http://localhost:8002/regimens/classify \
  -H 'Content-Type: application/json' \
  -d '{"drugs":[{"drug":"ifosfamide","days":[1,2]},{"drug":"etoposide","days":[2,3]}]}'
```

This returns Moderate on day 1, High on day 2 (combination exception), Low on day
3, and an overall High tier. `GET /regimens/policy` lists the active UZA agents.
Missing/unknown clinical inputs return a structured refusal, not a guessed tier.
Malformed input returns HTTP 422. Exactly 200 mg/m² cytarabine is flagged for
clinical review because the supplied UZA table leaves that boundary unspecified.

These outputs are baseline strategies, not patient-specific prescriptions.
Patient personalization, doses, interactions and approvals remain separate steps.
See `docs/clinical-rules.md` and `docs/open-questions.md` for scope and assumptions.


## Story 2 — Patient-specific dose calculations

Open **`/dosing`** on the unified backend. This is a working browser page;
no Gemini credentials are needed for record entry and deterministic calculations.
It links to Story 1 and uses its regimen classification automatically.

Rebuild the image after pulling these changes. From the repository root in WSL:

```bash
docker build -f backend/Dockerfile -t aimesis-backend ./backend
docker run --rm --name aimesis-story2 -p 8005:8000 -e USE_FIRESTORE=false aimesis-backend
```

Open <http://localhost:8005/dosing>. Choose a fictional example, then click
**Save record and calculate**. Alternatively load a patient ID already saved in
this backend. The page shows the selected BSA and measurement time, dose amounts,
formulas, caps, rounding, routes, timing and UZA source rules. It separates rescue
options from routine prophylaxis. Local demo records reset on container restart.

REST example (fictional patient):

```bash
curl -X PUT http://localhost:8005/patients/DEMO-S2 \
  -H 'Content-Type: application/json' \
  -d '{"age_years":8,"weight_kg":25,"bsa_m2":0.8,"bsa_measured_at":"2026-10-29T10:00:00Z","diagnosis":"osteosarcoma","preferred_formulation":"oral_tablet","chemo_regimen":[{"drug_name":"cisplatin","dose_mg_per_m2":60,"route":"IV","day_numbers":[1]}]}'

curl -X POST http://localhost:8005/patients/DEMO-S2/dosing \
  -H 'Content-Type: application/json' -d '{}'
```

This example returns ondansetron `5 mg/m² × 0.8 m² = 4 mg` per dose.
For IV administration, the calculation body can include
`{"antiemetic_route":"IV","aprepitant_route":"IV","fosaprepitant_schedule":"multi_day"}`.
Oral aprepitant and IV fosaprepitant have different dose caps. A single IV dose is
available only for one-day chemotherapy. The API documents options at `/docs`.

Every calculation fetches the patient record again. Submit a later BSA observation
with `PUT /patients/{id}` containing `bsa_m2` and `bsa_measured_at`; older values
remain in `bsa_measurements`. Timestamps must include a timezone. The newest
measurement wins even if an older observation was entered afterwards. Conflicting
values at the same time, invalid biometrics and missing diagnoses require correction.
The dose endpoint does not accept a BSA override. Legacy scalar BSA records still
work, with an unknown measurement time explicitly marked. If an API/agent save
omits the timestamp, its observation is labelled with recording time instead.
Use the patient endpoint to update BSA history; external writers should append a
new observation rather than only overwriting the scalar snapshot.

The agent has the **`get_patient_dosing(patient_id)`** tool, backed by exactly the
same patient store and calculator. With your existing Gemini credentials enabled,
ask: `Use get_patient_dosing to calculate the antiemetic doses for patient DEMO-S2.
Show the BSA measurement time, formulas, dose caps and UZA rules.`
The page and tool share records when served by the same unified backend process.

For persistent Google Cloud records, enable `USE_FIRESTORE=true`, set
`GOOGLE_CLOUD_PROJECT` and optionally `FIRESTORE_DATABASE`, and mount your existing
application default credentials as described above. Reads/writes use the `patients`
collection. Configured database failures return an error rather than switching to
demo records. Firestore integration is covered with a fake client; no live Google
Cloud database or Gemini model is required by the automated tests.

Doses follow the supplied UZA v2 page 2: ondansetron uses BSA, dexamethasone uses
BSA bands, and other medicines use weight or age. Dexamethasone exclusions still
apply, and its aprepitant adjustment is applied once. These calculations are
advisory and do not complete interaction review or clinical sign-off. The separate
Flutter mock frontend is not rewired by this story.
