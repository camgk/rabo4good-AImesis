# Google Cloud Firestore Database & Patient Passport Overview

This document provides a comprehensive technical reference for the Google Cloud Firestore database deployed for **rabo4good-AImesis** (Solve with Google: BSPHO 2026 / Pediatric CINV Control). It details the collections, data models, and system integrations linking the Clinician Web App, Family Companion App, and Cloud Run backend services.

> [!IMPORTANT]
> **Data Privacy Notice**: This repository and its documentation contain **no confidential or real patient data**. All schemas and illustrations use synthetic, anonymized structures and abstract clinical archetypes in compliance with the project's data governance standards.

---

## 1. Firestore Deployment Details

- **GCP Project ID**: `qwiklabs-gcp-00-cc29ec8bfdd9`
- **Database Mode**: `FIRESTORE_NATIVE`
- **Database Name**: `(default)` (`projects/qwiklabs-gcp-00-cc29ec8bfdd9/databases/(default)`)
- **Location / Region**: `europe-west1` (Belgium / Western Europe)
- **Deployment Automation**: Provisioned via Terraform in [`infra/terraform/firestore.tf`](file:///config/.gemini/antigravity/scratch/rabo4good-AImesis/infra/terraform/firestore.tf)

---

## 2. Collections & Data Models

The database manages five core collections supporting the clinical care-team workflow and family companion app:

```
projects/qwiklabs-gcp-00-cc29ec8bfdd9/databases/(default)/
├── accounts/               (Care team & family RBAC user profiles)
├── patients/               (Pseudonymized clinical metrics & chemotherapy regimens)
├── passports/              (Generated CINV Patient Passports & schedules)
├── reference_resources/    (Curated Belgian pediatric oncology hospital guides & deep links)
└── episodes/               (Real-time patient symptom & rescue medication logs)
```

---

### Collection 1: `patients`

Grounding contract: [`contracts/schemas/patient_context.schema.json`](file:///config/.gemini/antigravity/scratch/rabo4good-AImesis/contracts/schemas/patient_context.schema.json).  
Stores pseudonymized patient clinical parameters required for antiemetic decision support and dose calculations under UZA Policy v2.

#### Document Schema & Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| `patient_id` | String | Unique pseudonymized patient identifier (e.g. `PAT-001`). |
| `display_pseudonym` | String | Display pseudonym used across UI surfaces (e.g. `Patient A`). |
| `age_years` | Number | Patient age in years; guides age-specific dosing thresholds and tablet capability. |
| `sex` | String | Biological sex (`M` or `F`). |
| `weight_kg` | Number | Weight in kilograms; used for weight-based dose formulas (mg/kg). |
| `height_cm` | Number | Height in centimeters. |
| `bsa_m2` | Number | Body Surface Area in m² calculated via the Mosteller formula; used for BSA-based dosing (mg/m²). |
| `diagnosis` | String | Clinical diagnosis category. |
| `diagnosis_group` | String | Broad classification (`solid` tumor vs. `ALL` / hematologic); governs corticosteroid contraindication gates. |
| `protocol_name` | String | Named pediatric oncology protocol. |
| `current_cycle` | Integer | Active cycle sequence number. |
| `cycle_label` | String | Clinical label for the active cycle. |
| `cycle_start_date` | String | ISO-8601 date string for Day 1 of chemotherapy administration. |
| `chemo_regimen` | Array | Chemotherapy agents planned for the cycle, including drug name, dose (mg/m² or mg/kg), and administration day numbers. |
| `history_previous_cycles` | Object | Prior emesis response data: refractory CINV flag, prior episode counts, anticipatory nausea, and clinician ward notes. |
| `preferred_formulation` | String | Preferred drug delivery route (`oral_tablet`, `oral_liquid`, `iv`, `orodispersible`). |
| `preferred_language` | String | Preferred family communication language (`nl`, `fr`, `en`). |
| `pairing_code` | String | Random 7-character alphanumeric token for family companion app pairing (e.g. `PAIR-ABC`). |
| `active_medications` | Array | Concomitant non-chemotherapy medications evaluated for Drug-Drug Interactions (DDIs). |

#### Abstract Clinical Archetypes Supported

The system is designed to evaluate multiple distinct clinical archetypes without relying on specific patient files:

1. **High Emetogenicity Chemotherapy (HEC) Regimens**: Solid tumor protocols combining high-dose emetogenic agents that trigger triple antiemetic prophylaxis (5-HT3 antagonist + NK1 receptor antagonist + corticosteroid + dopamine/olanzapine step-up).
2. **Corticosteroid-Restricted Regimens**: Protocols (such as ALL induction/consolidation or brain tumors) where Dexamethasone is strictly contraindicated to prevent tumor lysis, CNS interference, or protocol violation.
3. **Multi-Day Chemotherapy Blocks**: Consecutive multi-day infusions requiring extended neurokinin-1 antagonist coverage and post-chemotherapy delayed CINV prophylaxis.
4. **Drug-Drug Interaction (DDI) & QTc Screening**: Regimens with concomitant azole antifungals or other strong CYP3A4 inhibitors / QTc-prolonging agents requiring dosing alerts and alternative antiemetic selection.

---

### Collection 2: `passports`

Grounding contract: [`contracts/schemas/passport.schema.json`](file:///config/.gemini/antigravity/scratch/rabo4good-AImesis/contracts/schemas/passport.schema.json).  
Stores the calculated CINV Patient Passport generated for a specific patient and chemotherapy cycle. Passports contain clinician-verified antiemetic schedules and day-by-day family timetables.

#### Document Schema & Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| `passport_id` | String | Unique passport identifier (e.g. `PSP-001-C1`). |
| `patient_id` | String | Foreign key referencing the parent record in `patients`. |
| `cycle_number` | Integer | Chemo cycle number to which this passport applies. |
| `status` | String | Lifecycle state: `draft` → `awaiting_pharmacist` → `approved` / `active` → `superseded`. |
| `emetogenicity_tier` | String | Calculated risk classification (`HIGH`, `MODERATE`, `LOW`, `MINIMAL`). |
| `classification_rationale` | String | Deterministic rule evidence citing policy dose thresholds and combination rules. |
| `dexamethasone_rules` | Object | Hard safety gate: `is_blocked` (boolean) and `rationale` (clinical explanation). |
| `antiemetic_schedule` | Array | Prophylactic medications with dose amount, dose unit, route, frequency, administration days, formula explanation, and rule citation. |
| `breakthrough_plan` | Object | Stepwise rescue protocol for breakthrough nausea or vomiting, with specific rescue agents, dosages, frequencies, and ward notification thresholds. |
| `signoffs` | Object | Dual-governance tracking: oncologist and clinical pharmacist sign-off status, clinician display names, timestamps, and RIZIV/INAMI numbers. |
| `family_schedule_multilingual`| Object | Localized daily timetables and administration instructions in Dutch (`nl`), French (`fr`), and English (`en`). |
| `emergency_contacts` | Object | Direct telephone numbers for hospital oncology wards and on-call services. |

#### Core Rule Invariants Enforced in Passports

- **Dose Precision & Safety Rounding**: Olanzapine doses calculated at 0.1 mg/kg are strictly rounded **DOWN** to the nearest 0.5 mg floor. Ondansetron is capped at 8 mg per single dose.
- **Contraindication Gates**: When `diagnosis_group` indicates ALL or brain tumors, `dexamethasone_rules.is_blocked` is set to `true`, preventing corticosteroid insertion into the schedule.
- **Export Locking**: Passports remain in `draft` or `awaiting_pharmacist` status and cannot be exported to print-ready HTML/PDF until both authorized clinicians have signed off.

---

### Collection 3: `accounts`

Manages user identity, credentials, and Role-Based Access Control (RBAC).

#### Role-Based Access Model

| Role | Intended User | Patient Scoping | Permissions |
| :--- | :--- | :--- | :--- |
| `oncologist` | Pediatric Oncologist | All patients | Formulate antiemetic plan, modify risk factors, submit for pharmacist sign-off. |
| `pharmacist` | Hospital Clinical Pharmacist | All patients | Review DDI/QTc alerts, approve or return antiemetic plan, finalize dual sign-off. |
| `nurse` | Oncology Nurse Specialist | All patients | View plans, administer medications, review symptom logs, update patient risk factors. |
| `parent` | Parent / Caregiver | Paired patient(s) only | View family schedule in preferred language, log real-time emetic episodes. |
| `patient` | Adolescent Patient | Paired patient only | View age-appropriate passport schedule, log symptom severity. |

#### Document Fields
- `account_id`: Unique identifier (e.g. `acc-onc`, `acc-pharm`, `acc-nurse`, `acc-family-01`).
- `email`: User login email.
- `role`: One of `oncologist`, `pharmacist`, `nurse`, `parent`, `patient`.
- `display_name`: Human-readable user name.
- `patient_ids`: Array of patient identifiers the user is authorized to access. Care-team accounts access all active patients; family accounts are restricted strictly to their paired child.
- `password_hash`: SHA-256 salted password hash.

---

### Collection 4: `reference_resources`

Stores curated Belgian pediatric oncology patient brochures, hospital CINV guidelines, and family portals ingested from hospital registries:

- **Participating Centers**: UZA (Antwerp), UZ Leuven, HUDERF / H.U.B (Brussels), Cliniques universitaires Saint-Luc, AZ Groeninge, KickCancer Foundation, and BSPHO.
- **Redirection Safeguards**: Stores direct deep links to multilingual resources (`nl`, `fr`, `en`, `de`) with metadata noting portal redirection caveats (e.g., sites resetting to homepages on language toggles) to ensure families receive direct guidance.

#### Document Fields
- `resource_id`: Identifier (e.g. `res-01`).
- `institution`: Hospital or foundation name.
- `title`: Resource title.
- `language`: Resource language (`nl`, `fr`, `en`, `de`).
- `url`: Direct deep link.
- `format`: Content format (`Web page`, `Web portal`, `PDF`).
- `effort`: Complexity rating (`low`, `medium`, `high`).
- `effort_note`: Technical notes on bilingual accessibility and deep-link reliability.

---

### Collection 5: `episodes`

Grounding contract: [`contracts/schemas/episode.schema.json`](file:///config/.gemini/antigravity/scratch/rabo4good-AImesis/contracts/schemas/episode.schema.json).  
Captures real-time nausea, vomiting, and retching events submitted by families through the Companion App.

#### Document Fields
- `episode_id`: Unique UUID identifier.
- `patient_id`: Foreign key referencing `patients`.
- `passport_id`: Foreign key referencing active `passports` cycle.
- `cycle_day`: Chemotherapy day number (Day 1, 2, etc.).
- `timestamp`: ISO-8601 UTC timestamp.
- `symptom_type`: Emetic symptom category (`nausea`, `vomiting`, `retching`, `both_nausea_and_vomiting`).
- `severity`: Standardized rating (Baxter visual analog scale 1–5 or categorical `mild`, `moderate`, `severe`).
- `vomiting_count`: Number of distinct vomiting events within the reporting window.
- `rescue_medication_administered`: Object recording rescue medicine intake (drug name, dose, timestamp).
- `reported_by`: User role submitting the log (`parent`, `patient`, `nurse`).

---

## 3. Connections & System Architecture

```mermaid
flowchart TD
    subgraph Clients["Frontend Clients (Cloud Run)"]
        W["Clinician Care Team Web App<br/>(Flutter Web)"]
        F["Family Companion App<br/>(Flutter Web / iOS)"]
    end

    subgraph BackendServices["Backend Services (Cloud Run)"]
        API["aimesis_api / mock-api<br/>(FastAPI REST Service)"]
        Rules["aimesis_rules<br/>(Deterministic Python Engine)"]
        Agent["aimesis_agent<br/>(ADK + Gemini + A2UI)"]
    end

    subgraph FirestoreDB["Google Cloud Firestore (Native Mode)"]
        P[("patients/<br/>Clinical context & regimens")]
        PSP[("passports/<br/>Dual sign-off Passport schedules")]
        ACC[("accounts/<br/>RBAC & user pairings")]
        RES[("reference_resources/<br/>Belgian hospital deep links")]
        EP[("episodes/<br/>Real-time symptom & rescue logs")]
    end

    W -->|1. Authenticate & View Worklist| API
    W -->|2. Review Risk Tier, Doses & Safety Gates| API
    W -->|3. Dual Sign-Off (Oncologist + Pharmacist)| API

    F -->|4. Pair Device via Pairing Code| API
    F -->|5. Real-time Localized Passport Stream| API
    F -->|6. One-Tap Symptom Log| API

    API -->|Read & Update Patient Context| P
    API -->|Fetch & Activate Passports| PSP
    API -->|Verify RBAC Permissions| ACC
    API -->|Query Hospital Brochures| RES
    API -->|Persist Symptom Episodes| EP

    API --- Rules
    Agent -.->|Evaluate Clinical Evidence & A2UI| Rules
```

### Key Integration Workflows

1. **Backend API ↔ Firestore Integration**:
   - Implemented via the official `google-cloud-firestore` SDK client in [`backend/api/src/aimesis_api/episodes/store.py`](file:///config/.gemini/antigravity/scratch/rabo4good-AImesis/backend/api/src/aimesis_api/episodes/store.py) and `mock-api` (`backend/mock_api/src/aimesis_mock_api/store.py`).
   - Automatically utilizes project credentials when deployed to Cloud Run (`STORE=firestore`, `GOOGLE_CLOUD_PROJECT=qwiklabs-gcp-00-cc29ec8bfdd9`).

2. **Dual Sign-Off Governance Flow**:
   - **Oncologist Submission**: An oncologist reviews the chemotherapy tier, selects formulation preferences, and calls `POST /patients/{id}/plan/submit`. The passport transitions to `awaiting_pharmacist`.
   - **Pharmacist Approval**: A hospital clinical pharmacist verifies dosing calculations, checks CYP3A4/QTc interactions, and calls `POST /patients/{id}/plan/approve`. The passport transitions to `approved` and is promoted to `active`.
   - **Export Lock**: Print-ready HTML/PDF generation (`/passport/export-html`) enforces that both signatures are present before releasing the official passport.

3. **Family Pairing Flow**:
   - A parent or patient logs into the Companion App and submits their 7-character pairing code (`POST /pairing`).
   - The backend validates the code against the `patients` collection and associates the patient ID with the family's `accounts` record, enabling secure access to the child's active passport.

4. **One-Tap Episode Logging with Offline Queue**:
   - Symptoms experienced at home are logged with a single button tap via `POST /patients/{id}/episodes`.
   - Events are stored in `episodes` and indexed by cycle day.
   - An offline queue ([`frontend/ios/lib/services/offline_queue.dart`](file:///config/.gemini/antigravity/scratch/rabo4good-AImesis/frontend/ios/lib/services/offline_queue.dart)) buffers submissions during network disconnects and replays them when reconnected.

5. **Deterministic Rules Engine (`backend/rules`)**:
   - Sits strictly between the API and Firestore to ensure antiemetic calculations are 100% deterministic (no LLM generation of clinical dosages).
   - Enforces emetic tier thresholds, combination drug elevations, Dexamethasone contraindication gates, and Olanzapine floor rounding.
