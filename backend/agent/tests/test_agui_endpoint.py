"""Integration tests for the AG-UI FastAPI router (`/agui/evaluate`, `/agui/stream`, `/agui/extract-notes`)."""

from __future__ import annotations

from fastapi.testclient import TestClient

from aimesis_agent.main import app

client = TestClient(app)


def test_agui_evaluate_endpoint_returns_plan_and_surfaces() -> None:
    resp = client.post(
        "/agui/evaluate",
        json={
            "case_id": "test-casus-3",
            "drug_list": ["ifosfamide", "etoposide"],
            "patient_age_years": 13.0,
            "patient_weight_kg": 44.0,
            "bsa_m2": 1.38,
            "chemo_duration_days": 5,
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["refused"] is False
    assert body["plan"]["overall_tier"] == "High"
    assert len(body["a2ui_surfaces"]) >= 6


def test_agui_stream_sse_emits_lifecycle_and_custom_a2ui_events() -> None:
    resp = client.post(
        "/agui/stream",
        json={
            "case_id": "sse-casus-1",
            "drug_list": ["vincristine", "cisplatin"],
            "patient_age_years": 16.0,
            "patient_weight_kg": 52.0,
            "bsa_m2": 1.54,
        },
    )
    assert resp.status_code == 200
    text = resp.text
    assert "RUN_STARTED" in text
    assert "a2ui.surfaceUpdate" in text
    assert "RUN_FINISHED" in text


def test_agui_extract_notes_endpoint() -> None:
    resp = client.post(
        "/agui/extract-notes",
        json={
            "note_text": "Patiënt kreeg Ondansetron 2x/d en had op dag 2 doorbraak braken en anticipatoire misselijkheid."
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["requires_clinician_confirmation"] is True
    assert data["prior_breakthrough_cinv"] is True
    assert data["prior_ondansetron_2xd_on_hec"] is True
    assert data["anticipatory_vomiting"] is True
