# rabo4good-AImesis
Rabobank Group on GHFG 2026 hackathon

## AImesis — part 1: rulebook and deterministic engine

Pediatric CINV prophylaxis support for UZA, built on the *Anti-emetica beleid CINV –
Juli 2026 versie 2*. This part contains **no LLM**: every dose comes from code reading a
versioned, cited rulebook, so it cannot be hallucinated.

```
rules/uza_v2.yaml          the policy as data — every rule has page + exact Dutch quote
rules/OPEN_QUESTIONS.md    15 ambiguities for the pharmacists + UZA vs POGO differences
aimesis_engine/            deterministic engine (tier, doses, blocks, decisions)
golden/casus_*.yaml        the 3 UZA cases with hand-calculated expected output
tests/                     golden cases, threshold edges, source-quote check
tools/verify_sources.py    fails if any quote is not in the policy text
sources/                   policy text for verification (git-ignored, see below)
```

## Run

```bash
pip install pyyaml pytest
pdftotext "Anti-emetica beleid CINV - V2.pdf" sources/uza_v2_policy.txt   # once
python tools/verify_sources.py      # 105/105 quotes verified
python -m pytest -q                 # 68 passed
```

## What the engine returns

A `Recommendation` that is always a **draft**:

- `status`: `DRAFT_REQUIRES_PHYSICIAN_APPROVAL`, or `BLOCKED_NEEDS_PHYSICIAN` when data is
  missing, a diagnosis is not coded, or a drug/dose is not in the policy. It never guesses.
- `tier`, `day_tiers`, `tier_trace`: which rule gave which tier.
- `items`: each anti-emetic with dose, frequency, days, route, the **formula** shown
  (Story 2) and the rule ids.
- `rescue`: breakthrough medication (alizapride, lorazepam).
- `blocks`: dexamethasone hard blocks with the policy quote.
- `decisions`: choices the policy leaves to the physician (e.g. dexamethasone *or*
  aprepitant in moderate; palonosetron switch; aprepitant beyond D3).

## Safety rules built in

1. Doses use exact decimal arithmetic; olanzapine is floored to 0,5 mg as the policy says.
2. Unknown drug, dose in a policy gap (cytarabine 200 mg/m²), missing weight/BSA →
   blocked, never defaulted.
3. Prior-cycle nausea is only used when a physician has confirmed it.
4. Anything outside the policy is a `Decision`, never a dose.

## Status

Draft. The rulebook and golden cases need pharmacist sign-off (see `meta.approved_by`
and `rules/OPEN_QUESTIONS.md`). Next parts: interaction screening, the doctor review
UI, the ADK agent (notes extraction, explanations, passport).

The policy PDF and case documents are not committed; keep them out of the repo unless
UZA agrees.
