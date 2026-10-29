# syntax=docker/dockerfile:1
# Build from the backend/ directory:
#   docker build -f backend/agent/Dockerfile -t aimesis-agent ./backend
FROM python:3.12-slim

WORKDIR /app/backend

COPY pyproject.toml ./pyproject.toml
COPY rules ./rules
COPY api ./api
COPY agent ./agent

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -e ./rules -e ./api -e ./agent

ENV PYTHONUNBUFFERED=1 \
    PORT=8000 \
    GOOGLE_GENAI_USE_VERTEXAI=TRUE \
    GOOGLE_CLOUD_PROJECT=qwiklabs-gcp-00-cc29ec8bfdd9 \
    GOOGLE_CLOUD_LOCATION=global \
    USE_FIRESTORE=false \
    CORS_ALLOW_ORIGINS=http://localhost:3000,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:5173

EXPOSE 8000

CMD ["sh", "-c", "uvicorn aimesis_agent.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
