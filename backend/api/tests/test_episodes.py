"""Integration tests for CINV episode logging and dual sign-off routes."""

from __future__ import annotations

from fastapi.testclient import TestClient

from aimesis_api.main import app

client = TestClient(app)


def test_create_episode_and_dual_sign_off_workflow() -> None:
    create_resp = client.post(
        "/episodes",
        json={
            "patient_id": "pt-uza-001",
            "cycle_number": 1,
            "regimen_agents": ["ifosfamide", "etoposide"],
            "patient_weight_kg": 44.0,
            "patient_age_years": 13.0,
            "bsa_m2": 1.38,
            "chemo_duration_days": 5,
        },
    )
    assert create_resp.status_code == 200
    ep = create_resp.json()
    episode_id = ep["episode_id"]
    assert ep["sign_off"]["export_unlocked"] is False

    # Log a breakthrough event
    bt_resp = client.post(
        f"/episodes/{episode_id}/breakthrough",
        json={
            "vomiting_episodes_24h": 3,
            "pepsin_nausea_score": 6,
            "rescue_administered": "Alizapride 44 mg IV",
        },
    )
    assert bt_resp.status_code == 200
    assert len(bt_resp.json()["breakthrough_events"]) == 1

    # Single sign-off is NOT enough to unlock export
    s1 = client.post(
        f"/episodes/{episode_id}/sign-off",
        json={"oncologist_signed": True, "oncologist_name": "Prof. J. van der Werff ten Bosch"},
    )
    assert s1.status_code == 200
    assert s1.json()["sign_off"]["export_unlocked"] is False

    # Second sign-off by clinical pharmacist unlocks export
    s2 = client.post(
        f"/episodes/{episode_id}/sign-off",
        json={"pharmacist_signed": True, "pharmacist_name": "Apr. Katleen Balliauw"},
    )
    assert s2.status_code == 200
    assert s2.json()["sign_off"]["export_unlocked"] is True
