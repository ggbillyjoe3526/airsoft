Task: SM4 · head ec4c175 · Verdict: Pass
Run: none (read-only judgment of 1da740a..ec4c175, per brief; check.sh already running elsewhere) · budget: no baseline yet, judged against targets and the attempt-1 pass
Metrics: not re-measured. Node counts, draw calls and materials are unchanged by the diff (judgment).
Regressions (> 10 % worse): none
Blocking findings: none
 - Models (assets/models/props/*.glb, tools/blender/maps/*.py): rebuilt, 956-2,972 triangles each, still one vertex-coloured mesh each, so draw calls and materials per prop are unchanged (judgment). File sizes moved -3 % to +29 % (cable drums 41 -> 53 KB, the largest); small, load-time only.
 - game/play/station/station_surface.gd:_add_track: with sleepers=false it emits 2 boxes per track instead of 2 plus one per 0.7 m, so fewer faces. It runs once at build time into the existing SurfaceTool, with no per-frame work and no new node or resource (judgment). The `look.sleepers` branch is a plain bool read.
 - game/config/station_look.gd:30: the rail finish is now PaintedMetal012, already in the station's texture array (also used by steel and car), so there is no new material or texture and no shader prewarm gap (judgment). The rail colour, PBR values and rail_size (0.09 x 0.12) are only data; the larger rail adds no faces.
 - Presets: nothing touches shadows, resolution scale or draw distance.
Advisory: none. Rails are still scenery with no collider; the only effect is slightly fewer triangles in the track mesh.
Fixes: none needed.
Unexplained: none
