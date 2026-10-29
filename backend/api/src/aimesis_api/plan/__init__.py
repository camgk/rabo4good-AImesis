"""Adapters from the `aimesis_rules` engine to the frontend `Plan` contract
(`contracts/mock-api.openapi.yaml`, camelCase)."""

from aimesis_api.plan.classification import classify_for_plan

__all__ = ["classify_for_plan"]
