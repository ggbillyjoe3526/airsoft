Task: TB2 · head 30b028d · Verdict: Fail
Run: static review only (no bot run: check.sh was running on this machine; no GPU) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and attempt 1
Metrics: not re-measured. Colliders 1044 blocks vs 1026 (attempt 1) / 879 (main), static, built at load: judgment, no per-frame cost. Lights +12 OmniLight3D, always on.
Regressions (> 10 % worse): none measured. Subway blocks +19 % vs main (static colliders at load; the cost is load time and broadphase, not per-tick).
Blocking findings
- game/play/station/station_fixtures.gd:105-115 and game/config/station_fixtures_config.gd:28-32 (judgment): 12 tunnel lamps are real OmniLight3D on every preset. data/graphics.md:57 sets lamp_lights to off on Low and Medium, and the row's text (l.95) says the overhead light stands in for the lamps there. The lights bypass the preset: nothing reads GraphicsQuality.lamp_lights for them. The lifts' lamps do: game/play/play_session.gd:2064 calls _lifts.set_lamps(...), and the fixtures view has no such call. Counts as a preset bypass, and it breaks UL1's ask that Low and Medium stay cheap.
- Cost (judgment, not measured): 12 unshadowed omnis of range 6.5 m on Forward+ cluster cheaply, but the Low target is 60 FPS on low-powered hardware, where per-pixel light count in a tunnel is fill-bound. Its cost on that hardware is unknown.
Advisory
- station_fixtures.gd:112-113: BAKE_STATIC does nothing at runtime unless a lightmap is baked (judgment); the lights are dynamic. Drop it or note it.
- station_fixtures.gd:106: Light nodes are made per lamp (12 at load, one time). Fine, no per-frame work; they are children of the view, freed with it.
- No new material or particle, so no prewarm entry is needed. No per-frame or per-tick allocation in the diff.
Fixes, ranked by impact
1. Give the fixtures view set_lamps(on) like lift_view.gd:104 and call it from play_session.gd beside l.2064 with lamp_lights != OFF, so Low and Medium keep the glass glow (unshaded) and no real lights. Cover the dark arch on Low/Medium with the glow material or the overhead light stand-in (design call for the owner/UL1).
2. If the owner wants the 12 lights on every preset, that is a new data/graphics.md row or a ruling in docs/DECISIONS.md; ask him. Do not ship it silently.
3. Re-run the bot match with --perf on both heads once check.sh is free, to record node count, orphans and static memory.
Unexplained: none
