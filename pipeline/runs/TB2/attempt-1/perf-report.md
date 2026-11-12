Task: TB2 · head 41e8db5 · Verdict: Pass
Run: not run (no GPU; --perf not wired in smoke; the owner's check.sh smoke was green on 3e12b51/dd39d3a) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and origin/main's diff
Metrics: static diff review only; no frame time, draw call or node numbers measured here
Regressions (> 10 % worse): Subway block count 879 → 1026 (+17 %), measured from the JSON; static boxes for the arches, load-time and broadphase only, not a Godot monitor or budget line, so advisory
Blocking findings: none
Advisory:
- data/maps/subway.json: blocks grew (vault_boxes for two more arches, minus cuts); colliders are static Jolt boxes built once at load, no per-tick cost beyond broadphase. judgment
- game/play/station/station_surface.gd:79-85, 156-175: the two vaults and _add_mouth go into the same single SurfaceTool commit as the platform vaults: no new node, material or draw call. Added geometry is 2 x (32 arc strips + ribs every 6 m over 32 m, about 5 rings x 32 quads) + 2 small mouth fans, a few thousand triangles at most. judgment
- station_surface.gd:117,142: `ends` Array[float] allocated per vault at map build only (load time, 2 vaults), not per frame. judgment
- station_dressing.gd:329-337: finish/mouth parsing is load-time only, no allocations in any tick. judgment
Freed resources: no new nodes, timers, tweens, signals or materials; finish reuses StationLook's existing materials, so nothing to free. judgment
Prewarm / presets: no new material or particle (vault finish reuses existing ones, so no first-use hitch); no shadow, resolution or draw-distance setting touched. judgment
Fixes: none required. Owner to check on hardware: the Subway frame time through the running tunnels, F3 draw calls (expected unchanged) and the longer-view overdraw of the arched ceilings.
Unexplained: none
