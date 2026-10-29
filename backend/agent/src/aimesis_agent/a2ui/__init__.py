"""A2UI declarative surface builder for AImesis."""

from .catalog import ALLOWED_COMPONENT_TYPES, load_catalog, validate_surface_component
from .surfaces import build_clinical_plan_surfaces

__all__ = [
    "ALLOWED_COMPONENT_TYPES",
    "build_clinical_plan_surfaces",
    "load_catalog",
    "validate_surface_component",
]
