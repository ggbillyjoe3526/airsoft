Task: SM4 · QA commit e0b7c32 · Verdict: Pass

Blocking: none.
Advisory:
- game/play/site/prop_layout.gd:103-111 · `facing` is read only by the default FIT lay (_fit_facing). On a block whose model has another lay (GRID, UNIT, RUN, BAY, SIDE, LINED...) it is silently ignored, and MapData does not warn. No Subway block does this today.
- game/map/map_data.gd:388-393 · `"facing": ""` in a file warns (empty is not one of the four); harmless.
- A facing on a ramp: dress on a rise block is dressed only under lay SET (prop_dress_config.gd:397), so facing never reaches FIT there. Not reachable in Subway.

Checked, no bug: colliders unchanged (all 799 Subway blocks identical to base apart from `dress` and `facing`; no other top-level key changed); other maps carry no facing and use none of the new models; StationSurface still leaves the named faces out (test_station_dress, 22/22, with the two SM4 adjustments clearing `dress` only to isolate one block); facing +x/-x/+z/-z fills the box and the front points the named way, also for a non-square box and a model long in z.

Tests added (tests/unit/test_sm4_facing.gd, appended):
- :test_a_facing_turns_a_model_long_in_z_and_its_depth_runs_along_the_front · all four facings with a z-long model fill and centre in a swapped-footprint box · without the facing branch the old path turns it toward the field's middle (and a z-long model in a x-long box would not fill it), so the +x/-x cases fail.
- :test_a_facing_does_not_change_the_height_or_the_foot · y range stays foot..box top for every facing · old path has no faced size, a swapped size would break the height only if y were scaled wrongly; guards the _faced_size swap.
- :test_a_numeric_facing_is_warned_about_and_the_map_still_loads · non-string facing gives empty facing, no problem · without the RISES check the number would be kept as a StringName.
(I could not stub production out, as I may not edit game/; fails-without reasoned from the code.)

Runs: test_sm4_facing 6/6 (37 asserts), test_sm4_subway_models 3/3, test_station_dress 22/22, plus 12 other Subway-using files, all green. Raw output: pipeline/out/qa/sm4-tests.txt. Full tools/check.sh and the smoke test were not run by me (another check run was in progress); not run: window or visual checks of how the booths and wagons look (needs a display; owner's list).
