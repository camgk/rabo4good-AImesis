"""Adapter: compute mock_api plans with the REAL deterministic engine (`aimesis_rules`).

Sources: UZA Anti-emetica beleid CINV v2 (juli 2026) and POGO 250111 via backend/rules.
Classification (drug/day tiers, combination rules), the dexamethasone guardrail,
UZA-vs-POGO rows, drug interactions and breakthrough lines come from aimesis_rules.
Per-line antiemetic dose arithmetic (mg, days, step-ups) is assembled by the line
builder in rules_mock.build_lines using the UZA v2 formulas, and each line carries the
aimesis_rules citation as its source. Advisory only — requires clinician sign-off.
"""

from __future__ import annotations

import aimesis_rules as ar
from aimesis_rules import ChemoDrugInput

from .models import BreakthroughLine, DayTier, DexStatus, DrugTier, Interaction, PogoRow, RuleRef

SOURCE_UZA = "UZA CINV beleid v2 (juli 2026)"
SOURCE_POGO = "POGO 250111"
SOURCE_DDI = "BCFI/CBIP + UZA CINV beleid v2 (juli 2026)"
STEROIDS = {"prednisolone", "prednisone", "dexamethasone", "methylprednisolone"}


def _t(tier) -> str:
    return str(getattr(tier, "value", tier)).strip().lower()


def _norm(s: str) -> str:
    return " ".join(s.strip().lower().split())


def classify(patient):
    """Return (drug_tiers, day_tiers, overall, combination_rules, unknown, pogo_rows)."""
    drug_tiers: list[DrugTier] = []
    unknown: list[str] = []
    known_rows = []
    for row in patient.chemo:
        res = ar.classify_regimen_uza_v2(
            drugs=[ChemoDrugInput(drug=row.drug, dose_mg_m2=row.dose_mg_m2, days=list(row.days))],
            strict_missing_dose=False,
        )
        if res.refused or not res.per_drug:
            unknown.append(row.drug)
            continue
        c = res.per_drug[0]
        known_rows.append(row)
        drug_tiers.append(
            DrugTier(drug=row.drug, dose_mg_m2=row.dose_mg_m2, tier=_t(c.tier),
                     rule=c.rule_citation, source=SOURCE_UZA)
        )
    if not known_rows:
        return drug_tiers, [], "minimal", [], unknown, []

    inputs = [ChemoDrugInput(drug=r.drug, dose_mg_m2=r.dose_mg_m2, days=list(r.days)) for r in known_rows]
    reg = ar.classify_regimen_uza_v2(drugs=inputs, strict_missing_dose=False)
    overall = _t(reg.overall_tier)
    day_tiers = [
        DayTier(day=int(d), tier=_t(t), drugs=[r.drug for r in known_rows if int(d) in r.days])
        for d, t in sorted(reg.per_day_tier.items(), key=lambda kv: int(kv[0]))
    ]
    combos: list[RuleRef] = []
    if reg.combination_rule_applied:
        combos.append(RuleRef(rule=reg.combination_rule_applied, source=f"{SOURCE_UZA} + {SOURCE_POGO}"))

    pogo_rows: list[PogoRow] = []
    cmp = ar.compare_regimen_uza_vs_pogo(inputs)
    for item in cmp.get("per_drug_comparison", []):
        dose = item.get("dose_mg_m2")
        pogo_rows.append(
            PogoRow(
                item=f"{item['drug']}" + (f" {dose:g} mg/m²" if dose is not None else ""),
                uza_tier=_t(item["uza_v2_tier"]), pogo_tier=_t(item["pogo_tier"]),
                differs=bool(item["differs"]),
                note=item.get("explanation", "") + (" — follow UZA v2 (source of truth)" if item["differs"] else ""),
            )
        )
    if reg.combination_elevated:
        names = " + ".join(_norm(r.drug) for r in known_rows)
        pogo_rows.append(
            PogoRow(item=f"{names} (combination)", uza_tier=overall, pogo_tier=overall, differs=False,
                    note="; ".join(cmp.get("combination_notes", [])) or reg.combination_rule_applied or "")
        )
    return drug_tiers, day_tiers, overall, combos, unknown, pogo_rows


def dex_status(patient) -> DexStatus:
    drugs = [_norm(r.drug) for r in patient.chemo]
    meds = [_norm(m) for m in patient.active_meds]
    indication = f"{patient.diagnosis_group} {patient.diagnosis}"
    ev = ar.evaluate_dexamethasone_contraindication(
        indication=indication.replace("brain_tumour", "brain tumour hersentumor"),
        regimen_drugs=drugs, concomitant_meds=meds,
        regimen_contains_corticosteroids=bool(set(drugs) & STEROIDS),
    )
    if ev.contraindicated:
        return DexStatus(blocked=True, reason="; ".join(ev.reasons), source=SOURCE_UZA)
    return DexStatus(blocked=False, reason=None, source=SOURCE_UZA)


def _severity(s: str) -> str:
    s = s.upper()
    if "CRITICAL" in s or "CONTRAINDIC" in s:
        return "critical"
    if "MAJOR" in s or "HIGH" in s or "WARN" in s or "MODERATE" in s:
        return "warning"
    return "info"


def interactions(patient, proposed: list[str]) -> list[Interaction]:
    primary = [_norm(r.drug) for r in patient.chemo] + [_norm(m) for m in patient.active_meds]
    res = ar.check_ddi_interactions(primary_drugs=primary, proposed_antiemetics=[_norm(p) for p in proposed])
    out: list[Interaction] = []
    for a in res.get("interactions_found", []):
        a = a if isinstance(a, dict) else a.model_dump()
        out.append(
            Interaction(
                severity=_severity(a.get("severity", "")),
                drugs=[d.strip() for d in a.get("interacting_pair", "").split("+")],
                message=f"{a.get('mechanism', '')} {a.get('clinical_action', '')}".strip(),
                alternative=a.get("safe_alternative") or None,
                source=a.get("citation") or SOURCE_DDI,
            )
        )
    return out


def breakthrough(patient, route: str) -> list[BreakthroughLine]:
    w = float(patient.weight_kg)
    ali = round(min(1.0 * w, 50.0), 1)
    lz_lo, lz_hi = round(min(0.025 * w, 2.0), 2), round(min(0.05 * w, 2.0), 2)
    return [
        BreakthroughLine(
            drug="alizapride", dose_mg=ali, frequency="max 6x/d if needed (chemo days only)", route=route,
            formula="1 mg/kg per dose, max 50 mg/dose, max 6x/d, only on chemotherapy days",
            source=f"{SOURCE_UZA} p.2 · Alizapride",
            notes=[f"{w:g} kg × 1 mg/kg = {w:.1f} mg → {ali:g} mg"],
        ),
        BreakthroughLine(
            drug="lorazepam", dose_mg=lz_lo, frequency="q6h if needed", route=route,
            formula="0.025–0.05 mg/kg per dose, max 2 mg (anticipatory CINV: 0.04–0.08 mg/kg)",
            source=f"{SOURCE_UZA} p.2 · Lorazepam",
            notes=[f"{w:g} kg × 0.025–0.05 mg/kg = {lz_lo:g}–{lz_hi:g} mg", "IV form not reimbursed in Belgium"],
        ),
    ]


def line_citations(patient, tier: str) -> dict[str, str]:
    """aimesis_rules dosing citations per antiemetic (keys: ondansetron, aprepitant, dexamethasone, olanzapine)."""
    try:
        res = ar.calculate_uza_dosing(
            tier=ar.EmetogenicTier(tier.capitalize()), patient_age_years=float(patient.age),
            patient_weight_kg=float(patient.weight_kg), bsa_m2=float(patient.bsa_m2),
            indication=f"{patient.diagnosis_group} {patient.diagnosis}",
            regimen_drugs=[r.drug for r in patient.chemo], concomitant_meds=list(patient.active_meds),
            can_swallow_tablets=patient.risk_factors.can_swallow_tablets,
        )
        return {k: ln.citation for k, ln in res.lines.items()}
    except Exception:  # noqa: BLE001 - citations are decoration; never block a plan on them
        return {}
