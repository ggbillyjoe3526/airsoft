Task: TB2 · head 7b2332f · Verdict: Pass
Run: smoke bot match (--smoke --perf), headless, no GPU, both heads · budget: no baseline yet (no pipeline/perf-budget.json), judged against targets and origin/main
Metrics (head / main): nodes_max 2210 / 2210 (ok), orphans_max 1031 / 1031 (ok, same as main), draw calls 0 / 0 (headless, not measurable), frames 1419 / 1488 (smoke run length, not a metric). Frame times: not measured (owner's hardware only).
Regressions (> 10 % worse): none
Blocking findings: none
 - Attempt-2 blocker fixed (judgment): the 12 tunnel-lamp OmniLight3D are visible=false at creation (station_fixtures.gd:113) and station_fixtures.gd set_lamps() shows them; play_session.gd:2066-2067 calls it from _apply_graphics with lamp_lights != OFF, as the lifts do. Low and Medium get no real lights; no preset bypass.
 - No per-frame or per-tick allocation in the diff; the lights are children of the view, freed with it. No new material or particle, so no prewarm entry.
Advisory
 - The 1031 orphans at peak equal main's, so not from this change; worth a separate look (measured, same on both).
 - The arch stays dark on Low and Medium (documented in the record); a design call, not performance.
Fixes: none needed
Unexplained: none
