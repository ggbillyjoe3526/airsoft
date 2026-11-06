Task: FA1 · head aa82d86 (diff 1307710..HEAD) · Verdict: Pass
Run: none (no GPU; CPU loaded by the background check; frame times skipped) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the counts
Metrics: no --perf run made; judged from counts, all judgment:
- Draw calls: each visible head mesh level gains one Face surface, so +1 draw per figure (the head is drawn at one LOD at a time), about +1 per figure on top of the head's existing surfaces. The shadow twin merges to one surface (figure_models.gd:206-237), so no extra shadow draw. A 10-figure match is about +10 draws at most.
- Materials: look 0 is the source Face material itself; looks 1-3 are duplicates made once per kind/look (figure_models.gd:156-172). That is at most 4 Face materials per kind, shared by every figure (key kind/source id/look), not per-instance. All use the one head atlas, so no new textures, and no new shader variants (same BaseMaterial3D features, only uv1_offset differs).
- Triangles: heads 9,000/3,200/900 at LOD0/1/2 (largest head 8,992/3,192/896, 99.9 % of budget); the figure 26,216/9,036/2,945 against 60k, so about 44 % of the figure budget. The face adds 1,094-1,318 / 594-708 / 82-90 triangles per head, and that is the whole change at LOD0.
- Assets: human.glb 6,368,156 -> 6,709,628 bytes (+342 KB, +5.4 %). Atlas webps: col +7.4 KB, orm +1 KB, nrm -4 KB, net +4.4 KB, a negligible change from baseline. VRAM unchanged in dimensions (same texture sizes), so no new GPU memory.
Regressions (> 10 % worse): none measured. Runtime: draw calls up about 1 per figure, a few percent of the figure's surfaces (judgment).
Blocking findings: none
 - Per-frame allocations: none. face_look and face_material run once in FigureBody.setup via _paint (figure_body.gd:87, 283-297); the "%d/%d/%d" key format is setup-only. No _process code was touched.
 - Teardown: _face_materials is a Dictionary owned by FigureModels, so the materials are shared and freed with it. Figures only set surface override references, so no per-figure leaks or orphans.
 - Prewarm: FigureModels.materials() lists every Face look (figure_models.gd:182-190), so there is no first-use hitch. It lists the very materials the figures wear, because face_material caches by the same key.
Advisory:
 - figure_models.gd:157-168: the cache key uses source.get_instance_id(), which is fine while the models stay loaded. If the kinds ever reload, the stale-keyed entries linger until the FigureModels is freed (judgment; minor).
 - figure_models.gd:182: `var name` shadows Node/Object.name only inside a RefCounted, so harmless, though gdlint may flag it (check passes it? the check is not run here).
 - Owner hardware: confirm the +1 head surface at 240 Hz Ultra with a full match, and the draw-call monitor from a rendered --perf run (F3 overlay).
Fixes: none required.
