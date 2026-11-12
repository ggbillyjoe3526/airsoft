Task: MQ1B (attempt 2) · head 8cd98c8 · Verdict: Pass
Run: no Godot run (model swap, no game code; full gate running); glb parsed directly · budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against the 40,000 / 3,000 triangle budgets and origin/main
Metrics (measured, glb JSON):
- Hands triangles 38,646 / limit 40,000 (ok); main 37,824 (+2.2 %); attempt 1 was 39,276.
- Figure copy triangles 3,000 / limit 3,000 (ok, at the limit); main 3,000 (unchanged).
- cyber.glb 1,363,988 bytes vs main 1,350,416 (+1.0 %).
- Body: 4 surfaces, vertices 21,485 vs 20,977 (+2.4 %). Magazine: 3 surfaces, vertices 3,751 vs 3,882 (-3.4 %).
- Materials 6 / 6 on main, embedded images 0 / 0, so no new materials, surfaces or draw calls. Selector, Slide, Trigger, Figure_Magazine unchanged; Figure vertices 5,516 vs 5,659.
- Nothing under game/ changed (0 files); no new shader or particle, so no prewarm entry is needed.
Regressions (> 10 % worse): none
Blocking findings: none
Advisory:
- Figure copy sits exactly on its 3,000 budget, so any further added detail there needs a cut elsewhere (judgment).
- tools/model_studio.gd is a dev picture tool and does not ship; its camera near/far change does not affect the game (judgment).
Unexplained: none
