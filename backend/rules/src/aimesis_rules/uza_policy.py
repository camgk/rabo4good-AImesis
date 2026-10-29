"""Story 1: UZA July 2026 v2 Emetogenicity Classification & Combination Rules.

Pure Python, deterministic implementation of `Anti-emetica beleid CINV - V2.pdf` page 1.
Enforces Ground Rule #1 (The model never calculates), #2 (Every clinical line cites its rule),
and #3 (Refuse rather than guess when a drug is unknown or a required dose threshold is missing).
"""

from __future__ import annotations

import math
from typing import Dict, List, Optional, Set, Tuple

from .models import (
    ADVISORY_LABEL,
    ChemoDrugInput,
    DrugClassification,
    EmetogenicTier,
    RANK_TO_TIER,
    RefusalReason,
    RegimenClassification,
    TIER_RANK,
)

# Canonical drug aliases (NL / EN / brand / protocol abbreviations)
DRUG_ALIASES: Dict[str, str] = {
    "carboplatine": "carboplatin",
    "cisplatine": "cisplatin",
    "cdpp": "cisplatin",
    "cyclofosfamide": "cyclophosphamide",
    "ctx": "cyclophosphamide",
    "cytarabine iv": "cytarabine",
    "ara-c": "cytarabine",
    "arac": "cytarabine",
    "dactinomycine": "dactinomycin",
    "actinomycin d": "dactinomycin",
    "actinomycin-d": "dactinomycin",
    "doxorubicine": "doxorubicin",
    "adriamycin": "doxorubicin",
    "methotrexaat": "methotrexate",
    "mtx": "methotrexate",
    "hd-mtx": "methotrexate",
    "melphalan iv": "melphalan",
    "melfalan": "melphalan",
    "thiotepa iv": "thiotepa",
    "arseentrioxide": "arsenic_trioxide",
    "arsenic trioxide": "arsenic_trioxide",
    "azacitidine iv": "azacitidine",
    "daunorubicine": "daunorubicin",
    "idarubicine": "idarubicin",
    "epirubicine": "epirubicin",
    "ifosfamide": "ifosfamide",
    "ifo": "ifosfamide",
    "asparaginase": "asparaginase",
    "pegasparaginase": "pegaspargase",
    "peg-asparaginase": "pegaspargase",
    "doxorubicine liposomaal": "liposomal_doxorubicin",
    "liposomal doxorubicin": "liposomal_doxorubicin",
    "inotuzumab": "inotuzumab_ozogamicin",
    "inotuzumab ozogamicin": "inotuzumab_ozogamicin",
    "mitomycine": "mitomycin",
    "mitoxantrone iv": "mitoxantrone",
    "triple it": "triple_it",
    "triple it/itt": "triple_it",
    "itt": "triple_it",
    "vcr": "vincristine",
    "vinc": "vincristine",
    "cisplatinum": "cisplatin",
    "cddp": "cisplatin",
    "dauno": "daunorubicin",
    "etoposid": "etoposide",
    "bleomycine": "bleomycin",
    "mitoxantron": "mitoxantrone",
    "doxorubicin liposomal": "liposomal_doxorubicin",
    "doxorubicin (liposomal)": "liposomal_doxorubicin",
    "gemtuzumab": "gemtuzumab_ozogamicin",
    "gemtuzumab ozogamicin": "gemtuzumab_ozogamicin",
    "5-fu": "fluorouracil",
    "5-fluorouracil": "fluorouracil",
    "6-mp": "mercaptopurine",
    "6-mercaptopurine": "mercaptopurine",
}

# Fixed-tier drugs in UZA v2 page 1 (do not require dose_mg_m2 to classify)
UZA_FIXED_TIER_DRUGS: Dict[str, Tuple[EmetogenicTier, str]] = {
    # HOOG EMETOGEEN (>90%)
    "carboplatin": (EmetogenicTier.HIGH, "UZA v2 p.1 · HOOG EMETOGEEN: Carboplatine"),
    "cisplatin": (EmetogenicTier.HIGH, "UZA v2 p.1 · HOOG EMETOGEEN: Cisplatine"),
    "dacarbazine": (EmetogenicTier.HIGH, "UZA v2 p.1 · HOOG EMETOGEEN: Dacarbazine"),
    "doxorubicin": (EmetogenicTier.HIGH, "UZA v2 p.1 · HOOG EMETOGEEN: Doxorubicine"),
    "melphalan": (EmetogenicTier.HIGH, "UZA v2 p.1 · HOOG EMETOGEEN: Melphalan IV"),
    # MATIG EMETOGEEN (30-90%)
    "arsenic_trioxide": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Arseentrioxide"),
    "azacitidine": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Azacitidine IV"),
    "bendamustine": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Bendamustine"),
    "busulfan": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Busulfan"),
    "clofarabine": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Clofarabine"),
    "daunorubicin": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Daunorubicine"),
    "idarubicin": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Idarubicine"),
    "ifosfamide": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Ifosfamide (alleen)"),
    "irinotecan": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Irinotecan"),
    "lomustine": (EmetogenicTier.MODERATE, "UZA v2 p.1 · MATIG EMETOGEEN: Lomustine"),
    # LAAG EMETOGEEN (10-30%)
    "asparaginase": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Asparaginase/Pegasparaginase"),
    "pegaspargase": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Asparaginase/Pegasparaginase"),
    "atg": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: ATG"),
    "blinatumomab": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Blinatumomab"),
    "liposomal_doxorubicin": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Doxorubicine liposomaal"),
    "etoposide": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Etoposide (alleen)"),
    "gemcitabine": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Gemcitabine"),
    "inotuzumab_ozogamicin": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Inotuzumab ozogamicin"),
    "mitomycin": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Mitomycine"),
    "mitoxantrone": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Mitoxantrone IV"),
    "temozolomide": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Temozolomide"),
    "topotecan": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Topotecan"),
    "triple_it": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Triple IT/ITT"),
    "vinblastine": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Vinblastine"),
    "vincristine": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Vincristine"),
    "vinorelbine": (EmetogenicTier.LOW, "UZA v2 p.1 · LAAG EMETOGEEN: Vinorelbine"),
    # MINIMAAL EMETOGEEN (<10%)
    "bevacizumab": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Bevacizumab"),
    "bleomycin": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Bleomycine"),
    "bortezomib": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Bortezomib"),
    "cladribine": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Cladribine"),
    "fludarabine": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Fludarabine"),
    "gemtuzumab_ozogamicin": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Gemtuzumab ozogamicin"),
    "nelarabine": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Nelarabine"),
    "rituximab": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Rituximab"),
    "thioguanine": (EmetogenicTier.MINIMAL, "UZA v2 p.1 · MINIMAAL EMETOGEEN: Thioguanine"),
}

DOSE_DEPENDENT_DRUGS: Set[str] = {
    "cyclophosphamide",
    "cytarabine",
    "dactinomycin",
    "methotrexate",
    "thiotepa",
}

ANTHRACYCLINES: Set[str] = {
    "doxorubicin",
    "daunorubicin",
    "idarubicin",
    "epirubicin",
}

BASELINE_PROPHYLAXIS_BY_TIER: Dict[EmetogenicTier, str] = {
    EmetogenicTier.HIGH: (
        "Ondansetron (3x/d) + Dexamethasone + Aprepitant + Olanzapine (>2j) "
        "[UZA v2 p.1 · HOOG EMETOGEEN]"
    ),
    EmetogenicTier.MODERATE: (
        "Ondansetron (2x/d) + (Dexamethasone OR Aprepitant) "
        "[UZA v2 p.1 · MATIG EMETOGEEN]"
    ),
    EmetogenicTier.LOW: "Ondansetron (1x/d) [UZA v2 p.1 · LAAG EMETOGEEN]",
    EmetogenicTier.MINIMAL: "Geen standaard profylaxe [UZA v2 p.1 · MINIMAAL EMETOGEEN]",
}


def normalize_drug_name(name: str) -> str:
    cleaned = " ".join(name.strip().lower().split())
    return DRUG_ALIASES.get(cleaned, cleaned)


def classify_single_drug_uza_v2(
    drug_name: str,
    dose_mg_m2: Optional[float] = None,
    route: str = "IV",
    days: Optional[List[int]] = None,
    strict_missing_dose: bool = True,
) -> Tuple[Optional[DrugClassification], Optional[RefusalReason]]:
    """Classifies a single cytostatic per UZA v2 page 1."""
    norm = normalize_drug_name(drug_name)
    norm_route = (route or "").strip().upper()
    day_list = [1] if days is None else days

    def refuse(field: str, message: str):
        return None, RefusalReason(field=field, message=message, citation="UZA v2 p.1")

    if not norm:
        return refuse("drug_list", "Provide a chemotherapy drug name.")
    if not day_list or any(type(day) is not int or day < 1 for day in day_list):
        return refuse(f"drug_days.{norm}", "Treatment days must be a non-empty list of positive integers.")
    day_list = sorted(set(day_list))
    if dose_mg_m2 is not None and (
        isinstance(dose_mg_m2, bool)
        or not isinstance(dose_mg_m2, (int, float))
        or not math.isfinite(dose_mg_m2)
        or dose_mg_m2 <= 0
    ):
        return refuse(f"drug_doses_mg_m2.{norm}", "Dose must be a finite positive number in mg/m².")
    if norm_route not in {"IV", "PO", "IT", "ITT"}:
        return refuse(f"drug_routes.{norm}", "Provide a supported route: IV, PO, IT or ITT.")
    if norm_route in {"IT", "ITT"} and norm not in {"methotrexate", "triple_it"}:
        return refuse(f"drug_routes.{norm}", "This intrathecal drug/route is not classified by the supplied UZA table.")
    iv_only = {"melphalan", "azacitidine", "mitoxantrone", "cyclophosphamide", "cytarabine", "dactinomycin", "thiotepa"}
    if norm in iv_only and norm_route != "IV":
        return refuse(f"drug_routes.{norm}", "The implemented UZA rule covers IV administration only; verify this route with the clinical team.")
    if norm == "triple_it" and norm_route not in {"IT", "ITT"}:
        return refuse(f"drug_routes.{norm}", "Triple IT/ITT requires an intrathecal route (IT or ITT).")
    if norm == "methotrexate" and norm_route == "PO" and dose_mg_m2 is not None and dose_mg_m2 >= 250:
        return refuse(f"drug_routes.{norm}", "UZA's methotrexate rules at ≥250 mg/m² specify IV; verify an oral regimen with the clinical team.")

    if norm in DOSE_DEPENDENT_DRUGS:
        # Intrathecal methotrexate is Low regardless of mg/m2
        if norm == "methotrexate" and norm_route in {"IT", "ITT"}:
            return (
                DrugClassification(
                    input_name=drug_name,
                    canonical_name=norm,
                    tier=EmetogenicTier.LOW,
                    dose_mg_m2=dose_mg_m2,
                    route=norm_route,
                    days=day_list,
                    rule_citation="UZA v2 p.1 · LAAG EMETOGEEN: Methotrexaat <250mg/m² of IT",
                ),
                None,
            )

        if dose_mg_m2 is None:
            # Retain the legacy keyword for callers, but never guess a clinical tier.
            return refuse(
                f"drug_doses_mg_m2.{norm}",
                f"Provide the dose in mg/m² for dose-dependent cytostatic '{drug_name}'.",
            )

        if norm == "cytarabine" and dose_mg_m2 == 200:
            return refuse(
                f"drug_doses_mg_m2.{norm}",
                "Exactly 200 mg/m² cytarabine is ambiguous: UZA prints <200 for Low and >200 for Moderate. Clinical review is required.",
            )

        if norm == "cyclophosphamide":
            if dose_mg_m2 > 1500.0:
                tier = EmetogenicTier.HIGH
                cite = "UZA v2 p.1 · HOOG EMETOGEEN: Cyclofosfamide >1500mg/m²"
            else:
                tier = EmetogenicTier.MODERATE
                cite = "UZA v2 p.1 · MATIG EMETOGEEN: Cyclofosfamide IV ≤1500mg/m²"
        elif norm == "cytarabine":
            if dose_mg_m2 >= 3000.0:
                tier = EmetogenicTier.HIGH
                cite = "UZA v2 p.1 · HOOG EMETOGEEN: Cytarabine IV vanaf 3g/m² (≥3000 mg/m²)"
            elif dose_mg_m2 > 200.0:
                tier = EmetogenicTier.MODERATE
                cite = "UZA v2 p.1 · MATIG EMETOGEEN: Cytarabine >200mg <3g/m²"
            else:
                tier = EmetogenicTier.LOW
                cite = "UZA v2 p.1 · LAAG EMETOGEEN: Cytarabine <200mg/m² (lage dosis)"
        elif norm == "methotrexate":
            if dose_mg_m2 >= 12000.0:
                tier = EmetogenicTier.HIGH
                cite = "UZA v2 p.1 · HOOG EMETOGEEN: Methotrexaat IV ≥12g/m² (≥12000 mg/m²)"
            elif dose_mg_m2 >= 250.0:
                tier = EmetogenicTier.MODERATE
                cite = "UZA v2 p.1 · MATIG EMETOGEEN: Methotrexaat IV ≥250mg <12g/m²"
            elif dose_mg_m2 >= 50.0:
                tier = EmetogenicTier.LOW
                cite = "UZA v2 p.1 · LAAG EMETOGEEN: Methotrexaat <250mg/m² of IT"
            else:
                tier = EmetogenicTier.MINIMAL
                cite = "UZA v2 p.1 · MINIMAAL EMETOGEEN: Methotrexaat <50mg/m²"
        elif norm == "dactinomycin":
            if dose_mg_m2 >= 1.35:
                tier = EmetogenicTier.HIGH
                cite = "UZA v2 p.1 · HOOG EMETOGEEN: Dactinomycine IV ≥1,35 mg/m²"
            else:
                tier = EmetogenicTier.MODERATE
                cite = "UZA v2 p.1 · MATIG EMETOGEEN: Dactinomycine (<1,35 mg/m²)"
        elif norm == "thiotepa":
            if dose_mg_m2 >= 300.0:
                tier = EmetogenicTier.HIGH
                cite = "UZA v2 p.1 · HOOG EMETOGEEN: Thiotepa IV ≥300mg/m²"
            else:
                tier = EmetogenicTier.LOW
                cite = "UZA v2 p.1 · LAAG EMETOGEEN: Thiotepa <300mg/m²"
        else:
            tier = EmetogenicTier.MODERATE
            cite = "UZA v2 p.1"

        return (
            DrugClassification(
                input_name=drug_name,
                canonical_name=norm,
                tier=tier,
                dose_mg_m2=dose_mg_m2,
                route=norm_route,
                days=day_list,
                rule_citation=cite,
            ),
            None,
        )

    if norm in UZA_FIXED_TIER_DRUGS:
        tier, cite = UZA_FIXED_TIER_DRUGS[norm]
        return (
            DrugClassification(
                input_name=drug_name,
                canonical_name=norm,
                tier=tier,
                dose_mg_m2=dose_mg_m2,
                route=norm_route,
                days=day_list,
                rule_citation=cite,
            ),
            None,
        )

    return (
        None,
        RefusalReason(
            field="drug_list",
            message=(
                f"Cytostatic '{drug_name}' is not listed in UZA Anti-emetica beleid CINV v2 (Juli 2026). "
                "Refusing to guess emetogenicity tier."
            ),
            citation="UZA v2 p.1 · Ground Rule #3 (Refuse rather than guess)",
        ),
    )


def evaluate_combination_rule(drug_names: Set[str]) -> Tuple[bool, Optional[str]]:
    """Checks UZA v2 page 1 combination rules that elevate a regimen/day to HIGH."""
    if {"ifosfamide", "etoposide"}.issubset(drug_names):
        return (
            True,
            "UZA v2 p.1 · HOOG EMETOGEEN Combinatie: Ifosfamide/Etoposide (MEC + LEC → HEC, Casus 3)",
        )
    if "cytarabine" in drug_names and bool(drug_names.intersection({"daunorubicin", "etoposide"})):
        return (
            True,
            "UZA v2 p.1 · HOOG EMETOGEEN Combinatie: Cytarabine/Daunorubicine of Etoposide",
        )
    if "cyclophosphamide" in drug_names and bool(drug_names.intersection(ANTHRACYCLINES)):
        if "etoposide" in drug_names:
            return (
                True,
                "UZA v2 p.1 · HOOG EMETOGEEN Combinatie: Cyclofosfamide/anthracycline/Etoposide",
            )
        return (
            True,
            "UZA v2 p.1 · HOOG EMETOGEEN Combinatie: Cyclofosfamide/anthracycline",
        )
    return False, None


def classify_regimen_uza_v2(
    drugs: List[ChemoDrugInput],
    strict_missing_dose: bool = True,
) -> RegimenClassification:
    """Classifies a complete chemotherapy regimen per UZA v2 page 1."""
    if not drugs:
        return RegimenClassification(
            refused=True,
            refusal_reasons=[
                RefusalReason(
                    field="drug_list",
                    message="No chemotherapy agents provided. Cannot classify regimen emetogenicity.",
                )
            ],
        )

    classifications: List[DrugClassification] = []
    refusals: List[RefusalReason] = []

    for item in drugs:
        classified, refusal = classify_single_drug_uza_v2(
            drug_name=item.drug,
            dose_mg_m2=item.dose_mg_m2,
            route=item.route,
            days=item.days,
            strict_missing_dose=strict_missing_dose,
        )
        if refusal is not None:
            refusals.append(refusal)
        elif classified is not None:
            classifications.append(classified)

    if refusals:
        return RegimenClassification(
            refused=True,
            refusal_reasons=refusals,
            per_drug=classifications,
        )

    # Calculate per-day emetogenicity tiers
    all_days: Set[int] = set()
    for c in classifications:
        all_days.update(c.days)

    per_day_tier: Dict[int, EmetogenicTier] = {}
    per_day_combination_rules: Dict[int, str] = {}
    for day in sorted(all_days):
        day_drugs = [c for c in classifications if day in c.days]
        day_names = {c.canonical_name for c in day_drugs}
        day_combo, day_rule = evaluate_combination_rule(day_names)
        if day_combo:
            per_day_tier[day] = EmetogenicTier.HIGH
            assert day_rule is not None
            per_day_combination_rules[day] = day_rule
        else:
            max_day_rank = max(TIER_RANK[c.tier] for c in day_drugs)
            per_day_tier[day] = RANK_TO_TIER[max_day_rank]

    overall_tier = max(per_day_tier.values(), key=TIER_RANK.__getitem__)
    combo_elevated = bool(per_day_combination_rules)
    combo_rule = "; ".join(
        f"Day {day}: {rule}" for day, rule in per_day_combination_rules.items()
    ) or None
    peak_days = [str(day) for day, tier in per_day_tier.items() if tier == overall_tier]
    rationale = (
        f"Overall {overall_tier.value} is the highest daily tier (day(s) {', '.join(peak_days)}). "
        "Each day uses the highest individual drug tier, with only the named UZA combination exceptions. "
        "UZA v2 p.1–2."
    )

    return RegimenClassification(
        refused=False,
        per_drug=classifications,
        per_day_tier=per_day_tier,
        overall_tier=overall_tier,
        combination_elevated=combo_elevated,
        combination_rule_applied=combo_rule,
        per_day_combination_rules=per_day_combination_rules,
        per_day_baseline_prophylaxis={day: BASELINE_PROPHYLAXIS_BY_TIER[tier] for day, tier in per_day_tier.items()},
        overall_rationale=rationale,
        baseline_prophylaxis_summary=BASELINE_PROPHYLAXIS_BY_TIER[overall_tier],
        citation="UZA Anti-emetica beleid CINV v2 (Juli 2026) p.1",
        advisory_status=ADVISORY_LABEL,
    )
