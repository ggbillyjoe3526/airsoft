Task: HA1 · QA commit 9d19b41 · Verdict: Pass

Blocking: none.
Advisory: none new.

Reviewed git diff ec22685..44287ad (arms.glb, build tools, one test file; no game/ change). Delta checked against the brief:
- Holds that should not move: the build thread's run of test_sh2_qa, test_ha1_grips, test_ha1_qa, test_ha1_qa2, test_hands_on_replica, test_bp8_arms(_qa) and test_ha1_arms_fade (119 tests) covers the shotgun pump, grips, pistols, bots' copies, reloads/bolt/pump clips and ArmsTuck; I did not rerun them (one Godot rule) and found nothing in the delta that bypasses them.
- Budget: the existing 40,000-triangle and 8 MB checks (test_ha1_qa, test_bp8_arms) sit in the files that passed; glb is 6.48 MB.
- Eye test soundness (the brief's question): it judges every third far-side finger vertex of HandSurface_L and Skin_L (gloved and bare), asserting more than 50 points per mesh and per replica. Sound, but sampling was untested.

Test added:
- tests/unit/test_ha1_rifle_hold.gd:256 · test_the_eye_check_catches_a_fingertip_that_shows_and_holds_at_every_vertex · (a) a point placed above each replica from the hip eye must count as shown, proving _seen can fail; (b) all far-side finger vertices (step 1, not 3) of both looks on aeg, sniper, smg, shotgun are hidden. Checked: first draft put the probe beside the replica and _seen returned 0 (the probe was hidden), so the probe assertion does discriminate; it was moved above. Part (b) cannot fail without the feature by stubbing alone; against the previous model the existing test already fails (110 points), and (b) is the same check, denser.
- _finger_points gained an optional step parameter (default unchanged).

Counts: test_ha1_rifle_hold.gd 9 tests, 131 asserts, all passing.
Not tested: how the fingers look in play at the hip (needs a display; owner's list), the full suite and smoke test (build thread's one run).
