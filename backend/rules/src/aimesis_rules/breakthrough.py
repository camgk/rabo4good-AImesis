"""Story 3: Personalization, Formulation Override & Breakthrough CINV Step-Up Rules.

Implements UZA v2 page 2:
- DOORBRAAK NAUSEA & BRAKEN:
  * Verhoog frequentie ondansetron naar 3x/d voor matig emetogeen – 2x/dag voor laag emetogeen – 1x/d voor minimaal emetogeen
  * Onvoldoende respons: overweeg opstart olanzapine (>2j)
  * Onvoldoende respons: associatie alizapride of lorazepam
  * Volgende chemotherapie cyclus: start met hoger profylaxe niveau
  * Switch ondansetron -> palonosetron bij onvoldoende controle van hoog emetogene kuren
- ANTICIPATOIR NAUSEA & BRAKEN:
  * Niet-farmacologische maatregelen (o.a. relaxatie) + Associatie lorazepam
"""

from __future__ import annotations

from typing import Dict, List

from .models import EmetogenicTier, UZA_POLICY_CITATION


def evaluate_breakthrough_and_personalization(
    baseline_tier: EmetogenicTier,
    patient_age_years: float,
    patient_weight_kg: float,
    can_swallow_tablets: bool = True,
    prior_breakthrough_cinv: bool = False,
    prior_ondansetron_2xd_on_hec: bool = False,
    chemo_duration_days: int = 1,
    anticipatory_vomiting: bool = False,
) -> Dict[str, object]:
    """Deterministically computes Story 3 personalization overrides and breakthrough steps."""
    effective_tier = baseline_tier
    overrides: List[str] = []
    breakthrough_steps: List[Dict[str, str]] = []

    if not can_swallow_tablets:
        overrides.append(
            "Swallowing override: Switched oral tablets to oral suspension / syrup / smelttablet or IV formulations "
            "[UZA v2 p.2 · Story 3]."
        )

    if prior_ondansetron_2xd_on_hec and baseline_tier == EmetogenicTier.HIGH:
        overrides.append(
            "Casus 1 / HEC Optimalisatie: Verhoog Ondansetron van 2x/d naar volledige HEC 3x/d dosering "
            "(5 mg/m², max 8 mg 3x/d) OF switch naar IV Palonosetron (niet combineren met Ondansetron binnen 3 dagen) "
            "[UZA v2 p.2 · Doorbraak & 5HT3-antagonist]."
        )

    if prior_breakthrough_cinv:
        # Step up tier for next cycle if below High
        if baseline_tier == EmetogenicTier.MINIMAL:
            effective_tier = EmetogenicTier.LOW
        elif baseline_tier == EmetogenicTier.LOW:
            effective_tier = EmetogenicTier.MODERATE
        elif baseline_tier == EmetogenicTier.MODERATE:
            effective_tier = EmetogenicTier.HIGH

        loraz_low = min(round(0.025 * patient_weight_kg, 2), 2.0)
        loraz_high = min(round(0.05 * patient_weight_kg, 2), 2.0)
        aliz_mg = min(round(1.0 * patient_weight_kg, 1), 50.0)

        overrides.append(
            f"Prior CINV breakthrough escalation: Start met hoger profylaxe-niveau ({baseline_tier.value} → {effective_tier.value}); "
            f"overweeg switch Ondansetron → Palonosetron IV bij HEC, of associatie Lorazepam {loraz_low}–{loraz_high} mg q6h / "
            f"Alizapride {aliz_mg} mg [UZA v2 p.2 · Doorbraak nausea & braken]."
        )

        breakthrough_steps.extend(
            [
                {
                    "step": "Stap 1: Verhoog frequentie Ondansetron",
                    "action": "3x/d voor matig emetogeen · 2x/d voor laag emetogeen · 1x/d voor minimaal emetogeen (of switch naar IV Palonosetron bij HEC)",
                    "citation": f"{UZA_POLICY_CITATION} p.2 · Doorbraak nausea & braken",
                },
                {
                    "step": "Stap 2: Opstart Olanzapine (indien ≥2 jaar)",
                    "action": (
                        "Start Olanzapine 0,1 mg/kg PO 1x/d (naar beneden afgerond op 0,5 mg, max 5 mg)"
                        if patient_age_years >= 2.0
                        else "Niet geïndiceerd (<2 jaar)"
                    ),
                    "citation": f"{UZA_POLICY_CITATION} p.2 · Doorbraak nausea & braken",
                },
                {
                    "step": "Stap 3: Associatie Alizapride of Lorazepam",
                    "action": f"Alizapride {aliz_mg} mg IV/PO (1 mg/kg, max 6x/d op chemodagen) OF Lorazepam {loraz_low}–{loraz_high} mg IV/PO q6h PRN",
                    "citation": f"{UZA_POLICY_CITATION} p.2 · Doorbraak nausea & braken",
                },
            ]
        )

    if chemo_duration_days >= 5 and baseline_tier == EmetogenicTier.HIGH and prior_breakthrough_cinv:
        overrides.append(
            "Multi-day 5-daagse kuur (Casus 3 / iEuroEwing IE): Overweeg verlenging van Aprepitant naar Dag 4 en Dag 5 "
            "in overleg met de ziekenhuisapotheker wegens eerdere Dag 4 doorbraak nausea [UZA v2 p.2]."
        )

    if anticipatory_vomiting:
        loraz_ant_low = min(round(0.04 * patient_weight_kg, 2), 2.0)
        loraz_ant_high = min(round(0.08 * patient_weight_kg, 2), 2.0)
        overrides.append(
            f"Anticipatory CINV protocol: Niet-farmacologische maatregelen (relaxatie/afleiding) + "
            f"Lorazepam {loraz_ant_low}–{loraz_ant_high} mg (0,04–0,08 mg/kg, max 2 mg) de avond vóór én ochtend van eerste chemotherapie "
            "[UZA v2 p.2 · Anticipatoir nausea & braken]."
        )

    return {
        "baseline_tier": baseline_tier.value,
        "effective_tier": effective_tier.value,
        "tier_escalated_for_prior_cinv": effective_tier != baseline_tier,
        "personalization_overrides": overrides,
        "breakthrough_steps": breakthrough_steps,
        "citation": f"{UZA_POLICY_CITATION} p.2 · Doorbraak & Anticipatoir CINV",
    }
