"""Input and output data structures. Inputs are what intake collects; outputs
are a DRAFT that a physician must approve — never a final order."""
from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from typing import Literal, Optional

Tier = Literal["minimal", "low", "moderate", "high"]
Route = Literal["IV", "PO", "IT", "SC", "IM"]
OralRoute = Literal["tablet", "liquid", "ng_tube", "none"]

# Coded diagnoses — free text is not accepted, so a hard block cannot be
# missed because of spelling ("medullo", "hersentumor", ...).
DIAGNOSES = {
    "ALL", "AML", "brain_tumor", "neuroblastoma", "ewing_sarcoma",
    "osteosarcoma", "rhabdomyosarcoma", "wilms_tumor", "lymphoma", "other_solid_tumor",
}


@dataclass
class ChemoAgent:
    name: str
    dose_mg_m2: Optional[float] = None
    route: Route = "IV"


@dataclass
class ChemoDay:
    day: int
    agents: list[ChemoAgent]


@dataclass
class PriorCycle:
    label: str
    tier: Tier
    ondansetron_times_per_day: Optional[int] = None
    prophylaxis: list[str] = field(default_factory=list)
    breakthrough_days: list[int] = field(default_factory=list)   # relative to cycle start
    source: str = ""                 # e.g. "toernota 05/09/2026"
    confirmed_by_physician: bool = False


@dataclass
class Patient:
    age_years: float
    weight_kg: float
    bsa_m2: float                    # take from the chemo order, do not recompute
    diagnosis: str
    oral_route: OralRoute = "tablet"
    comedications: list[str] = field(default_factory=list)   # coded, e.g. "dinutuximab_beta", "car_t"
    anticipatory_nausea: bool = False
    prior_cycles: list[PriorCycle] = field(default_factory=list)

    @property
    def age_months(self) -> float:
        return self.age_years * 12


@dataclass
class Regimen:
    protocol: str
    course: str
    days: list[ChemoDay]


# ----------------------------------------------------------------- outputs
@dataclass
class Item:
    drug: str
    dose: Decimal
    unit: str
    times_per_day: Optional[int]
    route: str
    days: list[int]
    calc: str
    rule_ids: list[str]
    notes: list[str] = field(default_factory=list)
    dose_max: Optional[Decimal] = None      # set when the policy gives a range (lorazepam)
    prn: bool = False                       # "indien nodig"


@dataclass
class Decision:
    """Something the policy leaves to the physician. The engine never picks."""
    id: str
    question: str
    options: list[str]
    rule_ids: list[str]


@dataclass
class Recommendation:
    status: Literal["DRAFT_REQUIRES_PHYSICIAN_APPROVAL", "BLOCKED_NEEDS_PHYSICIAN"]
    tier: Optional[Tier]
    day_tiers: dict[int, Tier]
    tier_trace: list[str]
    items: list[Item]
    rescue: list[Item]
    blocks: list[str]
    warnings: list[str]
    decisions: list[Decision]
    errors: list[str]
    rulebook_version: str

    def item(self, drug: str) -> Optional[Item]:
        return next((i for i in self.items if i.drug == drug), None)

    def rescue_item(self, drug: str) -> Optional[Item]:
        return next((i for i in self.rescue if i.drug == drug), None)

    def decision(self, id_: str) -> Optional[Decision]:
        return next((d for d in self.decisions if d.id == id_), None)
