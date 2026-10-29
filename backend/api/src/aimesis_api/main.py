"""FastAPI entrypoint for the AImesis REST API (Episodes & Patient Passport, port 8001)."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from aimesis_api.episodes.routes import router as episodes_router
from aimesis_api.passport.routes import router as passport_router
from aimesis_api.regimens.routes import router as regimens_router

load_dotenv(Path(__file__).resolve().parents[2] / ".env")
load_dotenv()

ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ALLOW_ORIGINS",
        "http://localhost:3000,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:5173",
    ).split(",")
    if origin.strip()
]


def create_app() -> FastAPI:
    app = FastAPI(
        title="AImesis Clinical REST API",
        version="0.2.0",
        description=(
            "Episode tracking, breakthrough CINV logging, dual sign-off governance, "
            "and multilingual (NL/FR/EN) CINV Patient Passport export."
        ),
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(regimens_router)
    app.include_router(episodes_router)
    app.include_router(passport_router)

    @app.get("/health", tags=["System"])
    def health_check() -> dict[str, Any]:
        return {
            "status": "healthy",
            "service": "aimesis-api",
            "policy_version": "UZA Kinderoncologie CINV Beleid V2 (Juli 2026)",
        }

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "aimesis_api.main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8001")),
        reload=True,
    )
