Task: SM2 · head 70f791f · Verdict: Pass
Run: no headless run (delta is one static MultiMesh and a model swap; no GPU in the cloud) · budget: no baseline yet, judged against targets and attempt 3
Metrics: draw calls +1 per lift view (LandingLights MultiMesh, judgment; not rendered); nodes +1 per view, built once at load; escalators 7,412 and 6,764 of 8,000 tris (ok); leaf 44, landing 732, car sign 5,622 (unchanged).
Regressions (> 10 % worse): none measured
Blocking findings: none
 - lift_view.gd:105 the new MultiMesh reuses _button_material (shared, unshaded); no new material, so the prewarm list (line 173) already covers it (judgment).
 - lift_view.gd:~110 landing transforms are set once in the build loop, no per-frame or per-tick work, no new Array/Dictionary in a hot path (judgment).
 - The node is a child of the view, freed with it; no connections or timers added (judgment).
Advisory: LandingLights duplicates the Landings instance count and transforms; fine at this size. Escalator tris are 93 % of the cap, so the next model addition needs headroom checked.
Unexplained: none
