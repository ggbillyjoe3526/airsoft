Task: MB2 · QA commit (see git log, trailer Agent: qa) · Verdict: Pass

Blocking: none. Advisory: none.

Checked:
- Rebuilt data/maps/woodland.json with tools/woodland/build_map.py: identical to the committed file. check.py prints TOTAL 0.
- Nothing is cut by the Culvert stand (x 21.3..23.0, z 39..45, +0.4 m margin): the only blocks in it are the road stack and the spruce thicket. No spawn, flag, light or foliage piece is there. Lane point (24.5, 43.8) is the only point nearby; it is walkable (existing every-lane-point test).
- Both lane points either side of the stand (20.6, 46.4) and (24.5, 43.8) route to each other both ways. The gap south of the stand is walkable at x 21..23 for z 45.4..46.2; z 46.4 is blocked by the cordwood at x 22..28, so the gap is about 1.2-1.5 m wide: enough for a body, but tight.

Tests added (tests/unit/test_mb2_qa.gd, gdlint clean):
- test_only_the_six_camp_gate_screens_stand_taller_than_a_woodpile: every cordwood stack of 1.2 m or more is 1.8 m except exactly six 2.8 m ones, all inside the camps (|x| >= 70). Fails on the old layout: the road stack at x 20.5 stood 2.8 m (seven tall, one outside a camp).
- test_nothing_but_the_stack_and_the_stand_stands_in_the_culvert_stand_box: no other block, flag or spawn in the stand's box. Fails if any is moved or added there.
- test_the_south_lane_is_walked_round_the_stand_between_its_two_points: routes both ways, and the south gap is walkable. Fails if the stand grows south or a block closes the gap.
I did not stub out the feature to watch the new tests fail; the old-layout reasoning above is from the diff.

Runs: test_mb2_qa + test_mb1_layouts: 13/13 pass, 123 s (raw output in pipeline/out/qa/mb2.txt). I did not run tools/check.sh or the smoke test (caller already ran all 101 woodland-related files: 1,270 of 1,271 pass, 1 pending).
Could not test: how the spruce looks and whether the stand reads right in play (needs a display, for the owner).
