# AImesis: requirements traceability

**Sources** (short codes used below)
- **US**: `user stories AImesis version 2.pdf` (3 pp.; S1–S3 on p.1–2, S4–S5 on p.2, S6 on p.2–3)
- **POL**: `Anti-emetica beleid CINV - V2.pdf` (UZA, July 2026 v2). p.1 is the emetogenicity table and the regimen per tier. p.2 has *Algemene info* (left column) and the drug monographs (right column).
- **CAS**: `casus voorbeelden.docx` (Casus 1–3). The protocol excerpts in it are images and were not extracted.
- **QS**: `uc3-aimesis-quickstart.lab.md` (§1 case table, §3 Stories 1–3 checks, §4 passport, §5 DDI)
- **RES**: `CINV resources in Belgium.xlsx` (36 resource rows)
- **DEMO**: `backend/mock_api/src/aimesis_mock_api/demo_data.py`. These are repo demo values and **not** source data.

## 1. Requirements

### Emetogenicity classification (US S1; POL p.1)
- **R1** The engine identifies each cytostatic in the regimen and gives it a tier: High (>90%), Moderate (30–90%), Low (10–30%) or Minimal (<10%). *(US S1 p.1; POL p.1)*
- **R2** Dose thresholds (mg/m²) *(POL p.1)*:
  - Cyclophosphamide: >1500 is High; IV ≤1500 is Moderate.
  - Cytarabine: IV ≥3 g/m² is High; >200 mg and <3 g/m² is Moderate; <200 mg/m² is Low. Exactly 200 is not defined in the source.
  - Methotrexate: IV ≥12 g/m² is High; IV ≥250 mg and <12 g/m² is Moderate; <250 mg/m² or IT is Low; <50 mg/m² is Minimal.
  - Thiotepa: IV ≥300 is High; <300 is Low.
  - Dactinomycin: IV ≥1.35 mg/m² is High; otherwise Moderate.
- **R3** Fixed High agents: carboplatin, cisplatin, dacarbazine, doxorubicin, melphalan IV. Fixed Moderate, Low and Minimal agents follow the POL p.1 lists (for example daunorubicin and ifosfamide are Moderate; vincristine and etoposide are Low). *(POL p.1)*
- **R4** The overall tier is the highest tier in the regimen ("de meest emetogene chemotherapie bepaalt het profylaxe-niveau"). *(US S1; POL p.2 Start profylaxe)*
- **R5** These combinations are High: cytarabine + daunorubicin; cytarabine + etoposide; cyclophosphamide + anthracycline; cyclophosphamide + anthracycline + etoposide; ifosfamide + etoposide. *(POL p.1 "Combinatie"; CAS Casus 3; QS §1)*

### Prophylaxis per tier (POL p.1 right column)
- **R6** High: ondansetron 3x/d + dexamethasone + aprepitant + olanzapine (olanzapine only if >2 y).
- **R6b** Moderate: ondansetron 2x/d + dexamethasone **or** aprepitant.
- **R6c** Low: ondansetron 1x/d.
- **R6d** Minimal: no standard prophylaxis.
- **R7** Start: 30 min (IV) to 60 min (PO) before the first chemotherapy dose. Consult the EHR for previous CINV prophylaxis. *(POL p.2 Start)*
- **R8** Stop *(POL p.2 Stop)*:
  - Ondansetron, Moderate/High: up to 3 days after the last chemotherapy.
  - Ondansetron, Low: only on chemotherapy days.
  - Dexamethasone: only on chemotherapy days.
  - Olanzapine: up to 3 days after the last chemotherapy.

### Dosing (US S2: latest BSA, show formula and rule; POL p.2)
- **R9** Ondansetron IV/PO: 5 mg/m² (max 8 mg per dose), max 3x/d. At discharge: 2x/d PO, with a referral to the hospital pharmacy.
- **R10** Dexamethasone IV/PO dose depends on BSA and on whether (fos)aprepitant is given:

  | BSA | With (fos)aprepitant | Without (fos)aprepitant |
  |---|---|---|
  | <0.6 m² | 1 mg 2x/d | 2 mg 2x/d |
  | ≥0.6 m² | 2 mg 2x/d | 4 mg 2x/d |

  For IV, show this alert: "Aacidexam® 5 mg/ml contains ±4 mg/ml active substance → convert dose".
- **R11** (Fos)aprepitant:
  - Not indicated if the child is <6 months or ≤6 kg.
  - PO, <12 y: 3 mg/kg (max 125 mg) on D1, then 2 mg/kg (max 80 mg) on D2–D3.
  - PO, ≥12 y: 125 mg on D1, then 80 mg on D2–D3.
  - IV: 3 mg/kg (max 115 mg) on D1, then 2 mg/kg (max 80 mg) on D2–D3.
  - Single IV dose for 1-day chemotherapy: >6 m to <2 y, 5 mg/kg (max 150 mg); ≥2 y to <12 y, 4 mg/kg (max 150 mg); ≥12 y, 150 mg.
  - PO is preferred. Flag CYP3A4/2C9 interactions.
- **R12** Olanzapine PO:
  - <2 y: no indication. ≥2 y: 0.1 mg/kg (max 5 mg) 1x/d.
  - **Round DOWN to the nearest 0.5 mg.**
  - Give the first dose just before chemotherapy, then preferably in the evening.
  - Never give it as monotherapy for CINV.
  - Check: 18.9 kg gives 1.89 mg, which rounds to **1.5 mg**. *(QS §3)*
- **R13** Palonosetron (only after consulting supervision/pharmacy):
  - <17 y: 20 mcg/kg (max 1500 mcg) once.
  - ≥17 y: 250 mcg on D1, repeated on D4 if needed.
  - Do not combine with ondansetron until 3 days after palonosetron.
  - Switch from ondansetron when a High regimen is insufficiently controlled. *(POL p.2)*

### Contraindications (POL p.2 Opmerkingen and Dexamethasone monograph)
- **R14** Hard block, **GEEN dexamethasone**, when any of these apply: the regimen already contains corticosteroids, ALL, brain tumours, dinutuximab beta. AML and CAR-T are "geen voorkeur" (soft warning). *(POL p.2; QS §3)*
- **R15** When dexamethasone is blocked in a Moderate regimen, the "dex OR aprepitant" choice resolves to aprepitant. *(POL p.1 + p.2; CAS Casus 2)*

### Personalisation, breakthrough and anticipatory nausea (US S3; POL p.2)
- **R16** Input fields: swallowing ability and formulation (oral liquid / tablet / IV), CINV history, and anticipatory vomiting or anxiety. If the child cannot swallow pills, default to liquid/syrup or IV. *(US S3 p.1–2)*
- **R17** Read nausea and vomiting days from prior cycles (EHR/toernota, plus companion-app logs). If there was breakthrough in the previous cycle, start the next cycle at a higher prophylaxis level. *(POL p.2 Doorbraak; CAS Casus 1 & 3)*
- **R18** Breakthrough steps *(POL p.2)*:
  1. Raise ondansetron frequency: Moderate to 3x/d, Low to 2x/d, Minimal to 1x/d.
  2. If the response is insufficient, add olanzapine (>2 y).
  3. If still insufficient, add alizapride 1 mg/kg (max 50 mg per dose, max 6x/d, chemotherapy days only) or lorazepam 0.025–0.05 mg/kg (max 2 mg) every 6 h as needed.
- **R19** Anticipatory nausea: non-pharmacological measures plus lorazepam 0.04–0.08 mg/kg (max 2 mg) the evening before and the morning of the first chemotherapy. The IV form is not reimbursed. *(POL p.2)*

### Outputs and safety (US S4–S6)
- **R20** Passport: a single-page PDF containing the strategy and BSA-based doses, risk factors and formulation, and notes on efficacy and adverse effects from previous cycles. It can be downloaded or exported to the EHR. Languages NL/FR/EN, with Belgian family resources. *(US S4 p.2; QS §1, §4; RES)*
- **R21** Companion app: logging a nausea episode takes one tap. Logs feed R17 for the next cycle. *(QS §1 Story 4 bonus)*
- **R22** UZA v2 vs POGO 250111 shown side by side with citations whenever they disagree. *(US S5 p.2; QS §1, §6)*
- **R23** DDI screening checks active medications against the regimen and shows:
  - a prominent warning with the evidence citation and a safe alternative *(US S6 p.2–3)*;
  - CYP3A4 (aprepitant, POL p.2);
  - voriconazole/posaconazole + vincristine as critical;
  - cumulative QTc risk (ondansetron + domperidone/haloperidol) *(QS §5)*.
- **R24** Advisory only. The oncologist reviews and approves, then the pharmacist checks and approves or returns (dual sign-off). The display shows the formula and the rule source for every dose. *(US S2 p.1, display of formula + protocol rule; sign-off flow is the team's J2/J3 design and is not specified in the sources)*

## 2. Journey map

| Req | Journey | Screen / step | Backend component |
|---|---|---|---|
| R16 (profile fields) | J1 | Onboarding: alias, age, sex, language, diagnosis | patient store (`patients/{id}`) |
| R1–R5 | J2 | Cycle setup: chemo, dose mg/m², days, weight/height → BSA | rules engine: classifier + combination rules |
| R14, R15 | J2 | Processing → plan card "GEEN dexamethasone" banner | rules engine: contraindication guard |
| R6–R13 | J2 | Plan review: dose table + formula + POL citation | rules engine: dosing calculator |
| R16–R19 | J2 | Patient session with family (swallowing, route, anticipatory, prior nausea, preferences) | personalisation rules + EHR/companion history reader |
| R16–R19 summary | J2 | Processing summary | Gemini summary (non-authoritative) |
| R24 | J2 → J3 | Doctor approve and send; pharmacist queue approve/return | plan workflow / status service |
| R20 | J4 | Passport preview and print (NL/FR/EN) | passport generator + RES resources |
| R21, R17 | J5 | Family app: one-tap nausea log | episode log feeding next-cycle history |
| R22 | J6 | Plan: UZA vs POGO panel | POGO comparison service |
| R23 | J6 | Plan: DDI/QTc alert | DDI screener (CYP3A4/QTc) |

## 3. Acceptance criteria

These columns are computed by the rules from DEMO inputs, not from the source documents: Ondansetron mg, Dexamethasone mg, Aprepitant mg, Olanzapine mg, BSA and chemo doses. Tiers, drugs, blocks and step-ups come from CAS, POL and QS.

### Casus 1: neuroblastoma, HR-NBL2 RAPID COJEC, cycle B4 (CAS; QS §1)

**Inputs**

| Input | Value | Source |
|---|---|---|
| Sex, age | F, 16 y | CAS |
| Diagnosis | Neuroblastoma (induction) | CAS |
| Cycle | B4 on 25/09/2026 | CAS |
| Chemo | Vincristine + Cisplatin | CAS |
| History | Previous cycle B3 on 05/09 with ondansetron 2x/d + aprepitant + dexamethasone + olanzapine; nausea on D2 | CAS |
| Weight / height / BSA | Not in source; DEMO 52 kg, 160 cm, 1.52 m² | DEMO |
| Chemo doses and days | Not in source; DEMO vincristine 1.5, cisplatin 80 mg/m², D1 | DEMO |

**Expected**
- Tier: **High** (cisplatin High, vincristine Low). Dexamethasone **not** blocked.
- Ondansetron 3x/d: 5 × 1.52 = **7.6 mg**. This is the policy High frequency; the previous cycle used 2x/d.
- Aprepitant (≥12 y): **125 / 80 / 80 mg**.
- Dexamethasone (≥0.6 m² with aprepitant): **2 mg 2x/d**, on chemotherapy days only.
- Olanzapine: 0.1 × 52 = 5.2 mg, capped at **5 mg**.
- Step-up for breakthrough on D2 while already on the High regimen: offer palonosetron (<17 y: 20 mcg/kg = **1040 mcg**, max 1500 mcg) after consulting supervision/pharmacy, with no ondansetron for 3 days. Breakthrough alizapride/lorazepam as in R18.

### Casus 2: ALL, ALLTogether Induction B, D8 (CAS; QS §1)

**Inputs**

| Input | Value | Source |
|---|---|---|
| Sex, age | M, 2 y | CAS |
| Diagnosis | ALL | CAS |
| Chemo | Vincristine + Daunorubicin on D8 | CAS |
| History | No nausea or vomiting at the previous administration | CAS |
| Weight / height / BSA | Not in source; DEMO 12.5 kg, 87 cm, 0.55 m² | DEMO |
| Chemo doses | Not in source; DEMO vincristine 1.5, daunorubicin 30 mg/m² | DEMO |

**Expected**
- Tier: **Moderate**. No combination rule applies because cytarabine is absent.
- **GEEN dexamethasone (ALL): hard block.**
- Ondansetron 2x/d: 5 × 0.55 = **2.75 mg**, continued up to 3 days after chemotherapy.
- Aprepitant (<12 y; 12.5 kg is >6 kg): **37.5 mg** D1, **25 mg** D2–D3.
- No olanzapine in the baseline regimen. No step-up.

### Casus 3: Ewing sarcoma, iEuroEwing, IE #3 (5 days) (CAS; QS §1)

**Inputs**

| Input | Value | Source |
|---|---|---|
| Sex, age | Not in source; DEMO M, 14 y | DEMO |
| Diagnosis | Ewing sarcoma | CAS |
| Chemo | Ifosfamide + Etoposide, D1–D5 | CAS |
| History | Nausea and vomiting on D4 in previous courses | CAS |
| Weight / height / BSA | Not in source; DEMO 45 kg, 158 cm, 1.41 m² | DEMO |
| Chemo doses | Not in source; DEMO ifosfamide 1800, etoposide 100 mg/m² | DEMO |

**Expected**
- Tier: **High** through the combination rule (ifosfamide Moderate + etoposide Low gives High; POL p.1 and POGO). Dexamethasone **not** blocked.
- Ondansetron 3x/d: **7.05 mg** for D1–D8.
- Dexamethasone: **2 mg 2x/d** for D1–D5.
- Aprepitant: **125 mg** D1, **80 mg** D2–D3.
- Olanzapine: 0.1 × 45 = **4.5 mg** for D1–D8.
- Step-up: "eventueel" extend aprepitant to **D4–D5** (CAS). No source gives a D4–D5 dose, so it must be confirmed by the pharmacist.

### Quickstart checks (QS §3–§5)

| Check | Inputs | Expected |
|---|---|---|
| Q1 Olanzapine rounding | 18.9 kg, ≥2 y | 1.89 mg → **1.5 mg** |
| Q2 Brain tumour | Cyclophosphamide 1800 mg/m², brain tumour, 9 y, 28 kg, BSA 1.02 | **High** (>1500); **dexamethasone blocked** |
| Q3 ALL | Any regimen with diagnosis ALL (DEMO Casus 4: 7 y, 22 kg, 120 cm, 0.85 m², cyclophosphamide 1600 + vincristine 1.5) | **Dexamethasone blocked**. Casus 4 is High. Ondansetron 4.25 mg 3x/d; aprepitant 66 / 44 / 44 mg; olanzapine 2.2 mg → 2.0 mg |
| Q4 DDI | Active medication voriconazole + vincristine (DEMO Casus 4) | **Critical** CYP3A4 DDI alert with alternative. Also flag aprepitant CYP3A4 (POL p.2) |
