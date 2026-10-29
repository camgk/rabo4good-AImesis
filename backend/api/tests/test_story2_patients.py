"""Story 2 acceptance: latest record BSA -> exact calculations -> cited interface."""

import copy

import pytest
from aimesis_api.main import app
from aimesis_api.patients import routes
from aimesis_api.patients.service import calculate_patient_dosing
from aimesis_api.patients.store import (
    PatientContextStore,
)
from fastapi.testclient import TestClient

client = TestClient(app)


@pytest.fixture(autouse=True)
def repository(monkeypatch):
    monkeypatch.delenv("USE_FIRESTORE", raising=False)
    store = PatientContextStore()
    monkeypatch.setattr(routes, "patient_store", store)
    return store


def record(**updates):
    return {
        "age_years": 8,
        "weight_kg": 25,
        "bsa_m2": 0.56,
        "bsa_measured_at": "2026-10-27T10:00:00Z",
        "diagnosis": "osteosarcoma",
        "preferred_formulation": "oral_tablet",
        "chemo_regimen": [
            {
                "drug_name": "cisplatin",
                "dose_mg_per_m2": 60,
                "route": "IV",
                "day_numbers": [1],
            }
        ],
        **updates,
    }


def save(**updates):
    response = client.put("/patients/TEST-S2", json=record(**updates))
    assert response.status_code == 200, response.text
    return response.json()


def calculate(options=None):
    response = client.post("/patients/TEST-S2/dosing", json=options or {})
    assert response.status_code == 200, response.text
    return response.json()


def ondansetron(data):
    return data["dosing"]["lines"]["ondansetron"]["calculations"][0]["final_dose"]


def test_latest_bsa_is_selected_by_measurement_time_not_write_order():
    save()
    assert ondansetron(calculate()) == 2.8
    newer = client.put(
        "/patients/TEST-S2",
        json={"bsa_m2": 1, "bsa_measured_at": "2026-10-29T10:00:00Z"},
    )
    assert newer.status_code == 200
    result = calculate()
    assert ondansetron(result) == 5
    assert result["biometrics_used"]["bsa"]["bsa_m2"] == 1
    older = client.put(
        "/patients/TEST-S2",
        json={"bsa_m2": 0.4, "bsa_measured_at": "2026-10-28T10:00:00Z"},
    )
    assert older.status_code == 200
    result = calculate()
    assert ondansetron(result) == 5
    assert (
        result["biometrics_used"]["bsa"]["measured_at"] == "2026-10-29T10:00:00+00:00"
    )
    assert (
        len(client.get("/patients/TEST-S2").json()["patient"]["bsa_measurements"]) == 3
    )


def test_bsa_history_timezones_and_array_order_do_not_change_latest():
    data = record()
    data.pop("bsa_m2")
    data.pop("bsa_measured_at")
    data["bsa_measurements"] = [
        {"bsa_m2": 1, "measured_at": "2026-10-29T09:00:00Z"},
        {"bsa_m2": 0.6, "measured_at": "2026-10-29T10:00:00+02:00"},
    ]
    assert client.put("/patients/TEST-S2", json=data).status_code == 200
    assert ondansetron(calculate()) == 5


def test_calculation_body_cannot_override_the_record_bsa():
    save()
    assert (
        client.post("/patients/TEST-S2/dosing", json={"bsa_m2": 2}).status_code == 422
    )
    assert ondansetron(calculate()) == 2.8


@pytest.mark.parametrize(
    "update",
    [
        {"bsa_m2": 0},
        {"weight_kg": -1},
        {"age_years": True},
        {"bsa_m2": 0.9, "bsa_measured_at": "not-a-date"},
        {"bsa_m2": 0.9, "bsa_measured_at": "2026-10-29T10:00:00"},
        {"bsa_m2": 0.9, "bsa_measured_at": "2026-10-27T10:00:00Z"},
        {"bsa_m2": 0.9, "bsa_measurements": []},
    ],
)
def test_invalid_or_conflicting_record_updates_do_not_replace_valid_bsa(update):
    save()
    assert client.put("/patients/TEST-S2", json=update).status_code == 422
    assert ondansetron(calculate()) == 2.8


def test_unknown_patient_has_no_invented_record_or_dose():
    assert client.post("/patients/MISSING/dosing", json={}).status_code == 404


def test_storage_failure_is_reported_instead_of_using_demo_values(
    monkeypatch, repository
):
    save()

    def fail(patient_id):
        raise RuntimeError("database unavailable")

    monkeypatch.setattr(repository, "get", fail)
    response = client.post("/patients/TEST-S2/dosing", json={})
    assert response.status_code == 503
    assert "dosing" not in response.json()


def test_legacy_scalar_bsa_is_explicit_about_missing_measurement_time(repository):
    p = record()
    p.pop("bsa_measured_at")
    p["patient_id"] = "LEGACY"
    repository._memory["LEGACY"] = p
    result = calculate_patient_dosing("LEGACY", store=repository)
    assert not result["refused"]
    assert result["biometrics_used"]["bsa"]["measured_at"] is None
    assert result["biometrics_used"]["bsa"]["time_basis"] == "unknown"


def test_malformed_latest_bsa_does_not_fall_back_to_an_older_value(repository):
    save()
    repository._memory["TEST-S2"]["bsa_measurements"].append(
        {"bsa_m2": None, "measured_at": "2026-10-30T10:00:00Z"}
    )
    result = calculate()
    assert result["refused"]
    assert result["dosing"] is None


def test_missing_weight_or_diagnosis_prevents_dosing(repository):
    save()
    repository._memory["TEST-S2"].pop("weight_kg")
    result = calculate()
    assert result["refused"]
    assert not result["dosing"]["lines"]
    repository._memory["TEST-S2"]["weight_kg"] = 25
    repository._memory["TEST-S2"].pop("diagnosis")
    assert calculate()["refused"]


def test_workbench_and_formula_source_payload_are_available():
    assert client.get("/dosing").status_code == 200
    save()
    data = calculate()
    assert data["classification"]["overall_tier"] == "High"
    for line in data["dosing"]["lines"].values():
        assert line["citation"].startswith("UZA v2 p.2")
        if line["indicated"]:
            assert line["formula_shown"]
            assert line["calculations"]
            assert all("formula" in calc for calc in line["calculations"])


def test_api_and_agent_use_the_same_record_backed_calculator(monkeypatch, repository):
    from aimesis_agent import tools
    from aimesis_agent.agent import root_agent

    monkeypatch.setattr(tools, "patient_store", repository)
    save()
    via_http = calculate()
    via_tool = tools.get_patient_dosing("TEST-S2")
    assert via_tool["dosing"] == via_http["dosing"]
    assert any(tool.__name__ == "get_patient_dosing" for tool in root_agent.tools)
    assert tools.get_patient_context("TEST-S2")["evaluation_inputs"]["bsa_m2"] == 0.56


def test_unified_backend_exposes_record_and_dosing_routes(repository):
    from aimesis_agent.main import app as unified_app

    unified = TestClient(unified_app)
    assert unified.get("/dosing").status_code == 200
    assert unified.put("/patients/TEST-S2", json=record()).status_code == 200
    assert unified.post("/patients/TEST-S2/dosing", json={}).json()["refused"] is False


def test_record_is_fetched_again_for_each_calculation():
    p = {"patient_id": "REMOTE", **record()}

    class ChangingStore:
        storage_mode = "firestore"
        reads = 0

        def get(self, patient_id):
            self.reads += 1
            result = copy.deepcopy(p)
            result["bsa_m2"] = 0.56 if self.reads == 1 else 1
            return result

    store = ChangingStore()
    first = calculate_patient_dosing("REMOTE", store=store)
    second = calculate_patient_dosing("REMOTE", store=store)
    assert ondansetron(first) == 2.8
    assert ondansetron(second) == 5
    assert store.reads == 2


def test_diagnosis_group_cannot_hide_an_excluded_diagnosis():
    save(diagnosis="ALL", diagnosis_group="solid")
    data = calculate()
    assert not data["dosing"]["lines"]["dexamethasone"]["indicated"]
    assert data["dosing"]["lines"]["aprepitant"]["indicated"]


def test_firestore_records_survive_a_new_repository_instance():
    from google.cloud.firestore import ArrayUnion

    class Snapshot:
        def __init__(self, data):
            self.data = copy.deepcopy(data)
            self.exists = data is not None

        def to_dict(self):
            return self.data

    class Document:
        data = None

        def get(self):
            return Snapshot(self.data)

        def set(self, payload, merge):
            assert merge is True
            previous = self.data or {}
            combined = {**previous, **payload}
            history = payload.get("bsa_measurements")
            assert isinstance(history, ArrayUnion)
            combined["bsa_measurements"] = copy.deepcopy(
                previous.get("bsa_measurements", [])
            )
            for item in history.values:
                if item not in combined["bsa_measurements"]:
                    combined["bsa_measurements"].append(copy.deepcopy(item))
            self.data = combined

    class FirestoreClient:
        doc = Document()

        def collection(self, name):
            assert name == "patients"
            return self

        def document(self, patient_id):
            assert patient_id == "REMOTE"
            return self.doc

    cloud = FirestoreClient()
    first = PatientContextStore(client=cloud)
    first.upsert({"patient_id": "REMOTE", **record()})
    second = PatientContextStore(client=cloud)
    assert ondansetron(calculate_patient_dosing("REMOTE", store=second)) == 2.8
    second.upsert(
        {"patient_id": "REMOTE", "bsa_m2": 1, "bsa_measured_at": "2026-10-29T10:00:00Z"}
    )
    assert ondansetron(calculate_patient_dosing("REMOTE", store=first)) == 5
    assert len(first.get("REMOTE")["bsa_measurements"]) == 2
