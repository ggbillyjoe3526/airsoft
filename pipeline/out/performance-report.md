# Performance report, FL1 (head d53525f vs origin/main e133c2f)

Verdict: **Pass**

Basis: no baseline in pipeline/perf-budget.json; judged by reading the diff (one file, game/ai/bot_bombs.gd) against the
targets. No --perf A/B run: the path only runs on a passed flash roll, so a 60 Hz match would not isolate it.

- Per-tick cost: none added. `_mate_sees` runs only after the flash roll passes (gated by bomb_roll_gap, 1.5 s per bot)
  and once more when the bot presses its throw (bot_bombs.gd:36-38), a one-off per throw.
- Worst case per call: (1 + flash_route_points) candidate spots x teammates in play x 2 `sight_clear` rays. A ray is cast
  only when the teammate is inside flash_mate_sight (16 m) and not already inside flash_mate_clear (8 m); the short
  circuit stops at the first catch. The led check is skipped for a stationary mate (EPSILON guard, :178).
- Allocations: no Array, Dictionary, String or Callable per call. Vector3 values are stack-only; `_caught` is a static
  helper. `g`, `lead` and `eye` are computed per mate, not per ray. Bot gains one Vector3 (`bomb_bang`, 12 bytes).
- Nodes and resources: none created, no signals, timers or tweens, so no orphan or teardown risk.
- Minor, can wait: `eye_of` is computed once per mate per call and the two `_caught` calls share it, so nothing to hoist.
  With many bots rolling in one tick the rays add up, but bomb_roll_gap spreads them out.
