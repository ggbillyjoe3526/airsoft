Task: SL4 · head 64813e3 · Verdict: Pass
Run: static diff review (UI constants and replica paint colours; no sim code) · budget: no baseline yet, judged against targets and origin/main
Metrics: not measured (judgment only); no new nodes, signals or per-frame work
Regressions (>10% worse): none (judgment)
Blocking findings: none
Checked fine: palette and doc edits are const Colors (evaluated once); ReplicaPaint.drawn() runs only when a paint's set is
built (cached, MAX_SETS 32) and once per own-realistic material; drawn() is a few float ops, no heap; Customise's
swatches call it once per tile when the page is built (about 24 calls), not per frame; no new resources or connections.
Advisory: paint_saturation() reads ProjectSettings on every drawn() call (build time only, harmless; a static cache is
optional); the cached sets would keep the old tone if the setting ever changed at runtime (it is static).
Fixes: none required.
