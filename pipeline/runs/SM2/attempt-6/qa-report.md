Task: SM2 · QA commit none (uncommitted, as asked) · Verdict: Pass

Blocking: none. Advisory: none new.

Reviewed `git diff 7b85ac5 f450d2b`: prop_dress.gd / prop_dress_config.gd (full_colour, Vector3 material key), escalator/spiral/platform/lift Blender scripts and glbs, build_map.py holes, fixtures.py poster row.

Tests added (tests/unit/test_sm2_full_colour.gd, new, uncommitted):
- test_full_colour_models_keep_by_alpha_and_others_do_not: every Subway prop view's material has keep_by_alpha equal to "its model is in full_colour"; both kinds are drawn. Checked: with prop_dress.gd's `_new_material` forced to keep_by_alpha false, it fails (2 of 3 tests fail); production file restored, git status shows only the new test.
- test_materials_are_shared_per_key_and_full_ones_are_separate: materials() lists each material once, has at least one full and one normal material, and no more full ones than full_colour models. Same stub fails it.
- test_the_default_full_colour_list_is_the_escalators_and_stairs: the four models are in the default list (fails if the config entry is dropped).

Fixtures never inside a deck piece: not added. The escalator deck pieces (ramp_barrier boxes) are emitted as map blocks (build_map.py:460), so the existing test_station_fixtures `test_each_fixture_stands_in_its_room_on_its_wall_ceiling_or_floor_and_in_no_block` already checks every fixture against them, including the moved poster row. It passes.

Touched test files, all green:
test_props 19/19 · test_lift_view 11/11 · test_sm2_edges 9/9 · test_sm2_transit 6/6 · test_station_fixtures 9/9 · test_station_dress 22/22 · test_saved_configs 1/1 · test_sm2_full_colour 3/3. Longest file about 5.4 s. I did not run tools/check.sh or the smoke test (not asked).

Not testable here: how the safety yellow and the lift display read on screen (needs a display; owner's list). A test cannot pin the regenerated glbs' newel/rim geometry without pinning vertex values.

Production seam needed: none.
