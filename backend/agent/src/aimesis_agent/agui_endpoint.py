"""AG-UI SSE & synchronous evaluation router for the AImesis clinician frontend.

Exposes:
- `GET /agui/catalog`: Returns the A2UI component catalog allowlist.
- `POST /agui/evaluate`: Deterministic evaluation + A2UI surface generation.
- `POST /agui/stream`: Server-Sent Events (SSE) stream emitting AG-UI lifecycle
  events (`RUN_STARTED`, `TOOL_CALL_START`, `TOOL_CALL_RESULT`, `CUSTOM` A2UI
  surfaces, `TEXT_MESSAGE_CONTENT`, `RUN_FINISHED`).
- `POST /agui/extract-notes`: Extracts structured prior-cycle signals and verbatim
  quotes from a ward progress note (`toernota`).
"""

from __future__ import annotations

import json
import uuid
from typing import Any, Dict, List, Optional

from aimesis_rules import (
    evaluate_uza_cinv_policy_v2,
    generate_cinv_patient_passport,
)
from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from aimesis_agent.a2ui.catalog import load_catalog
from aimesis_agent.a2ui.surfaces import build_clinical_plan_surfaces
from aimesis_agent.notes_extraction import extract_prior_cycle_signals_from_note

router = APIRouter(prefix="/agui", tags=["AG-UI & A2UI"])


class EvaluateCaseRequest(BaseModel):
    """Structured case evaluation payload for the clinician workbench."""

    case_id: Optional[str] = Field(default=None)
    patient_alias: str = Field(default="Kind (Anoniem)")
    drug_list: List[str] = Field(default_factory=list)
    patient_age_years: Optional[float] = Field(default=None)
    patient_weight_kg: Optional[float] = Field(default=None)
    bsa_m2: Optional[float] = Field(default=None)
    drug_doses_mg_m2: Dict[str, float] = Field(default_factory=dict)
    drug_days: Dict[str, List[int]] = Field(default_factory=dict)
    indication: str = Field(default="solid_tumor")
    can_swallow_tablets: bool = True
    prior_breakthrough_cinv: bool = False
    prior_ondansetron_2xd_on_hec: bool = False
    anticipatory_vomiting: bool = False
    chemo_duration_days: int = Field(default=1, ge=1, le=21)
    concomitant_meds: List[str] = Field(default_factory=list)
    strict_validation: bool = False
    free_text_note: Optional[str] = None
    language: str = "NL"


class ExtractNotesRequest(BaseModel):
    """Free-text ward progress note (`toernota`) extraction request."""

    note_text: str


@router.get("/catalog")
def get_a2ui_catalog() -> Dict[str, Any]:
    """Return the A2UI component catalog allowlist."""
    return load_catalog()


@router.post("/extract-notes")
def extract_notes_endpoint(req: ExtractNotesRequest) -> Dict[str, Any]:
    """Extract structured prior-cycle signals and verbatim quotes from a note."""
    return extract_prior_cycle_signals_from_note(req.note_text)


@router.post("/evaluate")
def evaluate_case_endpoint(req: EvaluateCaseRequest) -> Dict[str, Any]:
    """Run the deterministic UZA July 2026 v2 + POGO 250111 engine and return
    both the structured clinical plan and the A2UI surfaces.
    """
    extracted_note = None
    if req.free_text_note:
        extracted_note = extract_prior_cycle_signals_from_note(req.free_text_note)

    plan = evaluate_uza_cinv_policy_v2(
        drug_list=req.drug_list,
        patient_age_years=req.patient_age_years,
        patient_weight_kg=req.patient_weight_kg,
        bsa_m2=req.bsa_m2,
        drug_doses_mg_m2=req.drug_doses_mg_m2 or None,
        drug_days=req.drug_days or None,
        indication=req.indication,
        can_swallow_tablets=req.can_swallow_tablets,
        prior_breakthrough_cinv=req.prior_breakthrough_cinv,
        prior_ondansetron_2xd_on_hec=req.prior_ondansetron_2xd_on_hec,
        anticipatory_vomiting=req.anticipatory_vomiting,
        chemo_duration_days=req.chemo_duration_days,
        concomitant_meds=req.concomitant_meds,
        strict_validation=req.strict_validation,
    )

    passport = None
    if not plan.get("refused"):
        passport = generate_cinv_patient_passport(
            patient_alias=req.patient_alias,
            uza_evaluation=plan,
            language=req.language,
        )

    surfaces = build_clinical_plan_surfaces(plan, passport=passport)
    return {
        "run_id": str(uuid.uuid4()),
        "case_id": req.case_id,
        "refused": plan.get("refused", False),
        "plan": plan,
        "passport": passport,
        "extracted_note": extracted_note,
        "a2ui_surfaces": surfaces,
    }


def _sse_event(event_type: str, payload: Dict[str, Any]) -> str:
    data = {"type": event_type, **payload}
    return f"data: {json.dumps(data, ensure_ascii=False)}\n\n"


@router.post("/stream")
async def stream_agui_run(req: EvaluateCaseRequest) -> StreamingResponse:
    """Stream AG-UI protocol events (`RUN_STARTED`, `TOOL_CALL_*`, `CUSTOM` A2UI
    surfaces, `TEXT_MESSAGE_CONTENT`, `RUN_FINISHED`) over Server-Sent Events.
    """
    run_id = str(uuid.uuid4())

    async def event_generator():
        yield _sse_event("RUN_STARTED", {"run_id": run_id, "case_id": req.case_id})

        if req.free_text_note:
            yield _sse_event(
                "TOOL_CALL_START",
                {"run_id": run_id, "tool_name": "extract_prior_cycle_signals_from_note"},
            )
            extracted = extract_prior_cycle_signals_from_note(req.free_text_note)
            yield _sse_event(
                "TOOL_CALL_RESULT",
                {
                    "run_id": run_id,
                    "tool_name": "extract_prior_cycle_signals_from_note",
                    "result": extracted,
                },
            )

        yield _sse_event(
            "TOOL_CALL_START",
            {"run_id": run_id, "tool_name": "evaluate_uza_cinv_policy_v2"},
        )
        evaluated = evaluate_case_endpoint(req)
        plan = evaluated["plan"]
        surfaces = evaluated["a2ui_surfaces"]

        yield _sse_event(
            "TOOL_CALL_RESULT",
            {
                "run_id": run_id,
                "tool_name": "evaluate_uza_cinv_policy_v2",
                "refused": plan.get("refused", False),
            },
        )

        for surface in surfaces:
            yield _sse_event(
                "CUSTOM",
                {
                    "run_id": run_id,
                    "name": "a2ui.surfaceUpdate",
                    "value": surface,
                },
            )

        if not plan.get("refused"):
            summary = (
                f"UZA CINV Policy V2 (Juli 2026) evaluatie voltooid: "
                f"**{plan['overall_tier']}** — {plan['baseline_prophylaxis_summary']}"
            )
        else:
            reasons = "; ".join(r["message"] for r in plan.get("refusal_reasons", []))
            summary = f"Validatie geblokkeerd (Refuse Rather Than Guess): {reasons}"

        yield _sse_event(
            "TEXT_MESSAGE_CONTENT",
            {"run_id": run_id, "delta": summary},
        )
        yield _sse_event(
            "RUN_FINISHED",
            {"run_id": run_id, "refused": plan.get("refused", False)},
        )

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )
