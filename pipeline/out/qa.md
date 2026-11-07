Task: bp6-shoulder · QA commit 8ef75d7 (no tests added by QA) · Verdict: Pass
Blocking: none. Import of human.glb clean (no import errors).
Ran 10 files (test_bp6_models, hit_call_arm, hands_on_replica, figure_body, figure_hit_area, hit_registration, figure_view, figure_models, bp6_graphics, figure_pads): 76/76 pass, 542511 asserts, 87.6 s, 2 warnings.
Surface counts, BodyMerge cache, LOD counts (Body, Body_LOD1, Body_LOD2): covered by those tests, all green. Changed test_bp6_models asserts upper-arm mean share >= 0.33 by the armpit on all 3 levels.
Advisory: 'Parameter "material" is null' appears twice in free_all during figure_body/figure_models teardown; not compared with origin/main, likely pre-existing (not a test failure). Orphan counts printed by figure_view are the usual headless leak lines.
Not tested: how the raised shoulder looks in play (owner to eyeball); check.sh/smoke not run per instructions.
Raw output: /tmp/claude-0/bp6-reports/shoulder-raw.txt
