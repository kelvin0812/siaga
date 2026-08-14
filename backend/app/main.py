"""
App assembly. `create_app()` builds the REST-only FastAPI app used by both
the persistent process and the Vercel serverless entrypoint (api/index.py
at the repo root).

A Repository can be supplied eagerly (`repo=`, what the persistent process
does — it can afford to await the Postgres pool once before serving) or
lazily (`repo_factory=`, what the Vercel entrypoint does, since a
serverless module import can't do async work and ASGI lifespan isn't
reliably invoked there). api._repo() resolves whichever was given on
first request.

`run_full_process()` is the "single process" build brief Section 4.1
actually describes: REST API plus the MQTT ingest loop together, for
local/booth/persistent-host use. Splitting ingest onto a separate always-
on host from the read-only Vercel API (see docs/nexus-log.md) is a
deployment-topology choice forced by choosing Vercel, not a change to
this default: run_full_process() still runs everything in one process
exactly as specified, whether that process is your laptop or a small VM.
"""
from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Awaitable, Callable

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.app.api import router
from backend.app.config import settings
from backend.app.fcm import FCMClient, FirebaseFCMClient, NullFCMClient
from backend.app.repository import InMemoryRepository, Repository
from backend.app.state_machine import StateMachine
from backend.app.tier2 import HeuristicTier2Stub

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("siaga.main")


def create_app(
    repo: Repository | None = None,
    repo_factory: Callable[[], Awaitable[Repository]] | None = None,
) -> FastAPI:
    if repo is None and repo_factory is None:
        raise ValueError("create_app requires either repo or repo_factory")
    app = FastAPI(title="SIAGA backend", version="1")
    # No auth model exists anywhere in this system (Section 11: no user
    # accounts by design) and every endpoint here is either public safety
    # data or an anonymous write (reports, subscription pings), so a
    # wildcard origin carries no session/cookie exposure risk — unlike a
    # typical authenticated API, there's nothing origin-restriction would
    # protect. Needed for any browser-based client (e.g. local dev
    # preview of the Flutter web target) to call this API at all.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.state.repo = repo
    app.state.repo_factory = repo_factory
    app.include_router(router)
    return app


async def build_repository() -> Repository:
    if not settings.database_url:
        logger.warning("DATABASE_URL not set — running against InMemoryRepository (demo mode)")
        return InMemoryRepository()
    from backend.app.db_postgres import AsyncpgRepository

    return await AsyncpgRepository.connect(settings.database_url)


def build_fcm_client() -> FCMClient:
    if not settings.firebase_credentials_path:
        logger.warning("no Firebase credentials configured — FCM sends will only be logged")
        return NullFCMClient()
    return FirebaseFCMClient(settings.firebase_credentials_path)


async def run_full_process() -> None:
    import uvicorn

    from backend.app.ingest import run_ingest_loop

    repo = await build_repository()
    fcm_client = build_fcm_client()
    state_machine = StateMachine()
    tier2_model = HeuristicTier2Stub()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        ingest_task = asyncio.create_task(
            run_ingest_loop(settings, repo, state_machine, tier2_model, fcm_client)
        )
        try:
            yield
        finally:
            ingest_task.cancel()

    app = create_app(repo)
    app.router.lifespan_context = lifespan

    config = uvicorn.Config(app, host="0.0.0.0", port=8000)
    server = uvicorn.Server(config)
    await server.serve()


if __name__ == "__main__":
    asyncio.run(run_full_process())
