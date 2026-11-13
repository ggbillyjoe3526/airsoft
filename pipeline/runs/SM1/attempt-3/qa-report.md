Task: SM1 · QA commit 953ccdb · Verdict: Pass

Blocking: none. Advisory: none new.

Fix 774f2da verified (diff 66f6ba5..774f2da):
- My z-fight pin (test_trains, no_lining_stretch_shares_its_plane...) now passes; it was failing before.
- mesh() draws the same blocks as before: faces_drawn() is the old inline filter line for line (clear, bar railing, TILE-less prop, vault collider, held by trains), and mesh() appends to `faced` exactly where it draws.
- Partial cover: _flush limits to blocks whose face lies in the plane (within 2 mm) and that touch the box; _cuts adds their edges, so a partly covering block removes only its footprint. Pinned below.
- Straddling block (face not in the side's plane): not flush, no cut, side stays lined; no coplanar face exists, so no z-fight. Pinned below.
- Default `faced = []` keeps the old behaviour for the other callers and tests.

Test added:
- tests/unit/test_trains.gd (end of file) · test_a_flush_faced_block_takes_only_its_footprint_from_the_lining_and_a_straddling_one_nothing: a 3x3 m flush block cuts exactly 9 m2 from a +z side, a straddling block changes nothing · fails without the feature: lining() without the faced list (old behaviour) returns the full area, so the "base - 9" assertion fails.

Runs (singly, via -gdir=res://tests/unit -gprefix=test_<name>): test_trains 39/39 (15345 asserts, 6.9 s); test_station_dress 29/29 (50239 asserts, 9.7 s). Note: `-gtest=res://tests/unit/test_x.gd` as in the brief ran the whole suite here (the config's dirs are added), so it never finished in 15 min; the prefix form is the quick one. tools/check.sh not run (running in background per the brief).

Could not test: how the lining looks at the train ends and corners in a real window (needs a display): owner to look at Subway's trains from the platform edge and through the tunnel mouths for flicker.
