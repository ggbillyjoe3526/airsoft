Task: HV1 · The hit area fitted to the drawn figure (brief docs/records/HV1.md, no TASKS block)
Attempt: 2 of 4
Head: e6c1970dde8e36655045f68862645a91b8321203 (checks passed on it; CI #192 still running)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Gate: pipeline/out/qa-report.md is now QA's HV1 report (86cba0b, Pass); pipeline/out/performance.md HV1 Pass.
Evidence:
1. AC1 test_hit_registration.gd:51 + test_hit_registration_qa.gd:38,54 (every pose named, >=93 % struck); AC2
   test_hit_registration.gd:63 (>=95 % pass); AC3 _qa.gd:67 (400 m/s) and bb_step.gd:215-220; AC4 test_hit_fit.gd:93
   (top <= 1.18 m); AC5 hitbox.gd build_volume keeps _build when fit is null, range_targets untouched; AC6 bb_step.gd:215,
   bot_combat.gd:349,365 (room covers the inflate, the shift and the route); arms still out of the volume.
2. No contract touched: HitFit is a Resource, HitPose and Hitbox are static sim code, no scene in the sim.
3. HitPose.pose and Hitbox._build_fitted reuse static buffers and pass values only; HitFit.table() caches once per process.
4. The built-in volume struck 64-75 % of crouched and running figures (FI7), under STRIKE_SHARE 0.93: fails without HV1.
5. Typed throughout; the shapes are HitConfig.fit_*, the baked scalars come from FigureConfig through the baker.
6. Ballistic BBs, one hit and arms-don't-count kept; the hit area now matches what the player sees (pillar 1, 4).
7. The fitted pose moved verbatim into game/sim/hit_pose.gd (267 lines; diffed against a582229, only Hitbox.hit_top
   qualified); hitbox.gd is 353 lines of volume and ray tests; hit_shapes.gd:3 says twelve.
8. game/sim/README.md and game/config/README.md list hit_fit.gd, hit_pose.gd, hit_fit.tres and HitConfig's new fields;
   KNOWN_ISSUES, DECISIONS, the changelog note, PLAYTEST and the wiki page updated.
Failed checks: none. Advisory from attempt 1 withdrawn: fit is a preload, so hit_fit.tres ships as a dependency of hit_config.gd.
Must-fix: none. Merge once CI #192 is green.
Owner should test in the game (exported build):
- With F5 on, the wireframes sit on crouched, crouch-walking, running, leaning and vaulting bots.
- Shoot heads and shoulders showing over 1.2 m crates: every hit you see counts, and a bot fully behind one can't be hit.
- Against strafing, running and vaulting bots, BBs you see land count and BBs just past them fly on.
- A BB that only clips an elbow or muzzle flies on (arms don't count).
- In an 8v8 firefight on Ultra and Low, there are no new hitches, including on the first shots of a match.
