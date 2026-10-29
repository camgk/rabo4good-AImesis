"""Demo-data load/clear logic, tags, and the Firestore document shapes (schema-checked)."""

import json
from pathlib import Path

import jsonschema
import pytest
from fastapi.testclient import TestClient

from aimesis_mock_api import demo_data
from aimesis_mock_api.demo_data import clear_demo_data, find_demo_documents, load_demo_data
from aimesis_mock_api.main import create_app
from aimesis_mock_api.store import MemoryStore

SCHEMAS = Path(__file__).resolve().parents[3] / "contracts" / "schemas"
QUIET = {"log": lambda *_: None}
PW = "aimesis-demo"
P1, P2, P3 = "PAT-2026-0001", "PAT-2026-0002", "PAT-2026-0003"


def schema(name):
    return json.loads((SCHEMAS / f"{name}.schema.json").read_text())


def ids(db, collection):
    return sorted(s.id for s in db.collection(collection).stream())


def login(client, email):
    r = client.post("/auth/login", json={"email": email, "password": PW})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


@pytest.fixture()
def store():
    return MemoryStore()


def add_untagged_patient(db, pid="PAT-2026-0099"):
    """A non-demo patient (no tags) with its own passport + episode: clear must never touch these."""
    doc = {**demo_data.patients()[2], "patient_id": pid, "display_pseudonym": "Real-ish", "tags": []}
    db.collection("patients").document(pid).set(doc)
    db.collection("passports").document("PSP-2026-0099-C3").set({"passport_id": "PSP-2026-0099-C3", "patient_id": pid})
    db.collection("episodes").document("ep-keep").set(
        {"episode_id": "ep-keep", "patient_id": pid, "passport_id": "PSP-2026-0099-C3",
         "timestamp": "2026-10-29T10:00:00Z", "symptom_type": "nausea", "severity": "mild"}
    )
    return pid


# --------------------------------------------------------------------------- service behaviour
def test_no_seed_on_start_and_demo_accounts_empty_before_load(store, monkeypatch):
    monkeypatch.delenv("LOAD_DEMO_ON_START", raising=False)
    with TestClient(create_app(store)) as c:
        assert c.get("/auth/demo-accounts").json() == []
        assert c.post("/auth/login", json={"email": "oncologist@demo.aimesis.app", "password": PW}).status_code == 401
        assert c.post("/admin/reset", headers={"X-Demo-Reset": "test-secret"}).status_code in (404, 405)
        load_demo_data(store.db, **QUIET)
        accs = c.get("/auth/demo-accounts").json()
        assert len(accs) == 6 and accs[0]["role"] == "oncologist"


def test_demo_accounts_only_tagged(store):
    load_demo_data(store.db, **QUIET)
    store.db.collection("accounts").document("acc-real").set(
        {"account_id": "acc-real", "email": "real@example.org", "role": "nurse", "display_name": "Real", "tags": []}
    )
    with TestClient(create_app(store)) as c:
        emails = [a["email"] for a in c.get("/auth/demo-accounts").json()]
    assert "real@example.org" not in emails and len(emails) == 6


def test_load_demo_on_start_memory_only(store, monkeypatch):
    monkeypatch.setenv("LOAD_DEMO_ON_START", "true")
    monkeypatch.setenv("STORE", "memory")
    with TestClient(create_app(store)) as c:
        assert len(c.get("/auth/demo-accounts").json()) == 6


def test_patients_have_tags_and_tag_filter(store):
    load_demo_data(store.db, **QUIET)
    add_untagged_patient(store.db)
    with TestClient(create_app(store)) as c:
        h = login(c, "oncologist@demo.aimesis.app")
        allp = c.get("/patients", headers=h).json()
        assert [p["id"] for p in allp] == ["PAT-2026-0001", "PAT-2026-0002", "PAT-2026-0003", "PAT-2026-0004", "PAT-2026-0099"]
        assert allp[0]["tags"] == ["demo"] and allp[0]["alias"] == "Casus 1"
        assert allp[-1]["tags"] == []
        demo = c.get("/patients?tag=demo", headers=h).json()
        assert [p["id"] for p in demo] == demo_data.DEMO_PATIENT_IDS
        assert c.get("/patients?tag=nope", headers=h).json() == []
        assert c.get(f"/patients/{P1}", headers=h).json()["tags"] == ["demo"]
        # family filter still applies on top of the tag filter
        fam = login(c, "parent.casus2@demo.aimesis.app")
        assert [p["id"] for p in c.get("/patients?tag=demo", headers=fam).json()] == [P2]


def test_neutral_advisory_and_disclaimer(store):
    load_demo_data(store.db, **QUIET)
    with TestClient(create_app(store)) as c:
        h = login(c, "oncologist@demo.aimesis.app")
        assert c.get(f"/patients/{P1}/plan", headers=h).json()["advisory"] == "Advisory only — requires clinician sign-off."
        en = c.get(f"/patients/{P1}/passport?lang=en", headers=h).json()
        assert en["disclaimer"] == "This schedule was prepared by your care team. Call the ward if you are worried."
        for lang in ("nl", "fr", "en"):
            d = c.get(f"/patients/{P1}/passport?lang={lang}", headers=h).json()["disclaimer"].lower()
            assert "demo" not in d and "démonstration" not in d


# --------------------------------------------------------------------------- load
def test_load_is_idempotent(store):
    db = store.db
    first = load_demo_data(db, **QUIET)
    assert first["patients"] == demo_data.DEMO_PATIENT_IDS
    assert first["passports"] == ["PSP-2026-0001-C4", "PSP-2026-0002-C1", "PSP-2026-0003-C3", "PSP-2026-0004-C1"]
    snapshot = {c: ids(db, c) for c in ("patients", "passports", "accounts", "reference_resources", "episodes")}
    created = db.collection("patients").document(P1).get().to_dict()["created_at"]
    second = load_demo_data(db, **QUIET)
    assert second["passports"] == []  # existing passports (workflow state) are kept
    assert {c: ids(db, c) for c in snapshot} == snapshot
    assert len(snapshot["reference_resources"]) == 27 and len(snapshot["accounts"]) == 6
    assert db.collection("patients").document(P1).get().to_dict()["created_at"] == created


def test_load_keeps_workflow_unless_reset(store):
    load_demo_data(store.db, **QUIET)
    with TestClient(create_app(store)) as c:
        onc = login(c, "oncologist@demo.aimesis.app")
        assert c.post(f"/patients/{P3}/plan/submit", headers=onc).status_code == 200
        fam = login(c, "parent.casus3@demo.aimesis.app")
        assert c.post(f"/patients/{P3}/episodes", headers=fam, json={"type": "nausea"}).status_code == 201
        load_demo_data(store.db, **QUIET)
        assert c.get(f"/patients/{P3}/plan", headers=onc).json()["status"] == "awaiting_pharmacist"
        assert len(c.get(f"/patients/{P3}/episodes", headers=onc).json()) == 1
        load_demo_data(store.db, reset=True, **QUIET)
        onc = login(c, "oncologist@demo.aimesis.app")
        assert c.get(f"/patients/{P3}/plan", headers=onc).json()["status"] == "draft"
        assert c.get(f"/patients/{P3}/episodes", headers=onc).json() == []


# --------------------------------------------------------------------------- clear
def test_clear_is_dry_run_by_default(store):
    db = store.db
    load_demo_data(db, **QUIET)
    found = clear_demo_data(db, **QUIET)
    assert found["patients"] == demo_data.DEMO_PATIENT_IDS and len(found["accounts"]) == 6
    assert ids(db, "patients") == demo_data.DEMO_PATIENT_IDS  # nothing deleted


def test_clear_removes_only_tagged_docs(store):
    db = store.db
    load_demo_data(db, **QUIET)
    keep = add_untagged_patient(db)
    # An untagged episode / passport belonging to a demo patient (e.g. written by backend/api) goes too.
    db.collection("episodes").document("ep-orphan").set(
        {"episode_id": "ep-orphan", "patient_id": P1, "passport_id": "PSP-2026-0001-C4",
         "timestamp": "2026-10-29T08:00:00Z", "symptom_type": "vomiting", "severity": "severe"}
    )
    db.collection("passports").document("PSP-2026-0001-C3").set({"passport_id": "PSP-2026-0001-C3", "patient_id": P1})
    with TestClient(create_app(store)) as c:
        fam = login(c, "parent.casus2@demo.aimesis.app")
        assert c.post(f"/patients/{P2}/episodes", headers=fam, json={"type": "nausea", "severity": 2}).status_code == 201

    found = find_demo_documents(db)
    assert "ep-orphan" in found["episodes"] and "PSP-2026-0001-C3" in found["passports"]
    clear_demo_data(db, dry_run=False, **QUIET)

    assert ids(db, "patients") == [keep]
    assert ids(db, "passports") == ["PSP-2026-0099-C3"]
    assert ids(db, "episodes") == ["ep-keep"]
    assert ids(db, "accounts") == []
    assert len(ids(db, "reference_resources")) == 27  # reference data is never cleared
    assert all(n <= demo_data.BATCH_LIMIT for n in db.batch_sizes)
    # and clearing again is a no-op
    assert all(v == [] for v in clear_demo_data(db, dry_run=False, **QUIET).values())


def test_clear_batches_at_most_400(store):
    db = store.db
    load_demo_data(db, **QUIET)
    for i in range(450):
        db.collection("episodes").document(f"e{i:03d}").set({"episode_id": f"e{i:03d}", "patient_id": P1, "tags": ["demo"]})
    clear_demo_data(db, dry_run=False, **QUIET)
    assert ids(db, "episodes") == [] and max(db.batch_sizes) == 400


# --------------------------------------------------------------------------- document shapes
def test_patient_docs_match_schema():
    s = schema("patient_context")
    for p in demo_data.patients():
        jsonschema.validate(p, s)
        assert p["tags"] == ["demo"]
    c1 = demo_data.patients()[0]
    assert c1["patient_id"] == P1 and c1["current_cycle"] == 4 and c1["cycle_label"] == "B4"
    assert c1["cycle_start_date"] == "2026-10-28"
    assert [p["current_cycle"] for p in demo_data.patients()] == [4, 1, 3, 1]


def test_episode_doc_shape_and_severity_mapping(store):
    load_demo_data(store.db, **QUIET)
    s = schema("episode")
    with TestClient(create_app(store)) as c:
        fam = login(c, "parent.casus2@demo.aimesis.app")
        for sev in (1, 2, 3, 4, 5, None):
            body = {"type": "vomiting", "at": "2026-10-30T09:15:00+01:00"}
            if sev is not None:
                body["severity"] = sev
            r = c.post(f"/patients/{P2}/episodes", headers=fam, json=body)
            assert r.status_code == 201 and r.json()["severity"] == sev
    docs_ = [s_.to_dict() for s_ in store.db.collection("episodes").stream()]
    assert len(docs_) == 6
    by_score = {d["severity_score"]: d for d in docs_}
    assert {k: v["severity"] for k, v in by_score.items()} == {
        1: "mild", 2: "mild", 3: "moderate", 4: "severe", 5: "severe", None: "mild",
    }
    d = by_score[3]
    jsonschema.validate(d, s)
    assert d["patient_id"] == P2 and d["passport_id"] == "PSP-2026-0002-C1"
    assert d["symptom_type"] == "vomiting" and d["reported_by"] == "parent"
    assert d["timestamp"] == "2026-10-30T08:15:00Z" and d["cycle_day"] == 2
    assert d["logged_by_account"] == "acc-parent2" and d["tags"] == ["demo"]
    assert len(d["episode_id"]) == 36  # uuid4


def test_passport_doc_signoffs_and_status(store):
    load_demo_data(store.db, **QUIET)
    s = schema("passport")
    pp_ref = store.db.collection("passports").document("PSP-2026-0001-C4")
    draft = pp_ref.get().to_dict()
    jsonschema.validate(draft, s)
    assert draft["status"] == "draft" and draft["plan_status"] == "draft" and draft["tags"] == ["demo"]
    assert draft["emetogenicity_tier"] == "HIGH"
    with TestClient(create_app(store)) as c:
        onc = login(c, "oncologist@demo.aimesis.app")
        ph = login(c, "pharmacist@demo.aimesis.app")
        c.post(f"/patients/{P1}/plan/submit", headers=onc)
        mid = pp_ref.get().to_dict()
        assert mid["status"] == "draft" and mid["plan_status"] == "awaiting_pharmacist"
        assert mid["signoffs"]["oncologist"]["signed"] is True
        assert mid["signoffs"]["oncologist"]["clinician_name"] == "Oncologist (demo)"
        assert mid["signoffs"]["clinical_pharmacist"] == {"signed": False}
        c.post(f"/patients/{P1}/plan/approve", headers=ph, json={"comment": "OK"})
        done = pp_ref.get().to_dict()
        jsonschema.validate(done, s)
        assert done["status"] == "active" and done["plan_status"] == "approved"
        assert done["signoffs"]["clinical_pharmacist"]["signed"] is True
        assert done["signoffs"]["clinical_pharmacist"]["clinician_name"] == "Hospital pharmacist (demo)"
        assert done["comments"][0]["text"] == "OK"
        assert {a["drug_name"] for a in done["antiemetic_schedule"]} >= {"Ondansetron", "Aprepitant", "Olanzapine"}
        assert set(done["family_schedule_multilingual"]) == {"nl", "fr", "en"}
        # risk-factor change -> draft again, sign-offs withdrawn
        nurse = login(c, "nurse@demo.aimesis.app")
        c.put(f"/patients/{P1}/risk-factors", headers=nurse,
              json={"canSwallowTablets": False, "preferredRoute": "oral_tablet", "anticipatory": True})
        back = pp_ref.get().to_dict()
        assert back["status"] == "draft" and back["signoffs"]["oncologist"] == {"signed": False}
        assert back["risk_factors"] == {"can_swallow_tablets": False, "preferred_route": "oral_tablet", "anticipatory": True}


def test_passport_written_by_backend_api_is_understood(store):
    """A passport signed via backend/api's PassportStore.sign_off_passport (no plan_status) maps to approved."""
    load_demo_data(store.db, **QUIET)
    ref = store.db.collection("passports").document("PSP-2026-0002-C1")
    doc = ref.get().to_dict()
    doc.pop("plan_status")
    doc["status"] = "active"
    doc["signoffs"]["oncologist"] = {"signed": True, "clinician_name": "Dr. A", "timestamp": "2026-10-29T09:00:00Z", "riziv_inami": ""}
    doc["signoffs"]["clinical_pharmacist"] = {"signed": True, "clinician_name": "Apr. B", "timestamp": "2026-10-29T09:30:00Z", "riziv_inami": ""}
    ref.set(doc)
    with TestClient(create_app(store)) as c:
        h = login(c, "oncologist@demo.aimesis.app")
        plan = c.get(f"/patients/{P2}/plan", headers=h).json()
        assert plan["status"] == "approved" and plan["signoffs"]["pharmacist"]["by"] == "Apr. B"
        assert c.get(f"/patients/{P2}/passport?lang=fr", headers=h).json()["signedOff"] is True


def test_account_and_resource_docs():
    a = demo_data.accounts()
    assert {x["account_id"] for x in a} == {"acc-onc", "acc-nurse", "acc-pharm", "acc-teen1", "acc-parent2", "acc-parent3"}
    assert all(x["tags"] == ["demo"] and len(x["password_hash"]) == 64 for x in a)
    assert next(x for x in a if x["account_id"] == "acc-teen1")["patient_ids"] == [P1]
    r = demo_data.resources()
    assert len(r) == 27 and r[0]["resource_id"] == "res-01" and "tags" not in r[0]
