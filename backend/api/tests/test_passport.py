"""Integration tests for multilingual (NL/FR/EN) CINV Patient Passport & dual sign-off gate."""

from __future__ import annotations

from fastapi.testclient import TestClient

from aimesis_api.main import app

client = TestClient(app)


def test_generate_passport_multilingual_nl_fr_en() -> None:
    for lang, expected_word in [
        ("NL", "Paspoort"),
        ("FR", "Passeport"),
        ("EN", "Passport"),
    ]:
        resp = client.post(
            "/passport/generate",
            json={
                "patient_label": "Liam (6j)",
                "regimen_label": "Fludarabine 5d",
                "language": lang,
                "drug_list": ["fludarabine"],
                "patient_weight_kg": 23.0,
                "patient_age_years": 6.0,
                "bsa_m2": 0.88,
                "chemo_duration_days": 5,
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["language"] == lang
        assert expected_word in data["passport_title"]
        assert data["sign_off_status"]["export_unlocked"] is False


def test_export_html_requires_dual_sign_off() -> None:
    locked_resp = client.post(
        "/passport/export-html",
        json={
            "patient_label": "Liam (6j)",
            "regimen_label": "Fludarabine 5d",
            "language": "NL",
            "drug_list": ["fludarabine"],
            "patient_weight_kg": 23.0,
            "patient_age_years": 6.0,
            "bsa_m2": 0.88,
            "oncologist_signed": True,
            "pharmacist_signed": False,
        },
    )
    assert locked_resp.status_code == 403

    unlocked_resp = client.post(
        "/passport/export-html",
        json={
            "patient_label": "Liam (6j)",
            "regimen_label": "Fludarabine 5d",
            "language": "NL",
            "drug_list": ["fludarabine"],
            "patient_weight_kg": 23.0,
            "patient_age_years": 6.0,
            "bsa_m2": 0.88,
            "oncologist_signed": True,
            "pharmacist_signed": True,
        },
    )
    assert unlocked_resp.status_code == 200
    assert "GEVALIDEERD" in unlocked_resp.text
