Task: MT1 · head 82002d94 · Verdict: Pass
Run: seed 1234, smoke match (Depot), headless, head vs 410b8151 worktree; Kingsmere build timed by script · budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against targets and origin/main
Metrics (measured, headless; draw calls and frame times need a GPU and are not reported): nodes_max 2141 / 2139 (ok), orphans_max 991 / 991 (ok, same as main), steady nodes 1896 / 1894 (ok). Frame counts differ (1271 vs 2208; the smoke run is time-bound) so per-frame script time was not compared.
Kingsmere build (headless, one-off, measured): MapData load 117 ms (13k-line JSON, 854 blocks; Depot 7 ms), RoofView.build incl. 106 plain_reaches scans 17 ms (Depot 4 ms), AreaProbes 0 ms (18 probes, under probe_most 24). 106 spot lights built (Depot 91).
Regressions (> 10 % worse): none (the smoke match plays Depot, which the diff leaves unchanged apart from +2 nodes from the new FlagView "Standing" child)
Blocking findings: none
Advisory:
- game/play/roof_view.gd:288-300 plain_reaches (judgment/measured): 106 x floor_under over ~854 blocks, 17 ms once at build; fine. If maps grow, a spatial index would help.
- game/play/roof_lamps.gd:136-140 (judgment): 106 shadowed spots on Ultra (Depot 93) go through the preset's lamp_near / distance_fade_shadow, so no preset bypass. Lights have short ranges (floor + 2.5 m), so few overlap in view. The shadow atlas slot count (game/save/graphics_apply.gd:41 PROJECT_SLOTS) is untested with 106 lamps; needs a GPU run on the owner's hardware, both Ultra and High.
- game/play/look/area_probes.gd (judgment): 18 band probes, all ReflectionProbes update-once in the existing pattern; the interior probes from the floor up per band are fine. Render cost belongs to a rendered run.
- game/play/flag_view.gd:46-52 (judgment): one extra Node3D per pole, built once; nothing per frame.
- Memory/teardown: no new per-frame or per-tick code in the diff (no _process, _physics_process or signal-handler changes). New nodes (Standing, lamp lights, probes) are children of their views, freed with them. No new shader or material type (plain roof reuses the glow and ceiling materials), so no prewarm entry is missing.
Fixes: none required. Recommended: a rendered Kingsmere run on the owner's hardware (Low 60 FPS, Ultra 240 Hz) to record the first baseline, with attention to the 106 shadowed lamps on Ultra.
Unexplained: none. The 991 orphan max exists on main too (the smoke run's menu pages); the exit-time RID leak errors are the known ones.
