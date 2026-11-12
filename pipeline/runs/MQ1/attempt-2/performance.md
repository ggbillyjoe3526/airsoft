Task: none (MQ1) · head 6029fe9 · Verdict: Pass
Run: none (no --perf match, no GPU, check suite running); diff read only · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the diff
Metrics: not measured (judgment). Textures fetches unchanged: 5 texture() calls in the include, same as attempt 1. glb triangles unchanged (same meshes). Install: assets/ 126 MB total, replica glbs +1.2 MB (aeg 4.35, pistol 3.76, smg 3.98, sniper 1.63, cyber 1.35 MB), grain png +36 KB; far under 500 MB.
Regressions (> 10 % worse): none measured
Blocking findings: none
 - Allocations: replica_surfaces.gd:107-110 dress() sets four shared pre-built Array[Vector4] once per material (not per frame); _build() runs once (judgment).
 - Caching/freeing: replica_paint.gd:140-160 _surface_of caches by plain/mask/kind, capped at MAX_SURFACED 160 (cleared past it); clear() (:220-223) empties _surfaced, called at play_session.gd:1667. Rename complete: no stale worn_materials/MAX_WORN/OWN_GLOW references left in game, tests or tools.
 - Prewarm: play_session.gd:919 passes ReplicaPaint.surface_materials(); one shader for every replica and paint, so no new variants (KINDS 16 changes array size only, one compiled variant).
 - Shader cost: replica_surface.gdshaderinc:116-123 adds a handful of ALU ops (max/min, one divide, one smoothstep, a dot, mix) and SPECULAR per fragment, no fetches; uniform data 4 x 16 vec4 = 1 KB per material, uploaded on change only (judgment).
 - studio_sky.gd: static cached Sky (menu pictures only, 128 px radiance, rendered once per sky); not on the gameplay path.
Advisory:
 - game/play/replica_surface.gdshaderinc:100-113 still 7 grain fetches a fragment on the replica in the hands, no preset hook (unchanged from attempt 1, not measurable without a GPU); worth a rendered check on the owner's Low-preset hardware.
 - game/play/replica_paint.gd:143-144 the cap clears the whole cache, so ShaderMaterials already on meshes stay alive via references but a later prewarm list shrinks; only matters past 160 combinations (judgment).
Unexplained: none
