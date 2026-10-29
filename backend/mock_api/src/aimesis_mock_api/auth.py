"""Demo auth: HS256 JWT (env TOKEN_SECRET, default "dev-secret" locally), 12 h expiry, role checks."""

from __future__ import annotations

import hashlib
import hmac
import os
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, Header, Request

from .models import Account

CLINICIAN_ROLES = {"oncologist", "nurse", "pharmacist"}
FAMILY_ROLES = {"parent", "patient"}
TOKEN_TTL = timedelta(hours=12)
ALGO = "HS256"


class ApiError(Exception):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


def token_secret() -> str:
    return os.environ.get("TOKEN_SECRET", "dev-secret")


def issue_token(account: dict) -> str:
    now = datetime.now(timezone.utc)
    payload = {"sub": account["id"], "role": account["role"], "iat": now, "exp": now + TOKEN_TTL}
    return jwt.encode(payload, token_secret(), algorithm=ALGO)


def hash_password(pw: str) -> str:
    return hashlib.sha256(pw.encode("utf-8")).hexdigest()


def check_password(stored_hash: str, password: str) -> bool:
    return hmac.compare_digest(stored_hash or "", hash_password(password))


def public_account(doc: dict) -> Account:
    return Account(
        id=doc["id"],
        email=doc["email"],
        role=doc["role"],
        display_name=doc["displayName"],
        patient_ids=list(doc.get("patientIds", [])),
    )


def current_account(request: Request, authorization: str | None = Header(default=None)) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise ApiError(401, "Missing bearer token")
    token = authorization.split(" ", 1)[1].strip()
    try:
        claims = jwt.decode(token, token_secret(), algorithms=[ALGO])
    except jwt.ExpiredSignatureError:
        raise ApiError(401, "Token expired — please log in again")
    except jwt.PyJWTError:
        raise ApiError(401, "Invalid token")
    store = request.app.state.store
    acc = store.account(claims.get("sub", ""))
    if acc is None:
        raise ApiError(401, "Account no longer exists — please log in again")
    if acc["role"] in CLINICIAN_ROLES:
        # Clinicians see every patient, including ones added later.
        acc["patientIds"] = store.patient_ids()
    return acc


def require_roles(*roles: str):
    allowed = set(roles)

    def dep(acc: dict = Depends(current_account)) -> dict:
        if acc["role"] not in allowed:
            raise ApiError(403, f"Role '{acc['role']}' is not allowed to do this")
        return acc

    return dep


def ensure_patient_access(acc: dict, patient_id: str) -> None:
    if acc["role"] in CLINICIAN_ROLES:
        return
    if patient_id not in acc.get("patientIds", []):
        raise ApiError(403, "You do not have access to this patient")
