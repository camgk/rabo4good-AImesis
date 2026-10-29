"""AImesis mock API — FastAPI app.

Demo stand-in for backend/api + backend/agent so the Flutter frontends can run today.
Clinical logic comes from the MOCK rules in rules_mock.py (the real engine is backend/rules).
Advisory only — requires clinician sign-off. Demo data, not for clinical use.
"""

from __future__ import annotations

import logging
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import Depends, FastAPI, Header, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import rules_mock
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
    token_secret,
)
from .models import (
    ApproveRequest,
    DemoAccount,
    Episode,
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
from .store import Store, make_store

log = logging.getLogger("aimesis_mock_api")

LANGS = ("nl", "fr", "en")
RESOURCE_LANGS = ("nl", "fr", "en", "de")


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


# --------------------------------------------------------------------------- domain helpers
def _store(request: Request) -> Store:
    return request.app.state.store


def load_state(store: Store, patient_id: str) -> dict:
    st = store.get("plan_state", patient_id)
    if st is None:
        from .seed import DEFAULT_RISK_FACTORS

        st = {
            "patientId": patient_id,
            "status": "draft",
            "riskFactors": dict(DEFAULT_RISK_FACTORS.get(patient_id, RiskFactors().wire())),
            "signoffs": {"oncologist": None, "pharmacist": None},
            "comments": [],
        }
    return st


def load_patient_doc(store: Store, patient_id: str) -> dict:
    doc = store.get("patients", patient_id)
    if doc is None:
        raise ApiError(404, f"Patient '{patient_id}' not found")
    return doc


def episodes_for(store: Store, patient_id: str) -> list[Episode]:
    eps = [Episode.model_validate(e) for e in store.query("episodes", "patientId", patient_id)]
    eps.sort(key=lambda e: e.at, reverse=True)
    return eps


def build(store: Store, patient_id: str) -> tuple[Patient, Plan]:
    """Load patient + state + episodes and recompute the plan."""
    doc = load_patient_doc(store, patient_id)
    st = load_state(store, patient_id)
    patient = Patient.model_validate(
        {**doc, "riskFactors": st["riskFactors"], "overallTier": "minimal", "planStatus": st["status"]}
    )
    plan = rules_mock.compute_plan(patient, episodes_for(store, patient_id))
    plan.status = st["status"]
    plan.signoffs = Signoffs.model_validate(st.get("signoffs") or {})
    plan.comments = [PlanComment.model_validate(c) for c in st.get("comments", [])]
    patient.overall_tier = plan.overall_tier
    return patient, plan


def summary_of(patient: Patient) -> PatientSummary:
    return PatientSummary.model_validate(patient.model_dump(include=set(PatientSummary.model_fields)))


def cycle_day(at: str, cycle_start: str) -> int:
    day = rules_mock.episode_day(at, cycle_start)
    return day if day is not None else 1


def all_resources(store: Store) -> list[Resource]:
    rows = sorted(store.list("resources"), key=lambda r: r.get("id", ""))
    return [Resource.model_validate(r) for r in rows]


# --------------------------------------------------------------------------- app
@asynccontextmanager
async def lifespan(app: FastAPI):
    if getattr(app.state, "store", None) is None:
        app.state.store = make_store()
    store: Store = app.state.store
    if os.environ.get("SEED_ON_START", "true").lower() in ("1", "true", "yes"):
        if store.is_empty("accounts"):
            log.info("Seeding demo data")
            store.seed()
    yield


def create_app(store: Store | None = None) -> FastAPI:
    app = FastAPI(
        title="AImesis mock API",
        version="0.1.0",
        description="Demo stand-in with MOCK rules. Advisory only — requires clinician sign-off. "
        "Demo data, not for clinical use.",
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
    @app.get("/healthz")
    def healthz():
        return {"ok": True}

    @app.get("/auth/demo-accounts")
    def demo_accounts(request: Request):
        accs = sorted(_store(request).list("accounts"), key=lambda a: a["id"])
        order = {"oncologist": 0, "nurse": 1, "pharmacist": 2, "patient": 3, "parent": 4}
        accs.sort(key=lambda a: (order.get(a["role"], 9), a["id"]))
        return [
            DemoAccount(email=a["email"], role=a["role"], display_name=a["displayName"]).wire() for a in accs
        ]

    @app.post("/auth/login")
    def login(body: LoginRequest, request: Request):
        acc = _store(request).find_account_by_email(body.email)
        if acc is None or not check_password(acc.get("passwordHash", ""), body.password):
            raise ApiError(401, "Invalid email or password")
        if acc["role"] in CLINICIAN_ROLES:
            acc["patientIds"] = sorted(p["id"] for p in _store(request).list("patients"))
        return LoginResponse(token=issue_token(acc), account=public_account(acc)).wire()

    @app.get("/me")
    def me(acc: dict = Depends(current_account)):
        return public_account(acc).wire()

    # ---- patients
    @app.get("/patients")
    def list_patients(request: Request, acc: dict = Depends(current_account)):
        store = _store(request)
        out = []
        for pid in sorted(acc.get("patientIds", [])):
            if store.get("patients", pid) is None:
                continue
            patient, _ = build(store, pid)
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
        load_patient_doc(store, patient_id)
        st = load_state(store, patient_id)
        st["riskFactors"] = body.model_dump(mode="json", by_alias=True, exclude_none=True)
        # Plan changed → back to draft, previous sign-offs no longer valid.
        st["status"] = "draft"
        st["signoffs"] = {"oncologist": None, "pharmacist": None}
        store.put("plan_state", patient_id, st)
        _, plan = build(store, patient_id)
        return plan.wire()

    @app.post("/patients/{patient_id}/plan/submit")
    def submit_plan(patient_id: str, request: Request, acc: dict = Depends(require_roles("oncologist"))):
        store = _store(request)
        _, plan = build(store, patient_id)
        if plan.refused:
            raise ApiError(409, "Plan is refused (missing data or unknown drug) and cannot be submitted")
        st = load_state(store, patient_id)
        st["status"] = "awaiting_pharmacist"
        st["signoffs"] = {
            "oncologist": Signoff(by=acc["displayName"], at=now_iso()).wire(),
            "pharmacist": None,
        }
        store.put("plan_state", patient_id, st)
        return build(store, patient_id)[1].wire()

    def _pharmacist_decision(patient_id: str, request: Request, acc: dict, approve: bool, comment: str | None):
        store = _store(request)
        load_patient_doc(store, patient_id)
        st = load_state(store, patient_id)
        if st["status"] != "awaiting_pharmacist":
            raise ApiError(409, "Plan must be submitted by the oncologist first (status awaiting_pharmacist)")
        ts = now_iso()
        if approve:
            st["status"] = "approved"
            st.setdefault("signoffs", {})["pharmacist"] = Signoff(by=acc["displayName"], at=ts).wire()
        else:
            st["status"] = "returned"
            st["signoffs"] = {**(st.get("signoffs") or {}), "pharmacist": None}
        if comment:
            st.setdefault("comments", []).append(
                PlanComment(by=acc["displayName"], role=acc["role"], at=ts, text=comment).wire()
            )
        store.put("plan_state", patient_id, st)
        return build(store, patient_id)[1].wire()

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
        return [e.wire() for e in episodes_for(store, patient_id)]

    @app.post("/patients/{patient_id}/episodes", status_code=201)
    def log_episode(patient_id: str, body: EpisodeCreate, request: Request, acc: dict = Depends(current_account)):
        ensure_patient_access(acc, patient_id)
        store = _store(request)
        doc = load_patient_doc(store, patient_id)
        at = body.at or now_iso()
        try:
            datetime.fromisoformat(at.replace("Z", "+00:00"))
        except ValueError:
            raise ApiError(422, "at must be an ISO-8601 timestamp")
        ep = Episode(
            id=f"ep-{uuid.uuid4().hex[:12]}",
            patient_id=patient_id,
            type=body.type,
            severity=body.severity,
            at=at,
            cycle_day=cycle_day(at, doc["cycleStart"]),
            logged_by=acc["id"],
            logged_by_role=acc["role"],
        )
        store.put("episodes", ep.id, ep.wire())
        return ep.wire()

    # ---- pairing
    @app.post("/pairing")
    def pairing(body: PairingRequest, request: Request, acc: dict = Depends(require_roles(*FAMILY_ROLES))):
        store = _store(request)
        code = body.code.strip().upper()
        hits = [p for p in store.list("patients") if p.get("pairingCode", "").upper() == code]
        if not hits:
            raise ApiError(404, "Unknown pairing code")
        pid = hits[0]["id"]
        if pid not in acc.get("patientIds", []):
            acc["patientIds"] = list(acc.get("patientIds", [])) + [pid]
            store.put("accounts", acc["id"], acc)
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

    # ---- admin
    @app.post("/admin/reset")
    def admin_reset(request: Request, x_demo_reset: str | None = Header(default=None)):
        if not x_demo_reset or x_demo_reset != token_secret():
            raise ApiError(403, "Missing or wrong X-Demo-Reset header")
        _store(request).seed()
        return {"ok": True}

    return app


app = create_app()


def run() -> None:  # pragma: no cover
    import uvicorn

    uvicorn.run("aimesis_mock_api.main:app", host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
