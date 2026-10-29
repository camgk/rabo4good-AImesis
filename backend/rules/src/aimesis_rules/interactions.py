"""Story 6: Deterministic Drug-Drug Interaction (CYP3A4/2C9) & Cumulative QTc Screening.

Implements deterministic screening grounded in:
- UZA v2 p.2 (Aprepitant CYP3A4/2C9 warning, 50% Dexamethasone reduction, Palonosetron + Ondansetron 3-day lock)
- BCFI / CBIP Belgian Compendium & CredibleMeds QTc Risk Categories
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from .models import ADVISORY_LABEL, BCFI_CITATION, DdiAlert, UZA_POLICY_CITATION
from .uza_policy import normalize_drug_name

STRONG_MODERATE_AZOLES = {
    "voriconazole",
    "posaconazole",
    "itraconazole",
    "fluconazole",
    "isavuconazole",
    "ketoconazole",
}
NK1_ANTAGONISTS = {"aprepitant", "fosaprepitant"}
VINCA_ALKALOIDS = {"vincristine", "vinblastine", "vinorelbine"}

# CredibleMeds / BCFI QTc risk categories & point scores
QTC_RISK_REGISTRY: Dict[str, Dict[str, Any]] = {
    "ondansetron": {
        "category": "Known Risk",
        "score": 3,
        "note": "Dose-dependent QTc prolongation (higher with IV administration; max 8 mg/dose in UZA v2).",
    },
    "domperidone": {
        "category": "Known Risk",
        "score": 3,
        "note": "Known risk of ventricular arrhythmia / TdP; avoid combining with 5-HT3 antagonists in children (BCFI/CBIP).",
    },
    "haloperidol": {
        "category": "Known Risk",
        "score": 3,
        "note": "Known QTc prolongation risk, especially IV.",
    },
    "droperidol": {
        "category": "Known Risk",
        "score": 3,
        "note": "Boxed warning for QTc prolongation.",
    },
    "voriconazole": {
        "category": "Known Risk",
        "score": 3,
        "note": "Known QTc prolongation + strong CYP3A4 inhibitor.",
    },
    "ciprofloxacin": {
        "category": "Known Risk",
        "score": 3,
        "note": "Known QTc prolongation risk.",
    },
    "arsenic_trioxide": {
        "category": "Known Risk",
        "score": 3,
        "note": "Marked QTc prolongation; requires serial ECG monitoring.",
    },
    "granisetron": {
        "category": "Possible Risk",
        "score": 1,
        "note": "Lower QTc impact than high-dose IV ondansetron.",
    },
    "posaconazole": {
        "category": "Possible Risk",
        "score": 1,
        "note": "Azole antifungal; possible QTc prolongation + strong CYP3A4 inhibitor.",
    },
    "doxorubicin": {
        "category": "Possible Risk",
        "score": 1,
        "note": "Anthracycline cardiotoxicity and potential QTc dispersion.",
    },
    "daunorubicin": {
        "category": "Possible Risk",
        "score": 1,
        "note": "Anthracycline cardiotoxicity.",
    },
    "epirubicin": {
        "category": "Possible Risk",
        "score": 1,
        "note": "Anthracycline cardiotoxicity.",
    },
    "idarubicin": {
        "category": "Possible Risk",
        "score": 1,
        "note": "Anthracycline cardiotoxicity.",
    },
    "olanzapine": {
        "category": "Conditional Risk",
        "score": 1,
        "note": "Conditional QTc risk with polypharmacy or electrolyte depletion.",
    },
    "fluconazole": {
        "category": "Conditional Risk",
        "score": 1,
        "note": "Conditional QTc risk + CYP3A4 inhibition.",
    },
    "metoclopramide": {
        "category": "Conditional Risk",
        "score": 1,
        "note": "Conditional QTc risk + extrapyramidal symptoms in children.",
    },
    "palonosetron": {"category": "No Added Risk", "score": 0, "note": "Preferred 5-HT3 option when QTc is elevated."},
    "aprepitant": {"category": "No Added Risk", "score": 0, "note": "No direct QTc effect; CYP3A4 modulator."},
    "dexamethasone": {"category": "No Added Risk", "score": 0, "note": "No QTc prolongation."},
    "lorazepam": {"category": "No Added Risk", "score": 0, "note": "No QTc prolongation."},
    "alizapride": {"category": "No Added Risk", "score": 0, "note": "Dopamine antagonist per UZA v2 p.2."},
}


def assess_qtc_risk(
    medications: List[str],
    baseline_qtc_ms: Optional[float] = None,
) -> Dict[str, Any]:
    """Calculates deterministic cumulative QTc prolongation risk score."""
    meds_norm = [normalize_drug_name(m) for m in medications]
    total_score = 0
    risk_breakdown: Dict[str, Dict[str, Any]] = {}

    for med in meds_norm:
        entry = QTC_RISK_REGISTRY.get(med, {"category": "No Added Risk", "score": 0, "note": ""})
        total_score += int(entry["score"])
        if int(entry["score"]) > 0:
            risk_breakdown[med] = entry

    if total_score >= 4 or (baseline_qtc_ms is not None and baseline_qtc_ms >= 460.0):
        risk_tier = "HIGH"
        alert = (
            f"HIGH CUMULATIVE QTc RISK (Score: {total_score}). Combination of multiple QTc-prolonging agents "
            f"({', '.join(risk_breakdown.keys())}). Obtain baseline and serial 12-lead ECGs; maintain K+ ≥4.0 mmol/L "
            "and Mg2+ ≥0.8 mmol/L. Consider switching Ondansetron to Palonosetron [BCFI/CBIP · UZA v2 p.2]."
        )
    elif total_score >= 2:
        risk_tier = "MODERATE"
        alert = (
            f"MODERATE QTc RISK (Score: {total_score}). Monitor serum electrolytes (K+ ≥4.0 mmol/L, Mg2+ ≥0.8 mmol/L) "
            "[BCFI/CBIP]."
        )
    else:
        risk_tier = "LOW"
        alert = "LOW QTc RISK. Standard clinical monitoring."

    return {
        "cumulative_score": total_score,
        "risk_tier": risk_tier,
        "baseline_qtc_ms": baseline_qtc_ms,
        "risk_breakdown": risk_breakdown,
        "clinical_alert": alert,
        "citation": BCFI_CITATION,
    }


def check_ddi_interactions(
    primary_drugs: List[str],
    proposed_antiemetics: List[str],
    baseline_qtc_ms: Optional[float] = None,
) -> Dict[str, Any]:
    """Screens for CYP3A4, QTc, neurotoxicity, and duplicate 5-HT3 interactions."""
    norm_primary = {normalize_drug_name(d) for d in primary_drugs}
    norm_antiemetics = {normalize_drug_name(d) for d in proposed_antiemetics}
    all_drugs = norm_primary.union(norm_antiemetics)

    alerts: List[DdiAlert] = []
    modifications: List[str] = []
    severity_rank = 0  # 0=NONE, 1=LOW, 2=MODERATE, 3=HIGH, 4=CRITICAL

    present_azoles = sorted(all_drugs.intersection(STRONG_MODERATE_AZOLES))
    present_nk1 = sorted(all_drugs.intersection(NK1_ANTAGONISTS))
    present_vincas = sorted(all_drugs.intersection(VINCA_ALKALOIDS))
    qtc_eval = assess_qtc_risk(list(all_drugs), baseline_qtc_ms=baseline_qtc_ms)
    present_qtc = sorted(qtc_eval["risk_breakdown"].keys())

    # 1. Palonosetron + Ondansetron co-administration lock (UZA v2 p.2)
    if "palonosetron" in norm_antiemetics and "ondansetron" in norm_antiemetics:
        severity_rank = max(severity_rank, 4)
        alerts.append(
            DdiAlert(
                interacting_pair="palonosetron + ondansetron",
                severity="CRITICAL / CONTRAINDICATED",
                kind="contraindication",
                mechanism="Duplicate 5-HT3 receptor blockade; Palonosetron is a long-acting 5-HT3 antagonist.",
                clinical_action="Do NOT combine Palonosetron with Ondansetron within 3 days after Palonosetron administration.",
                safe_alternative="Use single-agent IV Palonosetron (or Ondansetron 3x/d alone).",
                citation=f"{UZA_POLICY_CITATION} p.2 · Palonosetron: niet samen met ondansetron (tot 3 dagen na toediening palonosetron)",
            )
        )
        modifications.append("Stop Ondansetron for at least 3 days following IV Palonosetron administration (UZA v2 p.2).")

    # 2. Azole Antifungals + Vinca Alkaloids (Lethal / Severe Neurotoxicity)
    if present_azoles and present_vincas:
        severity_rank = max(severity_rank, 4)
        alerts.append(
            DdiAlert(
                interacting_pair=f"{', '.join(present_azoles)} + {', '.join(present_vincas)}",
                severity="CRITICAL (Chemo-Azole Neurotoxicity Contraindication)",
                kind="cyp3a4",
                mechanism=(
                    "Strong inhibition of CYP3A4 and P-glycoprotein by azole antifungals blocks vincristine/vinblastine "
                    "clearance, causing severe peripheral/autonomic neuropathy, vocal cord palsy, and paralytic ileus."
                ),
                clinical_action=(
                    "Withhold azole antifungal 24–48 hours before and after vinca alkaloid dosing per pediatric oncology "
                    "pharmacy protocol."
                ),
                safe_alternative="Switch antifungal prophylaxis to echinocandin (e.g., micafungin/caspofungin) or liposomal amphotericin B around vincristine dosing.",
                citation=f"{BCFI_CITATION} · CYP3A4 / P-gp Vinca-Azole Contraindication",
            )
        )
        modifications.append(
            f"CRITICAL PHARMACY ALERT: Hold {', '.join(present_azoles)} around {', '.join(present_vincas)} dosing to prevent severe neurotoxicity."
        )

    # 3. Azole Antifungal + NK1 Antagonist (Aprepitant / Fosaprepitant)
    if present_azoles and present_nk1:
        severity_rank = max(severity_rank, 4)
        alerts.append(
            DdiAlert(
                interacting_pair=f"{', '.join(present_azoles)} + {', '.join(present_nk1)}",
                severity="CRITICAL / MAJOR CYP3A4 INTERACTION",
                kind="cyp3a4",
                mechanism=(
                    "Strong/moderate CYP3A4 inhibition by azole antifungals markedly increases aprepitant systemic exposure (AUC); "
                    "aprepitant also acts as a moderate CYP3A4 inhibitor/inducer."
                ),
                clinical_action=(
                    "Consult clinical pharmacist to omit/defer aprepitant during strong CYP3A4 inhibitor azole therapy "
                    "or monitor closely for neurocognitive/sedative toxicity."
                ),
                safe_alternative="Ondansetron + CYP3A4-adjusted Dexamethasone (if steroids permitted) + Olanzapine (if ≥2y).",
                citation=f"{UZA_POLICY_CITATION} p.2 · (Fos)Aprepitant: Opgelet voor interacties (CYP3A4/2C9) & {BCFI_CITATION}",
            )
        )
        modifications.append(
            f"Review/hold {', '.join(present_nk1)} during concomitant {', '.join(present_azoles)} therapy due to strong CYP3A4 inhibition."
        )

    # 4. Aprepitant/Fosaprepitant OR Azoles + Dexamethasone (50% dose reduction)
    if "dexamethasone" in norm_antiemetics and (present_nk1 or present_azoles):
        severity_rank = max(severity_rank, 3)
        inhibitors = sorted(set(present_nk1 + present_azoles))
        alerts.append(
            DdiAlert(
                interacting_pair=f"{', '.join(inhibitors)} + dexamethasone",
                severity="HIGH (Mandatory 50% Dose Adjustment)",
                kind="cyp3a4",
                mechanism=(
                    "CYP3A4 inhibition by (fos)aprepitant and/or azole antifungals reduces dexamethasone clearance by ~50%, "
                    "doubling systemic corticosteroid exposure."
                ),
                clinical_action=(
                    "Reduce antiemetic Dexamethasone dose by 50%: <0.6 m² → 1 mg 2x/d (instead of 2 mg 2x/d); "
                    "≥0.6 m² → 2 mg 2x/d (instead of 4 mg 2x/d) per UZA v2 p.2."
                ),
                safe_alternative="Use UZA v2 50%-reduced Dexamethasone tier (1 mg 2x/d if <0.6 m², 2 mg 2x/d if ≥0.6 m²).",
                citation=f"{UZA_POLICY_CITATION} p.2 · Dexamethasone i.c.m. (fos)aprepitant",
            )
        )
        modifications.append(
            "Reduce antiemetic Dexamethasone dose by 50% (1 mg 2x/d if BSA <0.6 m²; 2 mg 2x/d if BSA ≥0.6 m²) due to CYP3A4 inhibition."
        )

    # 5. Ifosfamide + Aprepitant (Encephalopathy risk)
    if "ifosfamide" in norm_primary and present_nk1:
        severity_rank = max(severity_rank, 3)
        alerts.append(
            DdiAlert(
                interacting_pair=f"ifosfamide + {', '.join(present_nk1)}",
                severity="MODERATE-HIGH (Ifosfamide Encephalopathy Risk)",
                kind="cyp3a4",
                mechanism=(
                    "CYP3A4 modulation by aprepitant may shift ifosfamide metabolism toward neurotoxic chloroacetaldehyde, "
                    "increasing pediatric encephalopathy risk."
                ),
                clinical_action=(
                    "Monitor neurological status closely (somnolence, confusion, cerebellar signs); ensure methylene blue "
                    "rescue readiness and review multi-day aprepitant extension with clinical pharmacist."
                ),
                safe_alternative="Continue HEC prophylaxis with close neurological monitoring per UZA v2 Casus 3.",
                citation=f"{UZA_POLICY_CITATION} p.2 · (Fos)Aprepitant CYP3A4 & {BCFI_CITATION}",
            )
        )
        modifications.append(
            "Institute neurological monitoring for ifosfamide-induced encephalopathy when co-administering aprepitant."
        )

    # 6. Additive QTc Prolongation
    if len(present_qtc) >= 2 or qtc_eval["risk_tier"] in {"HIGH", "MODERATE"}:
        is_high_qtc = qtc_eval["risk_tier"] == "HIGH"
        severity_rank = max(severity_rank, 3 if is_high_qtc else 2)
        alerts.append(
            DdiAlert(
                interacting_pair=" + ".join(present_qtc),
                severity=f"{qtc_eval['risk_tier']} (Additive QTc Prolongation, Score={qtc_eval['cumulative_score']})",
                kind="qtc",
                mechanism="Additive blockade of cardiac hERG potassium channels increases risk of QTc prolongation and Torsades de Pointes.",
                clinical_action=(
                    "Obtain baseline and on-treatment 12-lead ECG; maintain serum K+ ≥4.0 mmol/L and Mg2+ ≥0.8 mmol/L. "
                    "Avoid Domperidone/Haloperidol."
                ),
                safe_alternative="Consider switching Ondansetron to IV Palonosetron (no added QTc risk) or using Lorazepam/Alizapride for breakthrough.",
                citation=BCFI_CITATION,
            )
        )
        modifications.append(qtc_eval["clinical_alert"])

    severity_map = {0: "NONE", 1: "LOW", 2: "MODERATE", 3: "HIGH", 4: "CRITICAL"}

    return {
        "primary_drugs_evaluated": primary_drugs,
        "proposed_antiemetics_evaluated": proposed_antiemetics,
        "interactions_count": len(alerts),
        "highest_severity": severity_map[severity_rank],
        "qtc_prolonging_drugs_detected": present_qtc,
        "qtc_prolongation_risk": (
            "ELEVATED" if len(present_qtc) >= 2 else ("LOW-BASELINE" if present_qtc else "MINIMAL")
        ),
        "qtc_assessment": qtc_eval,
        "interactions_found": [a.model_dump() for a in alerts],
        "recommended_modifications": modifications
        or ["No major pharmacokinetic (CYP3A4) or QTc adjustments required for the evaluated drug set."],
        "safe_to_proceed_without_modification": severity_rank <= 1,
        "advisory_status": ADVISORY_LABEL,
    }


def check_antimicrobial_ddi(
    proposed_antiemetics: List[str],
    concurrent_medications: List[str],
) -> List[Dict[str, Any]]:
    """Compatibility helper matching the workshop quickstart signature."""
    res = check_ddi_interactions(
        primary_drugs=concurrent_medications,
        proposed_antiemetics=proposed_antiemetics,
    )
    return res["interactions_found"]
