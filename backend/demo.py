"""
Booth demo / manual test driver (build brief Section 3.5 & 6.3): replays
the synthetic hydrograph through the exact same pipeline.process_reading
real telemetry goes through, at a configurable playback speed, printing
every state transition as it happens.

    python -m backend.demo                  # 3h hydrograph compressed into 3 minutes
    python -m backend.demo --speed 1         # real time
    python -m backend.demo --speed 600       # 3h in 18s, fast sanity check
"""
from __future__ import annotations

import argparse
import asyncio
import logging
from datetime import datetime, timedelta, timezone

from backend.app.fcm import NullFCMClient
from backend.app.pipeline import decode_reading, frame_to_fields, process_reading
from backend.app.repository import InMemoryRepository
from backend.app.state_machine import StateMachine
from backend.app.tier2 import HeuristicTier2Stub
from shared.simulator import HydrographConfig, HydrographGenerator

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("siaga.demo")


async def run_demo(speed: float, node_id: int = 1) -> None:
    repo = InMemoryRepository()
    await repo.upsert_node(node_id, f"Demo Node {node_id}", lat=4.8500, lon=100.7400, datum_mm=3000)
    node = await repo.get_node(node_id)
    state_machine = StateMachine()
    tier2 = HeuristicTier2Stub()
    fcm = NullFCMClient()  # logs alerts instead of sending — no live push needed for a demo

    gen = HydrographGenerator(node_id=node_id, config=HydrographConfig())
    logger.info("replaying synthetic hydrograph at %sx speed...", speed)

    # Readings carry simulated time (sim start + t_s), not wall-clock time.
    # The dwell logic in state_machine.py reasons about the gap between
    # consecutive `received_at` values — using real wall-clock time here
    # would shrink that gap by the playback speed multiplier and silently
    # break every dwell timer at any speed other than 1x.
    sim_start = datetime.now(timezone.utc)
    for sim_reading in gen.replay_realtime(speed=speed):
        received_at = sim_start + timedelta(seconds=sim_reading.t_s)
        reading = decode_reading(
            node, "demo-gw", received_at, frame_to_fields(sim_reading.frame), rssi=-75.0, snr=10.0
        )
        state_before = state_machine.get_state(node_id)
        await process_reading(repo, state_machine, tier2, fcm, node, reading)
        state_after = state_machine.get_state(node_id)
        if state_after != state_before:
            logger.info(
                "t=%6.0fs depth=%6.0fmm  %s -> %s",
                sim_reading.t_s,
                sim_reading.depth_mm,
                state_before.name,
                state_after.name,
            )

    logger.info("demo replay complete. final state: %s", state_machine.get_state(node_id).name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--speed", type=float, default=60.0, help="playback speed multiplier")
    parser.add_argument("--node-id", type=int, default=1)
    args = parser.parse_args()
    asyncio.run(run_demo(speed=args.speed, node_id=args.node_id))


if __name__ == "__main__":
    main()
