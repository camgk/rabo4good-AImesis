"""AImesis mock API — FastAPI app.

Stand-in for backend/api + backend/agent so the Flutter frontends can run today.
Clinical logic comes from the MOCK rules in rules_mock.py (the real engine is backend/rules).
Data lives in the shared Firestore `(default)` database (snake_case docs, see docs.py); the REST API is camelCase.
Advisory only — requires clinician sign-off.
"""

from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import docs, rules_mock
from .auth import (
    CLINICIAN_ROLES,
    FAMILY_ROLES,
    ApiError,
    check_password,
    current_account,
    ensure_patient_access,
    issue_token,
    public_account,
    require_roles,
)
from .docs import now_iso
from .models import (
    ApproveRequest,
    DemoAccount,
    EpisodeCreate,
    LoginRequest,
    LoginResponse,
    PairingRequest,
    Patient,
    PatientSummary,
    Plan,
    PlanComment,
    Resource,
    ReturnRequest,
    RiskFactors,
    Signoff,
    Signoffs,
)
from .passport import build_passport
from .store import MemoryStore, Store, is_memory, make_store

log = logging.getLogger("aimesis_mock_api")

LANGS = ("nl", "fr", "en")
RESOURCE_LANGS = ("nl", "fr", "en", "de")
ROLE_ORDER = {"oncologist": 0, "nurse": 1, "pharmacist": 2, "patient": 3, "parent": 4}


def _truthy(v: str | None) -> bool:
    return (v or "").strip().lower() in ("1", "true", "yes", "on")


# --------------------------------------------------------------------------- domain helpers
def _store(request: Request) -> Store:
    return request.app.state.store


def load_patient_doc(store: Store, patient_id: str) -> dict:
    doc = store.patient(patient_id)
    if doc is None:
        raise ApiError(404, f"Patient '{patient_id}' not found")
    return doc


def load_state(store: Store, patient_doc: dict) -> tuple[dict, dict | None]:
    """(workflow state, raw passport doc or None) for the patient's current-cycle passport."""
    pp = store.passport(docs.passport_id_for(patient_doc))
    return docs.state_from_passport(pp, patient_doc), pp


def build_from_doc(store: Store, doc: dict, state: dict | None = None) -> tuple[Patient, Plan, dict, dict | None]:
    """Patient doc + passport state + episodes -> (Patient, recomputed Plan, state, passport doc)."""
    existing = None
    if state is None:
        state, existing = load_state(store, doc)
    internal = docs.patient_internal(doc)
    patient = Patient.model_validate(
        {**internal, "riskFactors": state["riskFactors"], "overallTier": "minimal", "planStatus": state["status"]}
    )
    episodes = [docs.episode_internal(e) for e in store.episodes(doc["patient_id"])]
    plan = rules_mock.compute_plan(patient, episodes)
    plan.status = state["status"]
    plan.signoffs = Signoffs.model_validate(state.get("signoffs") or {})
    plan.comments = [PlanComment.model_validate(c) for c in state.get("comments", [])]
    patient.overall_tier = plan.overall_tier
    return patient, plan, state, existing


def build(store: Store, patient_id: str) -> tuple[Patient, Plan]:
    patient, plan, _, _ = build_from_doc(store, load_patient_doc(store, patient_id))
    return patient, plan


def save_state(store: Store, patient_doc: dict, state: dict) -> Plan:
    """Persist the workflow state as the passports/{passport_id} doc and return the recomputed plan."""
    existing = store.passport(docs.passport_id_for(patient_doc))
    patient, plan, _, _ = build_from_doc(store, patient_doc, state)
    store.save_passport(docs.passport_doc(patient_doc, patient, plan, state, existing))
    return plan


def summary_of(patient: Patient) -> PatientSummary:
    return PatientSummary.model_validate(patient.model_dump(include=set(PatientSummary.model_fields)))


def cycle_day(at: str, cycle_start: str) -> int:
    day = rules_mock.episode_day(at, cycle_start)
    return day if day is not None else 1


def all_resources(store: Store) -> list[Resource]:
    return [docs.resource_internal(r) for r in store.resources()]


# --------------------------------------------------------------------------- app
@asynccontextmanager
async def lifespan(app: FastAPI):
    if getattr(app.state, "store", None) is None:
        app.state.store = make_store()
    store: Store = app.state.store
    # Local dev only: the in-memory store starts empty; load the demo dataset with the same loader the
    # scripts use. Never honoured against Firestore (use infra/scripts/demo-data.sh load there).
    if isinstance(store, MemoryStore) and is_memory() and _truthy(os.environ.get("LOAD_DEMO_ON_START")):
        from .demo_data import load_demo_data

        log.info("LOAD_DEMO_ON_START: loading demo data into the memory store")
        load_demo_data(store.db, log=log.info)
    yield


def create_app(store: Store | None = None) -> FastAPI:
    app = FastAPI(
        title="AImesis mock API",
        version="0.2.0",
        description="Stand-in API with MOCK rules. Advisory only — requires clinician sign-off.",
        lifespan=lifespan,
    )
    app.state.store = store
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
        allow_credentials=False,
    )

    # ---- uniform error bodies: {"error": "..."}
    @app.exception_handler(ApiError)
    async def _api_error(_: Request, exc: ApiError):
        return JSONResponse({"error": exc.message}, status_code=exc.status)

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(_: Request, exc: StarletteHTTPException):
        msg = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
        return JSONResponse({"error": msg}, status_code=exc.status_code, headers=getattr(exc, "headers", None))

    @app.exception_handler(RequestValidationError)
    async def _validation_error(_: Request, exc: RequestValidationError):
        parts = []
        for e in exc.errors():
            loc = ".".join(str(x) for x in e.get("loc", []) if x != "body")
            parts.append(f"{loc}: {e.get('msg')}" if loc else str(e.get("msg")))
        return JSONResponse({"error": "Invalid request — " + "; ".join(parts)}, status_code=422)

    @app.exception_handler(Exception)
    async def _unhandled(_: Request, exc: Exception):
        log.exception("Unhandled error")
        return JSONResponse({"error": "Internal server error"}, status_code=500)

    # ---- health + auth
    # Cloud Run's front end reserves /healthz, so /health is the public check.
    @app.get("/health")
    @app.get("/healthz")
    def healthz():
        return {"ok": True}

    @app.get("/auth/demo-accounts")
    def demo_accounts(request: Request):
        """Accounts tagged `demo` only (empty until demo data is loaded)."""
        accs = _store(request).demo_accounts()
        accs.sort(key=lambda a: (ROLE_ORDER.get(a["role"], 9), a["id"]))
        return [DemoAccount(email=a["email"], role=a["role"], display_name=a["displayName"]).wire() for a in accs]

    @app.post("/auth/login")
    def login(body: LoginRequest, request: Request):
        store = _store(request)
        acc = store.account_by_email(body.email)
        if acc is None or not check_password(acc.get("passwordHash", ""), body.password):
            raise ApiError(401, "Invalid email or password")
        if acc["role"] in CLINICIAN_ROLES:
            acc["patientIds"] = store.patient_ids()
        return LoginResponse(token=issue_token(acc), account=public_account(acc)).wire()

    @app.get("/me")
    def me(acc: dict = Depends(current_account)):
        return public_account(acc).wire()

    # ---- patients
    @app.get("/patients")
    def list_patients(
        request: Request, tag: str | None = Query(default=None), acc: dict = Depends(current_account)
    ):
        store = _store(request)
        allowed = set(acc.get("patientIds", []))
        out = []
        for doc in store.patients(tag=tag or None):
            if doc["patient_id"] not in allowed:
                continue
            patient, _, _, _ = build_from_doc(store, doc)
            out.append(summary_of(patient).wire())
        return out

    @app.get("/patients/{patient_id}")
    def get_patient(patient_id: str, request: Request, acc: dict = Depends(current_account)):
        ensure_patient_access(acc, patient_id)
        patient, _ = build(_store(request), patient_id)
        return patient.wire()

    @app.get("/patients/{patient_id}/plan")
    def get_plan(
        patient_id: str, request: Request, acc: dict = Depends(require_roles(*CLINICIAN_ROLES))
    ):
        _, plan = build(_store(request), patient_id)
        return plan.wire()

    @app.put("/patients/{patient_id}/risk-factors")
    def put_risk_factors(
        patient_id: str,
        body: RiskFactors,
        request: Request,
        acc: dict = Depends(require_roles("oncologist", "nurse")),
    ):
        store = _store(request)
        doc = load_patient_doc(store, patient_id)
        st, _ = load_state(store, doc)
        st["riskFactors"] = body.model_dump(mode="json", by_alias=True, exclude_none=True)
        # Plan changed → back to draft, previous sign-offs no longer valid.
        st["status"] = "draft"
        st["signoffs"] = {"oncologist": None, "pharmacist": None}
        return save_state(store, doc, st).wire()

    @app.post("/patients/{patient_id}/plan/submit")
    def submit_plan(patient_id: str, request: Request, acc: dict = Depends(require_roles("oncologist"))):
        store = _store(request)
        doc = load_patient_doc(store, patient_id)
        _, plan, st, _ = build_from_doc(store, doc)
        if plan.refused:
            raise ApiError(409, "Plan is refused (missing data or unknown drug) and cannot be submitted")
        st["status"] = "awaiting_pharmacist"
        st["signoffs"] = {
            "oncologist": Signoff(by=acc["displayName"], at=now_iso()).wire(),
            "pharmacist": None,
        }
        return save_state(store, doc, st).wire()

    def _pharmacist_decision(patient_id: str, request: Request, acc: dict, approve: bool, comment: str | None):
        store = _store(request)
        doc = load_patient_doc(store, patient_id)
        st, _ = load_state(store, doc)
        if st["status"] != "awaiting_pharmacist":
            raise ApiError(409, "Plan must be submitted by the oncologist first (status awaiting_pharmacist)")
        ts = now_iso()
        if approve:
            st["status"] = "approved"
            st["signoffs"] = {**st["signoffs"], "pharmacist": Signoff(by=acc["displayName"], at=ts).wire()}
        else:
            st["status"] = "returned"
            st["signoffs"] = {**st["signoffs"], "pharmacist": None}
        if comment:
            st.setdefault("comments", []).append(
                PlanComment(by=acc["displayName"], role=acc["role"], at=ts, text=comment).wire()
            )
        return save_state(store, doc, st).wire()

    @app.post("/patients/{patient_id}/plan/approve")
    def approve_plan(
        patient_id: str,
        request: Request,
        body: ApproveRequest | None = None,
        acc: dict = Depends(require_roles("pharmacist")),
    ):
        return _pharmacist_decision(patient_id, request, acc, True, body.comment if body else None)

    @app.post("/patients/{patient_id}/plan/return")
    def return_plan(
        patient_id: str, body: ReturnRequest, request: Request, acc: dict = Depends(require_roles("pharmacist"))
    ):
        return _pharmacist_decision(patient_id, request, acc, False, body.comment)

    # ---- passport
    @app.get("/patients/{patient_id}/passport")
    def get_passport(
        patient_id: str,
        request: Request,
        lang: str | None = Query(default=None),
        acc: dict = Depends(current_account),
    ):
        ensure_patient_access(acc, patient_id)
        store = _store(request)
        patient, plan = build(store, patient_id)
        lang = (lang or patient.language).lower()
        if lang not in LANGS:
            raise ApiError(400, "lang must be one of nl, fr, en")
        return build_passport(patient, plan, lang, all_resources(store)).wire()

    # ---- episodes
    @app.get("/patients/{patient_id}/episodes")
    def list_episodes(patient_id: str, request: Request, acc: dict = Depends(current_account)):
        ensure_patient_access(acc, patient_id)
        store = _store(request)
        load_patient_doc(store, patient_id)
        return [docs.episode_internal(e).wire() for e in store.episodes(patient_id)]

    @app.post("/patients/{patient_id}/episodes", status_code=201)
    def log_episode(patient_id: str, body: EpisodeCreate, request: Request, acc: dict = Depends(current_account)):
        ensure_patient_access(acc, patient_id)
        store = _store(request)
        doc = load_patient_doc(store, patient_id)
        try:
            at = docs.to_utc_iso(body.at) if body.at else now_iso()
        except ValueError:
            raise ApiError(422, "at must be an ISO-8601 timestamp")
        ep = docs.episode_doc(doc, acc, body.type, body.severity, at, cycle_day(at, doc.get("cycle_start_date") or ""))
        store.add_episode(ep)
        return docs.episode_internal(ep).wire()

    # ---- pairing
    @app.post("/pairing")
    def pairing(body: PairingRequest, request: Request, acc: dict = Depends(require_roles(*FAMILY_ROLES))):
        store = _store(request)
        code = body.code.strip().upper()
        hits = [p for p in store.patients() if (p.get("pairing_code") or "").upper() == code]
        if not hits:
            raise ApiError(404, "Unknown pairing code")
        pid = hits[0]["patient_id"]
        if pid not in acc.get("patientIds", []):
            store.set_account_patients(acc["id"], list(acc.get("patientIds", [])) + [pid])
        patient, _ = build(store, pid)
        return summary_of(patient).wire()

    # ---- resources
    @app.get("/resources")
    def resources(request: Request, lang: str | None = Query(default=None)):
        res = all_resources(_store(request))
        if lang:
            lang = lang.lower()
            if lang not in RESOURCE_LANGS:
                raise ApiError(400, "lang must be one of nl, fr, en, de")
            res = [r for r in res if r.language == lang]
        return [r.wire() for r in res]

    return app


app = create_app()


def run() -> None:  # pragma: no cover
    import uvicorn

    uvicorn.run("aimesis_mock_api.main:app", host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
