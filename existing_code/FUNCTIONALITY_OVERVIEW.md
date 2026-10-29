# AImesis — `existing-code` Branch: What Has Been Built

> Scope: this documents the code on the **`existing-code`** branch, which lives entirely
> under [existing_code/](.). It is the `agents-cli`-scaffolded ADK agent (`uc3-aimesis-cinv`).
> It is a **different, earlier codebase** than the `main` branch (which has a
> `backend/agent` + `backend/api` + `backend/rules` split). This doc is about `existing_code/` only.
>
> Generated 2026-10-29.

---

## 1. One-paragraph summary

AImesis is a **pediatric oncology Clinical Decision Support (CDS) agent for Chemotherapy-Induced
Nausea & Vomiting (CINV)**. It is built as a single **Google ADK ReAct agent** (`gemini-2.5-flash`)
with four Python tool functions that classify chemo emetogenicity, screen drug–drug interactions
(CYP3A4 / QTc), map an emetogenic tier to a POGO/MASCC prophylaxis regimen, and personalize that
regimen to patient risk factors. It is served over FastAPI with both the ADK web UI and the A2A
protocol, deployable to Cloud Run, with telemetry to Cloud Trace/BigQuery. Everything is grounded
in the UZA July 2026 v2 CINV policy and POGO guidelines, and every output is labelled
**"Advisory Only — Requires Clinician Sign-Off"** — the agent never prescribes.

---

## 2. How it maps to your design diagram

| Design block | Status in `existing_code/` |
|---|---|
| **Runtime: ADK agent (Gemini, orchestrates)** | ✅ Built — [app/agent.py](app/agent.py) `root_agent` |
| **Runtime: Rules engine (Cloud Run, no LLM)** | ⚠️ Partial — rules exist as deterministic Python *tools* inside the agent, not a separate no-LLM service. A richer standalone policy engine exists but is **not wired in** (see §4). |
| **Runtime: RAG Engine (citations only)** | ❌ Not built — a Vertex vector index is *specced* ([mocks/data_products/specs.py](mocks/data_products/specs.py) `CINV_GUIDELINES_INDEX`) but there is no retrieval code. Citations are currently hard-coded strings in the tools. |
| **Offline: build the rulebook (Document AI → Gemini extract → pharmacist OK → versioned rules)** | ❌ Not built — rules are hand-curated Python dicts, not extracted from source docs. |
| **Doctor review / Passport / Audit log** | ⚠️ Partial — a `generate_cinv_patient_passport` function exists in the **unused** mocks tools (§4). No doctor-review workflow or audit log. The "Advisory Only" banner is the only sign-off gate. |
| **Evaluation gate (golden cases, dose tests, agent evals, CI gate)** | ⚠️ Partial — ADK eval config + a dataset + a response-quality grader exist ([tests/eval/](tests/eval/)); integration tests exist. No exact-match dose tests, no CI gate wired to these. |
| **Deterministic vs LLM separation** | ✅ Conceptually present — the 4 tools are pure deterministic Python; the LLM only orchestrates which to call and how to phrase the answer. |

**Bottom line:** the *Runtime → ADK agent* lane is real and working. The *offline rulebook pipeline*,
*RAG citations*, *doctor-review/passport/audit*, and *CI eval gate* from your diagram are mostly
**aspirational / stubbed** in this branch.

---

## 3. The live agent — [app/agent.py](app/agent.py)

This is the actual deployed agent. `root_agent` is an ADK `Agent` wrapped in an `App`, using
`gemini-2.5-flash`, with a long `SYSTEM_INSTRUCTION` encoding the mandatory workflow and the three
official UZA clinical cases (Casus 1–3).

### Reference data (hard-coded in the file)
- `UZA_CASUS_VOORBEELDEN` — the 3 canonical teaching cases (NBL HR-NBL2, ALL ALLTogether1, Ewing iEuroEwing) with expected recommendations.
- `PEDIATRIC_CHEMO_EMETOGENICITY` — ~30 drugs with tier (High/Moderate/Low/Minimal), rank, % frequency, clinical notes.
- Drug-class sets: `ANTHRACYCLINES`, `STRONG_MODERATE_AZOLES`, `NK1_ANTAGONISTS`, `QTC_PROLONGING_AGENTS`, `VINCA_ALKALOIDS`.
- `_normalize_drug_name()` — maps brand names / abbreviations (Zofran→ondansetron, VCR→vincristine, …) to canonical keys.

### The 4 agent tools (deterministic, no LLM inside)

| Tool | What it does | Key logic |
|---|---|---|
| `classify_regimen_emetogenicity(chemo_drugs_list)` | Per-drug + overall emetogenic tier | Takes the max tier; applies **combination-escalation rules**: Ifosfamide+Etoposide→High, Cytarabine+Daunorubicin/Etoposide→High, Cyclophosphamide+Anthracycline or ≥2 Moderate→High. Unknown drugs default conservatively. |
| `check_ddi_interactions(primary_drugs, proposed_antiemetics)` | CYP3A4 + QTc + neurotoxicity DDI screen | 5 rule families: azole+NK1 (critical), inhibitor+dexamethasone (50% dose cut), additive QTc (≥2 QTc drugs), ifosfamide+aprepitant (encephalopathy), azole+vinca (critical neurotoxicity). Returns highest severity + modifications. |
| `get_pogo_guideline_recommendation(emetogenic_tier, age, route)` | Age-stratified baseline regimen | Infant <1y / child 1–11 / adolescent ≥12 branches; returns backbone, proposed antiemetic list (feeds the DDI tool), dosing notes, citations. |
| `calculate_risk_adjusted_regimen(base_regimen, patient_risk_factors)` | Personalizes to risk factors | Handles prior/refractory CINV, anticipatory anxiety, motion sickness, steroid contraindication (ALL/CNS), QTc, infant <6mo, azole DDI, multi-day/Casus-3, Casus-1 step-up. |

**Intended workflow** (from the system prompt): classify → get baseline → DDI check → risk-adjust,
then present with the advisory banner and citations.

---

## 4. The *unused* richer policy engine — [mocks/data_products/tools.py](mocks/data_products/tools.py)

⚠️ **Not imported anywhere except itself** (confirmed via grep). This is a parallel, more detailed
implementation (`class AImesisTools`) that is **not wired into the agent**. It is worth knowing about
because it is closer to your "rules engine" block and has capabilities the live agent lacks:

- `evaluate_uza_cinv_policy_v2(...)` — a real **dose calculator**: BSA/weight-based Ondansetron,
  Aprepitant, Dexamethasone (with Aacidexam® IV mL conversion), Olanzapine (rounded down to 0.5 mg),
  dose-dependent tiering (e.g. cyclophosphamide >1500 mg/m², HD-MTX thresholds), the hard
  **"GEEN dexamethasone"** contraindication (ALL / brain tumor / dinutuximab / steroid-containing blocks),
  and personalization overrides (swallowing, breakthrough, anticipatory).
- `generate_cinv_patient_passport(...)` — builds the **CINV Patient Passport** object (User Story 4) with
  active orders, safety gate, and curated **Belgian family resources** (`BELGIAN_CINV_PATIENT_RESOURCES`).
- `check_antimicrobial_ddi(...)`, `query_pogo_guidelines(...)`, `assess_qtc_risk(...)` — CredibleMeds-based
  QTc scoring (`QTC_RISK_REGISTRY`), antifungal DDI alerts.

**Opportunity:** if you want the diagram's dedicated rules engine + passport, this file is the seed —
it just needs to be promoted into a service/tool set and connected.

---

## 5. Data-product specs & fixtures (design scaffolding, not live)

- [mocks/data_products/specs.py](mocks/data_products/specs.py) — `DataProductSpec` definitions for 5
  BigQuery/Vertex products: `chemo_emetogenicity_matrix`, `ddi_qtc_risk_catalog`, `qtc_risk_reference`
  (licence-sensitive, CredibleMeds), `faers_signal_summary` (signal-only), `cinv_pediatric_guidelines`
  (vector index). **Note:** this file imports `config.settings` and `shared.contracts`, which **do not
  exist in this branch** → it will not import/run as-is here.
- [mocks/data_products/bigquery_ddl.sql](mocks/data_products/bigquery_ddl.sql) — matching BigQuery DDL
  (EU region), including a `v_actionable_alerts` view and governance flags (`signal_only`, `synthetic`).
- [mocks/fixtures/](mocks/fixtures/) — JSON seed data: `regimens.json`, `pogo_guidelines.json`,
  `crediblemeds_qtc.json`, `openfda_labels.json`.

These describe the *intended* governed data layer but are not connected to the running agent.

---

## 6. Serving, infra & ops

- **FastAPI app** — [app/fast_api_app.py](app/fast_api_app.py): `get_fast_api_app` (ADK web UI enabled)
  + A2A routes attached in `lifespan`. Shared session/artifact services.
- **A2A protocol** — [app/app_utils/a2a.py](app/app_utils/a2a.py): dynamic agent card, JSON-RPC routes,
  v0.3 compat for Gemini Enterprise registration.
- **Services** — [app/app_utils/services.py](app/app_utils/services.py): session service (InMemory /
  Vertex AI / configured URI), artifact service (GCS when `LOGS_BUCKET_NAME` set, else in-memory).
- **Deploy** — [Dockerfile](Dockerfile), Cloud Run via `agents-cli deploy`, Terraform in
  [deployment/terraform/single-project/](deployment/terraform/single-project/) (APIs, IAM, storage,
  service, telemetry → BigQuery/Cloud Logging).
- **Dependencies** — [pyproject.toml](pyproject.toml): `google-adk[gcp,otel-gcp]`, `a2a-sdk`, FastAPI,
  uvicorn, sqlalchemy/asyncpg, Vertex eval. Python 3.11–3.13, managed with `uv`.

## 7. Tests & evaluation

- [tests/integration/test_agent.py](tests/integration/test_agent.py) — streams a message through the
  agent, asserts text comes back (smoke test; uses a generic "why is the sky blue" prompt, **not**
  the clinical cases).
- `tests/integration/test_server_e2e.py` — server end-to-end.
- `tests/unit/test_dummy.py` — placeholder.
- [tests/eval/](tests/eval/) — ADK eval: `eval_config.yaml`, `response_quality.py` grader,
  `datasets/basic-dataset.json`. **No clinical golden-case eval / exact-match dose tests yet**, and
  nothing gates CI on eval results.

## 8. Docs & source material

- [docs/](docs/) — source clinical material: UZA `Anti-emetica beleid CINV - V2.pdf`, POGO
  emetogenicity guideline PDF, `casus voorbeelden.docx`, user-stories PDF, Belgian resources xlsx,
  pitch/briefing pptx.
- [codelabs/](codelabs/) — `uc3-aimesis-quickstart.lab.md` quickstart + screenshots.
- [sources/uza_v2_policy.txt](../sources/uza_v2_policy.txt) — extracted policy text (untracked, repo root).
- [README.md](README.md), [GEMINI.md](GEMINI.md), [WORKSHOP_RESOURCES.md](WORKSHOP_RESOURCES.md).

---

## 9. Gaps vs. the design (what to build next)

1. **Rules engine as a real no-LLM service** — promote [mocks/data_products/tools.py](mocks/data_products/tools.py)
   (`evaluate_uza_cinv_policy_v2`, passport) from dead code into the agent's tool set or a separate Cloud Run service.
2. **RAG citations** — no retrieval; `CINV_GUIDELINES_INDEX` is specced but unbuilt. Citations are hard-coded strings.
3. **Offline rulebook pipeline** — no Document AI parsing, no Gemini rule extraction, no versioned/pharmacist-approved rule store. Rules are hand-written dicts.
4. **Doctor review + audit log** — only the advisory banner exists; no approve/edit flow, no Firestore/BigQuery audit trail.
5. **Fix the specs import** — [specs.py](mocks/data_products/specs.py) depends on absent `config.settings` / `shared.contracts`.
6. **Clinical eval gate** — add golden-case + exact-match dose tests over Casus 1–3 and wire a CI gate that blocks deploy on failure.
7. **Two divergent emetogenicity tables** — [app/agent.py](app/agent.py) and [tools.py](mocks/data_products/tools.py)
   disagree (e.g. ifosfamide is Moderate in one, High in the other). Consolidate to one source of truth.
