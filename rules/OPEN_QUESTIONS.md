# Open questions for the UZA pharmacists

These came up while turning *Anti-emetica beleid CINV – Juli 2026 versie 2* into rules.
For each one the engine currently does what is written under **Now**. Nothing here was
guessed silently: each interpretation is labelled in `uza_v2.yaml` with its OQ number.

| # | Topic | What the policy says | Now (engine behaviour) | Question |
|---|---|---|---|---|
| OQ-1 | Dose basis | Thresholds in mg/m² ("Cyclofosfamide >1500mg/m²") | Compared against the dose **per administration** (per day) | Per administration, per day, or cumulative per course? E.g. cyclophosphamide 1050 mg/m² × 2 days. |
| OQ-2 | Cytarabine 200 mg/m² | Low: "<200mg/m²"; moderate: ">200mg <3g/m²" | Exactly 200 → **unclassified, recommendation blocked**. ">200mg" read as mg/m². | Which tier is 200 mg/m²? (POGO: ≤200 = low.) |
| OQ-3 | Dactinomycin | High: "≥ 1,35 mg/m2"; moderate: "Dactinomycine" (no dose) | <1,35 mg/m² → moderate | Confirm. (POGO: high at any dose.) |
| OQ-4 | Methotrexate low/minimal overlap | Low: "<250mg/m² of IT"; minimal: "<50mg/m²" | <50 → minimal; 50–<250 → low; IT → low | Confirm. Is exactly 50 low or minimal? (POGO: ≤50 = minimal.) |
| OQ-5 | Anthracycline class | Combination "Cyclofosfamide/anthracycline" | Anthracycline = doxorubicin, daunorubicin, idarubicin | Do mitoxantrone, liposomal doxorubicin or epirubicin count? |
| OQ-6 | Multi-day courses | "De meest emetogene chemotherapie bepaalt het profylaxe-niveau" | Tier per day (combinations only on the same day), then the highest day sets the course | Must combination agents be given on the same day? (POGO: per day.) |
| OQ-7 | Rounding | Only olanzapine has a rounding rule | Ondansetron, aprepitant, alizapride, lorazepam shown **unrounded** | Round to product strength / syringe volume? Which products (syrup, capsule, suspension)? |
| OQ-8 | Dexamethasone "GEEN voorkeur" | Hard list: corticoïden, hersentumoren, ALL, dinutuximab beta. "Geen voorkeur" list adds AML and CAR-T | AML / CAR-T → **warning**, dexamethasone stays in; physician decides | Should AML / CAR-T be hard blocks too? |
| OQ-9 | Formulations | Story 3 asks for liquid / NG / IV defaults; policy lists no products | Engine only switches route (PO ↔ IV) and warns for liquid/NG | Please share the formulary list (product, strength, form) per drug. |
| OQ-10 | Continuous infusions | Acute phase "t.e.m. 24u na laatste toediening" | A day counts as chemo day if a cytostatic is running (Casus 1: cisplatin 24h → days 0 and 1) | Confirm for dexamethasone ("enkel op dagen van chemotherapie") and ondansetron end date. |
| OQ-11 | Triple IT and steroids | "GEEN dexamethasone: indien kuur al corticoïden bevat" | Only explicit dexamethasone / prednisolone / hydrocortisone in the regimen trigger the block | Does hydrocortisone in triple IT count as a corticosteroid-containing course? |
| OQ-12 | Olanzapine at exactly 2 years | Bundle: "Olanzapine ( >2j)"; dosing: "≥2j." | Exactly 2 years → physician decision | Which one applies? |
| OQ-13 | Breakthrough on under-dosed prophylaxis | Breakthrough = "ondanks geschikte CINV-profylaxe" | If the prior cycle got less ondansetron than its tier's baseline (Casus 1: 2x/d on HEC), the engine applies the full baseline and does **not** escalate | Confirm this reading. |
| OQ-14 | Aprepitant beyond D3 | Only D1–D3 dosing (Casus 3 suggests "eventueel dag 4 en 5") | Shown as **physician decision, outside policy**; no dose proposed | Should the policy get a rule for multi-day courses? |
| OQ-15 | Weight freshness | Story 2: "most recent BSA" | Not enforced | Maximum age of weight/BSA (e.g. 7 days)? |

## Missing from the case document (filled with synthetic values in `golden/`)

- Casus 1: weight, BSA. Casus 2: weight, BSA. Casus 3: age, weight, BSA, prophylaxis given in earlier IE courses.
- Please replace the values marked `SYNTHETIC` and confirm the hand-calculated `expected` blocks.

## UZA v2 vs POGO 250111 — differences already spotted (input for Story 5)

| Agent / combination | UZA v2 | POGO 250111 |
|---|---|---|
| Cyclophosphamide | high **>1500** mg/m² | high **≥1 g/m²** |
| Doxorubicin | high | moderate |
| Vincristine | low | minimal |
| Asparaginase | low | minimal |
| Cyclophosphamide + etoposide | not listed (→ moderate) | high |
| Cytarabine + daunorubicin / etoposide | high (any dose) | high at specific doses (150–200 / 300 mg/m²) |
| Doxorubicin + ifosfamide | not listed (doxorubicin already high) | high |
| Methotrexate 50 mg/m² | ambiguous (OQ-4) | minimal |
