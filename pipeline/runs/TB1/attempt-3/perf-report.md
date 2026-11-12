Task: TB1 · head 1854d16 (delta a46ddad..1854d16) · Verdict: Pass
Run: headless, Subway built through StationSurface.mesh and StationFixtures.build (best of 5, same machine, HEAD vs origin/main worktree); no --perf match (delta is load-time geometry, no tick code) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and origin/main

Metrics (measured):
- Station mesh triangles: 23,490 (a46ddad: 23,490, unchanged; origin/main 14,092). Surfaces 1, one MeshInstance, one draw call for the station.
- Station mesh build: 132 ms now (a46ddad: 121 ms, same code path, machine noise; the 0.12 m frieze changes no face count) vs 84 ms on origin/main.
- Subway map load: 128 ms vs 95 ms on origin/main (+34 %, load-time only, from the TB1 mesh and 80 more blocks, 799 -> 879).
- StationFixtures (SM5, from main): 102 instances in 24 MultiMeshes, 25 nodes; build 27 ms here vs 20 ms on main, identical counts, so the merge adds nothing to it (the +7 ms is machine noise on the shared code).
- Orphans, static memory, frame times, draw calls: no node or resource added by TB1 beyond the main-equal fixtures; no GPU here, reported only.

Regressions (> 10 % worse than origin/main): triangles +67 %, mesh build +57 %, map load +34 %. All are load-time or vertex cost of TB1's intended geometry, already accepted at a46ddad; none is per-frame.

Blocking findings: none.
- Per-frame/per-tick work: none. station_fixtures.gd has no _process or _physics_process; MultiMeshes are static, built once at play_session.gd:447. TB1 adds work only inside StationSurface.mesh (map build). measured (grep) + judgment.
- Freed resources: fixtures are a child of the session, freed with it (the same lifecycle as on main; no TB1 change to play_session.gd). TB1's new RefCounted data lives on MapData. Test build and free of StationFixtures left no orphans in my run.
- Materials/shaders: no new material or shader in TB1; SM5's glow and printed materials come from main (its prewarm is SM5's concern, passed there). No preset bypass.

Advisory:
- station_surface.gd:150-181 (_add_ribs / _add_facing): per-quad Array[Vector3] allocation at build only; the likeliest share of the build cost. judgment.
- 24 MultiMesh draws for fixtures plus the station mesh: fine on the target, but check draw calls on the owner's Low hardware. judgment.
- Station tris +67 % over main also land in any shadow pass; verify frame time on owner hardware (Low, 60 FPS).

Fixes: none required.
Unexplained: none.
