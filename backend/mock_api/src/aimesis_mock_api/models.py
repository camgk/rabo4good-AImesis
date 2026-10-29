"""Pydantic models for the AImesis mock API.

Field names are snake_case in Python and camelCase on the wire (alias generator).
Shapes follow the shared demo spec exactly; the Dart client (frontend/shared/aimesis_client)
parses the same JSON.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

Tier = Literal["minimal", "low", "moderate", "high"]
Role = Literal["oncologist", "nurse", "pharmacist", "parent", "patient"]
Route = Literal["oral_tablet", "oral_liquid", "ng_tube", "iv"]
PlanStatus = Literal["draft", "awaiting_pharmacist", "approved", "returned"]
Severity = Literal["critical", "warning", "info"]
Lang = Literal["nl", "fr", "en"]
EpisodeType = Literal["nausea", "vomiting"]

ADVISORY = "Advisory only — requires clinician sign-off. Demo data, not for clinical use."


class ApiModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    def wire(self) -> dict:
        """JSON-ready dict with camelCase keys."""
        return self.model_dump(mode="json", by_alias=True)


# ---------------------------------------------------------------- accounts / auth
class Account(ApiModel):
    id: str
    email: str
    role: Role
    display_name: str
    patient_ids: list[str] = Field(default_factory=list)


class DemoAccount(ApiModel):
    email: str
    role: Role
    display_name: str


class LoginRequest(ApiModel):
    email: str
    password: str


class LoginResponse(ApiModel):
    token: str
    account: Account


# ---------------------------------------------------------------- patients
class ChemoRow(ApiModel):
    drug: str
    dose_mg_m2: float
    days: list[int]


class HistoryEntry(ApiModel):
    cycle: str
    date: str | None = None
    antiemetics: str | None = None
    nausea_days: list[int] = Field(default_factory=list)
    vomiting_days: list[int] = Field(default_factory=list)
    note: str = ""


class RiskFactors(ApiModel):
    can_swallow_tablets: bool = True
    preferred_route: Route = "oral_tablet"
    anticipatory: bool = False
    prior_nausea_note: str | None = None


class PatientSummary(ApiModel):
    id: str
    alias: str
    age: int
    sex: str
    diagnosis: str
    protocol: str
    cycle: str
    cycle_start: str
    overall_tier: Tier
    plan_status: PlanStatus
    language: Lang


class Patient(PatientSummary):
    weight_kg: float | None = None
    height_cm: float | None = None
    bsa_m2: float | None = None
    diagnosis_group: str
    chemo: list[ChemoRow]
    active_meds: list[str] = Field(default_factory=list)
    history: list[HistoryEntry] = Field(default_factory=list)
    risk_factors: RiskFactors
    pairing_code: str


# ---------------------------------------------------------------- plan
class DrugTier(ApiModel):
    drug: str
    dose_mg_m2: float | None = None
    tier: Tier
    rule: str
    source: str


class DayTier(ApiModel):
    day: int
    tier: Tier
    drugs: list[str]


class RuleRef(ApiModel):
    rule: str
    source: str


class DexStatus(ApiModel):
    blocked: bool
    reason: str | None = None
    source: str


class AntiemeticLine(ApiModel):
    drug: str
    dose_mg: float | None = None
    unit: str = "mg"
    frequency: str
    route: Route
    days: list[int]
    formula: str
    steps: list[str] = Field(default_factory=list)
    source: str
    notes: list[str] = Field(default_factory=list)


class BreakthroughLine(ApiModel):
    drug: str
    dose_mg: float | None = None
    unit: str = "mg"
    frequency: str
    route: Route
    formula: str
    source: str
    notes: list[str] = Field(default_factory=list)


class Alternative(ApiModel):
    title: str
    detail: str
    source: str


class StepUp(ApiModel):
    title: str
    reason: str
    source: str


class Interaction(ApiModel):
    severity: Severity
    drugs: list[str]
    message: str
    alternative: str | None = None
    source: str


class PogoRow(ApiModel):
    item: str
    uza_tier: Tier
    pogo_tier: Tier
    differs: bool
    note: str


class DaySummary(ApiModel):
    day: int
    nausea: int
    vomiting: int


class EpisodesSummary(ApiModel):
    current_cycle: list[DaySummary] = Field(default_factory=list)
    prior_nausea_days: list[int] = Field(default_factory=list)


class Signoff(ApiModel):
    by: str
    at: str


class Signoffs(ApiModel):
    oncologist: Signoff | None = None
    pharmacist: Signoff | None = None


class PlanComment(ApiModel):
    by: str
    role: Role
    at: str
    text: str


class Plan(ApiModel):
    patient_id: str
    status: PlanStatus = "draft"
    refused: bool = False
    refusal_reasons: list[str] = Field(default_factory=list)
    unknown_drugs: list[str] = Field(default_factory=list)
    drug_tiers: list[DrugTier] = Field(default_factory=list)
    day_tiers: list[DayTier] = Field(default_factory=list)
    overall_tier: Tier = "minimal"
    combination_rules: list[RuleRef] = Field(default_factory=list)
    dexamethasone: DexStatus
    antiemetics: list[AntiemeticLine] = Field(default_factory=list)
    breakthrough: list[BreakthroughLine] = Field(default_factory=list)
    alternatives: list[Alternative] = Field(default_factory=list)
    step_ups: list[StepUp] = Field(default_factory=list)
    interactions: list[Interaction] = Field(default_factory=list)
    uza_vs_pogo: list[PogoRow] = Field(default_factory=list)
    episodes_summary: EpisodesSummary = Field(default_factory=EpisodesSummary)
    signoffs: Signoffs = Field(default_factory=Signoffs)
    comments: list[PlanComment] = Field(default_factory=list)
    advisory: str = ADVISORY


class ApproveRequest(ApiModel):
    comment: str | None = None


class ReturnRequest(ApiModel):
    comment: str = Field(min_length=1)


# ---------------------------------------------------------------- passport / resources
class Resource(ApiModel):
    institution: str
    title: str
    format: str
    language: Literal["nl", "fr", "en", "de"]
    url: str
    effort: Literal["low", "medium", "high"]
    effort_note: str


class PassportItem(ApiModel):
    time: str
    medicine: str
    amount: str
    route: str
    note: str | None = None


class PassportDay(ApiModel):
    day: int
    label: str
    date: str | None = None
    items: list[PassportItem] = Field(default_factory=list)


class Passport(ApiModel):
    patient_id: str
    alias: str
    lang: Lang
    title: str
    overall_tier: Tier
    status: PlanStatus
    signed_off: bool
    days: list[PassportDay] = Field(default_factory=list)
    warning_signs: list[str] = Field(default_factory=list)
    ward_phone: str
    resources: list[Resource] = Field(default_factory=list)
    pairing_code: str
    disclaimer: str


# ---------------------------------------------------------------- episodes / pairing
class EpisodeCreate(ApiModel):
    type: EpisodeType
    severity: int | None = Field(default=None, ge=1, le=5)
    at: str | None = None


class Episode(ApiModel):
    id: str
    patient_id: str
    type: EpisodeType
    severity: int | None = None
    at: str
    cycle_day: int
    logged_by: str
    logged_by_role: Role


class PairingRequest(ApiModel):
    code: str
