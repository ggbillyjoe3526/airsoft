Task: SR1 · QA commit c8c6e59 · Verdict: Pass

Blocking findings: none.
Advisory findings:
- game/sim/railings.gd:_run_hit treats a path that starts exactly on a bar's face and heads away as a hit at t 0 (boundary inclusive). Not reachable today: Ricochet lifts a bounced BB 2 mm off (ricochet_config.gd lift_off) and 300 random BB shots at a bar all came to rest (no repeated landing). If lift_off is ever set to 0 a BB would re-land on the bar it left.
- game/map/map_level.gd build: a block whose kind is in both clear_kinds and railing_kinds gets a glass body but is still added to `railings` (and the Railings mesh run counter then drifts from the colliders). No such kind exists; only a config mistake would trigger it.
- A baked map would draw railings as solid blocks (author already lists this in KNOWN_ISSUES).

Tests added (tests/unit/test_sr1_railings_qa.gd, 10 tests, 40 asserts); all fail without the feature (the classes do not exist), and the key ones were mutation-checked:
- :44 bars agree with drawn boxes · 8,000 rays over 6 run shapes (along x/z, deep, too low for a foot rail, shorter than two bars, square), axis-aligned, vertical, grazing, a tick's length and up to 3 m · changing the bar search `ceili` to `floori` in railings.gd fails it (3 tests fail).
- :84 hit point and normal sit on the crossed face, facing the shooter · same mutation.
- :99 BB meets the nearer of a bar and the level (wall in front, wall behind, fraction of the whole segment) · BoxWorld.
- :118 zero, tiny, negative, NaN lengths, empty set, far outside the index do not fault.
- :140 a path starting inside a run's box exits a gap and stops in a bar.
- :152 300 random BBs fired through BBStep at a bar run all come to rest, none lands 8+ times.
- :183 glass beside a railing on a built Jolt level: sight passes both, ray_past_railings and bb_ray stop on the glass, ray stops on the box · removing the `past_railings` skip in BoxWorld also fails the earlier tests.
- :202 a ramp of the railing kind is an ordinary solid wedge (no bars, no Railings mesh, hides what is behind it).
- :214 the Jolt mover cannot walk through a railing · passes through when the railing is left out (checked).
- :232 5,000 bb_ray calls leave OBJECT_COUNT unchanged; building and freeing a railing level 3 times leaves no orphan nodes and no extra nodes.

Counts: test_sr1_railings.gd 12/12 (66 asserts); test_sr1_railings_qa.gd 10/10 (40 asserts, 1 s). Related files all pass: bb_step 18, box_world 11, bq1_glass_sight 6, bq1_qa 2, map_level 15, ricochet 9, st1_qa 9, st2_qa 3, street 5 (pipeline/out/qa/sr1_related.txt). Smoke test passes (zero script errors, 484 shots, 7 rounds; pipeline/out/qa/smoke.log). tools/check.sh not run (the worker runs it).

Not tested (needs a display or play): how the bars read at range and shimmer on a real window; the feel of shooting through a railing; mover feel against the box in a gap (the headless mover test only shows it is blocked).
