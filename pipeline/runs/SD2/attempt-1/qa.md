Task: SD2 · QA commit none (nothing committed, as asked) · Verdict: Fail (one defect, cosmetic; see below)

Blocking
- game/play/station/station_detail.gd:329 (`_hatches`): the ceiling test is `solids.solid(x, top+0.05, z)`, which is true for any solid, so a pillar
  that runs through a room's ceiling counts as ceiling. One hatch (frame and panel, 72 vertices) is laid inside the pillar at
  (-41.55..-39.45, 8.9..24.9, -8.55..-6.45), in the passage zone whose top is y 18.91, at about (-40.5, 18.9, -7.17). It is buried and
  invisible, and costs only a few triangles. Pinned by test_fittings_do_not_sink_into_walls_or_stand_in_a_walkway (fails now).
  Fix: for a hatch, also require that no solid contains the point just under the ceiling (top-0.05).
  Judgement call: it has no visible effect. If the owner takes it as advisory, loosen or drop that test.

Advisory: none. Checked and clean:
- No vertex in the 0.85..2.35 m band of any hall or passage.
- Every service door has wall behind its whole leaf, so none sits in a doorway.
- Vents keep clear of the fixtures.
- Build is deterministic.
- The mesh and material are freed with the node, and repeated builds leave no orphans.
- A null map, a null config, no station, no fitted room and `min_room` huge all return null.
- Degenerate settings (step 0.05, hatch_pitch 0.5) build without error.
- The play_tuning.tres entry loads, and the config round-trips through ResourceSaver.

Tests added (tests/unit/test_station_detail_qa.gd, 11 tests; the existing test_station_detail.gd and test_station_dress.gd are unchanged and pass)
- :18 null_inputs_and_a_map_without_a_station · null map, null config, station = null · fails if the null guard at station_detail.gd:22 is removed
- :26 a_config_that_fits_no_room_builds_nothing · empty `rooms`, huge `min_room` · fails if the `pieces == 0` return is removed (an empty mesh would be returned)
- :35 degenerate_settings · fine step and hatch pitch, no script error · passes; guards against hangs
- :46 vertices_in_halls_and_passages_never_enter_the_signs_band · strict vertex check, stricter than the existing centroid test · would fail if a pipe, conduit or vent were lowered into 0.85..2.35 m. I did not stub the change out to check.
- :64 fittings_do_not_sink_into_walls · no vertex more than 6 cm inside a wall, pillar or floor block · FAILS, the hatch bug above
- :84 every_door_stands_against_a_wall_across_its_whole_leaf · five widths by three heights probed behind the leaf · would fail if a door were placed over a doorway
- :112 vents_keep_clear_of_fixtures · vent-coloured vertices against the fixtures · would fail if the `_clear` check in `_vents` were removed
- :131 build_is_deterministic, :141 freeing_releases_mesh_and_material (weakrefs), :158 repeated_builds_leave_no_orphans, :166 tres_round_trip
  · lifetime and config checks. I did not stub any of the four out; the weakref test fails if a reference to the mesh or material is held anywhere.

Run (by file, with -gdir=): test_station_detail_qa 10 pass / 1 fail, 7.4 s; test_station_detail 6/6, 1.5 s; test_station_dress 22/22, 5.2 s.
Raw output: pipeline/out/qa/sd2-qa.txt, pipeline/out/qa/sd2-existing.txt. I did not run tools/check.sh or the smoke test, because another full check was
already running on the machine.

Not tested: how it looks (needs a display; the eye pictures need an owner to look at them); the full play_session wiring and a pause/restart cycle
(not exercised, only StationDetail's own lifetime); Windows window modes.

## Re-check (commit e3cb540)
`_blocked_under` skips a hatch when a solid stands just under the ceiling (top-0.05) at its middle or any corner. That is the check I proposed.
Re-run by file with `-gdir=`: test_station_detail_qa 11/11 (the buried-hatch test now passes), test_station_detail 6/6 (Subway still gets its fittings).
No new issue found in the diff; the new helper is static and allocates only during the load-time build.
Verdict: Pass. I did not rerun test_station_dress, tools/check.sh or the smoke test. Nothing committed.
