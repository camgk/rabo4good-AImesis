"""Regimen classification -> `Plan` classification fields.

Produces the part of the frontend `Plan` (contracts/mock-api.openapi.yaml) that the
risk-tier tab renders: `drugTiers`, `dayTiers`, `overallTier`, `combinationRules`,
`unknownDrugs`, plus classification refusals.

Unknown drugs are reported in `unknownDrugs` and refuse the plan, but the known drugs
are still classified so the clinician sees which row blocks the plan. The overall tier
is withheld (None) when any drug is unknown: refuse rather than guess.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from aimesis_rules import ChemoDrugInput, classify_regimen_uza_v2
from aimesis_rules.uza_policy import classify_single_drug_uza_v2

DEFAULT_SOURCE = "UZA v2 p.1"


def _tier(value: Any) -> str:
    """EmetogenicTier ('High') -> contract Tier ('high')."""
    return str(getattr(value, "value", value)).lower()


def split_citation(citation: Optional[str]) -> Tuple[str, str]:
    """'UZA v2 p.1 · HOOG EMETOGEEN: Cisplatine' -> (rule, source)."""
    if not citation:
        return "", DEFAULT_SOURCE
    source, sep, rule = citation.partition(" · ")
    if not sep:
        return citation, DEFAULT_SOURCE
    return rule, source


def classify_for_plan(chemo: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Classify `chemo_regimen` rows (patient_context.schema.json shape:
    `drug_name`, `dose_mg_per_m2`, `day_numbers`)."""
    inputs = [
        ChemoDrugInput(
            drug=row["drug_name"],
            dose_mg_m2=row.get("dose_mg_per_m2"),
            days=list(row.get("day_numbers") or [1]),
        )
        for row in chemo
    ]

    known: List[ChemoDrugInput] = []
    unknown: List[str] = []
    refusal_reasons: List[str] = []
    for item in inputs:
        _, refusal = classify_single_drug_uza_v2(
            drug_name=item.drug,
            dose_mg_m2=item.dose_mg_m2,
            route=item.route,
            days=item.days,
            strict_missing_dose=True,
        )
        if refusal is None:
            known.append(item)
            continue
        refusal_reasons.append(refusal.message)
        if refusal.field == "drug_list":
            unknown.append(item.drug)

    result: Dict[str, Any] = {
        "drugTiers": [],
        "dayTiers": [],
        "overallTier": None,
        "combinationRules": [],
        "unknownDrugs": unknown,
        "refused": bool(refusal_reasons) or not inputs,
        "refusalReasons": refusal_reasons,
    }
    if not known:
        if not inputs:
            result["refusalReasons"] = ["No chemotherapy agents provided"]
        return result

    cls = classify_regimen_uza_v2(drugs=known, strict_missing_dose=True)

    for d in cls.per_drug:
        rule, source = split_citation(d.rule_citation)
        result["drugTiers"].append(
            {"drug": d.input_name, "doseMgM2": d.dose_mg_m2, "tier": _tier(d.tier), "rule": rule, "source": source}
        )

    for day in sorted(cls.per_day_tier):
        result["dayTiers"].append(
            {
                "day": int(day),
                "tier": _tier(cls.per_day_tier[day]),
                "drugs": [d.input_name for d in cls.per_drug if day in d.days],
            }
        )

    if cls.combination_rule_applied:
        rule, source = split_citation(cls.combination_rule_applied)
        result["combinationRules"].append({"rule": rule, "source": source})

    if not result["refused"]:
        result["overallTier"] = _tier(cls.overall_tier)
    return result
