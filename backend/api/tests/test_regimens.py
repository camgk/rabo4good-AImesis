"""Story 1 through the real API and unified agent serving surfaces, without cloud calls."""

import pytest
from aimesis_api.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_workbench_and_approved_drug_catalog():
    response = client.get("/regimens")
    assert response.status_code == 200
    assert "Regimen risk assessment" in response.text
    assert "Case 3" in response.text
    catalog = client.get("/regimens/policy").json()
    drugs = {drug["name"]: drug for drug in catalog["drugs"]}
    assert drugs["cyclophosphamide"]["dose_required"]
    assert drugs["vincristine"]["fixed_tier"] == "Low"
    assert "carmustine" not in drugs


def test_classification_needs_no_biometrics_or_gemini():
    response = client.post(
        "/regimens/classify",
        json={
            "drugs": [
                {"drug": "ifosfamide", "days": [1, 2]},
                {"drug": "etoposide", "days": [2, 3]},
            ]
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert not data["refused"]
    assert data["overall_tier"] == "High"
    assert data["per_day_tier"] == {"1": "Moderate", "2": "High", "3": "Low"}
    assert list(data["per_day_combination_rules"]) == ["2"]
    assert "Ondansetron" in data["baseline_prophylaxis_summary"]
    assert "sign-off" in data["advisory_status"]
    assert "dosing_schedule" not in data


@pytest.mark.parametrize(
    "drugs",
    [
        [],
        [{"drug": "unknown"}],
        [{"drug": "cyclophosphamide"}],
        [{"drug": "cytarabine", "dose_mg_m2": 200}],
    ],
)
def test_clinical_refusals_are_structured_without_final_recommendation(drugs):
    response = client.post("/regimens/classify", json={"drugs": drugs})
    assert response.status_code == 200
    data = response.json()
    assert data["refused"]
    assert data["refusal_reasons"]
    assert data["overall_tier"] is None
    assert not data["baseline_prophylaxis_summary"]


@pytest.mark.parametrize(
    "drug",
    [
        {"drug": "cisplatin", "days": []},
        {"drug": "cisplatin", "days": [0]},
        {"drug": "cisplatin", "days": [True]},
        {"drug": "cisplatin", "days": [1.5]},
        {"drug": "cisplatin", "dose_mg_m2": -1},
        {"drug": "cisplatin", "dose_mg_m2": True},
    ],
)
def test_invalid_input_returns_422(drug):
    assert client.post("/regimens/classify", json={"drugs": [drug]}).status_code == 422


def test_unified_agent_exposes_the_same_story1_api():
    from aimesis_agent.main import app as agent_app

    unified = TestClient(agent_app)
    assert unified.get("/regimens").status_code == 200
    response = unified.post(
        "/regimens/classify", json={"drugs": [{"drug": "vincristine"}]}
    )
    assert response.json()["overall_tier"] == "Low"


def test_agent_tool_preserves_days_and_refuses_missing_dose():
    from aimesis_agent.tools import classify_regimen_emetogenicity

    result = classify_regimen_emetogenicity(
        ["ifosfamide", "etoposide"], drug_days={"ifosfamide": [1], "etoposide": [2]}
    )
    assert result["overall_tier"] == "Moderate"
    assert not result["combination_elevated"]
    result = classify_regimen_emetogenicity(
        ["cyclophosphamide"], strict_missing_dose=False
    )
    assert result["refused"]
    assert classify_regimen_emetogenicity(["cisplatin"], drug_days={"cisplatin": []})[
        "refused"
    ]


def test_full_evaluation_preserves_story1_daily_results():
    response = client.post(
        "/episodes",
        json={
            "regimen_agents": ["ifosfamide", "etoposide"],
            "patient_age_years": 13,
            "patient_weight_kg": 44,
            "bsa_m2": 1.38,
        },
    )
    assert response.status_code == 200
    from aimesis_agent.main import app as agent_app

    result = (
        TestClient(agent_app)
        .post(
            "/agui/evaluate",
            json={
                "drug_list": ["ifosfamide", "etoposide"],
                "drug_days": {"ifosfamide": [1], "etoposide": [2]},
                "patient_age_years": 13,
                "patient_weight_kg": 44,
                "bsa_m2": 1.38,
            },
        )
        .json()["plan"]
    )
    assert result["overall_tier"] == "Moderate"
    assert result["per_day_tier"] == {"1": "Moderate", "2": "Low"}
    assert result["per_day_combination_rules"] == {}


def test_repeated_drug_rows_support_different_doses_on_different_days():
    response = client.post(
        "/regimens/classify",
        json={
            "drugs": [
                {"drug": "cytarabine", "dose_mg_m2": 100, "days": [1]},
                {"drug": "cytarabine", "dose_mg_m2": 3000, "days": [2]},
            ]
        },
    )
    data = response.json()
    assert data["per_day_tier"] == {"1": "Low", "2": "High"}
    assert len(data["per_drug"]) == 2


def test_existing_episode_api_preserves_actual_treatment_days():
    response = client.post(
        "/episodes",
        json={
            "regimen_agents": ["ifosfamide", "etoposide"],
            "drug_days": {"ifosfamide": [1], "etoposide": [2]},
            "patient_age_years": 13,
            "patient_weight_kg": 44,
            "bsa_m2": 1.38,
        },
    )
    result = response.json()["uza_evaluation"]
    assert result["overall_tier"] == "Moderate"
    assert not result["combination_elevated"]


def test_full_evaluator_refuses_invalid_schedules_instead_of_crashing():
    from aimesis_rules import evaluate_uza_cinv_policy_v2

    result = evaluate_uza_cinv_policy_v2(["cisplatin"], drug_days={"cisplatin": []})
    assert result["refused"]
    assert result["refusal_reasons"]


def test_rebased_recommendation_api_preserves_story1_route_input():
    from aimesis_agent.main import app as agent_app

    response = TestClient(agent_app).post(
        "/recommendation",
        json={
            "regimen_agents": ["methotrexate"],
            "drug_routes": {"methotrexate": "IT"},
            "patient_age_years": 13,
            "patient_weight_kg": 44,
            "bsa_m2": 1.38,
        },
    )
    assert response.status_code == 200
    assert response.json()["overall_tier"] == "Low"
    assert response.json()["per_drug_details"][0]["route"] == "IT"
