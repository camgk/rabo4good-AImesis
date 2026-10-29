"""Story 2: Deterministic BSA, Weight, and Age Antiemetic Dosing Engine.

Implements every formula, age/weight gate, cap, rounding rule, and IV conversion
from `Anti-emetica beleid CINV - V2.pdf` page 2:
- ONDANSETRON: IV/PO 5 mg/m² (max. 8 mg/dosis) max. 3x/d (HEC 3x/d, MEC 2x/d, LEC 1x/d).
- PALONOSETRON: IV <17j 20 mcg/kg (max. 1500 mcg/dosis) eenmalig; >=17j 250 mcg/dosis eenmalig op D1.
- DEXAMETHASONE:
  * <0.6 m²: 1 mg 2x/d (i.c.m. (fos)aprepitant) OF 2 mg 2x/d (zonder (fos)aprepitant)
  * >=0.6 m²: 2 mg 2x/d (i.c.m. (fos)aprepitant) OF 4 mg 2x/d (zonder (fos)aprepitant)
  * IV Aacidexam® 5 mg/ml bevat ± 4 mg/ml actieve stof -> dosis omrekenen.
- (FOS)APREPITANT:
  * <6m of <=6kg: geen indicatie
  * PO <12j: 3 mg/kg (max. 125 mg) op D1 gevolgd door 2 mg/kg (max. 80 mg) op D2 en D3
  * PO >=12j: 125 mg op D1 gevolgd door 80 mg op D2 en D3
  * IV 3-daags: 3 mg/kg (max. 115 mg) op D1 gevolgd door 2 mg/kg (max. 80 mg) op D2 en D3
- OLANZAPINE:
  * <2j: geen indicatie
  * >=2j: 0.1 mg/kg (max. 5 mg/dosis) 1x/d, naar beneden afronden tot dichtstbijzijnde 0.5 mg.
- LORAZEPAM:
  * Doorbraak: 0.025-0.05 mg/kg (max. 2 mg/dosis) elke 6u indien nodig
  * Anticipatoir: 0.04-0.08 mg/kg (max. 2 mg/dosis) avond voor en ochtend van eerste chemo
- ALIZAPRIDE:
  * IV/PO: 1 mg/kg (max. 50 mg/dosis) max. 6x/d enkel op dagen van chemotherapie
"""

from __future__ import annotations

import math
from typing import Dict, List, Optional

from .dexamethasone import evaluate_dexamethasone_contraindication
from .models import (
    ADVISORY_LABEL,
    DexamethasoneEvaluation,
    DoseLine,
    DosingScheduleResult,
    EmetogenicTier,
    RefusalReason,
)


def round_down_to_half_mg(value_mg: float) -> float:
    """Rounds a milligram dose DOWN to the nearest 0.5 mg per UZA v2 Olanzapine rule."""
    return math.floor((value_mg + 1e-9) * 2.0) / 2.0


def calculate_uza_dosing(
    tier: EmetogenicTier,
    patient_age_years: Optional[float],
    patient_weight_kg: Optional[float],
    bsa_m2: Optional[float],
    indication: str = "solid_tumor",
    regimen_drugs: Optional[List[str]] = None,
    concomitant_meds: Optional[List[str]] = None,
    can_swallow_tablets: bool = True,
    chemo_duration_days: int = 1,
    prior_breakthrough_cinv: bool = False,
    anticipatory_vomiting: bool = False,
    use_palonosetron_switch: bool = False,
    mec_prefer_aprepitant: bool = False,
) -> DosingScheduleResult:
    """Computes exact deterministic doses and citations per UZA v2 p.2."""
    refusals: List[RefusalReason] = []
    if patient_age_years is None or patient_age_years < 0:
        refusals.append(
            RefusalReason(
                field="patient_age_years",
                message="Patient age is missing or invalid. Refusing to calculate antiemetic doses.",
            )
        )
    if patient_weight_kg is None or patient_weight_kg <= 0:
        refusals.append(
            RefusalReason(
                field="patient_weight_kg",
                message="Patient weight (kg) is missing or invalid. Refusing to calculate antiemetic doses.",
            )
        )
    if bsa_m2 is None or bsa_m2 <= 0:
        refusals.append(
            RefusalReason(
                field="bsa_m2",
                message="Patient BSA (m²) is missing or invalid. Refusing to calculate antiemetic doses.",
            )
        )

    if refusals:
        return DosingScheduleResult(refused=True, refusal_reasons=refusals)

    assert patient_age_years is not None
    assert patient_weight_kg is not None
    assert bsa_m2 is not None

    dex_eval: DexamethasoneEvaluation = evaluate_dexamethasone_contraindication(
        indication=indication,
        regimen_drugs=regimen_drugs or [],
        concomitant_meds=concomitant_meds or [],
    )

    oral_route = "PO (siroop / suspensie / smelttablet)" if not can_swallow_tablets else "PO / IV"
    lines: Dict[str, DoseLine] = {}

    # 1. ONDANSETRON (5HT3-antagonist)
    raw_ond = round(5.0 * bsa_m2, 2)
    ond_dose = min(raw_ond, 8.0)
    if tier == EmetogenicTier.HIGH:
        ond_freq = "3x/d (q8h)"
        ond_dur = "Chemodagen + t.e.m. 3 dagen na laatste chemotherapie (bij ontslag: 2x/d PO)"
    elif tier == EmetogenicTier.MODERATE:
        ond_freq = "3x/d (q8h, doorbraak step-up)" if prior_breakthrough_cinv else "2x/d (q12h)"
        ond_dur = "Chemodagen + t.e.m. 3 dagen na laatste chemotherapie"
    elif tier == EmetogenicTier.LOW:
        ond_freq = "2x/d (q12h, doorbraak step-up)" if prior_breakthrough_cinv else "1x/d"
        ond_dur = "Enkel op dagen van chemotherapie"
    else:
        ond_freq = "Geen standaard profylaxe"
        ond_dur = "N.v.t."

    lines["ondansetron"] = DoseLine(
        drug="Ondansetron",
        indicated=(tier != EmetogenicTier.MINIMAL and not use_palonosetron_switch),
        dose_text=(
            f"Ondansetron {ond_dose} mg ({oral_route}) {ond_freq} "
            f"(5 mg/m² × {bsa_m2} m² = {raw_ond} mg, max 8 mg/dosis)"
            if tier != EmetogenicTier.MINIMAL
            else "Geen standaard profylaxe (Minimaal emetogeen)"
        ),
        frequency=ond_freq,
        duration=ond_dur,
        route=oral_route,
        formula_shown=f"5 mg/m² × {bsa_m2} m² = {raw_ond} mg (capped at max 8 mg/dose)",
        citation="UZA v2 p.2 · Ondansetron IV/PO: 5 mg/m² (max. 8 mg/dosis) max. 3x/d",
        warnings=(
            ["Niet combineren met Palonosetron (tot 3 dagen na toediening palonosetron)."]
            if use_palonosetron_switch
            else []
        ),
    )

    # Optional Palonosetron calculation (for refractory HEC / Casus 1 option)
    if patient_age_years < 17.0:
        raw_palo_mcg = round(20.0 * patient_weight_kg, 0)
        palo_mcg = min(raw_palo_mcg, 1500.0)
        palo_formula = f"20 mcg/kg × {patient_weight_kg} kg = {raw_palo_mcg:.0f} mcg (max 1500 mcg)"
        palo_text = f"Palonosetron {palo_mcg:.0f} mcg IV eenmalig op D1 ({palo_formula})"
    else:
        palo_formula = ">=17j: 250 mcg/dosis eenmalig op D1 (indien nodig herhalen op D4)"
        palo_text = "Palonosetron 250 mcg IV eenmalig op D1 (indien nodig herhalen op D4)"

    lines["palonosetron"] = DoseLine(
        drug="Palonosetron",
        indicated=use_palonosetron_switch,
        dose_text=palo_text,
        frequency="Eenmalig op D1 (evt. herhalen op D4)",
        duration="Langwerkende vorm (dekt t.e.m. 3 dagen)",
        route="IV",
        formula_shown=palo_formula,
        citation="UZA v2 p.2 · Palonosetron IV (enkel in overleg met supervisie/apotheek; niet samen met ondansetron tot 3d)",
        warnings=[
            "Enkel in overleg met supervisie/apotheek.",
            "Niet samen met ondansetron (tot 3 dagen na toediening palonosetron).",
        ],
    )

    # 2. (FOS)APREPITANT (NK1-antagonist)
    # Indicated in High tier, OR in Moderate tier when Dexamethasone is contraindicated (Casus 2!) or preferred
    aprepitant_eligible_age_wt = patient_age_years >= 0.5 and patient_weight_kg > 6.0
    aprepitant_needed_by_tier = (
        tier == EmetogenicTier.HIGH
        or (tier == EmetogenicTier.MODERATE and (dex_eval.contraindicated or mec_prefer_aprepitant))
    )
    aprepitant_indicated = aprepitant_eligible_age_wt and aprepitant_needed_by_tier

    extend_aprepitant_d4_d5 = (
        aprepitant_indicated and chemo_duration_days >= 5 and prior_breakthrough_cinv
    )
    aprep_days_label = (
        "D1 t.e.m. D3 (overweeg verlenging naar D4 en D5 bij 5-daagse kuur + eerdere D4 doorbraak CINV i.o.m. apotheek)"
        if extend_aprepitant_d4_d5
        else "D1 t.e.m. D3"
    )

    if not aprepitant_eligible_age_wt:
        aprep_text = "Geen indicatie (<6 maanden of ≤6 kg — UZA v2 p.2)"
        aprep_formula = "<6m of ≤6kg: geen indicatie"
    elif not aprepitant_needed_by_tier:
        aprep_text = "Niet standaard geïndiceerd (enkel bij Hoog emetogeen of Matig emetogeen zonder Dexamethasone)"
        aprep_formula = "N.v.t."
    else:
        if patient_age_years >= 12.0 and can_swallow_tablets:
            aprep_formula = "≥12j PO: 125 mg op D1 gevolgd door 80 mg op D2 en D3"
            aprep_text = f"Aprepitant PO: D1 = 125 mg 1x/d; D2–D3 = 80 mg 1x/d ({aprep_days_label})"
        else:
            d1_raw = round(3.0 * patient_weight_kg, 1)
            d2_raw = round(2.0 * patient_weight_kg, 1)
            d1_cap = 125.0 if can_swallow_tablets else 125.0
            d1_mg = min(d1_raw, d1_cap)
            d2_mg = min(d2_raw, 80.0)
            aprep_route_label = "PO suspensie / IV" if not can_swallow_tablets else "PO"
            aprep_formula = (
                f"<12j: D1 = 3 mg/kg × {patient_weight_kg} kg = {d1_raw} mg (max 125 mg PO / 115 mg IV); "
                f"D2–D3 = 2 mg/kg × {patient_weight_kg} kg = {d2_raw} mg (max 80 mg)"
            )
            aprep_text = (
                f"(Fos)Aprepitant ({aprep_route_label}): Day 1 = {d1_mg} mg (3 mg/kg, max 125 mg); "
                f"Days 2–3 = {d2_mg} mg (2 mg/kg, max 80 mg) [{aprep_days_label}]"
            )

    lines["aprepitant"] = DoseLine(
        drug="(Fos)Aprepitant",
        indicated=aprepitant_indicated,
        dose_text=aprep_text,
        frequency="1x/d op D1–D3" + (" (evt. D4–D5 i.o.m. apotheek)" if extend_aprepitant_d4_d5 else ""),
        duration=aprep_days_label if aprepitant_indicated else "N.v.t.",
        route="PO (voorkeur) / IV",
        formula_shown=aprep_formula,
        citation="UZA v2 p.2 · (Fos)Aprepitant: <6m of ≤6kg geen indicatie; <12j 3 mg/kg D1, 2 mg/kg D2-D3; ≥12j 125 mg D1, 80 mg D2-D3",
        warnings=(
            ["Opgelet voor interacties (CYP3A4/2C9): halveert klaring van Dexamethasone (50% dosisreductie vereist)."]
            if aprepitant_indicated
            else []
        ),
    )

    # 3. DEXAMETHASONE (Corticoïden)
    if dex_eval.contraindicated:
        dex_indicated = False
        dex_text = (
            "CONTRAINDICATED ('GEEN DEXAMETHASONE' — UZA July 2026 v2 Policy): "
            + "; ".join(dex_eval.reasons)
        )
        dex_formula = "GEEN Dexamethasone (harde contra-indicatie UZA v2 p.2)"
        dex_warnings = dex_eval.reasons
    elif tier in {EmetogenicTier.HIGH, EmetogenicTier.MODERATE} and not (
        tier == EmetogenicTier.MODERATE and mec_prefer_aprepitant
    ):
        dex_indicated = True
        if bsa_m2 < 0.6:
            dex_mg = 1.0 if aprepitant_indicated else 2.0
            bsa_band = "<0,6 m²"
        else:
            dex_mg = 2.0 if aprepitant_indicated else 4.0
            bsa_band = "≥0,6 m²"
        aacidexam_ml = round(dex_mg / 4.0, 2)
        cyp_note = (
            "i.c.m. (fos)aprepitant (50% CYP3A4 reductie)"
            if aprepitant_indicated
            else "zonder (fos)aprepitant"
        )
        dex_formula = f"BSA {bsa_m2} m² ({bsa_band}) {cyp_note} → {dex_mg} mg 2x/d"
        dex_text = (
            f"Dexamethasone {dex_mg} mg IV/PO 2x/d ({dex_formula}) — "
            f"UZA Aacidexam® IV Alert: 5 mg/mL ampul bevat ±4 mg/mL actieve stof (= {aacidexam_ml} mL IV per dosis)."
        )
        dex_warnings = [
            f"IV Aacidexam® 5 mg/mL bevat ±4 mg/mL actieve dexamethasone base → reken {aacidexam_ml} mL per dosis van {dex_mg} mg."
        ]
    else:
        dex_indicated = False
        dex_text = "Niet geïndiceerd voor Laag/Minimaal emetogeen (of Aprepitant gekozen bij Matig emetogeen)"
        dex_formula = "N.v.t."
        dex_warnings = []

    lines["dexamethasone"] = DoseLine(
        drug="Dexamethasone",
        indicated=dex_indicated,
        dose_text=dex_text,
        frequency="2x/d (enkel op dagen van chemotherapie)" if dex_indicated else "N.v.t.",
        duration="Enkel op dagen van chemotherapie" if dex_indicated else "N.v.t.",
        route="IV / PO",
        formula_shown=dex_formula,
        citation="UZA v2 p.2 · Dexamethasone: <0,6m² 1mg (met aprepitant) / 2mg (zonder) 2x/d; ≥0,6m² 2mg (met) / 4mg (zonder) 2x/d; IV Aacidexam® 5 mg/ml = ±4 mg/ml",
        warnings=dex_warnings,
    )

    # 4. OLANZAPINE (Antipsychotica)
    # Indicated in High tier (if >=2y) OR as breakthrough step-up in Moderate tier (if >=2y)
    olanz_needed = tier == EmetogenicTier.HIGH or (
        tier == EmetogenicTier.MODERATE and prior_breakthrough_cinv
    )
    if patient_age_years < 2.0:
        olanz_indicated = False
        olanz_formula = "<2j: geen indicatie"
        olanz_text = "Niet geïndiceerd (<2 jaar — UZA v2 p.2)"
    elif not olanz_needed:
        olanz_indicated = False
        olanz_formula = "Enkel bij Hoog emetogeen of bij onvoldoende respons (doorbraak CINV)"
        olanz_text = "Niet standaard geïndiceerd (enkel bij Hoog emetogeen of doorbraak CINV, ≥2j)"
    else:
        olanz_indicated = True
        raw_olanz = min(round(0.1 * patient_weight_kg, 2), 5.0)
        floored_olanz = round_down_to_half_mg(raw_olanz)
        olanz_formula = (
            f"0.1 mg/kg × {patient_weight_kg} kg = {raw_olanz:.2f} mg → "
            f"naar beneden afgerond tot dichtstbijzijnde 0,5 mg = {floored_olanz:.1f} mg (max 5 mg/dosis)"
        )
        olanz_text = (
            f"Olanzapine {floored_olanz:.1f} mg PO 1x/d "
            f"(0.1 mg/kg = {raw_olanz:.2f} mg, rounded DOWN to nearest 0.5 mg per UZA v2; max 5 mg). "
            "1e dosis vlak voor chemotherapie, nadien bij voorkeur 's avonds."
        )

    lines["olanzapine"] = DoseLine(
        drug="Olanzapine",
        indicated=olanz_indicated,
        dose_text=olanz_text,
        frequency="1x/d ('s avonds)" if olanz_indicated else "N.v.t.",
        duration="Chemodagen + t.e.m. 3 dagen na laatste chemotherapie" if olanz_indicated else "N.v.t.",
        route="PO",
        formula_shown=olanz_formula,
        citation="UZA v2 p.2 · Olanzapine PO: <2j geen indicatie; ≥2j 0,1 mg/kg (max. 5 mg/dosis) 1x/d, naar beneden afronden tot dichtstbijzijnde 0,5mg. Nooit in monotherapie.",
        warnings=["Nooit in monotherapie voor CINV-indicatie."] if olanz_indicated else [],
    )

    # 5. LORAZEPAM (Benzodiazepine — Doorbraak & Anticipatoir)
    loraz_bt_low = min(round(0.025 * patient_weight_kg, 2), 2.0)
    loraz_bt_high = min(round(0.05 * patient_weight_kg, 2), 2.0)
    loraz_ant_low = min(round(0.04 * patient_weight_kg, 2), 2.0)
    loraz_ant_high = min(round(0.08 * patient_weight_kg, 2), 2.0)
    loraz_indicated = prior_breakthrough_cinv or anticipatory_vomiting

    if anticipatory_vomiting:
        loraz_text = (
            f"Lorazepam {loraz_ant_low}–{loraz_ant_high} mg IV/PO (0,04–0,08 mg/kg, max 2 mg) "
            "avond voor én ochtend van eerste chemotherapie + niet-farmacologische relaxatie"
        )
        loraz_formula = f"0,04–0,08 mg/kg × {patient_weight_kg} kg = {loraz_ant_low}–{loraz_ant_high} mg (max 2 mg/dosis)"
    else:
        loraz_text = (
            f"Lorazepam {loraz_bt_low}–{loraz_bt_high} mg IV/PO (0,025–0,05 mg/kg, max 2 mg) "
            "elke 6u indien nodig bij doorbraak CINV"
        )
        loraz_formula = f"0,025–0,05 mg/kg × {patient_weight_kg} kg = {loraz_bt_low}–{loraz_bt_high} mg (max 2 mg/dosis)"

    lines["lorazepam"] = DoseLine(
        drug="Lorazepam",
        indicated=loraz_indicated,
        dose_text=loraz_text,
        frequency="Avond voor + ochtend van chemo (anticipatoir) of q6h PRN (doorbraak)",
        duration="Indien nodig bij doorbraak of anticipatoir CINV",
        route="PO / IV",
        formula_shown=loraz_formula,
        citation="UZA v2 p.2 · Lorazepam IV/PO: 0,025-0,05 mg/kg (max 2 mg) q6h bij doorbraak OF 0,04-0,08 mg/kg bij anticipatoir CINV (IV-vorm niet terugbetaald)",
        warnings=["IV-vorm niet terugbetaald in België."],
    )

    # 6. ALIZAPRIDE (Dopamine-antagonist — Doorbraak)
    aliz_mg = min(round(1.0 * patient_weight_kg, 1), 50.0)
    lines["alizapride"] = DoseLine(
        drug="Alizapride",
        indicated=prior_breakthrough_cinv,
        dose_text=f"Alizapride {aliz_mg} mg IV/PO (1 mg/kg, max 50 mg/dosis) max. 6x/d enkel op dagen van chemotherapie",
        frequency="Max. 6x/d PRN bij doorbraak CINV",
        duration="Enkel op dagen van chemotherapie",
        route="IV / PO",
        formula_shown=f"1 mg/kg × {patient_weight_kg} kg = {aliz_mg} mg (max 50 mg/dosis)",
        citation="UZA v2 p.2 · Alizapride IV of per os: 1 mg/kg (max. 50mg/dosis) max. 6x/d, enkel op dagen van chemotherapie",
    )

    return DosingScheduleResult(
        refused=False,
        dexamethasone_evaluation=dex_eval,
        lines=lines,
        advisory_status=ADVISORY_LABEL,
    )
