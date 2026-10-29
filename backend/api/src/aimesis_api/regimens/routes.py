"""Deterministic Story 1 workbench; no Gemini, patient storage or biometrics."""

from pathlib import Path

from aimesis_rules import (
    ADVISORY_LABEL,
    UZA_POLICY_CITATION,
    ChemoDrugInput,
    RegimenClassification,
    classify_regimen_uza_v2,
)
from aimesis_rules.uza_policy import DOSE_DEPENDENT_DRUGS, UZA_FIXED_TIER_DRUGS
from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, ConfigDict, Field

router = APIRouter(prefix="/regimens", tags=["Story 1 — Regimen classification"])


class ClassifyRegimenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    drugs: list[ChemoDrugInput] = Field(default_factory=list)


@router.get("", response_class=HTMLResponse, include_in_schema=False)
def regimen_workbench():
    return HTMLResponse(
        Path(__file__).with_name("workbench.html").read_text(encoding="utf-8")
    )


@router.get("/policy")
def classification_policy():
    """Selectable drugs from the active UZA table; external-only drugs are excluded."""
    names = sorted(set(UZA_FIXED_TIER_DRUGS) | DOSE_DEPENDENT_DRUGS)
    return {
        "policy_version": UZA_POLICY_CITATION,
        "citation": f"{UZA_POLICY_CITATION} p.1–2",
        "advisory_status": ADVISORY_LABEL,
        "drugs": [
            {
                "name": name,
                "dose_required": name in DOSE_DEPENDENT_DRUGS,
                "fixed_tier": UZA_FIXED_TIER_DRUGS[name][0]
                if name in UZA_FIXED_TIER_DRUGS
                else None,
            }
            for name in names
        ],
    }


@router.post("/classify", response_model=RegimenClassification)
def classify_regimen(req: ClassifyRegimenRequest):
    """Return per-drug/day/overall tiers, baseline strategy and cited rules.

    Omitted days mean day 1. Explicit empty/invalid schedules are rejected.
    Clinical gaps return refused=true and no overall tier or baseline strategy.
    Invalid numeric/JSON shapes return HTTP 422. This endpoint never calculates
    patient-specific antiemetic doses or writes patient records.
    """
    return classify_regimen_uza_v2(req.drugs)
