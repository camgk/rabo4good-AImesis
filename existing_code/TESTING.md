# Testing the AImesis Agent

How to run and try the `uc3-aimesis-cinv` agent locally. Three options, easiest first.

All commands are run from the [existing_code/](.) directory:

```bash
cd existing_code
```

---

## Option A — Test the clinical logic with NO cloud / NO API key (fastest)

The 4 tools are plain deterministic Python. You can exercise the actual clinical
logic without Gemini, a GCP project, or any key. Good for sanity-checking the rules.

```bash
uv run python -c "
from app.agent import (
    classify_regimen_emetogenicity,
    get_pogo_guideline_recommendation,
    check_ddi_interactions,
    calculate_risk_adjusted_regimen,
)
import json

# Casus 1: 16yo, neuroblastoma, cisplatin + vincristine, on voriconazole
emeto = classify_regimen_emetogenicity(['cisplatin', 'vincristine'])
print('TIER:', emeto['overall_emetogenic_tier'])          # -> High

base = get_pogo_guideline_recommendation(emeto['overall_emetogenic_tier'], age=16)
print('BASELINE:', base['recommended_backbone'])

ddi = check_ddi_interactions(
    primary_drugs=['cisplatin', 'vincristine', 'voriconazole'],
    proposed_antiemetics=base['proposed_antiemetics_list'],
)
print('DDI SEVERITY:', ddi['highest_severity'])           # -> CRITICAL (azole + vinca)
for i in ddi['interactions_found']:
    print('  -', i['severity'], ':', i['interacting_pair'])

adj = calculate_risk_adjusted_regimen(base['recommended_backbone'], ['prior_cinv'])
print('ADJUSTED:', adj['personalized_regimen_summary'][:200], '...')
"
```

If this prints a High tier and a CRITICAL azole+vincristine interaction, the core logic works.
Try the other canonical cases:

- **Casus 2 (ALL, no steroids):** `['vincristine', 'daunorubicin']` → Moderate; the agent must NOT add dexamethasone.
- **Casus 3 (Ewing IE):** `['ifosfamide', 'etoposide']` → should escalate to **High** via the combination rule (each alone is lower).

---

## Option B — Chat with the full agent in the web playground (recommended)

This runs the real Gemini-orchestrated agent with a chat UI. You need **one** of:

### 1. Pick an auth method — edit `.env`

```bash
cp .env.example .env
```

Then either:

**(a) Google AI Studio key (simplest, no GCP project):** edit `.env` to comment out the three
`GOOGLE_*` lines and set:
```
GEMINI_API_KEY=your-key-from-aistudio.google.com
```

**(b) Vertex AI (if you have a GCP project):** keep the defaults and set your project, then auth:
```
GOOGLE_GENAI_USE_VERTEXAI=true
GOOGLE_CLOUD_PROJECT=your-gcp-project-id
GOOGLE_CLOUD_LOCATION=global
```
```bash
gcloud auth application-default login
```

### 2. Install deps and launch

```bash
uv sync                 # installs into a local .venv (Python 3.11+ managed by uv)
uv run adk web          # opens the ADK dev UI, usually at http://localhost:8000
```

Pick **`app`** in the agent dropdown and start chatting. Watch the **"Events"/trace** panel to
see which tools Gemini calls and with what arguments — that's the best way to verify behavior.

> If `agents-cli` is installed (`uv tool install google-agents-cli`), `agents-cli playground`
> does the same thing with auto-reload on save.

### Prompts to try

```
A 16-year-old girl with neuroblastoma is on HR-NBL2 RAPID COJEC, cycle B4:
cisplatin + vincristine. She's also taking voriconazole and had breakthrough
nausea on day 2 of the last cycle. What antiemetic regimen do you recommend?
```
```
2-year-old with ALL on ALLTogether1 Induction B, day 8: vincristine + daunorubicin.
What CINV prophylaxis should we use?
```
*(Expect: it should refuse to add dexamethasone for ALL.)*
```
Ewing sarcoma patient on iEuroEwing, 5-day IE cycle: ifosfamide + etoposide.
Prior day-4 breakthrough vomiting. Recommend prophylaxis.
```

**What to check in every answer:**
- Correct overall emetogenic tier
- The "Advisory Only — Requires Clinician Sign-Off" banner is present
- Dangerous interactions are flagged (e.g. azole + vincristine, dexamethasone in ALL)
- It cites UZA v2 / POGO

---

## Option C — Run the API server (for integration / A2A testing)

```bash
uv run uvicorn app.fast_api_app:app --host 0.0.0.0 --port 8000
```

- ADK web UI + REST API at `http://localhost:8000` (docs at `/docs`).
- A2A agent card at `http://localhost:8000/a2a/app/.well-known/agent-card.json`.

---

## Running the test suite

```bash
# Unit + integration (the integration test calls the live model, so needs auth from Option B)
uv run pytest tests/unit tests/integration

# Just the fast unit test, no model needed
uv run pytest tests/unit

# ADK evaluation
uv run pytest tests/eval      # or: agents-cli eval
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `adk: command not found` | Use `uv run adk ...` (don't rely on a global `adk`). |
| Auth / 401 / "could not find credentials" | You skipped `.env` setup. Do Option B step 1. |
| `Python 3.10` errors / wrong version | The project needs 3.11–3.13; let `uv sync` provision it rather than using system Python. |
| Model refuses or gives vague "verify manually" | The drug isn't in the hard-coded table in [app/agent.py](app/agent.py) — expected limitation. |
| Want to see *why* it answered | Open the Events/trace panel in `adk web` to see tool calls + arguments. |
