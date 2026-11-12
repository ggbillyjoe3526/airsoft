Task: TB1 · QA commit (see git log, Agent: qa) · Verdict: Pass

Blocking: none. Advisory: none.

Merged-tree checks (head 1854d16):
- Dress parse keeps every section: fixtures (102), trims (16), words, vaults (2), zones, strips, tracks all load (test_station_dress 29/29, incl. the two new TB1 tests).
- SM5 fixtures vs vault colliders: SM5's own "in no block" test passes (test_station_fixtures); the vault lid starts at y 4.1, all wall fixtures (clocks 3.8, CCTV 3.65, name boards 3.15) sit below it.
- Fixtures vs trims: the frieze is 3.96-4.08; clocks hang below their origin (top ~3.83), name boards span 2.9-3.4, CCTV 3.5-3.73, so they clear it. Wide posters top at 3.95, under the frieze. Now pinned by a test.
- StationFixtures and StationSurface coexist: test_station_dress and test_station_fixtures both pass in the same tree, no orphans test failures; test_subway_rename 3/3.

Test added:
- tests/unit/test_station_fixtures.gd:196 (end of file) · test_no_fixture_is_drawn_through_a_trim_or_the_vault_s_lid: every fixture's world AABB (model mesh, yaw, position) against every trim box and each vault's lid · checked by moving the four frieze boxes in data/maps/subway.json to y 3.1-3.3 (through the name boards): 1 failure; reverted, 9/9 pass.

Runs: test_station_dress 29/29 (7.5 s), test_station_fixtures 9/9 (1.7 s), test_subway_rename 3/3. Exit-time RID/resource leak warnings are the known ones; the "does_not_exist.res" texture-array error is the deliberate missing-arrays test. tools/check.sh not run (running elsewhere); smoke test not run by me.

Not tested: how the frieze, posters and lamps look in a lit window (needs a display); owner to look at a platform wall in play.
