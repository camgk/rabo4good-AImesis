"""Deterministic AImesis rules engine.

No LLM is involved here. Every number is computed from rules/uza_v2.yaml with
exact decimal arithmetic, and every item records the rule ids and the formula
used. Anything the policy does not decide becomes a `Decision` for the
physician; anything the engine cannot classify blocks the recommendation.
"""
from __future__ import annotations

from decimal import ROUND_FLOOR, Decimal
from pathlib import Path
from typing import Optional

import yaml

from .models import (DIAGNOSES, ChemoAgent, Decision, Item, Patient, Recommendation,
                     Regimen)

RULES_PATH = Path(__file__).resolve().parents[1] / "rules" / "uza_v2.yaml"


def D(x) -> Decimal:
    return Decimal(str(x))


def fmt(x: Decimal) -> str:
    s = format(x.normalize(), "f")
    return s


class Rulebook:
    def __init__(self, path: Path = RULES_PATH):
        self.raw = yaml.safe_load(path.read_text(encoding="utf-8"))
        self.version = self.raw["meta"]["rulebook_version"]
        self.tiers: list[str] = self.raw["tiers"]
        self.alias: dict[str, str] = {}
        for agent_id, a in self.raw["agents"].items():
            for name in [agent_id, *a.get("aliases", [])]:
                self.alias[name.lower()] = agent_id
        self.non_emetogenic: dict[str, str] = {}
        for c in self.raw["non_emetogenic_regimen_components"]:
            for name in [c["id"], *c["aliases"]]:
                self.non_emetogenic[name.lower()] = c["id"]
        self.classes = {k: set(v["members"]) for k, v in self.raw["drug_classes"].items()}

    def rank(self, tier: str) -> int:
        return self.tiers.index(tier)

    def max_tier(self, tiers) -> str:
        return max(tiers, key=self.rank)


# ---------------------------------------------------------------- classify
def _match_when(when: dict, agent: ChemoAgent) -> Optional[bool]:
    """True/False, or None when a dose condition cannot be evaluated."""
    if not when:
        return True
    if "route" in when and agent.route != when["route"]:
        return False
    cond = when.get("dose_mg_m2")
    if cond:
        if agent.dose_mg_m2 is None:
            return None
        d = D(agent.dose_mg_m2)
        ops = {"gt": d > D(cond.get("gt", 0)), "gte": d >= D(cond.get("gte", 0)),
               "lt": d < D(cond.get("lt", 0)), "lte": d <= D(cond.get("lte", 0))}
        return all(ops[k] for k in cond)
    return True


def classify_agent(rb: Rulebook, agent: ChemoAgent):
    """Return (agent_id, tier, rule_id) or raise ValueError with a reason."""
    key = agent.name.strip().lower()
    agent_id = rb.alias.get(key)
    if agent_id is None:
        raise ValueError(f"'{agent.name}' is not in the UZA v2 emetogenicity table")
    results, not_evaluable = [], False
    for rule in rb.raw["agents"][agent_id]["rules"]:
        m = _match_when(rule.get("when", {}), agent)
        if m is None:
            not_evaluable = True
        elif m:
            results.append(rule)
    if not results:
        if not_evaluable:
            raise ValueError(f"{agent_id}: tier depends on dose — dose in mg/m² is required")
        raise ValueError(f"{agent_id} at {agent.dose_mg_m2} mg/m² ({agent.route}) matches no "
                         f"rule in the policy — UNCLASSIFIED")
    if len(results) > 1:
        raise ValueError(f"{agent_id}: overlapping rules {[r['id'] for r in results]} — rulebook error")
    r = results[0]
    return agent_id, r["tier"], r["id"]


# ---------------------------------------------------------------- recommend
def recommend(patient: Patient, regimen: Regimen, rb: Optional[Rulebook] = None) -> Recommendation:
    rb = rb or Rulebook()
    errors, warnings, blocks, trace = [], [], [], []
    decisions: list[Decision] = []

    # -- intake validation: missing data blocks instead of defaulting
    for f in ("age_years", "weight_kg", "bsa_m2"):
        v = getattr(patient, f)
        if v is None or v <= 0:
            errors.append(f"{f} is missing or invalid")
    if patient.diagnosis not in DIAGNOSES:
        errors.append(f"diagnosis '{patient.diagnosis}' is not a coded diagnosis {sorted(DIAGNOSES)}")
    if not regimen.days:
        errors.append("regimen has no chemotherapy days")

    # -- emetogenicity per day (POGO-style per-day evaluation, OQ-6)
    day_tiers: dict[int, str] = {}
    steroid_in_regimen = False
    for day in regimen.days:
        present, tiers = set(), []
        for agent in day.agents:
            comp = rb.non_emetogenic.get(agent.name.strip().lower())
            if comp:
                if comp in rb.classes["corticosteroid"]:
                    steroid_in_regimen = True
                continue
            try:
                aid, tier, rid = classify_agent(rb, agent)
            except ValueError as e:
                errors.append(f"day {day.day}: {e}")
                continue
            present.add(aid)
            tiers.append(tier)
            trace.append(f"day {day.day}: {aid} -> {tier} [{rid}]")
        for combo in rb.raw["combinations"]:
            ok = all((req[6:] in rb.classes and present & rb.classes[req[6:]])
                     if req.startswith("class:") else req in present
                     for req in combo["requires"])
            if ok:
                tiers.append(combo["tier"])
                trace.append(f"day {day.day}: combination {'+'.join(combo['requires'])} -> "
                             f"{combo['tier']} [{combo['id']}]")
        if tiers:
            day_tiers[day.day] = rb.max_tier(tiers)

    if errors:
        return Recommendation("BLOCKED_NEEDS_PHYSICIAN", None, day_tiers, trace, [], [], [],
                              warnings, decisions, errors, rb.version)

    tier = rb.max_tier(day_tiers.values())
    trace.append(f"overall tier = most emetogenic day -> {tier} [GEN-MAX]")

    chemo_days = sorted(day_tiers)          # days with at least one cytostatic (OQ-10)
    first, last = chemo_days[0], chemo_days[-1]
    age, wt, bsa = D(patient.age_years), D(patient.weight_kg), D(patient.bsa_m2)

    # -- prior-cycle history (only physician-confirmed facts are used)
    escalate_to = None
    for pc in patient.prior_cycles:
        if not pc.confirmed_by_physician:
            warnings.append(f"prior cycle {pc.label}: history not confirmed by physician — ignored")
            continue
        if not pc.breakthrough_days:
            continue
        if pc.ondansetron_times_per_day is None:
            warnings.append(f"prior cycle {pc.label}: prophylaxis given is unknown — check EPD [GEN-EPD]")
        baseline = next((x.get("times_per_day") for x in rb.raw["bundles"][pc.tier]["all_of"]
                         if x["drug"] == "ondansetron"), None)
        underdosed = (baseline is not None and pc.ondansetron_times_per_day is not None
                      and pc.ondansetron_times_per_day < baseline)
        if underdosed:
            warnings.append(
                f"prior cycle {pc.label} ({pc.tier}): ondansetron {pc.ondansetron_times_per_day}x/d was below "
                f"the policy baseline {baseline}x/d, so nausea on day(s) {pc.breakthrough_days} was not on "
                f"'geschikte profylaxe' — first apply the full {pc.tier} baseline [BUN-{pc.tier.upper()[:3]}]")
        elif pc.tier != "high":
            nxt = rb.tiers[min(rb.rank(pc.tier) + 1, len(rb.tiers) - 1)]
            if rb.rank(nxt) > rb.rank(tier):
                escalate_to = nxt
                trace.append(f"breakthrough in {pc.label} -> start one level higher: {nxt} [BRK-NEXT]")
        if pc.tier == "high":
            decisions.append(Decision(
                "PALO-SWITCH",
                f"Insufficient control in {pc.label} (high emetogenic). Switch ondansetron to palonosetron? "
                "Only after consultation with supervisor/pharmacy.",
                ["keep ondansetron 3x/d", f"switch to palonosetron IV: {_palonosetron_text(rb, age, wt)}"],
                ["BRK-PALO", "DOS-PALO"]))
        pc_late = [d for d in pc.breakthrough_days if d > first + 2]
        if pc_late and tier in ("high", "moderate"):
            decisions.append(Decision(
                "APREPITANT-LATE-BREAKTHROUGH",
                f"Breakthrough on day(s) {pc_late} in {pc.label} falls after aprepitant coverage "
                f"(days {first}-{first + 2}). The policy only specifies D1-D3; extending aprepitant is "
                "OUTSIDE the UZA v2 policy.",
                ["keep policy D1-D3", "physician extends aprepitant (own judgement, document reason)"],
                ["DOS-APR"]))
    if escalate_to:
        tier = escalate_to

    # -- dexamethasone blocks
    dex_blocked = False
    for b in rb.raw["dexamethasone_blocks"]["hard"]:
        w = b["when"]
        hit = (w == "regimen_contains_corticosteroid" and steroid_in_regimen) or \
              (isinstance(w, dict) and patient.diagnosis in w.get("diagnosis_in", [])) or \
              (isinstance(w, dict) and set(patient.comedications) & set(w.get("comedication_in", [])))
        if hit:
            dex_blocked = True
            blocks.append(f"GEEN dexamethasone [{b['id']}]: {b['src']['quote']}")
    for b in rb.raw["dexamethasone_blocks"]["not_preferred"]:
        w = b["when"]
        if patient.diagnosis in w.get("diagnosis_in", []) or set(patient.comedications) & set(w.get("comedication_in", [])):
            warnings.append(f"dexamethasone not preferred [{b['id']}] — physician decides")

    apr_cfg = rb.raw["dosing"]["aprepitant"]["not_indicated_if"]
    apr_ok = not (D(patient.age_months) < D(apr_cfg["age_months_lt"]) or wt <= D(apr_cfg["weight_kg_lte"]))

    oral = patient.oral_route != "none"
    route = "PO" if oral else "IV"
    if patient.oral_route in ("liquid", "ng_tube"):
        warnings.append(f"oral route via {patient.oral_route}: choose liquid/dispersible product from "
                        "the pharmacy formulary (not in policy, OQ-9)")

    # -- build the baseline bundle
    items: list[Item] = []
    bundle = rb.raw["bundles"][tier]
    trace.append(f"baseline bundle {bundle['id']} for tier {tier}")
    want = {x["drug"]: x for x in bundle["all_of"]}

    if "ondansetron" in want:
        items.append(_ondansetron(rb, bsa, want["ondansetron"]["times_per_day"], tier, chemo_days, route))

    use_apr = use_dex = False
    if tier == "high":
        use_apr, use_dex = apr_ok, not dex_blocked
        if not apr_ok:
            warnings.append("aprepitant not indicated (<6 months or ≤6 kg) [DOS-APR]")
    elif tier == "moderate":
        if dex_blocked and apr_ok:
            use_apr = True
            trace.append("moderate: dexamethasone blocked -> aprepitant")
        elif not apr_ok and not dex_blocked:
            use_dex = True
            trace.append("moderate: aprepitant not indicated -> dexamethasone")
        elif not apr_ok and dex_blocked:
            decisions.append(Decision("MEC-NO-SECOND-AGENT",
                "Moderate tier needs dexamethasone OR aprepitant, but dexamethasone is blocked and "
                "aprepitant is not indicated. Policy gives no alternative.", ["physician decides"],
                ["BUN-MOD", "DOS-APR"]))
        else:
            dex_opt = _dexamethasone(rb, bsa, False, chemo_days, route)
            apr_opt = _aprepitant(rb, age, wt, first, route)
            decisions.append(Decision("MEC-DEX-OR-APREPITANT",
                "Moderate tier: add dexamethasone OR aprepitant (policy: 'OF').",
                [f"dexamethasone {dex_opt.calc}",
                 "aprepitant " + "; ".join(i.calc for i in apr_opt)], ["BUN-MOD"]))

    if use_apr:
        items.extend(_aprepitant(rb, age, wt, first, route))
        if steroid_in_regimen:
            warnings.append("aprepitant inhibits CYP3A4 and can raise exposure to the corticosteroid in the "
                            "chemo protocol — pharmacist interaction check (policy: 'Opgelet voor "
                            "interacties (CYP3A4/2C9)')")
    if use_dex:
        items.append(_dexamethasone(rb, bsa, use_apr, chemo_days, route))

    if "olanzapine" in want:
        if age > 2 and oral:
            items.append(_olanzapine(rb, wt, chemo_days))
        elif age == 2:
            decisions.append(Decision("OLZ-AGE-2",
                "Patient is exactly 2 years: bundle says olanzapine '>2j', dosing table says '≥2j'.",
                ["give olanzapine", "omit olanzapine"], ["BUN-HIGH", "DOS-OLZ"]))
        elif age < 2:
            warnings.append("olanzapine omitted: <2 years [DOS-OLZ]")
        else:
            decisions.append(Decision("OLZ-NO-ORAL", "Olanzapine is PO only and no oral route is available.",
                                      ["omit olanzapine", "physician decides route"], ["DOS-OLZ"]))

    # -- anticipatory CINV
    if patient.anticipatory_nausea:
        items.append(_lorazepam(rb, wt, "anticipatory", [first - 1, first], route))
        warnings.append("anticipatory CINV: also non-pharmacological measures (relaxation) [ANT-1]")

    # -- rescue plan for breakthrough (always provided above minimal)
    rescue: list[Item] = []
    # rescue plan is shown for every tier (BRK-1 covers minimal too)
    if True:
        rescue.append(_alizapride(rb, wt, chemo_days, route))
        rescue.append(_lorazepam(rb, wt, "breakthrough", chemo_days, route))
        step = rb.raw["breakthrough"]["steps"][0]["to_times_per_day"].get(tier)
        if step:
            warnings.append(f"breakthrough ladder: raise ondansetron to {step}x/d [BRK-1] -> "
                            "consider olanzapine (>2j) [BRK-2] -> add alizapride or lorazepam [BRK-3]")
        else:
            warnings.append("breakthrough ladder (already at max ondansetron): add alizapride or "
                            "lorazepam [BRK-3]; next cycle consider palonosetron [BRK-PALO]")

    return Recommendation("DRAFT_REQUIRES_PHYSICIAN_APPROVAL", tier, day_tiers, trace, items, rescue,
                          blocks, warnings, decisions, [], rb.version)


# ---------------------------------------------------------------- dosing
def _ondansetron(rb, bsa, times, tier, chemo_days, route) -> Item:
    c = rb.raw["dosing"]["ondansetron"]
    raw = D(c["per_dose"]["mg_per_m2"]) * bsa
    dose = min(raw, D(c["per_dose"]["max_mg"]))
    if tier in ("moderate", "high"):
        days = list(range(chemo_days[0], chemo_days[-1] + c["duration"]["moderate_or_high"]
                          ["through_days_after_last_chemo"] + 1))
    else:
        days = chemo_days
    calc = f"5 mg/m² × {fmt(bsa)} m² = {fmt(raw)} mg" + (" -> max 8 mg" if raw > dose else "")
    return Item("ondansetron", dose, "mg", times, route, days, calc, ["DOS-OND", f"BUN-{tier.upper()[:3]}"])


def _dexamethasone(rb, bsa, with_apr, chemo_days, route) -> Item:
    c = rb.raw["dosing"]["dexamethasone"]
    band = "bsa_lt_split" if bsa < D(c["bsa_split_m2"]) else "bsa_gte_split"
    key = "with_aprepitant" if with_apr else "without_aprepitant"
    dose = D(c["mg_per_dose"][band][key])
    calc = (f"BSA {fmt(bsa)} m² {'<' if band == 'bsa_lt_split' else '≥'} 0,6 m², "
            f"{'with' if with_apr else 'without'} aprepitant -> {fmt(dose)} mg 2x/d")
    notes = []
    if route == "IV":
        ml = dose / D(c["iv_product_note"]["active_mg_per_ml"])
        notes.append(f"IV Aacidexam® 5 mg/ml ≈ 4 mg/ml active: {fmt(dose)} mg ≈ {fmt(ml)} ml — verify")
    return Item("dexamethasone", dose, "mg", 2, route, chemo_days, calc, ["DOS-DEX"], notes)


def _aprepitant(rb, age, wt, first, route) -> list[Item]:
    c = rb.raw["dosing"]["aprepitant"]
    days23 = [first + 1, first + 2]
    if route == "PO":
        if age < 12:
            r1, r2 = c["po"]["under_12"]["d1"], c["po"]["under_12"]["d2_d3"]
            d1 = min(D(r1["mg_per_kg"]) * wt, D(r1["max_mg"]))
            d2 = min(D(r2["mg_per_kg"]) * wt, D(r2["max_mg"]))
            calc1 = f"<12j: 3 mg/kg × {fmt(wt)} kg = {fmt(D(3) * wt)} mg (max 125) -> {fmt(d1)} mg"
            calc2 = f"<12j: 2 mg/kg × {fmt(wt)} kg = {fmt(D(2) * wt)} mg (max 80) -> {fmt(d2)} mg"
        else:
            d1, d2 = D(c["po"]["from_12"]["d1"]["mg"]), D(c["po"]["from_12"]["d2_d3"]["mg"])
            calc1, calc2 = "≥12j: 125 mg on D1", "≥12j: 80 mg on D2 and D3"
        name = "aprepitant"
    else:
        r1, r2 = c["iv_fosaprepitant"]["three_day"]["d1"], c["iv_fosaprepitant"]["three_day"]["d2_d3"]
        d1 = min(D(r1["mg_per_kg"]) * wt, D(r1["max_mg"]))
        d2 = min(D(r2["mg_per_kg"]) * wt, D(r2["max_mg"]))
        calc1 = f"IV: 3 mg/kg × {fmt(wt)} kg = {fmt(D(3) * wt)} mg (max 115) -> {fmt(d1)} mg"
        calc2 = f"IV: 2 mg/kg × {fmt(wt)} kg = {fmt(D(2) * wt)} mg (max 80) -> {fmt(d2)} mg"
        name = "fosaprepitant"
    notes = ["PO preferred; reimbursement depends on age", "check interactions CYP3A4/2C9",
             "no rounding rule in policy — round to product strength with pharmacy (OQ-7)"]
    return [Item(f"{name}_d1", d1, "mg", 1, route, [first], calc1, ["DOS-APR"], notes),
            Item(f"{name}_d2_d3", d2, "mg", 1, route, days23, calc2, ["DOS-APR"], notes)]


def _olanzapine(rb, wt, chemo_days) -> Item:
    c = rb.raw["dosing"]["olanzapine"]
    raw = D(c["per_dose"]["mg_per_kg"]) * wt
    capped = min(raw, D(c["per_dose"]["max_mg"]))
    step = D(c["rounding"]["step_mg"])
    dose = (capped / step).to_integral_value(rounding=ROUND_FLOOR) * step
    days = list(range(chemo_days[0], chemo_days[-1] + c["duration"]["through_days_after_last_chemo"] + 1))
    calc = (f"0,1 mg/kg × {fmt(wt)} kg = {fmt(raw)} mg" + (" -> max 5 mg" if raw > capped else "")
            + f" -> rounded DOWN to 0,5 mg = {fmt(dose)} mg")
    notes = [c["administration"], "never monotherapy for CINV"]
    if dose <= 0:
        notes.append("computed dose is 0 mg after rounding — physician decides")
    return Item("olanzapine", dose, "mg", 1, "PO", days, calc, ["DOS-OLZ"], notes)


def _lorazepam(rb, wt, kind, days, route) -> Item:
    c = rb.raw["dosing"]["lorazepam"][kind]
    lo = min(D(c["mg_per_kg_min"]) * wt, D(c["max_mg"]))
    hi = min(D(c["mg_per_kg_max"]) * wt, D(c["max_mg"]))
    calc = (f"{fmt(D(c['mg_per_kg_min']))}-{fmt(D(c['mg_per_kg_max']))} mg/kg × {fmt(wt)} kg "
            f"(max 2 mg) -> {fmt(lo)}-{fmt(hi)} mg, {c['schedule']}")
    notes = ["IV form not reimbursed"] if route == "IV" else []
    return Item(f"lorazepam_{kind}", lo, "mg", None, route, days, calc, ["DOS-LZP"], notes,
                dose_max=hi, prn=(kind == "breakthrough"))


def _alizapride(rb, wt, chemo_days, route) -> Item:
    c = rb.raw["dosing"]["alizapride"]
    raw = D(c["per_dose"]["mg_per_kg"]) * wt
    dose = min(raw, D(c["per_dose"]["max_mg"]))
    calc = f"1 mg/kg × {fmt(wt)} kg = {fmt(raw)} mg (max 50) -> {fmt(dose)} mg, max 6x/d"
    return Item("alizapride", dose, "mg", 6, route, chemo_days, calc, ["DOS-ALZ"], prn=True)


def _palonosetron_text(rb, age, wt) -> str:
    c = rb.raw["dosing"]["palonosetron"]
    if age < 17:
        raw = D(c["under_17"]["mcg_per_kg"]) * wt
        dose = min(raw, D(c["under_17"]["max_mcg"]))
        return f"<17j: 20 mcg/kg × {fmt(wt)} kg = {fmt(raw)} mcg (max 1500) -> {fmt(dose)} mcg once; " \
               "no ondansetron until 3 days after"
    return "≥17j: 250 mcg on D1, repeat on D4 if needed; no ondansetron until 3 days after"
