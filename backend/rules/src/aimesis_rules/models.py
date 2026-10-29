"""Typed models and constants for the pure-Python AImesis rules engine."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional

try:
    from pydantic import BaseModel as _PydanticBaseModel, Field as _PydanticField

    _HAS_PYDANTIC = True
except ImportError:  # pragma: no cover - pure stdlib fallback before pip/uv install
    _HAS_PYDANTIC = False

ADVISORY_LABEL = "Advisory only — requires clinician sign-off"
UZA_POLICY_CITATION = "UZA Anti-emetica beleid CINV v2 (Juli 2026)"
POGO_CITATION = "POGO Emetogenicity Classification Guideline (Final-rev-250111)"
BCFI_CITATION = "BCFI / CBIP Repertorium & CredibleMeds QTc Reference"


class EmetogenicTier(str, Enum):
    HIGH = "High"
    MODERATE = "Moderate"
    LOW = "Low"
    MINIMAL = "Minimal"


TIER_RANK: Dict[EmetogenicTier, int] = {
    EmetogenicTier.MINIMAL: 1,
    EmetogenicTier.LOW: 2,
    EmetogenicTier.MODERATE: 3,
    EmetogenicTier.HIGH: 4,
}

RANK_TO_TIER: Dict[int, EmetogenicTier] = {v: k for k, v in TIER_RANK.items()}


def _to_serializable(obj: Any) -> Any:
    if isinstance(obj, Enum):
        return obj.value
    if isinstance(obj, dict):
        return {k: _to_serializable(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_to_serializable(v) for v in obj]
    return obj


class _DumpMixin:
    def model_dump(self) -> Dict[str, Any]:
        return _to_serializable(asdict(self))  # type: ignore[arg-type]


if _HAS_PYDANTIC:

    class RefusalReason(_PydanticBaseModel):
        field: str
        message: str
        citation: str = UZA_POLICY_CITATION

    class ChemoDrugInput(_PydanticBaseModel):
        drug: str
        dose_mg_m2: Optional[float] = None
        route: str = "IV"
        days: List[int] = _PydanticField(default_factory=lambda: [1])

    class DrugClassification(_PydanticBaseModel):
        input_name: str
        canonical_name: str
        tier: EmetogenicTier
        dose_mg_m2: Optional[float] = None
        route: str = "IV"
        days: List[int] = _PydanticField(default_factory=lambda: [1])
        rule_citation: str
        notes: str = ""

    class RegimenClassification(_PydanticBaseModel):
        refused: bool = False
        refusal_reasons: List[RefusalReason] = _PydanticField(default_factory=list)
        per_drug: List[DrugClassification] = _PydanticField(default_factory=list)
        per_day_tier: Dict[int, EmetogenicTier] = _PydanticField(default_factory=dict)
        overall_tier: Optional[EmetogenicTier] = None
        combination_elevated: bool = False
        combination_rule_applied: Optional[str] = None
        baseline_prophylaxis_summary: str = ""
        citation: str = f"{UZA_POLICY_CITATION} p.1"
        advisory_status: str = ADVISORY_LABEL

    class DexamethasoneEvaluation(_PydanticBaseModel):
        contraindicated: bool
        reasons: List[str] = _PydanticField(default_factory=list)
        citation: str = f"{UZA_POLICY_CITATION} p.2 · GEEN dexamethasone"

    class DoseLine(_PydanticBaseModel):
        drug: str
        indicated: bool
        dose_text: str
        frequency: str
        duration: str
        route: str
        formula_shown: str
        citation: str
        warnings: List[str] = _PydanticField(default_factory=list)

    class DosingScheduleResult(_PydanticBaseModel):
        refused: bool = False
        refusal_reasons: List[RefusalReason] = _PydanticField(default_factory=list)
        dexamethasone_evaluation: Optional[DexamethasoneEvaluation] = None
        lines: Dict[str, DoseLine] = _PydanticField(default_factory=dict)
        advisory_status: str = ADVISORY_LABEL

    class PogoComparisonItem(_PydanticBaseModel):
        drug: str
        dose_mg_m2: Optional[float] = None
        uza_v2_tier: str
        pogo_tier: str
        differs: bool
        explanation: str
        uza_citation: str
        pogo_citation: str

    class DdiAlert(_PydanticBaseModel):
        interacting_pair: str
        severity: str
        kind: str  # "cyp3a4" | "qtc" | "contraindication"
        mechanism: str
        clinical_action: str
        safe_alternative: str
        citation: str = BCFI_CITATION

else:

    @dataclass
    class RefusalReason(_DumpMixin):  # type: ignore[no-redef]
        field: str
        message: str
        citation: str = UZA_POLICY_CITATION

    @dataclass
    class ChemoDrugInput(_DumpMixin):  # type: ignore[no-redef]
        drug: str
        dose_mg_m2: Optional[float] = None
        route: str = "IV"
        days: List[int] = field(default_factory=lambda: [1])

    @dataclass
    class DrugClassification(_DumpMixin):  # type: ignore[no-redef]
        input_name: str
        canonical_name: str
        tier: EmetogenicTier
        rule_citation: str = ""
        dose_mg_m2: Optional[float] = None
        route: str = "IV"
        days: List[int] = field(default_factory=lambda: [1])
        notes: str = ""

    @dataclass
    class RegimenClassification(_DumpMixin):  # type: ignore[no-redef]
        refused: bool = False
        refusal_reasons: List[RefusalReason] = field(default_factory=list)
        per_drug: List[DrugClassification] = field(default_factory=list)
        per_day_tier: Dict[int, EmetogenicTier] = field(default_factory=dict)
        overall_tier: Optional[EmetogenicTier] = None
        combination_elevated: bool = False
        combination_rule_applied: Optional[str] = None
        baseline_prophylaxis_summary: str = ""
        citation: str = f"{UZA_POLICY_CITATION} p.1"
        advisory_status: str = ADVISORY_LABEL

    @dataclass
    class DexamethasoneEvaluation(_DumpMixin):  # type: ignore[no-redef]
        contraindicated: bool
        reasons: List[str] = field(default_factory=list)
        citation: str = f"{UZA_POLICY_CITATION} p.2 · GEEN dexamethasone"

    @dataclass
    class DoseLine(_DumpMixin):  # type: ignore[no-redef]
        drug: str
        indicated: bool
        dose_text: str
        frequency: str
        duration: str
        route: str
        formula_shown: str
        citation: str
        warnings: List[str] = field(default_factory=list)

    @dataclass
    class DosingScheduleResult(_DumpMixin):  # type: ignore[no-redef]
        refused: bool = False
        refusal_reasons: List[RefusalReason] = field(default_factory=list)
        dexamethasone_evaluation: Optional[DexamethasoneEvaluation] = None
        lines: Dict[str, DoseLine] = field(default_factory=dict)
        advisory_status: str = ADVISORY_LABEL

    @dataclass
    class PogoComparisonItem(_DumpMixin):  # type: ignore[no-redef]
        drug: str
        dose_mg_m2: Optional[float]
        uza_v2_tier: str
        pogo_tier: str
        differs: bool
        explanation: str
        uza_citation: str
        pogo_citation: str

    @dataclass
    class DdiAlert(_DumpMixin):  # type: ignore[no-redef]
        interacting_pair: str
        severity: str
        kind: str
        mechanism: str
        clinical_action: str
        safe_alternative: str
        citation: str = BCFI_CITATION
