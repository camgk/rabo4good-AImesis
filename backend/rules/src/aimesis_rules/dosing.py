"""Deterministic UZA v2 p.2 doses with inspectable arithmetic and explicit routes.

BSA bands, weight/age gates, maximum doses and the olanzapine floor are applied
before presentation. Decimal arithmetic avoids rounding across a dose boundary.
"""

from __future__ import annotations

import math
from decimal import ROUND_FLOOR, Decimal
from typing import Any

from .dexamethasone import evaluate_dexamethasone_contraindication
from .models import (
    ADVISORY_LABEL,
    DoseLine,
    DosingScheduleResult,
    EmetogenicTier,
    RefusalReason,
)


def _number(value: Decimal) -> str:
    return format(value.normalize(), "f")


def round_down_to_half_mg(value_mg: float) -> float:
    """Round down without rounding the input up to a half-milligram boundary."""
    value = Decimal(str(value_mg))
    if not value.is_finite() or value < 0:
        raise ValueError("A finite non-negative dose is required.")
    return float((value * 2).to_integral_value(rounding=ROUND_FLOOR) / 2)


def _calculation(
    label: str,
    value: float,
    input_unit: str,
    rate: str,
    maximum: float | None,
    unit: str = "mg",
    floor_half: bool = False,
) -> dict[str, Any]:
    raw = Decimal(str(value)) * Decimal(rate)
    capped = min(raw, Decimal(str(maximum))) if maximum is not None else raw
    final = (
        (capped * 2).to_integral_value(rounding=ROUND_FLOOR) / 2
        if floor_half
        else capped
    )
    formula = (
        f"{rate} {unit}/{input_unit} × {value} {input_unit} = {_number(raw)} {unit}"
    )
    if maximum is not None:
        formula += f"; maximum {maximum:g} {unit}"
    if floor_half:
        formula += "; round DOWN to nearest 0.5 mg"
    formula += f" → {_number(final)} {unit} per dose"
    return {
        "label": label,
        "input_value": value,
        "input_unit": input_unit,
        "rate": float(rate),
        "raw_dose": float(raw),
        "maximum_dose": maximum,
        "capped_dose": float(capped),
        "final_dose": float(final),
        "unit": unit,
        "rounding_rule": "floor to 0.5 mg" if floor_half else "none",
        "formula": formula,
    }


def _fixed(label: str, amount: float, rule: str) -> dict[str, Any]:
    return {
        "label": label,
        "raw_dose": amount,
        "maximum_dose": None,
        "final_dose": amount,
        "unit": "mg",
        "rounding_rule": "fixed protocol dose",
        "formula": rule,
    }


def calculate_uza_dosing(
    tier: EmetogenicTier,
    patient_age_years: float | None,
    patient_weight_kg: float | None,
    bsa_m2: float | None,
    indication: str = "solid_tumor",
    regimen_drugs: list[str] | None = None,
    concomitant_meds: list[str] | None = None,
    can_swallow_tablets: bool = True,
    chemo_duration_days: int = 1,
    prior_breakthrough_cinv: bool = False,
    anticipatory_vomiting: bool = False,
    use_palonosetron_switch: bool = False,
    mec_prefer_aprepitant: bool = False,
    antiemetic_route: str = "PO",
    aprepitant_route: str = "PO",
    fosaprepitant_schedule: str = "multi_day",
) -> DosingScheduleResult:
    """Calculate source-specific doses, never defaulting missing biometrics.

    Routes are explicit: oral aprepitant and IV fosaprepitant have different caps.
    `single_dose` fosaprepitant is an option only for one-day chemotherapy.
    Rescue agents are returned as options/ranges for clinician selection.
    """
    refusals = []
    for name, value, lower, upper in [
        ("patient_age_years", patient_age_years, 0, 21),
        ("patient_weight_kg", patient_weight_kg, 1, 150),
        ("bsa_m2", bsa_m2, 0.1, 3),
    ]:
        if (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not math.isfinite(value)
            or not lower <= value <= upper
        ):
            refusals.append(
                RefusalReason(
                    field=name,
                    message=f"Provide a finite {name} in [{lower}, {upper}]; no dose can be calculated without valid patient measurements.",
                )
            )
    try:
        tier = EmetogenicTier(tier)
    except ValueError:
        refusals.append(
            RefusalReason(field="tier", message="Provide a classified UZA risk tier.")
        )
    antiemetic_route = antiemetic_route.strip().upper()
    aprepitant_route = aprepitant_route.strip().upper()
    if antiemetic_route not in {"PO", "IV"} or aprepitant_route not in {"PO", "IV"}:
        refusals.append(
            RefusalReason(
                field="route",
                message="Select PO or IV administration; routes are not interchangeable.",
            )
        )
    if type(chemo_duration_days) is not int or chemo_duration_days < 1:
        refusals.append(
            RefusalReason(
                field="chemo_duration_days",
                message="Provide a positive whole number of chemotherapy days.",
            )
        )
    if fosaprepitant_schedule not in {"multi_day", "single_dose"}:
        refusals.append(
            RefusalReason(
                field="fosaprepitant_schedule",
                message="Select multi_day or single_dose.",
            )
        )
    if fosaprepitant_schedule == "single_dose" and (
        aprepitant_route != "IV" or chemo_duration_days != 1
    ):
        refusals.append(
            RefusalReason(
                field="fosaprepitant_schedule",
                message="Single-dose fosaprepitant requires IV administration and one-day chemotherapy.",
            )
        )
    if use_palonosetron_switch and tier != EmetogenicTier.HIGH:
        refusals.append(
            RefusalReason(
                field="use_palonosetron_switch",
                message="UZA's palonosetron switch is for insufficient control of HEC, in consultation with supervision/pharmacy.",
            )
        )
    if (
        aprepitant_route == "IV"
        and fosaprepitant_schedule == "single_dose"
        and patient_age_years == 0.5
    ):
        refusals.append(
            RefusalReason(
                field="fosaprepitant_schedule",
                message="The single-dose IV rule says >6 months; exactly 6 months needs pharmacy confirmation or the multi-day schedule.",
            )
        )
    if refusals:
        return DosingScheduleResult(refused=True, refusal_reasons=refusals)

    assert (
        patient_age_years is not None
        and patient_weight_kg is not None
        and bsa_m2 is not None
    )
    age, weight, bsa = patient_age_years, patient_weight_kg, bsa_m2
    dex_eval = evaluate_dexamethasone_contraindication(
        indication, regimen_drugs or [], concomitant_meds or []
    )
    lines: dict[str, DoseLine] = {}

    def line(
        key: str,
        name: str,
        indicated: bool,
        calculations: list[dict],
        frequency: str,
        duration: str,
        route: str,
        citation: str,
        reason: str = "Not routinely indicated for this plan.",
        warnings: list[str] | None = None,
        purpose: str = "prophylaxis",
    ):
        calculations = calculations if indicated else []
        formula = (
            " | ".join(c["formula"] for c in calculations) if calculations else reason
        )
        amounts = "; ".join(
            f"{c['label']}: {c['final_dose']:g} {c['unit']}" for c in calculations
        )
        if indicated and purpose in {"prophylaxis", "alternative"}:
            warnings = [
                *(warnings or []),
                f"Start {30 if route == 'IV' else 60} minutes before first chemotherapy (UZA v2 p.2).",
            ]
        lines[key] = DoseLine(
            drug=name,
            indicated=indicated,
            dose_text=f"{name} — {amounts}; {frequency}" if indicated else reason,
            frequency=frequency if indicated else "Not applicable",
            duration=duration if indicated else "Not applicable",
            route=route,
            formula_shown=formula,
            citation=citation,
            warnings=warnings or [],
            calculations=calculations,
            purpose=purpose,
        )

    ond_indicated = (
        tier != EmetogenicTier.MINIMAL or prior_breakthrough_cinv
    ) and not use_palonosetron_switch
    frequencies = {
        EmetogenicTier.HIGH: 3,
        EmetogenicTier.MODERATE: 2,
        EmetogenicTier.LOW: 1,
        EmetogenicTier.MINIMAL: 0,
    }
    times = min(
        3,
        frequencies[tier]
        + (1 if prior_breakthrough_cinv and tier != EmetogenicTier.HIGH else 0),
    )
    line(
        "ondansetron",
        "Ondansetron",
        ond_indicated,
        [_calculation("Each dose", bsa, "m²", "5", 8)],
        f"{times}x/d",
        "Chemotherapy days and through 3 days after the last chemotherapy"
        if tier in {EmetogenicTier.HIGH, EmetogenicTier.MODERATE}
        else "Chemotherapy days only",
        antiemetic_route,
        "UZA v2 p.2 · Ondansetron IV/PO 5 mg/m², max 8 mg/dose, max 3x/d",
        reason="Replaced by palonosetron; do not combine within 3 days."
        if use_palonosetron_switch
        else "Minimal risk: no routine prophylaxis.",
        warnings=["At discharge: 2x/d PO and referral to hospital pharmacy."]
        if tier in {EmetogenicTier.HIGH, EmetogenicTier.MODERATE}
        else [],
    )

    palo = (
        _calculation("Day 1", weight, "kg", "20", 1500, "micrograms")
        if age < 17
        else _fixed("Day 1", 250, "Age ≥17 years: fixed 250 micrograms IV on day 1.")
    )
    if age >= 17:
        palo["unit"] = "micrograms"
    line(
        "palonosetron",
        "Palonosetron",
        use_palonosetron_switch,
        [palo],
        "Once on day 1; repeat on day 4 only if needed" if age >= 17 else "Single dose",
        "Long-acting alternative",
        "IV",
        "UZA v2 p.2 · Palonosetron: <17y 20 micrograms/kg, max 1500; ≥17y 250 micrograms",
        warnings=[
            "Requires supervision/pharmacy consultation.",
            "Do not combine with ondansetron for 3 days after administration.",
        ],
        purpose="alternative",
    )

    eligible = age >= 0.5 and weight > 6
    nk1_needed = tier == EmetogenicTier.HIGH or (
        tier == EmetogenicTier.MODERATE
        and (dex_eval.contraindicated or mec_prefer_aprepitant)
    )
    nk1 = eligible and nk1_needed
    nk1_calcs = []
    if aprepitant_route == "IV" and fosaprepitant_schedule == "single_dose":
        if age >= 12:
            nk1_calcs = [
                _fixed(
                    "Day 1",
                    150,
                    "Age ≥12 years: 150 mg IV once for one-day chemotherapy.",
                )
            ]
        else:
            nk1_calcs = [
                _calculation("Day 1", weight, "kg", "5" if age < 2 else "4", 150)
            ]
    elif aprepitant_route == "PO" and age >= 12:
        # Swallowing ability changes formulation, not the adolescent fixed-dose rule.
        nk1_calcs = [
            _fixed("Day 1", 125, "Age ≥12 years: 125 mg PO on day 1."),
            _fixed("Days 2–3", 80, "Age ≥12 years: 80 mg PO on days 2 and 3."),
        ]
    else:
        nk1_calcs = [
            _calculation(
                "Day 1", weight, "kg", "3", 115 if aprepitant_route == "IV" else 125
            ),
            _calculation("Days 2–3", weight, "kg", "2", 80),
        ]
    single = aprepitant_route == "IV" and fosaprepitant_schedule == "single_dose"
    nk1_warnings = (
        [
            "Check CYP3A4/2C9 interactions; dexamethasone's aprepitant adjustment is already included below."
        ]
        if nk1
        else []
    )
    if nk1 and chemo_duration_days >= 5 and prior_breakthrough_cinv:
        nk1_warnings.append(
            "Prior day-4 breakthrough in a five-day course: discuss days 4–5 extension with pharmacy; this calculation does not prescribe that extension."
        )
    if nk1 and aprepitant_route == "PO" and not can_swallow_tablets:
        nk1_warnings.append(
            "Use an appropriate oral suspension/formulation; do not substitute an IV dose without recalculating."
        )
    line(
        "aprepitant",
        "Fosaprepitant" if aprepitant_route == "IV" else "Aprepitant",
        nk1,
        nk1_calcs,
        "Once on day 1" if single else "1x/d on days 1–3",
        "Day 1 only" if single else "Days 1–3",
        aprepitant_route,
        "UZA v2 p.2 · (Fos)aprepitant: eligibility ≥6 months and >6 kg; PO <12y 3/2 mg/kg (125/80 mg caps), ≥12y 125/80 mg; IV multi-day 3/2 mg/kg (115/80 mg caps); single IV 5 mg/kg <2y, 4 mg/kg 2–<12y, 150 mg ≥12y",
        reason="No indication: age <6 months or weight ≤6 kg."
        if not eligible
        else "Not selected for this risk tier/MEC strategy.",
        warnings=nk1_warnings,
    )

    dex = (
        not dex_eval.contraindicated
        and tier in {EmetogenicTier.HIGH, EmetogenicTier.MODERATE}
        and not (tier == EmetogenicTier.MODERATE and mec_prefer_aprepitant)
    )
    standard = 2.0 if bsa < 0.6 else 4.0
    dose = standard / 2 if nk1 else standard
    dex_formula = f"BSA {bsa} m² is {'<0.6' if bsa < 0.6 else '≥0.6'} m²: {standard:g} mg per dose without (fos)aprepitant"
    dex_formula += (
        f" × 0.5 with (fos)aprepitant → {dose:g} mg per dose (adjustment applied once)."
        if nk1
        else f" → {dose:g} mg per dose."
    )
    dex_calc = _fixed("Each dose", dose, dex_formula)
    dex_calc.update(
        {
            "raw_dose": standard,
            "input_value": bsa,
            "input_unit": "m²",
            "bsa_band": "<0.6" if bsa < 0.6 else "≥0.6",
            "standard_dose_mg": standard,
            "aprepitant_adjustment_factor": 0.5 if nk1 else 1.0,
        }
    )
    dex_warnings = list(dex_eval.reasons)
    if antiemetic_route == "IV" and dex:
        volume = dose / 4
        dex_calc.update({"volume_ml": volume, "concentration_mg_ml": 4.0})
        dex_calc["formula"] += (
            f" Aacidexam: {dose:g} mg ÷ approximately 4 mg/mL active base = {volume:g} mL."
        )
        dex_warnings.append(
            "Aacidexam labelled 5 mg/mL contains approximately 4 mg/mL active dexamethasone; verify the product concentration with pharmacy."
        )
    line(
        "dexamethasone",
        "Dexamethasone",
        dex,
        [dex_calc],
        "2x/d",
        "Chemotherapy days only",
        antiemetic_route,
        "UZA v2 p.2 · Dexamethasone BSA <0.6 m²: 1 mg with / 2 mg without aprepitant; ≥0.6 m²: 2 mg with / 4 mg without; twice daily",
        reason="GEEN Dexamethasone: " + "; ".join(dex_eval.reasons)
        if dex_eval.contraindicated
        else "Not selected for this risk tier/MEC strategy.",
        warnings=dex_warnings,
    )

    olanz = age >= 2 and (
        tier == EmetogenicTier.HIGH
        or (tier == EmetogenicTier.MODERATE and prior_breakthrough_cinv)
    )
    line(
        "olanzapine",
        "Olanzapine",
        olanz,
        [_calculation("Each dose", weight, "kg", "0.1", 5, floor_half=True)],
        "1x/d (preferably in the evening after the first dose)",
        "Chemotherapy days and through 3 days after the last chemotherapy",
        "PO",
        "UZA v2 p.2 · Olanzapine ≥2 years: 0.1 mg/kg, max 5 mg, round DOWN to nearest 0.5 mg",
        reason="No indication below age 2 or outside the selected HEC/breakthrough strategy.",
        warnings=["Never use as monotherapy for CINV."] if olanz else [],
    )

    low, high = ("0.04", "0.08") if anticipatory_vomiting else ("0.025", "0.05")
    loraz = [
        _calculation("Lower end of range", weight, "kg", low, 2),
        _calculation("Upper end of range", weight, "kg", high, 2),
    ]
    line(
        "lorazepam",
        "Lorazepam",
        prior_breakthrough_cinv or anticipatory_vomiting,
        loraz,
        "Evening before and morning of first chemotherapy"
        if anticipatory_vomiting
        else "Every 6 hours if needed",
        "Anticipatory symptoms"
        if anticipatory_vomiting
        else "Breakthrough symptoms only",
        antiemetic_route,
        "UZA v2 p.2 · Lorazepam: breakthrough 0.025–0.05 mg/kg q6h PRN OR anticipatory 0.04–0.08 mg/kg; max 2 mg/dose",
        warnings=[
            "Dose range/option requires clinician selection.",
            "IV form is not reimbursed according to the supplied policy.",
        ],
        purpose="anticipatory option" if anticipatory_vomiting else "rescue option",
    )
    line(
        "alizapride",
        "Alizapride",
        prior_breakthrough_cinv,
        [_calculation("Each dose", weight, "kg", "1", 50)],
        "Up to 6x/d if needed",
        "Chemotherapy days only",
        antiemetic_route,
        "UZA v2 p.2 · Alizapride IV/PO 1 mg/kg, max 50 mg/dose, max 6x/d on chemotherapy days",
        warnings=[
            "Alternative rescue option; clinician selects the appropriate agent."
        ],
        purpose="rescue option",
    )

    return DosingScheduleResult(
        refused=False,
        dexamethasone_evaluation=dex_eval,
        lines=lines,
        inputs_used={
            "patient_age_years": age,
            "patient_weight_kg": weight,
            "bsa_m2": bsa,
            "tier": tier.value,
            "antiemetic_route": antiemetic_route,
            "aprepitant_route": aprepitant_route,
            "fosaprepitant_schedule": fosaprepitant_schedule,
        },
        advisory_status=ADVISORY_LABEL,
    )
