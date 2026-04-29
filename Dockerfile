# Multi-stage build: install deps, then ship a minimal runtime.
FROM python:3.13-slim-bookworm AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build

COPY requirements.txt ./
RUN pip install --prefix=/install -r requirements.txt


FROM python:3.13-slim-bookworm

LABEL org.opencontainers.image.source="https://github.com/sarteta/postgres-production-playbook"
LABEL org.opencontainers.image.description="Postgres production diagnostics: SQL queries + Python runner that produces a Markdown report"
LABEL org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/src

RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid app --create-home app

COPY --from=builder /install /usr/local

WORKDIR /app
COPY --chown=app:app src ./src
COPY --chown=app:app queries ./queries

USER app

# DSN is required at runtime, e.g.:
#   docker run -e DSN=postgresql://user:pass@host:5432/db ghcr.io/sarteta/postgres-production-playbook \
#     --dsn "$DSN" --out /tmp/report.md
ENTRYPOINT ["python", "-m", "playbook.runner"]
