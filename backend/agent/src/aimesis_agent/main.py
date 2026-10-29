"""FastAPI entrypoint for the AImesis Clinical Decision Support & Cycle Tracking service."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from aimesis_rules import evaluate_uza_cinv_policy_v2
from aimesis_agent.agui_endpoint import router as agui_router
from aimesis_api.episodes.routes import router as episodes_router
from aimesis_api.passport.routes import router as passport_router, passports_router
from aimesis_api.regimens.routes import router as regimens_router

load_dotenv(Path(__file__).resolve().parents[2] / ".env")
load_dotenv()

ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ALLOW_ORIGINS",
        "*",
    ).split(",")
    if origin.strip()
]


class RecommendationRequest(BaseModel):
    patient_id: Optional[str] = Field(default="anon-patient", description="Patient identifier")
    patient_age_years: Optional[float] = Field(default=None, description="Patient age in years")
    patient_weight_kg: Optional[float] = Field(default=None, description="Patient weight in kg")
    bsa_m2: Optional[float] = Field(default=None, description="Body Surface Area (m²)")
    regimen_agents: List[str] = Field(..., description="List of chemotherapeutic agents, e.g. ['cisplatin', 'doxorubicin']")
    drug_doses_mg_m2: Optional[Dict[str, float]] = Field(default=None, description="Drug doses in mg/m² for dose-dependent classification")
    drug_days: Optional[Dict[str, List[int]]] = Field(default=None, description="Days each drug is administered")
    drug_routes: Optional[Dict[str, str]] = Field(default=None, description="Administration route for each drug")
    indication: str = Field(default="solid_tumor", description="Clinical indication (e.g. solid_tumor, all, aml)")
    can_swallow_tablets: bool = Field(default=True, description="Whether child can swallow solid tablets/capsules")
    prior_breakthrough_cinv: bool = Field(default=False, description="Whether patient had breakthrough nausea/vomiting in prior cycle")
    prior_ondansetron_2xd_on_hec: bool = Field(default=False, description="Prior ondansetron twice-daily on HEC regimen")
    anticipatory_vomiting: bool = Field(default=False, description="Anticipatory vomiting/nausea history")
    chemo_duration_days: int = Field(default=1, ge=1, description="Chemotherapy duration in days")
    concomitant_meds: Optional[List[str]] = Field(default=None, description="Concomitant medications for DDI and QTc checking")
    strict_validation: bool = Field(default=False, description="Reject if biometrics or required doses are missing")


def create_app() -> FastAPI:
    """Create the streamlined AImesis Clinical Decision Support FastAPI application."""
    app = FastAPI(
        title="AImesis Clinical Decision Support API",
        version="1.0.0",
        description="Pediatric Oncology CINV Decision Support, Cycle Tracking & Patient Passport API",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS if "*" not in ALLOWED_ORIGINS else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 1. Health check
    @app.get("/health", tags=["System"])
    def health_check() -> dict[str, Any]:
        return {
            "status": "healthy",
            "service": "aimesis-clinical-backend",
            "policy_version": "UZA Kinderoncologie CINV Beleid V2 (Juli 2026)",
            "benchmark_version": "POGO 2025 (250111)",
        }

    # 2. Recommendation Engine
    @app.post("/recommendation", tags=["Recommendation"])
    @app.post("/api/recommendation", tags=["Recommendation"])
    def get_recommendation(req: RecommendationRequest) -> Dict[str, Any]:
        """Compute UZA CINV v2 antiemetic recommendation, dosing, and DDI alerts from patient information."""
        if not req.regimen_agents:
            raise HTTPException(status_code=422, detail="At least one chemotherapeutic agent must be provided in `regimen_agents`.")

        result = evaluate_uza_cinv_policy_v2(
            drug_list=req.regimen_agents,
            patient_age_years=req.patient_age_years,
            patient_weight_kg=req.patient_weight_kg,
            bsa_m2=req.bsa_m2,
            drug_doses_mg_m2=req.drug_doses_mg_m2,
            drug_days=req.drug_days,
            drug_routes=req.drug_routes,
            indication=req.indication,
            can_swallow_tablets=req.can_swallow_tablets,
            prior_breakthrough_cinv=req.prior_breakthrough_cinv,
            prior_ondansetron_2xd_on_hec=req.prior_ondansetron_2xd_on_hec,
            anticipatory_vomiting=req.anticipatory_vomiting,
            chemo_duration_days=req.chemo_duration_days,
            concomitant_meds=req.concomitant_meds,
            strict_validation=req.strict_validation,
        )
        return result

    # Story 1 standalone workbench and deterministic classification.
    app.include_router(regimens_router)

    # 3. Episodes & Cycle Tracking
    app.include_router(episodes_router)
    app.include_router(episodes_router, prefix="/api")

    # 4. Patient Passport (supports /passport, /passports, and /api/passports)
    app.include_router(passport_router)
    app.include_router(passports_router)
    app.include_router(passports_router, prefix="/api")

    # 5. Internal AG-UI router (hidden from public OpenAPI/Swagger docs)
    app.include_router(agui_router, include_in_schema=False)

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "aimesis_agent.main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        reload=True,
    )
