Task: TB1 · head a46ddad (delta 3779e94..a46ddad) · Verdict: Pass
Run: headless, Subway built through StationSurface.mesh (best of 5, same machine, both heads); no --perf match: the delta is a load-time mesh build, no tick code · budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against targets and the 3779e94 build

Metrics (measured, same machine):
- Station mesh triangles: 16,770 -> 23,490 (+40 %). Earlier pass logged 16,718; the 52 difference is the floor finish change.
- Station mesh build: 99.8 ms -> 121.3 ms (+22 %, +21 ms, once per map load).
- Blocks 879 -> 879, mesh surfaces 1 -> 1 (still one MeshInstance, one ShaderMaterial, one draw call for the station).
- Nodes, orphans, static memory: unchanged by construction (no node or resource added). Mesh vertex data grows by about 6.7k tris x 3 verts, roughly 1 MB (judgment, no index buffer).
- Frame times, draw calls: not measurable here (no GPU); reported only.

Regressions (> 10 % worse): triangles +40 %, build +22 %. Both are geometry/load cost, not per-frame cost; see advisory.

Blocking findings: none.
- Per-frame/per-tick work: none. Trims (station_surface.gd:74-77) and ribs (station_surface.gd:136, _add_ribs :150) run only inside mesh(), at map build. judgment, confirmed by reading the diff.
- New materials/shaders: none. Trims and ribs use existing finishes (look.vault_rib_finish, t.finish) in the same layered material, so no prewarm entry is needed. Presets: no new shadow/resolution/post setting in the diff.
- Freed resources: StationDressing.Trim is a RefCounted held by MapData; the SurfaceTool is local. Nothing left unfreed. Dressing.trims loads from data/maps/subway.json (+178 lines, 16 trims).

Advisory:
- station_surface.gd:150-176 (_add_ribs): each rib is steps x 3 quads (underside and two sides), via add_face with a per-quad Array/PackedVector3Array and Array[Vector3] allocation (_add_facing). Allocation is at build only, but it is the likeliest share of the +21 ms; if the build budget tightens, emit ribs with plain arrays reused across the loop. judgment.
- Ribs every 6 m add the bulk of the +6.7k tris, each rib's side faces mostly hidden against the shell (the side facing the tunnel is visible, the underside too). Low-end cost is vertex work in one draw, small next to the pass's 16.7k base. The ribs are not tied to a Low preset: consider dropping them on Low (look.vault_rib_every <= 0 already disables them, so it is one config line). judgment, owner call.
- No shadow-casting concern checked: if the station mesh casts shadows, +40 % tris also lands in the shadow pass; verify on owner hardware.

Fixes, ranked: none required. Optional: rib_every 0 on the Low preset; reuse arrays in _add_ribs.
Unexplained: none. Frame-time effect of +6.7k tris needs the owner's hardware (Low preset, 60 FPS target).
