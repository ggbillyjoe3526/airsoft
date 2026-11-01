Task: BQ3 · head 3597106 · Verdict: Pass
Run: smoke match (--smoke --perf, fixed smoke seed), headless, vs worktree of ef8659c · budget: no baseline yet, judged against targets and ef8659c
Metrics: nodes_max 1238 / 1238 (ok) · orphans_max 792 / 792 (ok, same) · draw_max 0 / 0 (headless) · frames 1641 / 3087 (the match ends sooner: bots press and kneel, different play; not a cost). Script time per tick not logged by --smoke: judged from the code.
Regressions (> 10 % worse): none
Blocking findings: none
Advisory:
- tests/unit/test_bots.gd:430-435 (measured): the adjusted warm-tick test is a fair reading of SimEvents (game/sim/sim_events.gd:3 documents a pool that grows to the busiest tick seen). GameEvent is one RefCounted with no sub-objects, so each pooled event is exactly one object and `before + grown` is exact accounting, not a loophole. Probe: Normal pool 4, grown 0; Hard 2 -> 4 in the measured window (ef8659c: Hard 3 stable, no growth). The new high is a different RNG stream and play, not a leak. Weakness: a late new high still lands in the measured window. Could warm longer or assert `grown` is small; non-blocking, the pool is bounded by the busiest tick.
- game/ai/bot_world.gd:100-125 (judgment): pressing/careful_last are gated by mode, skill flag and live before any loop, so Easy pays nothing. pressing loops all characters (_out_lead, full pass) once per bot per tick only in ADVANCE, not hunting, Elimination, Normal/Hard; careful_last exits at the first teammate in play, and bot_brain.gd:50 short-circuits it. Worst case about 2 x bots x characters (~200 iterations at 5v5) per tick, no allocation. Could cache _out_lead per tick in BotController if 10v10 or more ever matters; can wait.
- game/ai/bot_radio.gd:20-45 (judgment): step() is one pass over bots per sim tick with two cheap compares; tell() runs only when a call is due (once per fresh sighting, bots x 1 pass). Vector2(...) is a value, no heap. Allocates nothing as documented.
- bot_movement.gd:646, bot_bombs.gd:110,168 (judgment): line_clear -> sight_clear is the same single ray on the sight cast (JoltQuery reuses its one RayCast3D, BoxWorld the same slab loop). No added ray count; the kneel early return in _strafe is cheaper than before.
- No nodes, resources, signal connections or timers added. New Bot fields (share_at/share_id/share_spot) are reset in Bot.reset; nothing unbounded.
Fixes: none required.
Unexplained: none. GUT: test_bots.gd 16/16 pass on this head.
