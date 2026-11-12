Task: MQ1B (attempt 3) · head 7499a89 · Verdict: Pass
Run: no Godot run (the local gate is running); the committed cyber.glb parsed directly · budget: no baseline yet, judged against targets, the 40,000 / 3,000 triangle budgets and origin/main's glb
Metrics (measured, from the glb JSON):
- Triangles in the hands (Body + Magazine + Selector + Slide + Trigger): 38,706 / 40,000 (ok); attempt 2 38,646; main 37,824 (+2.3 %)
- Figure copy (Figure + Figure_Magazine): 3,000 / 3,000 (ok, at the limit); main 3,000
- File size: 1,361,544 B vs main 1,350,416 B (+0.8 %)
- Body: 4 surfaces, materials 0-3 (same as main), 21,491 vertices (main 20,977, +2.4 %)
- Magazine: 3 surfaces, materials 3/4/2 (same as main), 3,778 vertices (main 3,882, -2.7 %), 4,244 triangles (main 4,576)
- Materials in the file: 6 (main 6); no new material, so no new shader prewarm needed
Regressions (> 10 % worse): none
Blocking findings: none
- Nothing under game/ changed (git diff origin/main...HEAD lists 0 game/ paths); no runtime script, scene or config in the diff.
- tools/model_studio.gd:54 calls RenderingServer.directional_shadow_atlas_set_size(SHADOW_MAP, true) inside the tool's own run. The only other mention of the tool in game/ is a doc comment in game/ui/studio_sky.gd:8. No game script, scene, export preset or CI step references it, so the call cannot reach the shipped game (judgment, by grep).
Advisory:
- The figure copy sits exactly on its 3,000 budget; any later rounding of the figure needs a trade-off elsewhere (judgment).
- The hands are 1,294 triangles under budget, and Body alone is 30,318 (judgment). It is a per-draw cost on the owner's GPU only; frame time was not measured here.
Fixes: none needed.
Unexplained: none. Draw calls, frame times and orphan nodes were not re-measured because no game code changed since attempt 2's pass.
