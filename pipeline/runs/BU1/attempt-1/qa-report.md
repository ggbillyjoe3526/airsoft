Task: BU1 · QA commit (this commit) · Verdict: Pass

Blocking: none. Advisory: none found.

Tests added (tests/unit/test_bu1_qa.gd, 5 tests, 11 asserts, 1.4 s):
- :20 thin bush fired through at exactly close_awareness, held at +0.02 m · boundary of the flat-distance check · old rule holds the ~0.56 m of leaves (> 0.25), so the first assert fails without the feature.
- :32 line straight up/down (flat 0 m) · counts only leaves before the body; line shorter than a body never held · old rule would hold the 0.5 m case.
- :40 three small bushes in a row add up past leaf_stop_depth, one thin bush is fired through · old rule holds the single bush.
- :48 verdict equals leaf depth to body_radius short, standing and fully crouched shooter at point blank · exercises the new formula; old rule disagrees for the thick-bush case.
- :88 sim shoot-out at 0.5/0.65/0.8/1.0 m in one bush · wherever the rule fires (0.5, 0.65), a hit lands within 20 s, so BBs are not wasted in the leaves (bb_step stops at leaf_stop_depth; body hit is tested before the stop). Checked by logic, not by stubbing the fix.

Regressions run, all green: test_bu1_point_blank_bush 4/4, test_bushes 39/39, test_bot_angles 16/16, test_night_sight 12/12, every test_bp8* file (no failures; pipeline/out/qa/bu1-bp8.txt).

Hot path: the new branch uses only locals, floats and Vector3 values (no arrays, no dictionaries, no new nodes); the same one depth() call as before.
Friendly fire: leaves_in_line only judges leaves; the teammate-in-line checks are separate (_line_of_fire_blocked) and untouched. Not separately tested.

Not tested: full Woodland night seed 14 match (the thread's check.sh / smoke run), a teammate standing in the bush beside the target, lean at point blank (lean moves the eye, covered by the same formula).
