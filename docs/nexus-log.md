# Nexus Log

AI collaboration record for the SIAGA build (Project Nexus 2026, Track 3). Kept per build brief Section 10.1: how AI shaped workflow and design, where the team caught and corrected an AI error or limitation, and how the AI-assisted result diverged from the original concept. Entries are dated and in build order.

## 2026-08-13 — Step 1: shared data contract + synthetic telemetry generator

**Gap found before writing code.** `CLAUDE.md` Section 8 ("Build Order") is a header with no actual numbered steps — just the instruction to follow a sequence that isn't written down. The working agreement in Section 1 explicitly requires flagging ambiguity rather than silently picking an interpretation, so this was raised to the team before any implementation started.

**How it was resolved.** Offered the team a choice of orderings inferred from other sections (2.2's stated importance order, 3.5's "build the simulator early," the physical data-flow order in Section 4). The team gave no preference, so the AI-recommended order was used: shared data contract + simulator → backend → app → firmware. This is a case where the brief's own stated priority (get the alerting path testable before hardware exists) is the deciding argument, not just AI judgment — worth revisiting if the team disagrees once the backend exists.

**What was built.**
- `shared/frame.py`: the 12-byte packed binary uplink frame codec (Section 5.1), including `level_mm_to_height_above_datum`, the single point where the down-looking-distance inversion happens. Kept as the one authoritative definition — the gateway firmware's C++ struct will need to be hand-mirrored against this, not the other way around.
- `shared/simulator.py`: a deterministic rising-hydrograph generator (`HydrographGenerator`) producing valid `UplinkFrame` sequences — smoothstep rise to peak, exponential recession, correlated rainfall/soil-moisture/tilt, and a simplified rate-of-rise check standing in for the node's real Tier 1 anomaly logic (Section 6.1) since reimplementing EWMA/z-score/autoencoder logic here would duplicate firmware work not yet done. A `replay_realtime(speed=...)` wrapper exists for later wiring into the backend's MQTT publisher.
- 31 pytest tests across `tests/test_frame.py` and `tests/test_simulator.py`, covering round-trip encode/decode, all field boundary values, the flags-byte bit layout including the two-bit boot-cause subfield, and — the case Section 5.1 calls out as the most likely bug source — that rising water produces a *decreasing* `level_mm` and a correctly increasing computed height.

**Assumption made, flagged for the team to confirm or override:** the anomaly-flag rate-of-rise threshold in the simulator (`anomaly_rate_mm_per_min`, default 30 mm/min) is a placeholder chosen to make the demo hydrograph exercise the flag, not a hydrologically-derived value. Section 6.1 asks for "an explicit rate-of-rise threshold from hydrological first principles" on the real node — that derivation still needs to happen and this number should not be treated as it.

**Divergence from the original concept:** none yet at this scope — this step is infrastructure (codec + fixture) rather than a design decision with room to diverge.
