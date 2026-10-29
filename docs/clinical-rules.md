# Story 1 classification rules

The active source is `sources/uza_v2_policy.txt`, transcribed from the supplied
UZA Anti-emetica beleid CINV, July 2026 version 2, pages 1–2. This implementation
is a hackathon prototype and requires clinical verification.

## Scope

`aimesis_rules.classify_regimen_uza_v2` determines per-drug, per-day and peak
regimen tiers and returns a cited baseline antiemetic strategy. It requires no
patient age, weight or BSA and does not calculate individual antiemetic doses.
Only agents in the UZA table are classified. POGO-only entries must not silently
be presented as local hospital policy; Story 5 remains a separate comparator.

## Dose thresholds in mg/m²

| Drug | Classification |
|---|---|
| Cyclophosphamide IV | ≤1500 Moderate; >1500 High |
| Cytarabine IV | <200 Low; >200 and <3000 Moderate; ≥3000 High; exactly 200 requires clinical review |
| Methotrexate IV | <50 Minimal; 50–<250 Low; 250–<12000 Moderate; ≥12000 High |
| Dactinomycin IV | <1.35 Moderate; ≥1.35 High |
| Thiotepa IV | <300 Low; ≥300 High |

Intrathecal methotrexate is Low independently of dose. The more specific Minimal
methotrexate row takes precedence below 50 mg/m². Oral methotrexate is supported
only below the IV-specific threshold of 250 mg/m². Explicitly IV drug rules are
not reused for another route. Triple IT/ITT requires IT or ITT. Unknown routes,
unknown agents, missing threshold doses and invalid numbers/schedules never
produce a final baseline recommendation.

## Multi-agent and multi-day treatment

Use the highest component tier on each administration day, with the named UZA
exceptions: ifosfamide + etoposide; cytarabine + daunorubicin or etoposide;
cyclophosphamide + anthracycline, with or without etoposide. A generic two-Moderate
escalation is not a UZA rule. Exceptions apply only to drugs on the same day.
The overall tier is the highest resulting daily tier. Days without chemotherapy
are not inferred or classified; delayed-phase prophylaxis is a separate task.
Each result includes daily baseline strategies and the days and citations for
combination exceptions. Repeated administration rows may have different doses
and days when using the structured `/regimens/classify` endpoint.

## Refusal and input conventions

The legacy `strict_missing_dose` argument is retained for compatibility but
`False` no longer guesses a Moderate tier. Omitted route/day inputs retain the
existing IV/day-1 convention; explicit invalid or empty values are rejected.
Clinical gaps return `refused=true`, no overall tier and no final strategy.
Valid classifications of other rows can still be shown as partial information.
Malformed request values return HTTP 422.

## Verification

Regression tests cover the three supplied cases, all dose-dependent cutoffs,
local/POGO table separation, overlapping/non-overlapping schedules, route
restrictions and refusals. The browser workbench uses the same function as the
ADK tool and REST endpoint. It does not modify or replace the Flutter mock API.
