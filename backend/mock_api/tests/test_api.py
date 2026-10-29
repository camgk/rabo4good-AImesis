"""API tests against the in-memory store (STORE=memory)."""

import pytest
from fastapi.testclient import TestClient

from aimesis_mock_api.main import create_app
from aimesis_mock_api.store import MemoryStore

PW = "aimesis-demo"


@pytest.fixture()
def client():
    app = create_app(MemoryStore())
    with TestClient(app) as c:
        yield c


def login(client, email):
    r = client.post("/auth/login", json={"email": email, "password": PW})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}, r.json()["account"]


ONC = "oncologist@demo.aimesis.app"
NURSE = "nurse@demo.aimesis.app"
PHARM = "pharmacist@demo.aimesis.app"
TEEN1 = "teen.casus1@demo.aimesis.app"
PARENT2 = "parent.casus2@demo.aimesis.app"
PARENT3 = "parent.casus3@demo.aimesis.app"


def test_health_and_demo_accounts(client):
    assert client.get("/healthz").json() == {"ok": True}
    accs = client.get("/auth/demo-accounts").json()
    assert len(accs) == 6
    assert set(accs[0]) == {"email", "role", "displayName"}


@pytest.mark.parametrize(
    "email,role,n",
    [(ONC, "oncologist", 4), (NURSE, "nurse", 4), (PHARM, "pharmacist", 4), (TEEN1, "patient", 1), (PARENT2, "parent", 1), (PARENT3, "parent", 1)],
)
def test_login_each_role(client, email, role, n):
    h, acc = login(client, email)
    assert acc["role"] == role
    assert set(acc) == {"id", "email", "role", "displayName", "patientIds"}
    assert client.get("/me", headers=h).json()["email"] == email
    pts = client.get("/patients", headers=h).json()
    assert len(pts) == n
    assert set(pts[0]) == {
        "id", "alias", "age", "sex", "diagnosis", "protocol", "cycle", "cycleStart", "overallTier", "planStatus", "language",
    }


def test_wrong_password(client):
    r = client.post("/auth/login", json={"email": ONC, "password": "nope"})
    assert r.status_code == 401
    assert "error" in r.json()


def test_missing_token_401(client):
    r = client.get("/patients")
    assert r.status_code == 401
    assert r.json() == {"error": "Missing bearer token"}
    assert client.get("/me", headers={"Authorization": "Bearer junk"}).status_code == 401


def test_family_only_own_patient(client):
    h, _ = login(client, PARENT2)
    assert client.get("/patients/casus-2", headers=h).status_code == 200
    for path in ["/patients/casus-1", "/patients/casus-1/passport?lang=nl", "/patients/casus-1/episodes"]:
        r = client.get(path, headers=h)
        assert r.status_code == 403, path
        assert "error" in r.json()
    # family cannot read the clinician plan
    assert client.get("/patients/casus-2/plan", headers=h).status_code == 403


def test_patient_shape(client):
    h, _ = login(client, ONC)
    p = client.get("/patients/casus-1", headers=h).json()
    assert p["bsaM2"] == 1.52 and p["pairingCode"] == "C1-NBL2"
    assert p["chemo"][0] == {"drug": "vincristine", "doseMgM2": 1.5, "days": [1]}
    assert p["riskFactors"]["preferredRoute"] == "oral_tablet"
    assert p["overallTier"] == "high"


def test_submit_then_approve(client):
    onc, _ = login(client, ONC)
    ph, _ = login(client, PHARM)
    # pharmacist cannot submit, oncologist cannot approve
    assert client.post("/patients/casus-1/plan/submit", headers=ph).status_code == 403
    assert client.post("/patients/casus-1/plan/approve", headers=onc, json={}).status_code == 403
    r = client.post("/patients/casus-1/plan/submit", headers=onc)
    assert r.status_code == 200
    plan = r.json()
    assert plan["status"] == "awaiting_pharmacist"
    assert plan["signoffs"]["oncologist"]["by"] == "Oncologist (demo)"
    assert plan["signoffs"]["pharmacist"] is None
    r = client.post("/patients/casus-1/plan/approve", headers=ph, json={"comment": "OK"})
    plan = r.json()
    assert plan["status"] == "approved"
    assert plan["signoffs"]["pharmacist"]["by"] == "Hospital pharmacist (demo)"
    assert plan["comments"][0]["text"] == "OK" and plan["comments"][0]["role"] == "pharmacist"
    pp = client.get("/patients/casus-1/passport?lang=en", headers=onc).json()
    assert pp["signedOff"] is True and pp["status"] == "approved"
    # risk-factor change resets to draft
    nurse, _ = login(client, NURSE)
    r = client.put(
        "/patients/casus-1/risk-factors",
        headers=nurse,
        json={"canSwallowTablets": False, "preferredRoute": "oral_tablet", "anticipatory": False},
    )
    plan = r.json()
    assert plan["status"] == "draft"
    assert plan["signoffs"] == {"oncologist": None, "pharmacist": None}
    assert plan["antiemetics"][0]["route"] == "oral_liquid"
    assert client.put("/patients/casus-1/risk-factors", headers=ph, json={}).status_code == 403


def test_return_with_comment(client):
    onc, _ = login(client, ONC)
    ph, _ = login(client, PHARM)
    client.post("/patients/casus-2/plan/submit", headers=onc)
    plan = client.post("/patients/casus-2/plan/return", headers=ph, json={"comment": "Check route"}).json()
    assert plan["status"] == "returned"
    assert plan["comments"][-1]["text"] == "Check route"
    r = client.post("/patients/casus-2/plan/return", headers=ph, json={})
    assert r.status_code == 422 and "error" in r.json()


def test_episode_changes_plan(client):
    fam, acc = login(client, PARENT2)
    onc, _ = login(client, ONC)
    before = client.get("/patients/casus-2/plan", headers=onc).json()
    assert before["episodesSummary"] == {"currentCycle": [], "priorNauseaDays": []}
    assert before["antiemetics"][0]["frequency"] == "2x/d"
    r = client.post("/patients/casus-2/episodes", headers=fam, json={"type": "vomiting", "severity": 3, "at": "2026-10-30T09:15:00Z"})
    assert r.status_code == 201
    ep = r.json()
    assert ep["cycleDay"] == 2 and ep["loggedBy"] == acc["id"] and ep["loggedByRole"] == "parent"
    assert set(ep) == {"id", "patientId", "type", "severity", "at", "cycleDay", "loggedBy", "loggedByRole"}
    after = client.get("/patients/casus-2/plan", headers=onc).json()
    assert after["episodesSummary"]["currentCycle"] == [{"day": 2, "nausea": 0, "vomiting": 1}]
    assert after["episodesSummary"]["priorNauseaDays"] == [2]
    assert after["antiemetics"][0]["frequency"] == "3x/d"
    eps = client.get("/patients/casus-2/episodes", headers=fam).json()
    assert len(eps) == 1
    # family cannot log for someone else
    assert client.post("/patients/casus-1/episodes", headers=fam, json={"type": "nausea"}).status_code == 403


def test_passport_languages(client):
    h, _ = login(client, PARENT2)
    fr = client.get("/patients/casus-2/passport?lang=fr", headers=h).json()
    assert fr["lang"] == "fr"
    assert fr["title"].startswith("Passeport")
    assert fr["days"][0]["label"] == "Jour 1"
    assert any("Ondansétron" in i["medicine"] for i in fr["days"][0]["items"])
    assert any("sirop" in i["route"] for i in fr["days"][0]["items"])
    assert "Fièvre de 38,5 °C ou plus" in fr["warningSigns"]
    assert all(r["language"] == "fr" for r in fr["resources"]) and 0 < len(fr["resources"]) <= 5
    assert fr["wardPhone"] == "+32 3 000 00 00"
    assert fr["signedOff"] is False
    nl = client.get("/patients/casus-2/passport?lang=nl", headers=h).json()
    assert nl["days"][0]["label"] == "Dag 1"
    en = client.get("/patients/casus-2/passport?lang=en", headers=h).json()
    assert any("cannot keep fluids down for more than 6 hours" in w for w in en["warningSigns"])
    assert client.get("/patients/casus-2/passport?lang=xx", headers=h).status_code == 400


def test_passport_times_casus1(client):
    h, _ = login(client, TEEN1)
    pp = client.get("/patients/casus-1/passport?lang=en", headers=h).json()
    d1 = pp["days"][0]
    times = [(i["time"], i["medicine"].split(" ")[0]) for i in d1["items"]]
    assert ("08:00", "Ondansetron") in times and ("16:00", "Ondansetron") in times and ("00:00", "Ondansetron") in times
    assert ("20:00", "Olanzapine") in times
    assert d1["date"] == "2026-09-25"


def test_pairing(client):
    h, acc = login(client, PARENT3)
    assert client.get("/patients/casus-4", headers=h).status_code == 403
    r = client.post("/pairing", headers=h, json={"code": "c4-ddi7"})
    assert r.status_code == 200 and r.json()["id"] == "casus-4"
    assert client.get("/patients/casus-4", headers=h).status_code == 200
    assert client.post("/pairing", headers=h, json={"code": "NOPE"}).status_code == 404
    onc, _ = login(client, ONC)
    assert client.post("/pairing", headers=onc, json={"code": "C1-NBL2"}).status_code == 403


def test_resources(client):
    assert len(client.get("/resources").json()) == 27
    de = client.get("/resources?lang=de").json()
    assert len(de) == 1 and set(de[0]) == {"institution", "title", "format", "language", "url", "effort", "effortNote"}


def test_admin_reset(client):
    fam, _ = login(client, PARENT2)
    client.post("/patients/casus-2/episodes", headers=fam, json={"type": "nausea"})
    assert client.post("/admin/reset").status_code == 403
    assert client.post("/admin/reset", headers={"X-Demo-Reset": "test-secret"}).json() == {"ok": True}
    fam, _ = login(client, PARENT2)
    assert client.get("/patients/casus-2/episodes", headers=fam).json() == []


def test_unknown_patient_404(client):
    h, _ = login(client, ONC)
    r = client.get("/patients/nope/plan", headers=h)
    assert r.status_code == 404 and r.json() == {"error": "Patient 'nope' not found"}
    assert client.get("/no-such-route").json() == {"error": "Not Found"}
