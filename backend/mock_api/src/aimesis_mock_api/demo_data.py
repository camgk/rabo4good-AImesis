"""Demo dataset (Casus 1–4, demo accounts, Belgian resources) and the load / clear logic.

Shared by:
- scripts/load_demo_data.py and scripts/clear_demo_data.py (real Firestore, `(default)` database)
- the in-memory store (STORE=memory, LOAD_DEMO_ON_START=true) and the tests (FakeFirestore)

`db` is anything with the google.cloud.firestore.Client surface used here: a real Client or
aimesis_mock_api.fake_firestore.FakeFirestore.

Safety rules of clear_demo_data():
- only documents whose `tags` array contains "demo" (array_contains query) in patients, passports,
  episodes, accounts;
- plus passports/episodes whose `patient_id` belongs to a demo-tagged patient (that patient's data);
- never reference_resources, never anything else. Dry run unless dry_run=False. Batches of <= 400.
"""

from __future__ import annotations

import hashlib
from typing import Any

from . import docs, rules_mock
from .docs import DEMO_TAG, now_iso
from .models import Patient

DEMO_PASSWORD = "aimesis-demo"
BATCH_LIMIT = 400

# Casus N -> PAT-2026-000N
CASUS_IDS = {n: f"PAT-2026-{n:04d}" for n in (1, 2, 3, 4)}
DEMO_PATIENT_IDS = [CASUS_IDS[n] for n in (1, 2, 3, 4)]

# Collections the clear script may touch (reference_resources is deliberately absent).
CLEARABLE = ("patients", "passports", "episodes", "accounts")
PATIENT_OWNED = ("passports", "episodes")


# --------------------------------------------------------------------------- dataset
def _chemo(*rows: tuple[str, float, list[int]]) -> list[dict]:
    return [{"drug_name": d, "dose_mg_per_m2": dose, "day_numbers": days} for d, dose, days in rows]


def _rf(can_swallow: bool, route: str, anticipatory: bool = False) -> dict:
    return {"can_swallow_tablets": can_swallow, "preferred_route": route, "anticipatory": anticipatory}


def _patient(
    n: int,
    *,
    alias: str,
    age: int,
    sex: str,
    weight: float,
    height: float,
    bsa: float,
    diagnosis: str,
    group: str,
    protocol: str,
    current_cycle: int,
    cycle_label: str,
    cycle_start: str,
    chemo: list[dict],
    active_meds: list[str],
    language: str,
    previous_cycles: list[dict],
    risk_factors: dict,
    pairing_code: str,
) -> dict:
    return {
        "patient_id": CASUS_IDS[n],
        "display_pseudonym": alias,
        "age_years": age,
        "weight_kg": weight,
        "bsa_m2": bsa,
        "diagnosis": diagnosis,
        "protocol_name": protocol,
        "current_cycle": current_cycle,
        "chemo_regimen": chemo,
        "history_previous_cycles": docs.history_summary(previous_cycles, risk_factors["anticipatory"]),
        "preferred_formulation": docs.formulation_for_route(risk_factors["preferred_route"]),
        "allergies_and_contraindications": [],
        # ---- extensions (optional properties in patient_context.schema.json)
        "tags": [DEMO_TAG],
        "sex": sex,
        "height_cm": height,
        "diagnosis_group": group,
        "cycle_label": cycle_label,
        "cycle_start_date": cycle_start,
        "active_medications": active_meds,
        "preferred_language": language,
        "pairing_code": pairing_code,
        "previous_cycles": previous_cycles,
        "risk_factors": risk_factors,
    }


def patients() -> list[dict]:
    """The four fictional demo patients as `patients/{patient_id}` docs (without timestamps)."""
    return [
        _patient(
            1,
            alias="Casus 1",
            age=16, sex="F", weight=52, height=160, bsa=1.52,
            diagnosis="Neuroblastoma", group="solid", protocol="HR-NBL2 · RAPID COJEC",
            current_cycle=4, cycle_label="B4",
            cycle_start="2026-10-28",  # demo shift so that today (29/10) is cycle day 2 (case doc: 25/09)
            chemo=_chemo(("Vincristine", 1.5, [1]), ("Cisplatin", 80, [1])),
            active_meds=[], language="nl",
            previous_cycles=[
                {
                    "cycle_label": "B3",
                    "date": "2026-09-05",
                    "antiemetics": "Ondansetron 2x/d + aprepitant + dexamethasone + olanzapine",
                    "nausea_days": [2],
                    "vomiting_days": [],
                    "note": "Toch nausea gehad op dag 2 (toernota)",
                }
            ],
            risk_factors=_rf(True, "oral_tablet"),
            pairing_code="C1-NBL2",
        ),
        _patient(
            2,
            alias="Casus 2",
            age=2, sex="M", weight=12.5, height=87, bsa=0.55,
            diagnosis="Acute lymphoblastic leukaemia (ALL)", group="ALL", protocol="ALLTogether1 · Induction B",
            current_cycle=1, cycle_label="Day 8", cycle_start="2026-10-29",
            chemo=_chemo(("Vincristine", 1.5, [1]), ("Daunorubicin", 30, [1])),
            active_meds=[], language="fr",
            previous_cycles=[
                {
                    "cycle_label": "Induction B D1",
                    "nausea_days": [],
                    "vomiting_days": [],
                    "note": "Geen misselijkheid of braken bij vorige toediening",
                }
            ],
            risk_factors=_rf(False, "oral_liquid"),
            pairing_code="C2-ALL8",
        ),
        _patient(
            3,
            alias="Casus 3",
            age=14, sex="M", weight=45, height=158, bsa=1.41,
            diagnosis="Ewing sarcoma", group="solid", protocol="iEuroEwing · IE",
            current_cycle=3, cycle_label="IE #3", cycle_start="2026-10-29",
            chemo=_chemo(("Ifosfamide", 1800, [1, 2, 3, 4, 5]), ("Etoposide", 100, [1, 2, 3, 4, 5])),
            active_meds=[], language="nl",
            previous_cycles=[
                {
                    "cycle_label": "IE #2",
                    "nausea_days": [4],
                    "vomiting_days": [4],
                    "note": "Misselijkheid en braken op dag 4",
                }
            ],
            risk_factors=_rf(True, "oral_tablet"),
            pairing_code="C3-IE03",
        ),
        _patient(
            4,
            alias="Casus 4 · interactions",
            age=7, sex="M", weight=22, height=120, bsa=0.85,
            diagnosis="ALL", group="ALL", protocol="ALLTogether1 · Consolidation",
            current_cycle=1, cycle_label="C1", cycle_start="2026-10-29",
            chemo=_chemo(("Cyclophosphamide", 1600, [1]), ("Vincristine", 1.5, [1])),
            active_meds=["voriconazole"], language="en",
            previous_cycles=[],
            risk_factors=_rf(False, "oral_liquid"),
            pairing_code="C4-DDI7",
        ),
    ]


def hash_password(pw: str) -> str:
    """sha256 hex, same as auth.hash_password (kept here so the scripts don't need fastapi/jwt)."""
    return hashlib.sha256(pw.encode("utf-8")).hexdigest()


def accounts() -> list[dict]:
    """The six demo login accounts as `accounts/{account_id}` docs."""
    pw = hash_password(DEMO_PASSWORD)

    def acc(id_: str, email: str, role: str, name: str, pids: list[str]) -> dict:
        return {
            "account_id": id_,
            "email": email,
            "role": role,
            "display_name": name,
            "patient_ids": list(pids),
            "password_hash": pw,
            "tags": [DEMO_TAG],
        }

    return [
        acc("acc-onc", "oncologist@demo.aimesis.app", "oncologist", "Oncologist (demo)", DEMO_PATIENT_IDS),
        acc("acc-nurse", "nurse@demo.aimesis.app", "nurse", "Nurse specialist (demo)", DEMO_PATIENT_IDS),
        acc("acc-pharm", "pharmacist@demo.aimesis.app", "pharmacist", "Hospital pharmacist (demo)", DEMO_PATIENT_IDS),
        acc("acc-teen1", "teen.casus1@demo.aimesis.app", "patient", "Casus 1 · teen (demo)", [CASUS_IDS[1]]),
        acc("acc-parent2", "parent.casus2@demo.aimesis.app", "parent", "Casus 2 · parent (demo)", [CASUS_IDS[2]]),
        acc("acc-parent3", "parent.casus3@demo.aimesis.app", "parent", "Casus 3 · parent (demo)", [CASUS_IDS[3]]),
    ]


_RESOURCE_ROWS = [
    ("Fondation contre le Cancer", "La chimiothérapie", "PDF", "fr", "https://www.cancer.be/ressource/la-chimiotherapie/", "low", "Direct French PDF download"),
    ("Stichting tegen Kanker", "Chemotherapie", "PDF", "nl", "https://www.cancer.be/ressource/chemotherapie/", "low", "Direct Dutch PDF download"),
    ("Stichting tegen Kanker", "Die Chemotherapie", "PDF", "de", "https://www.cancer.be/ressource/chemotherapie-de/", "low", "Direct German PDF download"),
    ("CHU de Liège", "Les nausées et les vomissements", "PDF", "fr", "https://www.chuliege.be/cms/c_60648/fr/broch-a5-les-nausees-et-les-vomissements-2024-pp", "low", "Direct clinical PDF download"),
    ("ZAS (Ziekenhuis aan de Stroom)", "Chemotherapie: Informatie voor patiënten", "PDF", "nl", "https://media.zas.be/m/1be42769d38ec4ee/original/Chemotherapie.pdf", "low", "Direct regional PDF download"),
    ("AZ Org", "Chemotherapie... wat nu?", "PDF", "nl", "https://www.azorg.be/sites/default/files/patient_brochures/01016-NL.pdf", "low", "Direct clinical PDF download"),
    ("Fondation contre le Cancer", "Nausées et vomissements", "Web page", "fr", "https://www.cancer.be/les-cancers/effets-secondaires/nausees-et-vomissements", "low", "Direct web article"),
    ("Stichting tegen Kanker", "Misselijkheid en braken", "Web page", "nl", "https://www.cancer.be/kanker/bijwerkingen/misselijkheid-en-braken", "low", "Direct web article"),
    ("AZ Groeninge", "Effets indésirables : nausées et vomissements", "Web page", "fr", "https://www.azgroeninge.be/fr/blogs/bijwerkingen-chemotherapie/effets-indesirables-chimiotherapie-nausees-et-vomissements", "low", "Direct French web guide"),
    ("AZ Groeninge", "Bijwerkingen chemotherapie: misselijkheid en braken", "Web page", "nl", "https://www.azgroeninge.be/nl/blogs/bijwerkingen-chemotherapie/bijwerkingen-chemotherapie-misselijkheid-en-braken", "low", "Direct Dutch web guide"),
    ("KickCancer Foundation", "Family Support & Research Hub", "Web portal", "en", "https://kickcancer.org/en", "low", "Trilingual"),
    ("KickCancer Foundation", "Guide pour les familles", "Web portal", "fr", "https://kickcancer.org/fr", "low", "Trilingual"),
    ("KickCancer Foundation", "Gids voor families", "Web portal", "nl", "https://kickcancer.org/nl", "low", "Trilingual"),
    ("UZ Leuven", "Misselijkheid en braken bij chemotherapie", "Web page", "nl", "https://www.uzleuven.be/nl/chemotherapie/bijwerkingen/misselijkheid-en-braken", "medium", "Language switch resets to home"),
    ("UZ Leuven (KIDZ)", "Kinderoncologie en -hematologie", "Web page", "nl", "https://www.uzleuven.be/nl/kinderoncologie", "medium", "General portal"),
    ("UZ Brussel / KidZ Health Castle", "KidZ Health Castle - Kinderoncologie", "Web page", "nl", "https://www.uzbrussel.be/web/kidz-health-castle/kinderoncologie", "medium", "Use this deep link; language toggle redirects to homepage"),
    ("UZ Brussel / KidZ Health Castle", "KidZ Health Castle - Oncologie pédiatrique", "Web page", "fr", "https://www.uzbrussel.be/fr/web/kidz-health-castle/oncologie-pediatrique", "medium", "Use this deep link; language toggle redirects to homepage"),
    ("UZ Brussel / KidZ Health Castle", "KidZ Health Castle - General Overview", "Web page", "en", "https://www.uzbrussel.be/en/web/kidz-health-castle", "medium", "English intro only"),
    ("HUDERF / H.U.B (Brussels)", "Hémato-Oncologie Pédiatrique - Accueil", "Web page", "fr", "https://www.huderf.be/fr/services-medicaux/hemato-oncologie", "medium", "Use this deep link; language toggle redirects"),
    ("HUDERF / H.U.B (Brussels)", "Pediatrische Hemato-Oncologie - Onthaal", "Web page", "nl", "https://www.huderf.be/nl/medische-diensten/hemato-oncologie", "medium", "Use this deep link; language toggle redirects"),
    ("Cliniques universitaires Saint-Luc", "Service d'Hémato-oncologie Pédiatrique", "Web page", "fr", "https://www.saintluc.be/fr/service-hemato-oncologie-pediatrique", "medium", "Use this deep link; language toggle redirects"),
    ("Cliniques universitaires Saint-Luc", "Dienst Pediatrische Hemato-oncologie", "Web page", "nl", "https://www.saintluc.be/nl/dienst-pediatrische-hemato-oncologie", "medium", "Use this deep link; language toggle redirects"),
    ("Cliniques universitaires Saint-Luc", "Pediatric Hematology and Oncology", "Web page", "en", "https://www.saintluc.be/en/pediatric-hematology-and-oncology-department", "medium", "English summaries only"),
    ("UZA (Queen Mathilde Center)", "Kinderoncologie en kinderhematologie", "Web page", "nl", "https://www.uza.be/oncologie-hematologie-kinderen", "medium", "No FR/EN version"),
    ("UZA / magUZA", "Kinderen met kanker behandelen is teamwerk", "Web page", "nl", "https://maguza.be/zorg/artikel/kinderen-met-kanker-behandelen-teamwerk", "medium", "Single article"),
    ("Kinderkankerfonds vzw", "Publicaties & Gids voor Ouders", "Web page", "nl", "https://www.kinderkankerfonds.be", "high", "Registration or print order needed"),
    ("BSPHO", "Clinical Treatment Protocols", "Web page", "en", "https://www.bspho.be", "high", "For professionals"),
]


def resources() -> list[dict]:
    """The 27 Belgian family resources as `reference_resources/{res-NN}` docs (reference data, no tags)."""
    return [
        {
            "resource_id": f"res-{i:02d}",
            "institution": inst,
            "title": title,
            "format": fmt,
            "language": lang,
            "url": url,
            "effort": effort,
            "effort_note": note,
        }
        for i, (inst, title, fmt, lang, url, effort, note) in enumerate(_RESOURCE_ROWS, start=1)
    ]


# --------------------------------------------------------------------------- helpers
def _where(col, field: str, op: str, value: Any):
    from google.cloud.firestore_v1.base_query import FieldFilter

    return col.where(filter=FieldFilter(field, op, value))


def initial_passport(patient_doc: dict) -> dict:
    """Draft passport for the patient's current cycle (plan computed by the mock rules, no episodes)."""
    internal = docs.patient_internal(patient_doc)
    patient = Patient.model_validate({**internal, "overallTier": "minimal", "planStatus": "draft"})
    plan = rules_mock.compute_plan(patient, [])
    state = docs.default_state(patient_doc)
    return docs.passport_doc(patient_doc, patient, plan, state)


# --------------------------------------------------------------------------- load
def load_demo_data(db, reset: bool = False, log=print) -> dict[str, list[str]]:
    """Idempotently upsert demo patients (+ draft passport if none yet), demo accounts and resources.

    reset=True first runs clear_demo_data(db, dry_run=False) so the demo starts fresh.
    Returns {collection: [doc ids written]}.
    """
    if reset:
        clear_demo_data(db, dry_run=False, log=log)
    ts = now_iso()
    written: dict[str, list[str]] = {"patients": [], "passports": [], "accounts": [], "reference_resources": []}

    def upsert(collection: str, doc_id: str, data: dict) -> None:
        ref = db.collection(collection).document(doc_id)
        snap = ref.get()
        created = (snap.to_dict() or {}).get("created_at") if snap.exists else None
        ref.set({**data, "created_at": created or ts, "updated_at": ts})
        written[collection].append(doc_id)

    for p in patients():
        upsert("patients", p["patient_id"], p)
        pp = initial_passport(p)
        ref = db.collection("passports").document(pp["passport_id"])
        if not ref.get().exists:  # keep an existing workflow (sign-offs, comments) unless --reset
            ref.set(pp)
            written["passports"].append(pp["passport_id"])
    for a in accounts():
        upsert("accounts", a["account_id"], a)
    for r in resources():
        upsert("reference_resources", r["resource_id"], r)

    for c, ids in written.items():
        log(f"  wrote {len(ids):>3} {c}: {', '.join(ids) if len(ids) <= 8 else ', '.join(ids[:8]) + ', …'}")
    return written


# --------------------------------------------------------------------------- clear
def find_demo_documents(db) -> dict[str, list[str]]:
    """{collection: sorted doc ids} that clear_demo_data would delete."""
    found: dict[str, set[str]] = {c: set() for c in CLEARABLE}
    for c in CLEARABLE:
        for snap in _where(db.collection(c), "tags", "array_contains", DEMO_TAG).stream():
            found[c].add(snap.id)
    demo_patients = sorted(found["patients"])
    for c in PATIENT_OWNED:
        for pid in demo_patients:
            for snap in _where(db.collection(c), "patient_id", "==", pid).stream():
                found[c].add(snap.id)
    return {c: sorted(ids) for c, ids in found.items()}


def clear_demo_data(db, dry_run: bool = True, log=print) -> dict[str, list[str]]:
    """Delete demo-tagged docs (and demo patients' passports/episodes). Dry run unless dry_run=False."""
    found = find_demo_documents(db)
    verb = "would delete" if dry_run else "deleting"
    for c in CLEARABLE:
        ids = found[c]
        log(f"  {verb} {len(ids):>3} {c}" + (f": {', '.join(ids)}" if ids else ""))
    if dry_run:
        return found
    refs = [db.collection(c).document(doc_id) for c in CLEARABLE for doc_id in found[c]]
    for i in range(0, len(refs), BATCH_LIMIT):
        batch = db.batch()
        for ref in refs[i : i + BATCH_LIMIT]:
            batch.delete(ref)
        batch.commit()
    log(f"  deleted {len(refs)} documents")
    return found


# --------------------------------------------------------------------------- script plumbing
def firestore_client(project: str | None, database: str):
    """Real google-cloud-firestore client (ADC). database may be '(default)'."""
    from google.cloud import firestore

    return firestore.Client(project=project or None, database=database)
