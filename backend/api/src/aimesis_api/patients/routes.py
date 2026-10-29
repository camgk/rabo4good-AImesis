"""Story 2 patient records, BSA observations and dose calculations."""

from pathlib import Path
from typing import Any, Literal

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, ConfigDict, Field

from .service import calculate_patient_dosing
from .store import PatientValidationError, latest_bsa, patient_store

patient_router = APIRouter(
    prefix="/patients", tags=["Story 2 — Patient records and dosing"]
)
dosing_router = APIRouter(tags=["Story 2 — Patient records and dosing"])


class BsaMeasurement(BaseModel):
    model_config = ConfigDict(extra="forbid")
    bsa_m2: float = Field(ge=0.1, le=3, allow_inf_nan=False, strict=True)
    measured_at: str
    source: str = "patient record"


class PatientUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    age_years: float | None = Field(
        default=None, ge=0, le=21, allow_inf_nan=False, strict=True
    )
    weight_kg: float | None = Field(
        default=None, ge=1, le=150, allow_inf_nan=False, strict=True
    )
    bsa_m2: float | None = Field(
        default=None, ge=0.1, le=3, allow_inf_nan=False, strict=True
    )
    bsa_measured_at: str | None = None
    bsa_measurements: list[BsaMeasurement] | None = None
    diagnosis: str | None = None
    diagnosis_group: str | None = None
    chemo_regimen: list[dict[str, Any]] | None = None
    preferred_formulation: (
        Literal["oral_liquid", "oral_tablet", "iv", "orodispersible"] | None
    ) = None
    active_medications: list[str] | None = None
    history_previous_cycles: dict[str, Any] | None = None
    protocol_name: str | None = None
    current_cycle: int | None = Field(default=None, ge=1)


class DoseOptions(BaseModel):
    model_config = ConfigDict(extra="forbid")
    antiemetic_route: Literal["PO", "IV"] = "PO"
    aprepitant_route: Literal["PO", "IV"] = "PO"
    fosaprepitant_schedule: Literal["multi_day", "single_dose"] = "multi_day"
    use_palonosetron_switch: bool = False
    mec_prefer_aprepitant: bool = False


def _context(record):
    try:
        selected = latest_bsa(record)
    except PatientValidationError as exc:
        selected = None
        error = str(exc)
    else:
        error = None
        record = {**record, "bsa_m2": selected["bsa_m2"]}
    return {
        "patient": record,
        "latest_bsa": selected,
        "bsa_error": error,
        "storage_mode": patient_store.storage_mode,
    }


@dosing_router.get("/dosing", response_class=HTMLResponse, include_in_schema=False)
def dosing_workbench():
    return HTMLResponse(
        Path(__file__).with_name("workbench.html").read_text(encoding="utf-8")
    )


@patient_router.get("/storage")
def storage_mode():
    return {"mode": patient_store.storage_mode}


@patient_router.get("/{patient_id}")
def get_patient(patient_id: str):
    try:
        record = patient_store.get(patient_id)
    except Exception as exc:
        raise HTTPException(
            503,
            "Patient storage is unavailable; no cached or invented measurements were used.",
        ) from exc
    if record is None:
        raise HTTPException(404, "Patient record not found.")
    return _context(record)


@patient_router.put("/{patient_id}")
def save_patient(patient_id: str, req: PatientUpdate):
    try:
        record = patient_store.upsert(
            {"patient_id": patient_id, **req.model_dump(exclude_none=True)}
        )
    except PatientValidationError as exc:
        raise HTTPException(422, str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            503, "Patient storage is unavailable; the record was not saved."
        ) from exc
    return _context(record)


@patient_router.post("/{patient_id}/dosing")
def patient_dosing(patient_id: str, options: DoseOptions):
    try:
        result = calculate_patient_dosing(
            patient_id, store=patient_store, **options.model_dump()
        )
    except Exception as exc:
        raise HTTPException(
            503,
            "Patient storage is unavailable; no cached or invented measurements were used.",
        ) from exc
    if not result["patient_found"]:
        raise HTTPException(404, result["refusal_reasons"])
    return result
