"""Plan computation for mock_api — now delegating to the REAL engine (aimesis_rules).

Public API is unchanged (compute_plan, episode_day, interactions, classify_regimen,
dex_status). Classification, combination rules, the dexamethasone guardrail,
UZA-vs-POGO rows, interactions and breakthrough lines come from backend/rules
(UZA CINV beleid v2 (juli 2026) + POGO 250111) via real_rules.py. This module keeps the
per-line antiemetic assembly (doses per UZA v2 formulas, days, step-ups) and the
episode summary. Advisory only — requires clinician sign-off.

Everything is a pure function: data in, data out. No I/O, no LLM.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass, field
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from .models import (
    ADVISORY,
    Alternative,
    AntiemeticLine,
    BreakthroughLine,
    DaySummary,
    DayTier,
    DexStatus,
    DrugTier,
    Episode,
    EpisodesSummary,
    Interaction,
    Patient,
    Plan,
    PogoRow,
    RuleRef,
    StepUp,
)

from . import real_rules

SOURCE = "UZA CINV beleid v2 (juli 2026)"
SOURCE_COMBO = "UZA CINV beleid v2 (juli 2026) + POGO 250111"
SOURCE_DDI = "BCFI/CBIP"
SOURCE_POGO = "POGO 250111"

TIERS = ["minimal", "low", "moderate", "high"]
TIER_RANK = {t: i for i, t in enumerate(TIERS)}

STEROIDS = {"prednisolone", "prednisone", "dexamethasone", "methylprednisolone"}
AZOLES = {"voriconazole", "posaconazole", "itraconazole"}
QT_DRUGS = {"domperidone", "haloperidol"}
DEX_BLOCK_GROUPS = {"ALL": "ALL", "brain_tumour": "hersentumor"}

ONDANSETRON_TIMES = {1: ["08:00"], 2: ["08:00", "20:00"], 3: ["08:00", "16:00", "00:00"]}


def max_tier(*tiers: str) -> str:
    return max(tiers, key=lambda t: TIER_RANK[t]) if tiers else "minimal"


def round_half_up(x: float, places: int = 1) -> float:
    q = Decimal(1).scaleb(-places)
    return float(Decimal(repr(round(x, 6))).quantize(q, rounding=ROUND_HALF_UP))


def fmt(x: float) -> str:
    """Compact number for formulas: 7.6, 5.0 -> 5.0 kept only via explicit formatting."""
    return f"{x:g}"


def norm(drug: str) -> str:
    return " ".join(drug.strip().lower().split())


# --------------------------------------------------------------------------- Story 1
def classify_drug(drug: str, dose_mg_m2: float) -> tuple[str, str] | None:
    """(tier, rule) for one chemo drug, or None when the drug is not in the mock table."""
    d = norm(drug)
    simple = {
        "vincristine": ("low", "Vincristine = low"),
        "cisplatin": ("high", "Cisplatin = high"),
        "carboplatin": ("high", "Carboplatin = high (UZA high)"),
        "doxorubicin": ("high", "Doxorubicin = high (UZA high)"),
        "daunorubicin": ("moderate", "Daunorubicin = moderate"),
        "ifosfamide": ("moderate", "Ifosfamide = moderate"),
        "etoposide": ("low", "Etoposide = low"),
        "dinutuximab beta": ("low", "Dinutuximab beta = low"),
    }
    if d in simple:
        tier, rule = simple[d]
        return tier, f"UZA v2 · {rule}"
    if d == "cyclophosphamide":
        if dose_mg_m2 > 1500:
            return "high", f"UZA v2 · Cyclophosphamide {fmt(dose_mg_m2)} mg/m² > 1500 mg/m² = high"
        return "moderate", f"UZA v2 · Cyclophosphamide {fmt(dose_mg_m2)} mg/m² ≤ 1500 mg/m² = moderate"
    if d == "cytarabine":
        if dose_mg_m2 >= 3000:
            return "high", f"UZA v2 · Cytarabine {fmt(dose_mg_m2)} mg/m² ≥ 3000 mg/m² = high"
        if dose_mg_m2 >= 200:
            return "moderate", f"UZA v2 · Cytarabine {fmt(dose_mg_m2)} mg/m² ≥ 200 mg/m² = moderate"
        return "low", f"UZA v2 · Cytarabine {fmt(dose_mg_m2)} mg/m² < 200 mg/m² = low"
    if d == "methotrexate":
        if dose_mg_m2 >= 12000:
            return "high", f"UZA v2 · Methotrexate {fmt(dose_mg_m2)} mg/m² ≥ 12000 mg/m² = high"
        if dose_mg_m2 >= 1000:
            return "moderate", f"UZA v2 · Methotrexate {fmt(dose_mg_m2)} mg/m² ≥ 1000 mg/m² = moderate"
        return "low", f"UZA v2 · Methotrexate {fmt(dose_mg_m2)} mg/m² < 1000 mg/m² = low"
    return None


def pogo_tier(drug: str, dose_mg_m2: float, uza_tier: str) -> str:
    d = norm(drug)
    if d == "doxorubicin":
        return "moderate"
    if d == "carboplatin":
        return "high"
    if d == "cyclophosphamide":
        return "high" if dose_mg_m2 >= 1000 else "moderate"
    return uza_tier


@dataclass
class Classification:
    drug_tiers: list[DrugTier] = field(default_factory=list)
    day_tiers: list[DayTier] = field(default_factory=list)
    overall: str = "minimal"
    combination_rules: list[RuleRef] = field(default_factory=list)
    unknown: list[str] = field(default_factory=list)
    uza_vs_pogo: list[PogoRow] = field(default_factory=list)


def _legacy_classify_regimen(patient: Patient) -> Classification:  # unused; kept for reference
    c = Classification()
    tier_of: dict[str, str] = {}
    for row in patient.chemo:
        res = classify_drug(row.drug, row.dose_mg_m2)
        if res is None:
            c.unknown.append(row.drug)
            continue
        tier, rule = res
        tier_of[norm(row.drug)] = tier
        c.drug_tiers.append(DrugTier(drug=row.drug, dose_mg_m2=row.dose_mg_m2, tier=tier, rule=rule, source=SOURCE))
        p = pogo_tier(row.drug, row.dose_mg_m2, tier)
        differs = p != tier
        c.uza_vs_pogo.append(
            PogoRow(
                item=f"{row.drug} {fmt(row.dose_mg_m2)} mg/m²",
                uza_tier=tier,
                pogo_tier=p,
                differs=differs,
                note=(
                    f"POGO classifies as {p}, UZA v2 as {tier} — follow UZA v2 (source of truth)"
                    if differs
                    else "Same tier in UZA v2 and POGO"
                ),
            )
        )

    drugs = {norm(r.drug) for r in patient.chemo}
    combo_ie = "ifosfamide" in drugs and "etoposide" in drugs
    if combo_ie:
        c.combination_rules.append(RuleRef(rule="UZA v2 + POGO · Ifosfamide + Etoposide = HEC", source=SOURCE_COMBO))
        c.uza_vs_pogo.append(
            PogoRow(
                item="ifosfamide + etoposide (combination)",
                uza_tier="high",
                pogo_tier="high",
                differs=False,
                note="Both classify the combination as highly emetogenic",
            )
        )

    days = sorted({d for r in patient.chemo for d in r.days})
    multi_moderate_days: list[int] = []
    for day in days:
        on_day = [r for r in patient.chemo if day in r.days and norm(r.drug) in tier_of]
        names = [r.drug for r in on_day]
        tiers = [tier_of[norm(r.drug)] for r in on_day]
        t = max_tier(*tiers) if tiers else "minimal"
        day_drugs = {norm(n) for n in names}
        if "ifosfamide" in day_drugs and "etoposide" in day_drugs:
            t = "high"
        moderates = {norm(r.drug) for r in on_day if tier_of[norm(r.drug)] == "moderate"}
        if len(moderates) >= 2:
            t = "high"
            multi_moderate_days.append(day)
        c.day_tiers.append(DayTier(day=day, tier=t, drugs=names))
    if multi_moderate_days:
        c.combination_rules.append(
            RuleRef(
                rule="UZA v2 · ≥ 2 moderate drugs on the same day = high (day "
                + ", ".join(map(str, multi_moderate_days))
                + ")",
                source=SOURCE,
            )
        )

    single = max_tier(*[dt.tier for dt in c.drug_tiers]) if c.drug_tiers else "minimal"
    by_day = max_tier(*[dt.tier for dt in c.day_tiers]) if c.day_tiers else "minimal"
    c.overall = max_tier(single, by_day, "high" if combo_ie else "minimal")
    return c


def classify_regimen(patient: Patient) -> Classification:
    """Story 1 via aimesis_rules (UZA v2 + POGO 250111)."""
    dt, days, overall, combos, unknown, pogo = real_rules.classify(patient)
    return Classification(drug_tiers=dt, day_tiers=days, overall=overall, combination_rules=combos,
                          unknown=unknown, uza_vs_pogo=pogo)


def dex_status(patient: Patient) -> DexStatus:
    """Story 3 guardrail via aimesis_rules."""
    return real_rules.dex_status(patient)


# --------------------------------------------------------------------------- Story 3 helpers
def _legacy_dex_status(patient: Patient) -> DexStatus:  # unused; kept for reference
    group = patient.diagnosis_group
    if group in DEX_BLOCK_GROUPS:
        return DexStatus(blocked=True, reason=f"GEEN dexamethasone bij {DEX_BLOCK_GROUPS[group]} (UZA v2)", source=SOURCE)
    drugs = {norm(r.drug) for r in patient.chemo}
    if "dinutuximab beta" in drugs:
        return DexStatus(blocked=True, reason="GEEN dexamethasone bij dinutuximab beta (UZA v2)", source=SOURCE)
    steroid = sorted(drugs & STEROIDS)
    if steroid:
        return DexStatus(
            blocked=True,
            reason=f"GEEN extra dexamethasone: regime bevat al een corticosteroïd ({steroid[0]}) (UZA v2)",
            source=SOURCE,
        )
    return DexStatus(blocked=False, reason=None, source=SOURCE)


def episode_day(at: str, cycle_start: str) -> int | None:
    """Cycle day for an episode timestamp, or None if it falls before the current cycle."""
    try:
        d = date.fromisoformat(at[:10])
        start = date.fromisoformat(cycle_start[:10])
    except (TypeError, ValueError):
        return 1
    delta = (d - start).days
    return None if delta < 0 else delta + 1


def summarise_episodes(patient: Patient, episodes: list[Episode]) -> EpisodesSummary:
    per_day: dict[int, DaySummary] = {}
    current_nausea_days: set[int] = set()
    for ep in episodes:
        day = episode_day(ep.at, patient.cycle_start)
        if day is None:
            continue
        s = per_day.setdefault(day, DaySummary(day=day, nausea=0, vomiting=0))
        if ep.type == "nausea":
            s.nausea += 1
        else:
            s.vomiting += 1
        current_nausea_days.add(day)
    history_days = {d for h in patient.history for d in h.nausea_days}
    return EpisodesSummary(
        current_cycle=[per_day[d] for d in sorted(per_day)],
        prior_nausea_days=sorted(history_days | current_nausea_days),
    )


def prior_ondansetron_freq(patient: Patient) -> int | None:
    """Ondansetron frequency used in the most recent previous cycle, if recorded."""
    for h in reversed(patient.history):
        if h.antiemetics:
            m = re.search(r"ondansetron\s*(\d)\s*x", h.antiemetics, re.IGNORECASE)
            if m:
                return int(m.group(1))
    return None


def resolve_route(preferred: str, can_swallow: bool) -> tuple[str, list[str]]:
    if preferred == "oral_tablet" and not can_swallow:
        return "oral_liquid", ["Cannot swallow tablets → oral liquid formulation (BCFI/CBIP)"]
    return preferred, []


def days_label(days: list[int]) -> str:
    if not days:
        return ""
    if days == list(range(days[0], days[-1] + 1)) and len(days) > 1:
        return f"days {days[0]}–{days[-1]}"
    return "day " + ", ".join(map(str, days)) if len(days) == 1 else "days " + ", ".join(map(str, days))


# --------------------------------------------------------------------------- main entry
def compute_plan(patient: Patient, episodes: list[Episode] | None = None) -> Plan:
    """Compute the plan *content* (status / signoffs / comments are filled by the caller)."""
    episodes = episodes or []
    cls = classify_regimen(patient)
    dex = dex_status(patient)
    summary = summarise_episodes(patient, episodes)

    plan = Plan(
        patient_id=patient.id,
        drug_tiers=cls.drug_tiers,
        day_tiers=cls.day_tiers,
        overall_tier=cls.overall,
        combination_rules=cls.combination_rules,
        dexamethasone=dex,
        uza_vs_pogo=cls.uza_vs_pogo,
        episodes_summary=summary,
        unknown_drugs=cls.unknown,
        advisory=ADVISORY,
    )

    # Refuse rather than guess.
    reasons: list[str] = []
    if patient.weight_kg is None or patient.height_cm is None or patient.bsa_m2 is None:
        reasons.append("BSA missing")
    for d in cls.unknown:
        reasons.append(f"Drug not in UZA v2: {d} — refusing to classify or dose")
    if reasons:
        plan.refused = True
        plan.refusal_reasons = reasons
        plan.interactions = interactions(patient, [])
        return plan

    bsa = float(patient.bsa_m2)
    weight = float(patient.weight_kg)
    rf = patient.risk_factors
    route, route_notes = resolve_route(rf.preferred_route, rf.can_swallow_tablets)
    tier = cls.overall
    chemo_days = sorted({d for r in patient.chemo for d in r.days})
    cover_days = sorted({x for d in chemo_days for x in (d, d + 1)})
    prior_days = summary.prior_nausea_days
    has_prior = bool(prior_days)
    prior_days_txt = ", ".join(map(str, prior_days))

    lines: list[AntiemeticLine] = []

    # ---- ondansetron
    base_freq = {"high": 3, "moderate": 2, "low": 1}.get(tier, 0)
    if base_freq:
        freq = base_freq
        notes = list(route_notes)
        prev = prior_ondansetron_freq(patient)
        on_freq = min(base_freq, prev) if prev is not None else base_freq
        if has_prior and on_freq < 3:
            freq = 3
            note = f"step-up: prior nausea day {prior_days_txt} on ondansetron {on_freq}x/d"
            notes.append(note)
            plan.step_ups.append(
                StepUp(title="Ondansetron → 3x/d", reason=note, source=SOURCE)
            )
            plan.alternatives.append(
                Alternative(
                    title="Palonosetron IV once instead of ondansetron",
                    detail="Single IV dose replaces ondansetron for the cycle — never within 3 days of ondansetron",
                    source=SOURCE,
                )
            )
        raw = 5 * bsa
        dose = round_half_up(min(raw, 8.0), 1)
        steps = [f"{fmt(bsa)} m² × 5 mg/m² = {raw:.2f} mg"]
        steps.append(f"max 8 mg/dose → {dose:.1f} mg" if raw > 8 else f"≤ 8 mg/dose, rounded to 0.1 mg → {dose:.1f} mg")
        lines.append(
            AntiemeticLine(
                drug="ondansetron",
                dose_mg=dose,
                frequency=f"{freq}x/d",
                route=route,
                days=cover_days,
                formula="5 mg/m² per dose, max 8 mg/dose",
                steps=steps,
                source=f"{SOURCE} · Ondansetron 5 mg/m², max 8 mg/dose",
                notes=notes,
            )
        )

    # ---- aprepitant (high + moderate)
    give_aprepitant = tier in ("high", "moderate")
    if give_aprepitant:
        adult = patient.age >= 12 and weight >= 30
        if adult:
            d1, d23 = 125.0, 80.0
            f1 = "age ≥ 12 y and weight ≥ 30 kg: 125 mg day 1"
            f23 = "age ≥ 12 y and weight ≥ 30 kg: 80 mg days 2–3"
            s1 = [f"age {patient.age} y, {fmt(weight)} kg → fixed dose 125 mg"]
            s23 = [f"age {patient.age} y, {fmt(weight)} kg → fixed dose 80 mg"]
        else:
            r1, r23 = 3 * weight, 2 * weight
            d1, d23 = round_half_up(min(r1, 125.0), 1), round_half_up(min(r23, 80.0), 1)
            f1 = "3 mg/kg day 1, max 125 mg"
            f23 = "2 mg/kg days 2–3, max 80 mg"
            s1 = [f"{fmt(weight)} kg × 3 mg/kg = {r1:.1f} mg" + (" → max 125 mg" if r1 > 125 else f" → {d1:g} mg")]
            s23 = [f"{fmt(weight)} kg × 2 mg/kg = {r23:.1f} mg" + (" → max 80 mg" if r23 > 80 else f" → {d23:g} mg")]
        later_days = [2, 3]
        later_notes = list(route_notes)
        last_chemo = chemo_days[-1] if chemo_days else 1
        if last_chemo > 3:
            late_prior = [d for d in prior_days if d >= 4]
            if late_prior:
                later_days = list(range(2, last_chemo + 1))
                note = (
                    f"extend aprepitant to days 4–{last_chemo}, prior nausea day "
                    + ", ".join(map(str, late_prior))
                )
                later_notes.append(note)
                f23 = f23.replace("days 2–3", f"days 2–{last_chemo}")
                plan.step_ups.append(StepUp(title=f"Aprepitant through day {last_chemo}", reason=note, source=SOURCE))
            else:
                later_notes.append(
                    f"multi-day chemo (days 1–{last_chemo}): aprepitant stays days 1–3 unless prior nausea on day ≥ 4"
                )
        lines.append(
            AntiemeticLine(
                drug="aprepitant", dose_mg=d1, frequency="1x/d", route=route, days=[1],
                formula=f1, steps=s1, source=f"{SOURCE} · Aprepitant", notes=list(route_notes),
            )
        )
        lines.append(
            AntiemeticLine(
                drug="aprepitant", dose_mg=d23, frequency="1x/d", route=route, days=later_days,
                formula=f23, steps=s23, source=f"{SOURCE} · Aprepitant", notes=later_notes,
            )
        )

    # ---- dexamethasone
    want_dex = tier == "high" or (tier == "moderate" and has_prior)
    give_dex = want_dex and not dex.blocked
    if give_dex:
        base = 2.0 if bsa <= 0.6 else 4.0
        steps = [f"BSA {fmt(bsa)} m² {'≤' if bsa <= 0.6 else '>'} 0.6 m² → {base:g} mg 2x/d"]
        dose = base
        notes = list(route_notes)
        if give_aprepitant:
            dose = base / 2
            steps.append(f"CYP3A4: dose halved with aprepitant → {dose:g} mg 2x/d")
            notes.append("CYP3A4: dose halved with aprepitant")
        if route == "iv":
            notes.append("IV Aacidexam 5 mg/mL ≈ 4 mg/mL dexamethasone base")
        if tier == "moderate":
            notes.append(f"added because of prior nausea day {prior_days_txt}")
        lines.append(
            AntiemeticLine(
                drug="dexamethasone", dose_mg=dose, frequency="2x/d", route=route, days=cover_days,
                formula="BSA ≤ 0.6 m²: 2 mg 2x/d; BSA > 0.6 m²: 4 mg 2x/d; halve with aprepitant",
                steps=steps, source=f"{SOURCE} · Dexamethasone", notes=notes,
            )
        )

    # ---- olanzapine (high)
    if tier == "high":
        raw = 0.1 * weight
        capped = min(raw, 5.0)
        dose = math.floor(round(capped, 6) * 2) / 2
        lines.append(
            AntiemeticLine(
                drug="olanzapine", dose_mg=dose, frequency="1x/d (evening)", route=route, days=cover_days,
                formula="0.1 mg/kg once daily (first dose just before chemo, then evening), max 5 mg, rounded down to 0.5 mg",
                steps=[f"{fmt(weight)} kg × 0.1 = {raw:.1f} mg → {dose:.1f} mg"]
                + (["max 5 mg applied"] if raw > 5 else []),
                source=f"{SOURCE} · Olanzapine", notes=list(route_notes),
            )
        )

    plan.antiemetics = lines

    # ---- breakthrough (aimesis_rules UZA v2 p.2)
    plan.breakthrough = real_rules.breakthrough(patient, route)

    # ---- sources: aimesis_rules citations per line
    cites = real_rules.line_citations(patient, tier)
    for ln in lines:
        if ln.drug in cites:
            ln.source = f"{SOURCE} · {cites[ln.drug]}"

    plan.interactions = interactions(patient, [ln.drug for ln in lines])
    return plan


# --------------------------------------------------------------------------- Story 6
def interactions(patient: Patient, proposed: list[str]) -> list[Interaction]:
    """Story 6 via aimesis_rules (BCFI/CBIP-cited DDI + QTc screen)."""
    out = real_rules.interactions(patient, proposed)
    prop = {norm(p) for p in proposed}
    have_apr_dex = any({"aprepitant", "dexamethasone"} <= {norm(d) for d in i.drugs} for i in out)
    if "aprepitant" in prop and "dexamethasone" in prop and not have_apr_dex:
        out.append(
            Interaction(
                severity="info",
                drugs=["aprepitant", "dexamethasone"],
                message="Aprepitant inhibits CYP3A4 and raises dexamethasone exposure — dexamethasone dose already halved",
                alternative=None,
                source=f"{SOURCE} p.2 · Dexamethasone 50% reductie i.c.m. (fos)aprepitant",
            )
        )
    return out
