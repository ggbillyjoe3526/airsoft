Task: CN1 · head e1133ce · Verdict: Pass (attempt 2)
Run: no match run needed (no game/ code changed since adb2321; only tools/blender/figures, tests, rebuilt human.glb and body textures) · budget: no baseline yet, judged against targets and base 4ea951a
Metrics (measured on the committed files):
- human.glb 9,707,612 B / base 9,708,632 (-0.0 %), attempt 1 9,703,220 (+0.05 %). ok
- human_body_col.webp 565,022 / base 567,998 (-0.5 %); orm 90,776 / 91,778 (-1.1 %); nrm 856,624 / 852,226 (+0.5 %). ok
- glb structure: 26 meshes, 68 primitives (surfaces), 8 materials, 10 images, identical to base. No new meshes, surfaces or materials.
- Triangles per LOD for the largest-head human (budgets 60k / 20k / 6k): tests/unit/test_figure_body.gd HUMAN_HIGH = [58868, 58868, 19424, 5639] is unchanged by this diff, so the pinned counts still hold. QA's run at this head reports test_figure_body 17/17 (pipeline/out/qa-report.md). My own re-run timed out at 300 s because tools/check.sh was loading the machine, so the per-LOD counts are QA's measurement plus the test file untouched, not mine. All inside the budgets (judgment on that last point).
Regressions (> 10 % worse): none
Blocking findings: none
Advisory: none new. The only runtime-visible change is skin weights and vertex positions (collar, back rise, scarf radius), so no new draw calls, shaders, prewarm entries or per-frame work.
Unexplained: none
