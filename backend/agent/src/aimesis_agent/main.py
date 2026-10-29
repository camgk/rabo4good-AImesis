"""FastAPI entrypoint for the AImesis Agent & AG-UI service (port 8000)."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from aimesis_agent.agui_endpoint import router as agui_router

try:
    from aimesis_api.episodes.routes import router as episodes_router
    from aimesis_api.passport.routes import router as passport_router
    from aimesis_api.regimens.routes import router as regimens_router
except ImportError:
    episodes_router = None
    passport_router = None
    regimens_router = None

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
    """Create the AImesis Agent + AG-UI FastAPI application."""
    try:
        from google.adk.cli.fast_api import get_fast_api_app

        agents_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        app: FastAPI = get_fast_api_app(
            agents_dir=agents_dir,
            web=True,
            allow_origins=ALLOWED_ORIGINS,
        )
    except Exception:
        app = FastAPI(
            title="AImesis Agent & AG-UI Service",
            version="0.2.0",
            description="UZA Pediatric Oncology CINV Decision Support Agent + AG-UI/A2UI",
        )
        app.add_middleware(
            CORSMiddleware,
            allow_origins=ALLOWED_ORIGINS,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.include_router(agui_router)
    if regimens_router is not None:
        app.include_router(regimens_router)
    if episodes_router is not None:
        app.include_router(episodes_router)
    if passport_router is not None:
        app.include_router(passport_router)

    @app.get("/health", tags=["System"])
    def health_check() -> dict[str, Any]:
        return {
            "status": "healthy",
            "service": "aimesis-agent",
            "policy_version": "UZA Kinderoncologie CINV Beleid V2 (Juli 2026)",
            "benchmark_version": "POGO 2025 (250111)",
        }

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "aimesis_agent.main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        reload=True,
    )
