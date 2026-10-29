"""FastAPI routes for CINV episode logging, breakthrough tracking, and dual sign-off."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from aimesis_rules import evaluate_uza_cinv_policy_v2
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from aimesis_api.episodes.store import episode_store

router = APIRouter(prefix="/episodes", tags=["Episodes & Cycle Tracking"])


class CreateEpisodeRequest(BaseModel):
    patient_id: str = Field(default="anon-patient")
    cycle_number: int = Field(default=1, ge=1)
    regimen_agents: List[str] = Field(default_factory=list)
    patient_weight_kg: Optional[float] = None
    patient_age_years: Optional[float] = None
    bsa_m2: Optional[float] = None
    indication: str = "solid_tumor"
    chemo_duration_days: int = 1
    drug_doses_mg_m2: Dict[str, float] = Field(default_factory=dict)
    drug_days: Dict[str, List[int]] = Field(default_factory=dict)
    drug_routes: Dict[str, str] = Field(default_factory=dict)
    can_swallow_tablets: bool = True
    prior_breakthrough_cinv: bool = False
    uza_evaluation: Optional[Dict[str, Any]] = None


class BreakthroughEventRequest(BaseModel):
    vomiting_episodes_24h: int = Field(default=1, ge=0)
    pepsin_nausea_score: int = Field(default=2, ge=0, le=10)
    rescue_administered: Optional[str] = None
    notes: Optional[str] = None


class DualSignOffRequest(BaseModel):
    oncologist_signed: Optional[bool] = None
    oncologist_name: Optional[str] = None
    pharmacist_signed: Optional[bool] = None
    pharmacist_name: Optional[str] = None


@router.post("")
def create_episode(req: CreateEpisodeRequest) -> Dict[str, Any]:
    """Create a new CINV cycle episode and compute its UZA v2 plan if not supplied."""
    uza_eval = req.uza_evaluation
    if uza_eval is None and req.regimen_agents:
        uza_eval = evaluate_uza_cinv_policy_v2(
            drug_list=req.regimen_agents,
            patient_age_years=req.patient_age_years,
            patient_weight_kg=req.patient_weight_kg,
            bsa_m2=req.bsa_m2,
            drug_doses_mg_m2=req.drug_doses_mg_m2 or None,
            drug_days=req.drug_days or None,
            drug_routes=req.drug_routes or None,
            indication=req.indication,
            can_swallow_tablets=req.can_swallow_tablets,
            prior_breakthrough_cinv=req.prior_breakthrough_cinv,
            chemo_duration_days=req.chemo_duration_days,
        )

    return episode_store.create_episode(
        {
            "patient_id": req.patient_id,
            "cycle_number": req.cycle_number,
            "regimen_agents": req.regimen_agents,
            "uza_evaluation": uza_eval or {},
        }
    )


@router.get("")
def list_episodes(patient_id: Optional[str] = None) -> Dict[str, Any]:
    """List CINV episodes, optionally filtered by `patient_id`."""
    episodes = episode_store.list_episodes(patient_id=patient_id)
    return {"count": len(episodes), "episodes": episodes}


@router.get("/{episode_id}")
def get_episode(episode_id: str) -> Dict[str, Any]:
    """Retrieve a single CINV episode by ID."""
    record = episode_store.get_episode(episode_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"Episode '{episode_id}' not found.")
    return record


@router.post("/{episode_id}/breakthrough")
def record_breakthrough(
    episode_id: str,
    req: BreakthroughEventRequest,
) -> Dict[str, Any]:
    """Log a breakthrough CINV event and return updated episode state."""
    record = episode_store.log_breakthrough_event(episode_id, req.model_dump())
    if not record:
        raise HTTPException(status_code=404, detail=f"Episode '{episode_id}' not found.")
    return record


@router.post("/{episode_id}/sign-off")
def update_episode_sign_off(
    episode_id: str,
    req: DualSignOffRequest,
) -> Dict[str, Any]:
    """Update the attending pediatric oncologist and/or clinical pharmacist sign-off."""
    record = episode_store.update_sign_off(
        episode_id=episode_id,
        oncologist_signed=req.oncologist_signed,
        oncologist_name=req.oncologist_name,
        pharmacist_signed=req.pharmacist_signed,
        pharmacist_name=req.pharmacist_name,
    )
    if not record:
        raise HTTPException(status_code=404, detail=f"Episode '{episode_id}' not found.")
    return record
