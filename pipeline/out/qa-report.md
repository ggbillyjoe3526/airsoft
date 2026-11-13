Task: none (MB1) · QA commit 1ba134c (tests unchanged; re-verified at head 85bcc67) · Verdict: Pass

Blocking
- none. The earlier fault (Subway north lane stops 1.1 m against 15 m about the middle) is fixed: layout.py LANES "n" now has (3.5,-7.0) and (12.4,-7.5), 4.45 m either side of x 7.95; test_subway_lanes_have_a_point_either_side_of_the_middle_about_equally_deep_for_both_ends passes.
Advisory (unchanged, still true)
- Woodland's middle lane ends at (58, 4.5) in the east camp's Back yard, 35 m from the nearest pole: by design per the record; pinned as an exemption in the defender-post test.
- Depot's and Woodland's middle lanes read inside the 3.5 m slack I pinned.
- Exit-time leak warnings and ExpectedError lines in test_baked_light are its deliberate mismatch cases.

Change since the last report (85bcc67): Woodland's north lane stops moved off the North bridge's deck ends ((-2.8,-41.5) west, (-6.4,-41.6) east), Subway's north lane gained two stops; both JSONs rebuilt. No test changed; the existing lane-depth, reachability and seeded-match tests cover both.

Tests (tests/unit/test_mb1_layouts.gd, 9 tests, added earlier; each was checked against origin/main's data, see the earlier run: the lane-depth, flag-B post, Subway flag B and sight-line tests fail on main).

Runs at head, one file each, -gdir= -gtest: test_mb1_layouts 9/9, 124 s; test_woodland_layout 17/17, 57 s; test_wg2_woodland_models 8/8; test_bot_lifts 8/8 (Subway lifts). Loaded machine.
tools/woodland/check.py: TOTAL 0. Subway and Woodland build_map.py ran earlier in this session: git status of data/maps was empty (JSON matches its scripts); not rerun on the coordinator's instruction.

Not covered: tools/check.sh, the full suite and the smoke test (skipped by instruction); win share (balance); dev tools. Note: two stray whole-suite runs I started by mistake (missing -gdir=) were left to end by themselves.
