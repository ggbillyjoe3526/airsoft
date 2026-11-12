Task: SM2 · QA commit 28e8bcc · Verdict: Pass

Blocking: none. Advisory: none reproducible.

Tests added (tests/unit/test_sm2_edges.gd, 7 tests, all pass; raw output pipeline/out/qa/sm2-tests.txt):
- :11 z-run drawn filling its box, faces wound as the x run's (turn, not mirror) · fails if RailingMesh._add's z branch mirrored (flips winding); checked by counting faces against normals (x run baseline: all clockwise, as Godot fronts).
- :38 one-bar, no-foot-rail and very flat runs stay inside their box with finite unit normals · fails if the foot/sink/plate guards were dropped (negative sizes leave the box).
- :56 an unreadable top/foot/post model returns null so MapLevel falls back to boxes · fails if build() used a partial kit.
- :63 empty Railings draws nothing (null).
- :67 set_heads names only platform_stair and a taller box scales the fit up · fails with the old fit (no head).
- :75 lifts re-pointed to face every direction build, draw a body, expose 4 materials and leave no nodes behind after free · fails if a node were leaked by build/free.
- :92 a lift with empty/unreadable car, landing, leaf, button models builds boxes, no Landings, non-empty leaves and buttons.
Existing SM2 tests (test_sm2_transit, test_lift_view) re-run: pass.

Read-only checks: _fits needs the far jamb on +x/+z, so doors facing n and e use the models and s and w keep boxes (as documented; leaf and button turns are right for all four, _turn checked). Rib branch is an else-if after the perforation branch, so perforated parts are unchanged.

Run: 21 tests, 1719 asserts, 1.4 s for the three touched files. Full tools/check.sh and the smoke test not run here (the build thread's run is in flight).
Not testable headless: how the ribs, models and railings look, and the lift's look at s/w doors (owner's list).
