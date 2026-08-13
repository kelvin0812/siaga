"""
Vercel serverless entrypoint. Exposes the same FastAPI app the persistent
process serves — read/write REST endpoints only (Section 5.3). The MQTT
ingest loop (backend/app/ingest.py) is NOT started here; Vercel can't
sustain the persistent broker connection Section 6.3 requires. Run that
separately as backend/main.py on an always-on host — see docs/nexus-log.md
for why this split exists.
"""
from backend.app.main import build_repository, create_app

app = create_app(repo_factory=build_repository)
