Task: SX1 · head 32f364e · Verdict: Pass
Run: none (no match run: suite and benches busy on a 4-core machine, per brief) · budget: pipeline/perf-budget.json does not exist in this repo; no baseline yet, judged against targets and the diff (judgment only)
Metrics: not measured. Nodes, orphans, static memory and script time cannot change for the remaining maps: the diff only removes content.
Regressions (> 10 % worse): none expected (judgment)

What changed at runtime (game/, 10 files in the stat): comments only, plus prop_dress_config.gd (-30/+2 lines): 23 model_paths entries, 4 model_lays and 4 grid_cells entries for Street-only kinds removed. No new code, no allocation, no signal, no node, material or shader added. Fewer dictionary entries means a slightly smaller config resource at load; no per-frame effect.
Dangling references: git grep of the 23 removed model keys, street.json and Street paths in game/, data/, scenes, project.godot, export_presets.cfg and tools/*.sh finds none. The &"skip", &"lamp", &"fridge" hits (map_style.gd, noise_config.gd, site_look.gd, site_dress.gd) are box-kind keys used by Depot/Woodland dressing, not model paths: a missing model would only fall back to a box, and none is missing.
Ambience "street" stays (data/maps/range.json:3, play_tuning.tres loops): audio kept on purpose, unchanged cost.

Install size: 46 .glb removed (23 props plus .import/.uid pairs counted by file; 50 binary/asset files in all) and 2.76 MB of asset/data bytes (glb, png, jpg, ogg, wav, json, bin) deleted from the tree. The install and export shrink by about that much; nothing grows. The pooled/prewarmed paths (BBs, puffs, shader prewarm) are untouched; removed props carried no prewarm entries.
Blocking findings: none
Advisory: none. A rendered/headless --perf run on this head vs 53234c6 would only confirm "no change" for Depot/Woodland; not required for a deletion-only diff.
Fixes: none needed.
