# syntax=docker/dockerfile:1
FROM python:3.12-slim

WORKDIR /app/backend

# Copy workspace configuration and backend packages
COPY pyproject.toml ./pyproject.toml
COPY rules ./rules
COPY api ./api
COPY agent ./agent

# Install all workspace packages (rules engine, clinical REST API, and ADK/AG-UI agent)
# Editable mode keeps aimesis_agent inside /app/backend/agent/src so ADK discovers only aimesis_agent
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -e ./rules -e ./api -e ./agent

# Runtime & Google Cloud / Vertex AI authentication environment variables
ENV PYTHONUNBUFFERED=1 \
    PORT=8000 \
    GOOGLE_GENAI_USE_VERTEXAI=TRUE \
    GOOGLE_CLOUD_PROJECT=qwiklabs-gcp-00-cc29ec8bfdd9 \
    GOOGLE_CLOUD_LOCATION=global \
    USE_FIRESTORE=false \
    CORS_ALLOW_ORIGINS=http://localhost:3000,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:5173

# Note on Google Cloud Credentials:
# - On Cloud Run / GKE: Application Default Credentials (ADC) automatically use the attached service account.
# - Locally in Docker: Mount your local ADC JSON file and pass GOOGLE_APPLICATION_CREDENTIALS:
#   -v ~/.config/gcloud/application_default_credentials.json:/gcp/creds.json:ro
#   -e GOOGLE_APPLICATION_CREDENTIALS=/gcp/creds.json

EXPOSE 8000

CMD ["sh", "-c", "uvicorn aimesis_agent.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
