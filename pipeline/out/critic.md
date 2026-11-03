Task: HV1 · The hit area fitted to the drawn figure (brief docs/records/HV1.md, no TASKS block)
Attempt: 1 of 4
Head: a582229f49b64babf96f7b74606eb8fe722821c9 (checks passed on it; CI #192 still running)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✗
Score: 6/8 → Retry (two non-blocking, judgment; and QA's HV1 report is missing)
Gate: pipeline/out/qa-report.md is UF2's report (f030bf5), not HV1's; no HV1 QA report exists, so Retry whatever the score.
Evidence for the passes:
1. AC1 test_hit_registration.gd:51 (8 poses x 3 sides, >=93 % struck) + _qa.gd:38,54 (lean, aim up, run, jump); AC2 :63 (>=95 % pass);
   AC3 _qa.gd:67 and bb_step.gd:215-220 (swept ray kept); AC4 test_hit_fit.gd:93 (top <= 1.15+0.03 < 1.2); AC5 hitbox.gd:192
   (fit null keeps _build; plywood untouched); AC6 bb_step.gd:215, bot_combat.gd:349,365 (room covers the inflate, shift and route).
2. No contract touched: HitFit/Hitbox are plain Resource/static code, no scene in the sim (Contract 1).
3. _fit_pose/_legs/_add_* reuse statics; values only; HitFit.table() caches once per process (perf advisory 4, one-time).
4. The built-in volume struck 64-75 % of crouched/running figures (FI7), under STRIKE_SHARE 0.93: the test fails without HV1.
Failed checks, with evidence:
7. [judgment] game/sim/hitbox.gd grew 261 -> 613 lines: ray geometry plus an emulation of the blend spaces and the mixer
   (_fit_pose :370, _add_gait :480, _legs :587, _add_upper :609). Split the fitted pose into its own script
   (e.g. game/sim/hit_pose.gd) and leave Hitbox the volume and its ray tests. game/debug/hit_shapes.gd:3 still says
   "the nine capsules" (now 12).
8. [judgment] Folder READMEs not updated for the files added: game/sim/README.md:43 has no hit_fit.gd row and still
   describes the old volume (head, chest, hips leaning; swinging legs); game/config/README.md has no hit_fit.tres row and
   its hit_config.gd row misses the fit, volume_reach/volume_top and fit_* shapes.
Must-fix for the next attempt: run QA on HV1 and write its report to pipeline/out/qa-report.md; move the fitted pose out
of hitbox.gd; update game/sim/README.md, game/config/README.md and hit_shapes.gd:3.
Advisory: HitConfig.fit's preload default is not written into sim_tuning.tres and test_saved_configs skips file-backed
resources; if an export ever drops it, build_volume silently falls back to the old volume. Check the exported build.
Owner should test in the game (exported build, not the editor):
- F5 on: wireframes sit on crouched, crouch-walking, running, leaning and vaulting bots (proves the fit shipped).
- Shoot heads/shoulders showing over 1.2 m crates: every visible strike counts; a crouched bot behind one can't be hit.
- Strafing, running and vaulting bots: BBs seen landing count, BBs just past them fly on.
- A BB clipping only an elbow or muzzle flies on (arms don't count).
- 8v8 firefight on Ultra and Low: no new hitches, including the first shots of a match.
