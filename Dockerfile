# Persistent ingest process (build brief Section 4.1/6.3): the always-on
# MQTT subscriber + state machine + REST API bundled together, exactly the
# "single process" the brief describes. NOT what Vercel runs — see
# api/index.py and docs/nexus-log.md for why the REST-only surface is
# split out separately.
FROM python:3.11-slim

WORKDIR /app

COPY pyproject.toml ./
COPY shared ./shared
COPY backend ./backend

RUN pip install --no-cache-dir -e .

ENV PYTHONUNBUFFERED=1
EXPOSE 8000

CMD ["python", "-m", "backend.app.main"]
