# AImesis mock API — plans computed by aimesis_rules (UZA v2 + POGO 250111). Advisory only — requires clinician sign-off.
# Build context is backend/ (needs backend/rules):  docker build -f mock_api/Dockerfile backend/
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PORT=8080

WORKDIR /app
COPY rules /rules
COPY mock_api/pyproject.toml mock_api/README.md ./
COPY mock_api/src ./src
RUN pip install /rules . && useradd --create-home --uid 10001 app

USER app
EXPOSE 8080
CMD ["sh", "-c", "exec uvicorn aimesis_mock_api.main:app --host 0.0.0.0 --port ${PORT:-8080} --proxy-headers"]
