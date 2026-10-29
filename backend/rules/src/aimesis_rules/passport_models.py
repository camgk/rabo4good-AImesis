"""Pydantic models for the agent CINV passport.

Mirror `contracts/schemas/agent_passport.schema.json` (a strict profile of
`passport.schema.json`); `agent/tests/test_passport_contract.py` checks the
serialised models against those schemas. Use `to_contract()` to serialise:
optional fields that are unset are omitted, nullable fields stay `null`.

`AgentPassport` is either a `DraftPassport` (unsigned, all clinician-review
sections) or a `RefusalPassport` (inputs and reasons, no tier, no doses).
"""

from __future__ import annotations

from typing import (
    Annotated,
    Any,
    ClassVar,
    Dict,
    FrozenSet,
    List,
    Literal,
    Optional,
    Union,
)

from pydantic import (
    BaseModel,
    ConfigDict,
    Discriminator,
    Field,
    Tag,
    TypeAdapter,
    model_serializer,
)

Tier = Literal["HIGH", "MODERATE", "LOW", "MINIMAL"]
Route = Literal["iv", "oral_liquid", "oral_capsule", "oral_tablet", "orodispersible"]
InputSource = Literal["patient_record", "derived", "default"]
FlagSeverity = Literal["critical", "warning", "info"]


class ContractModel(BaseModel):
    """Strict base: unknown fields are rejected, no type coercion."""

    model_config = ConfigDict(extra="forbid", strict=True)

    # Optional properties of the contract: omitted (not `null`) when None.
    contract_omit_if_none: ClassVar[FrozenSet[str]] = frozenset()

    @model_serializer(mode="wrap")
    def _omit_optional_nones(self, handler: Any) -> Dict[str, Any]:
        data = handler(self)
        for name in self.contract_omit_if_none:
            if data.get(name) is None:
                data.pop(name, None)
        return data

    def to_contract(self) -> Dict[str, Any]:
        return self.model_dump(mode="json")


# --------------------------------------------------------------------------- shared


class CitedReason(ContractModel):
    field: str
    message: str
    citation: str


class Generation(ContractModel):
    generated_at: str
    generator: str
    policy_version: str
    benchmark_version: str
    advisory_status: str


class InputItem(ContractModel):
    contract_omit_if_none: ClassVar[FrozenSet[str]] = frozenset({"unit", "note"})

    field: str
    value: Any
    source: InputSource
    unit: Optional[str] = None
    note: Optional[str] = None


class ReviewFlag(ContractModel):
    contract_omit_if_none: ClassVar[FrozenSet[str]] = frozenset({"citation"})

    severity: FlagSeverity
    code: str
    message: str
    citation: Optional[str] = None


class ClassifiedDrug(ContractModel):
    drug: str
    dose_mg_m2: Optional[float]
    days: List[int]
    tier: Tier
    rule_citation: str


class ClassifiedDay(ContractModel):
    day: int
    tier: Tier
    drugs: List[str]


class Classification(ContractModel):
    overall_tier: Optional[Tier]
    drugs: List[ClassifiedDrug]
    days: List[ClassifiedDay]
    combination_rules: List[str]


# --------------------------------------------------------------------------- draft sections


class Administration(ContractModel):
    dose_amount: float
    dose_unit: str
    cycle_days: List[int]
    day_label: str


class ScheduleItem(ContractModel):
    drug_name: str
    dose_amount: float
    dose_unit: str
    formula_used: str
    route: Route
    frequency: str
    cycle_days: List[int]
    rule_citation: str
    day_label: str
    duration: str
    route_options: List[str]
    warnings: List[str]


class DexamethasoneRules(ContractModel):
    is_blocked: bool
    rationale: str
    reasons: List[str]
    aprepitant_dose_reduction: bool
    citation: str


class RescueStep(ContractModel):
    contract_omit_if_none: ClassVar[FrozenSet[str]] = frozenset({"max_daily_frequency"})

    step_number: int
    drug_name: str
    dose: str
    route: str
    rule_citation: str
    action: str
    max_daily_frequency: Optional[str] = None


class BreakthroughPlan(ContractModel):
    rescue_steps: List[RescueStep]
    instructions: str


class UnsignedSignoff(ContractModel):
    signed: Literal[False]


class Signoffs(ContractModel):
    requires_dual_signoff: Literal[True]
    advisory_notice: str
    oncologist: UnsignedSignoff
    clinical_pharmacist: UnsignedSignoff


class FamilySchedule(ContractModel):
    headline: str
    daily_steps: List[str]
    what_to_do_if_vomiting: str


class FamilyScheduleMultilingual(ContractModel):
    nl: FamilySchedule
    fr: FamilySchedule
    en: FamilySchedule


class DoseReviewLine(ContractModel):
    drug: str
    indicated: bool
    dose_text: str
    frequency: str
    duration: str
    route: str
    formula: str
    citation: str
    warnings: List[str]
    administrations: List[Administration]


class Interaction(ContractModel):
    interacting_pair: str
    severity: str
    kind: str
    mechanism: str
    clinical_action: str
    safe_alternative: str
    citation: str


class QtcContributor(ContractModel):
    drug: str
    category: str
    score: float
    note: str


class Qtc(ContractModel):
    contract_omit_if_none: ClassVar[FrozenSet[str]] = frozenset({"clinical_alert", "citation"})

    risk_tier: str
    cumulative_score: float
    baseline_qtc_ms: Optional[float] = None
    contributors: List[QtcContributor]
    clinical_alert: Optional[str] = None
    citation: Optional[str] = None


class Safety(ContractModel):
    interactions: List[Interaction]
    highest_severity: str
    safe_to_proceed_without_modification: bool
    recommended_modifications: List[str]
    qtc: Qtc


class PogoDrug(ContractModel):
    drug: str
    dose_mg_m2: Optional[float] = None
    uza_tier: str
    pogo_tier: str
    differs: bool
    explanation: str
    uza_citation: str
    pogo_citation: str


class PogoComparison(ContractModel):
    has_differences: bool
    drugs: List[PogoDrug]
    combination_notes: List[Any]
    prophylaxis_comparison: Dict[str, Any]


class NoRefusal(ContractModel):
    refused: Literal[False]
    reasons: Annotated[List[CitedReason], Field(max_length=0)]


class Refusal(ContractModel):
    refused: Literal[True]
    reasons: Annotated[List[CitedReason], Field(min_length=1)]


class TieredClassification(Classification):
    overall_tier: Tier


# --------------------------------------------------------------------------- documents


class DraftPassport(ContractModel):
    """Unsigned draft passport with every section a clinician needs to judge the plan."""

    passport_id: str
    patient_id: str
    cycle_number: Annotated[int, Field(ge=1)]
    status: Literal["draft"]
    emetogenicity_tier: Tier
    classification_rationale: str
    antiemetic_schedule: List[ScheduleItem]
    dexamethasone_rules: DexamethasoneRules
    breakthrough_plan: BreakthroughPlan
    signoffs: Signoffs
    family_schedule_multilingual: FamilyScheduleMultilingual
    generation: Generation
    inputs: List[InputItem]
    refusal: NoRefusal
    classification: TieredClassification
    dose_review: List[DoseReviewLine]
    personalization: List[str]
    safety: Safety
    pogo_comparison: PogoComparison
    review_flags: List[ReviewFlag]


class RefusalPassport(ContractModel):
    """Refuse rather than guess: inputs, reasons and partial classification; no tier, no doses."""

    contract_omit_if_none: ClassVar[FrozenSet[str]] = frozenset({"cycle_number", "classification"})

    patient_id: str
    cycle_number: Optional[Annotated[int, Field(ge=1)]] = None
    generation: Generation
    inputs: List[InputItem]
    refusal: Refusal
    classification: Optional[Classification] = None
    review_flags: List[ReviewFlag]


def _passport_kind(value: Any) -> str:
    refusal = value.get("refusal") if isinstance(value, dict) else getattr(value, "refusal", None)
    refused = refusal.get("refused") if isinstance(refusal, dict) else getattr(refusal, "refused", None)
    return "refusal" if refused else "draft"


AgentPassport = Annotated[
    Union[Annotated[DraftPassport, Tag("draft")], Annotated[RefusalPassport, Tag("refusal")]],
    Discriminator(_passport_kind),
]
AGENT_PASSPORT_ADAPTER: TypeAdapter[Union[DraftPassport, RefusalPassport]] = TypeAdapter(AgentPassport)


def parse_agent_passport(data: Dict[str, Any]) -> Union[DraftPassport, RefusalPassport]:
    """Validate a dict into the matching passport model (raises `pydantic.ValidationError`)."""
    return AGENT_PASSPORT_ADAPTER.validate_python(data)
