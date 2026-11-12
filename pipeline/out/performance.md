Task: SM5 · head 94294ee · Verdict: Pass
Run: no rendered run (cloud, no GPU); static measurement of the diff b43f473..94294ee · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the install budget
Metrics: signs.png 4.52 MB on disk (measured; install budget 500 MB, assets/ total 122 MB, ok). VRAM BC7+mips about 5.3 MiB vs about 4 MiB (+1.3 MiB, judgment from size). Poster triangles: 28 placed x 38 = about 1.06k (measured from data/maps/subway.json). Fixture MultiMeshes: 24 model entries (24 distinct models, 103 instances; 16 are posters). Draw calls: about +12 (judgment, not rendered). Frame times: not measured.
Regressions (> 10 % worse): none measured. Draw calls rise from about 12 to about 24 fixture draws on Subway (judgment; unconfirmed in a render).
Blocking findings: none
Advisory:
- game/play/station/station_fixtures.gd:85-94 one MultiMeshInstance3D per model, no visibility range set; shadows are off (line 94), so the cost is draw calls only. 12 extra draws is small against Low's 60 FPS target but unmeasured on low-powered hardware. Judgment.
- Option 1, one poster mesh per size (small, wide) with instance custom-data UV offset: cuts the poster draws from 16 to 2 (saves about 14). It needs a shader change and the prewarm entry; worth doing only if the owner's Low-preset run shows draw-call pressure. Judgment.
- Option 2, visible_instance_end_margin or visibility_range on poster MultiMeshes: posters are tiny, per-MultiMesh culling is by whole AABB, so it helps little with posters spread over the map. Not recommended. Judgment.
- signs.png 2048x2048 is shared by all printed faces (one material, no new material or shader), so no new prewarm entry needed. If the Low preset ever needs VRAM headroom, import the sheet at half resolution there. Judgment.
Fixes, ranked: none required.
Unexplained: none. Please record a rendered Subway draw-call count on the owner's hardware to start perf-budget.json.
