Task: GA1 · head a1bbbc9 · Verdict: Pass
Run: figure_bench headless, 11 figures, 600 frames (10 s), eye in the middle, same machine, this head vs origin/main worktree · budget: no baseline yet (no pipeline/perf-budget.json), judged against targets and origin/main
Metrics (measured, script time; noisy, single run each): animation per figure mean 116.0 us / 128.6 (ok), p99 308 / 387 (ok); skeleton per figure mean 24.5 us / 25.2 (ok), p99 59 / 89 (ok); both, 11 figures mean 1.545 ms / 1.692 ms (ok). Frame times on owner's hardware only; no rendered run (no GPU), so draw calls not measured.
Regressions (> 10 % worse): none (the differences are inside run-to-run noise, in this head's favour).
Blocking findings: none.
 - Hitbox.step_walk_cycle/cycle_length/_by_speed (game/sim/hitbox.gd:173-205): judgment, no allocation. PackedFloat32Array reads, a loop of at most 3 steps, early return on moved <= 0 (standing still costs nothing). Two lerps per moving character per tick, negligible.
 - HitPose.pose steady turn (game/sim/hit_pose.gd:97-104): judgment, Basis/float values only (stack), no heap; still_heading is cached.
 - HitFit.still_heading (game/sim/hit_fit.gd:114-119): judgment, first call reads two samples and caches in _still_headings (Vector2 NaN sentinel); later calls are one lerp_angle. No per-tick allocation. Cache is per fit resource, not per character.
 - FigureBend.steady_upper (game/play/figures/figure_bend.gd:85-96): measured, skeleton per figure +0 (24.5 vs 25.2 us). Two get_bone_global_pose and one set per figure per frame; Transform3D/Basis are values. Early-outs on steady <= 0.
Advisory:
 - game/sim/hit_pose.gd:5-6 doc line is now over the 120-column style (gdlint line length may flag it); not a perf matter.
 - Asset size: human.glb 4.03 -> 4.48 MB (+11 %), robot.glb 3.25 -> 3.70 MB (+14 %; the brief's 3.54 is not what git shows), hit_fit.tres 56 -> 72 KB. About +0.9 MB install in total, from old clip data left unused in the binary chunk (splice.mjs). Judgment: within noise of a multi-hundred-MB install, but stripping the dead chunk would win it back; owner sets the install budget, none recorded. Load time unchanged: models 60.2 ms vs 59.4 ms, set_body 154 vs 157 ms (measured).
 - hit_fit.tres phases 24 -> 32: HitFit tables built once on first use, so +33 % one-time memory/build for the tables only (judgment); no per-tick cost, since sampling is indexed with interpolation.
 - tools/gait_pictures.gd and tools/blender/bot-figure/gait/* are dev-only; confirm they are excluded from export presets (judgment, not checked).
Fixes: none required.
Unexplained: none. The bench is scripted (no simulation), so Hitbox.step_walk_cycle and HitPose per tick are judged by reading, not by a measured match run; no --perf bot match was run.
