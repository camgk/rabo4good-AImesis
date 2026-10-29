"""POST /cycles/evaluate -- stateless plan evaluation (AI disabled)."""

import pytest
from fastapi.testclient import TestClient

from aimesis_mock_api.demo_data import load_demo_data
from aimesis_mock_api.main import create_app
from aimesis_mock_api.store import MemoryStore

PW = "aimesis-demo"


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.setenv("AIMESIS_AI_DISABLED", "1")
    s = MemoryStore()
    load_demo_data(s.db, log=lambda *_: None)
    with TestClient(create_app(s)) as c:
        yield c


def _auth(client, email="oncologist@demo.aimesis.app"):
    r = client.post("/auth/login", json={"email": email, "password": PW})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


def _all_patient():
    return {
        "id": "NEW-test-1",
        "alias": "Test ALL",
        "age": 6,
        "sex": "M",
        "diagnosis": "Acute lymphoblastic leukaemia",
        "diagnosisGroup": "ALL",
        "protocol": "ALLTogether",
        "cycle": "C1",
        "cycleStart": "2026-10-29",
        "language": "nl",
        "weightKg": 20,
        "heightCm": 115,
        "bsaM2": None,
        "chemo": [{"drug": "cyclophosphamide", "doseMgM2": 1000, "days": [1]}],
        "activeMeds": [],
        "history": [],
        "riskFactors": {"canSwallowTablets": True, "preferredRoute": "oral_tablet", "anticipatory": False,
                        "priorNauseaNote": None},
    }


def test_evaluate_all_blocks_dex_and_computes_bsa(client):
    r = client.post("/cycles/evaluate", json={"patient": _all_patient()}, headers=_auth(client))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["ai"] is None and body["aiError"]
    plan = body["plan"]
    assert plan["patientId"] == "NEW-test-1"
    assert plan["dexamethasone"]["blocked"] is True
    assert plan["overallTier"]
    assert not any(a["drug"] == "dexamethasone" for a in plan["antiemetics"])


def test_evaluate_bsa_computed_on_patient(client):
    from aimesis_mock_api.main import evaluate_patient

    patient, plan = evaluate_patient(_all_patient())
    assert patient.bsa_m2 == 0.8
    assert plan.patient_id == "NEW-test-1"


def test_evaluate_requires_clinician(client):
    r = client.post("/cycles/evaluate", json={"patient": _all_patient()},
                    headers=_auth(client, "parent.casus2@demo.aimesis.app"))
    assert r.status_code == 403


def test_evaluate_rejects_bad_body(client):
    r = client.post("/cycles/evaluate", json={"nope": 1}, headers=_auth(client))
    assert r.status_code in (400, 422)


def test_evaluate_accepts_null_optional_fields(client):
    """The web cycle flow leaves start date, protocol and sex optional."""
    body = {"patient": {
        "id": "NEW-X", "alias": "Casus 9", "age": 7, "sex": None, "diagnosis": "Ewing sarcoma",
        "diagnosisGroup": None, "protocol": None, "cycle": "Cycle 1", "cycleStart": None,
        "language": "nl", "weightKg": 22, "heightCm": 120, "bsaM2": None,
        "chemo": [{"drug": "ifosfamide", "doseMgM2": 1800, "days": [1, 2, 3]}],
        "activeMeds": [], "history": [],
        "riskFactors": {"canSwallowTablets": True, "preferredRoute": "oral_tablet", "anticipatory": False},
    }}
    r = client.post("/cycles/evaluate", json=body, headers=_auth(client))
    assert r.status_code == 200, r.text
    assert r.json()["plan"]["overallTier"] in ("moderate", "high")
