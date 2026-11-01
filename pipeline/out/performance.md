Task: SR1 · head 865d388 · Verdict: Pass
Run: no match run (the smoke/`--perf` match is Depot, which has no railings; its only new work is the `railings.is_empty()` early-out in bb_ray). Headless micro-benchmarks on The Street instead (525 blocks, 42 railing runs, fixed RNG seeds), once on this machine; budget: no baseline yet (pipeline/perf-budget.json absent), judged against the targets and a main-like build (railing_kinds = [], i.e. railings as plain boxes).
Metrics (measured, script time only, this machine):
- Railings.first_bar: 1.1 us/call at 0.5 to 2 m segments (a BB's per-tick travel), 2.5 us at 8 m, 6.2 us at 40 m. Index = 4 m grid; 0 Objects allocated over 50k calls.
- bb_ray (Jolt + first_bar) 4.6 us vs plain Jolt ray 2.5 us: about +2.2 us per BB per tick. 60 BBs in flight = 0.13 ms/tick; the full 256-BB pool (max_bbs) = 0.56 ms/tick (3 % of 16.7 ms), unreachable in practice.
- Bot shot checks: same count of Jolt rays as before (ray -> ray_past_railings, one-for-one), no first_bar call. No added cost.
- MapLevel.build on The Street: 61 to 66 ms vs 51 ms without railings (+10 to 15 ms once, behind the loading screen). Nodes +3 (Railings mesh, PastRailingsRay, railing collider body); all freed with the level: node delta +0 and 0 orphans after queue_free, twice in a row (build, free, build, free).
- Railings mesh: 1 surface, 1,592 boxes, 19,104 tris, 1 draw call (+ shadow passes). AABB 17 x 1 x 112 m.
Regressions (> 10 % worse): none measurable on the headless metrics (node count, orphans, per-tick script time on Depot unchanged by construction). Draw calls and frame times need a rendered run on the owner's hardware.
Blocking findings: none.
Advisory:
- game/map/map_level.gd:155-159 (judgment): Railings casts shadows (default) and is one mesh spanning most of the map, so it is never frustum-culled; its 19k tris are about 3x the rest of the greybox (525 boxes, roughly 6k tris) and are re-drawn in every sun-shadow cascade, and they sit outside the "bake draws no more shadow tris" arrangement (map_level.gd:334-350). About 25k tris is trivial for a Low-preset GPU, but check Low on the owner's PC; if it matters, add SHADOW_CASTING_SETTING_OFF on thin bars, a visibility range, or split by area.
- game/map/map_level.gd:408-423 (judgment): each bar is a full 6-face box (bottoms and tops included; end bars and rails overlap). Dropping hidden faces would save about 15 to 20 % of the tris; low value.
- game/map/map_level.gd:154 (judgment): the Railings mesh uses the shared greybox ShaderMaterial (no new shader), so no prewarm entry is missing on The Street (it has no site dress). If a site-dressed map ever lists railing_kinds, this material would differ from that map's main one and need a prewarm entry.
- game/sim/railings.gd:13 INDEX_CELL = 4.0 is a magic number but a named const; fine.
- Nothing allocates in first_bar, bb_ray or ray_past_railings (reused _bar_hit, static scratch vars); _index() allocates once after the last add (level build), not per tick.
Fixes: none required.
Unexplained: none. Not measured: draw calls, GPU frame time, and the Low-preset 60 fps target (no GPU in the container); a Street match with --perf on the owner's PC would confirm.
