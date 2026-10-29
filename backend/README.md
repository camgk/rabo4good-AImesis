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
