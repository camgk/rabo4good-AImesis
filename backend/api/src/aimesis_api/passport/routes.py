"""FastAPI routes for generating and exporting the multilingual CINV Patient Passport."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from aimesis_rules import evaluate_uza_cinv_policy_v2
from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from aimesis_api.passport.render import render_passport_payload

router = APIRouter(prefix="/passport", tags=["Patient Passport (NL/FR/EN)"])


class PassportGenerateRequest(BaseModel):
    patient_label: str = Field(default="Kind (Anoniem)")
    regimen_label: str = Field(default="Chemotherapie")
    language: str = Field(default="NL", description="NL, FR, or EN")
    uza_evaluation: Optional[Dict[str, Any]] = None
    drug_list: List[str] = Field(default_factory=list)
    patient_weight_kg: Optional[float] = None
    patient_age_years: Optional[float] = None
    bsa_m2: Optional[float] = None
    indication: str = "solid_tumor"
    chemo_duration_days: int = 1
    oncologist_signed: bool = False
    oncologist_name: Optional[str] = None
    pharmacist_signed: bool = False
    pharmacist_name: Optional[str] = None


@router.post("/generate")
def generate_passport(req: PassportGenerateRequest) -> Dict[str, Any]:
    """Generate a multilingual (NL/FR/EN) CINV Patient Passport JSON + HTML."""
    uza_eval = req.uza_evaluation
    if uza_eval is None:
        if not req.drug_list:
            raise HTTPException(
                status_code=422,
                detail="Provide either `uza_evaluation` or `drug_list`.",
            )
        uza_eval = evaluate_uza_cinv_policy_v2(
            drug_list=req.drug_list,
            patient_age_years=req.patient_age_years,
            patient_weight_kg=req.patient_weight_kg,
            bsa_m2=req.bsa_m2,
            indication=req.indication,
            chemo_duration_days=req.chemo_duration_days,
        )

    return render_passport_payload(
        patient_label=req.patient_label,
        regimen_label=req.regimen_label,
        uza_evaluation=uza_eval,
        language=req.language,
        oncologist_signed=req.oncologist_signed,
        oncologist_name=req.oncologist_name,
        pharmacist_signed=req.pharmacist_signed,
        pharmacist_name=req.pharmacist_name,
    )


@router.post("/export-html", response_class=HTMLResponse)
def export_passport_html(req: PassportGenerateRequest) -> HTMLResponse:
    """Export print-ready HTML only when dual sign-off (oncologist + pharmacist) is complete."""
    if not (req.oncologist_signed and req.pharmacist_signed):
        raise HTTPException(
            status_code=403,
            detail=(
                "Export locked: Dual sign-off by both the attending pediatric oncologist "
                "and clinical pharmacist is required before exporting the Patient Passport."
            ),
        )
    payload = generate_passport(req)
    return HTMLResponse(content=payload["printable_html"], status_code=200)
