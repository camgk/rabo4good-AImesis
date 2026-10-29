"""Story 2 & 3: Deterministic 'GEEN Dexamethasone' Contraindication Guardrail.

Implements UZA v2 page 2:
- OPMERKINGEN: 'GEEN dexamethasone: indien kuur al corticoïden bevat, bij hersentumoren,
  bij ALL behandeling, bij dinutuximab beta'
- DEXAMETHASONE box: 'GEEN voorkeur bij kuur met corticoïden/ALL/AML/hersentumoren/CAR-T patiënten'
"""

from __future__ import annotations

from typing import Iterable

from .models import DexamethasoneEvaluation, UZA_POLICY_CITATION

CORTICOSTEROID_AGENTS = {
    "dexamethasone",
    "dexamethason",
    "prednisone",
    "prednison",
    "prednisolone",
    "prednisolon",
    "methylprednisolone",
    "methylprednisolon",
    "hydrocortisone",
    "hydrocortison",
}

BRAIN_TUMOR_KEYWORDS = (
    "brain",
    "hersentumor",
    "hersen",
    "cns",
    "medulloblasto",
    "glioma",
    "glioom",
    "ependymom",
    "ependymoom",
    "astrocytom",
    "astrocytoom",
    "dipg",
    "craniopharyngiom",
)


def evaluate_dexamethasone_contraindication(
    indication: str,
    regimen_drugs: Iterable[str] = (),
    concomitant_meds: Iterable[str] = (),
    regimen_contains_corticosteroids: bool = False,
) -> DexamethasoneEvaluation:
    """Deterministically checks if Dexamethasone is contraindicated per UZA v2 p.2."""
    ind = (indication or "").strip().lower()
    all_drugs = {d.strip().lower() for d in list(regimen_drugs) + list(concomitant_meds)}
    reasons: list[str] = []

    # 1. ALL (Acute Lymphoblastic Leukemia) — Casus 2
    ind_tokens = set(ind.replace("-", " ").replace("/", " ").replace("_", " ").split())
    if "all" in ind_tokens or "alltogether" in ind or "lymphoblastic" in ind or "lymfoblast" in ind:
        reasons.append(
            "GEEN Dexamethasone bij ALL behandeling (interferes with leukemia steroid backbone; UZA v2 p.2, Casus 2)"
        )

    # 2. Brain tumors (hersentumoren)
    if any(k in ind for k in BRAIN_TUMOR_KEYWORDS):
        reasons.append(
            "GEEN Dexamethasone bij hersentumoren / CNS tumors (alters blood-brain barrier permeability; UZA v2 p.2)"
        )

    # 3. Dinutuximab beta
    if (
        "dinutuximab" in ind
        or "dinutuximab" in all_drugs
        or "dinutuximab beta" in all_drugs
        or "dinutuximab_beta" in all_drugs
    ):
        reasons.append(
            "GEEN Dexamethasone bij dinutuximab beta immuuntherapie (immunosuppressive blunting of ADCC; UZA v2 p.2)"
        )

    # 4. Regimen already contains corticosteroids
    present_steroids = sorted(all_drugs.intersection(CORTICOSTEROID_AGENTS))
    if regimen_contains_corticosteroids or present_steroids:
        steroid_detail = f" ({', '.join(present_steroids)})" if present_steroids else ""
        reasons.append(
            f"GEEN Dexamethasone: kuur bevat al corticoïden{steroid_detail} (UZA v2 p.2)"
        )

    # 5. AML / CAR-T per Dexamethasone table box on UZA v2 p.2
    if "aml" in ind_tokens or "myeloid" in ind or "myeloïde" in ind:
        reasons.append(
            "GEEN voorkeur voor Dexamethasone bij AML patiënten (UZA v2 p.2 Dexamethasone richtlijn)"
        )
    if "car-t" in ind or "cart" in ind_tokens or "car_t" in ind:
        reasons.append(
            "GEEN voorkeur voor Dexamethasone bij CAR-T patiënten (UZA v2 p.2 Dexamethasone richtlijn)"
        )

    return DexamethasoneEvaluation(
        contraindicated=len(reasons) > 0,
        reasons=reasons,
        citation=f"{UZA_POLICY_CITATION} p.2 · OPMERKINGEN & Corticoïden",
    )
