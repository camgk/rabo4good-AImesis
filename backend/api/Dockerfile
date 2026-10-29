# syntax=docker/dockerfile:1
# Build from the backend/ directory:
#   docker build -f backend/api/Dockerfile -t aimesis-api ./backend
FROM python:3.12-slim

WORKDIR /app/backend

COPY pyproject.toml ./pyproject.toml
COPY rules ./rules
COPY api ./api

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -e ./rules -e ./api

ENV PYTHONUNBUFFERED=1 \
    PORT=8001 \
    USE_FIRESTORE=false \
    GOOGLE_CLOUD_PROJECT=qwiklabs-gcp-00-cc29ec8bfdd9 \
    CORS_ALLOW_ORIGINS=http://localhost:3000,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:5173

EXPOSE 8001

CMD ["sh", "-c", "uvicorn aimesis_api.main:app --host 0.0.0.0 --port ${PORT:-8001}"]
