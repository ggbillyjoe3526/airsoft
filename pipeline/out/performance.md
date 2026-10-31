Task: WR1 · head c7e8c44 · Verdict: Pass
Run: test_terrain.gd headless (30/30, 8.8 s); no bot match run (a full tools/check.sh was running). Budget: no baseline (pipeline/perf-budget.json does not exist), judged against the owner's targets (install ≤500 MB, Low 60 fps, High 1.5M tris) and the worker's old-vs-new numbers in KNOWN_ISSUES (not re-measured). No GPU: no frame times or draw calls.
Metrics (worker-measured, headless):
- Install: woodland.json 549 KB; the old-wood fixture is under tests/ (excluded from exports). Under 1 MB of 500 MB.
- Triangles: the 1800-cone forest is one MultiMesh, about 11K tris, none on Low.
- Draws: the greybox is one mesh; foliage, trees and forest are MultiMeshes. WL10's draw figures are the old wood's.
- Nav build 6.2 s, 528k nodes, +288 MB: linear in nodes, on the loading screen's worker thread. No RAM budget in the repo; low-end machines a risk (judgment).
- Routes 5.5 ms mean, 9.3 ms worst, capped at one search a tick: tight against Low's 16.7 ms; the cause is the grid's size, not new code.
- Load: 347 vault links 1.9 s and cover 0.55 s on the main thread at loading; no frame cost in play.
Regressions (>10 %): none from the diff's per-frame code; growth is the map's size, recorded as "can wait".
Code paths: _sloped_diagonal/_between build-time only, no allocation; drop_on_line's fallback integer maths on a miss only; follow() adds one Vector2 length behind the off-leg test; Bot.off_leg_at a value member; floor_blocks load-time only; MapStyle 3 entries, no new material.
Advisory: measure the worst route on Low hardware in the playtest; re-measure Woodland's draws on the owner's PC (WL10); a 0.4 m open-ground cell or packed-array search are the right follow-ups.
performance: Pass
