Task: MB2 (attempt 2) · QA commit 80631f2 · Verdict: Pass

Blocking: none.

Advisory:
- tests/unit/test_mb1_layouts.gd:20,180-215 (the sight test) samples the strip at ROAD_SIDE 2.0 m, not the 2.5 m edge,
  and at 1 m steps along ROAD_WEST. It is honest: centre line and both sides, over 250 eye points, standing. A point
  on the 2.5 m edge is not covered.
- tests/unit/test_mb2_qa.gd's ROAD constant leaves out layout.py's two end legs, (-90,24) and (48,31). The JSON was
  scanned against the full ROAD. The only extra hit is the west camp palisade at (-88.263, 24.0), the gate wall at the
  road's end, which is not between the camps.
- Puddle in dressing.puddles at (-52.0, 30.5), 3.0 x 1.8 m. It lies on the strip, 1.1 m off the centre line. It is a
  ground decal, not an obstacle, but the owner may still read it as "on the road".

Criteria:
1. data/maps/woodland.json scanned against the full ROAD polyline. The only blocks within 2.5 m of the centre line are
   the culvert's own floor, walls and kerbs (the road's deck), plus the gate palisade above. No log, tyre, truck,
   crate, thicket or tree trunk is on the strip. No bush reaches it (116 checked, radius included). The 1800-tree far
   forest is placed outside the field (woods_shapes.gd:126).
2. The road is walkable end to end on its strip, and the route is under 1.1x the road's length. Seeded Woodland
   matches, all finished, held_up 0: Elimination 9 rounds, Attack / Defend 7 rounds, Plant The Bomb 5 rounds. The
   three-map match in test_mb1_layouts also gave held_up 0.
3. The sight test passes on the new road.
4. All 9 tests in test_mb1_layouts pass: lane rules, floor, reachability, bomb sites.
5. Woodpile heights pass: six 2.8 m gate screens, all in the camps; every other stack is 1.8 m.
6. Tyre tracks start on the road, and every point along the road has an area name. test_wear_marks and test_props
   were left to the full gates.
7. build_map.py then check.py gave TOTAL 0 and a clean `git status`.

Tests added in tests/unit/test_mb2_qa.gd: test_no_bush_stands_on_the_long_road,
test_the_tyre_tracks_run_along_the_new_road, test_every_point_along_the_long_road_is_named,
test_a_seeded_match_in_each_mode_on_woodland_holds_no_bot_up (seed 5, three modes: finished, hits, held_up 0).

Run (single files under shared CPU): test_mb2_qa 7/7 pass, 36 asserts; test_mb1_layouts 9/9 pass, 65 asserts.
Could not test: how the S bend looks and plays from the player's eye (the owner's play checklist).
