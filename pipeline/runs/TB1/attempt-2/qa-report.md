Task: TB1 · QA commit 7306510 · Verdict: Pass

Delta re-checked: 3779e94..a46ddad (platform_floor, near-black ballast, trims, vault ribs).

Blocking: none.
Advisory: none new. The 70 GUT orphans in test_station_dress.gd are unchanged by this delta (same count with my test stashed).

Hunt results
- Look only: data/maps/subway.json changes are additions only (the 16 `trims`); no block is added or changed. Trims and ribs are drawn in StationSurface.mesh/add_vault only, and no collider is built from them.
- Trims lie flat: frieze 2 cm off the wall, cables 6 cm, edge face 1 cm over the track side of each platform edge. No z-fighting (each is offset from its wall) and none enters walkable space beyond 6 cm.
- Malformed trims: non-dict, missing finish and short box are warned and left out (existing test, now 8 warnings).
- Ribs: 5 cm under the arc, within the vault's length; a degenerate setting (zero depth, width or spacing, or a rib wider than the vault) draws none.
- Low detail: trims and ribs are flat faces, not relief, so Low does not touch them. Not tested separately.

Tests
- tests/unit/test_station_dress.gd:496 test_vault_ribs_stand_under_the_arc_inside_the_vault_and_off_turns_them_off · builds the vault mesh with and without ribs; the extra vertices lie within rib depth of the arc and inside the vault's length; a huge width adds none · fails with the `_add_ribs` call commented out (1 failing).
- Existing test_trims_lie_flat_on_the_tunnel_walls_out_of_the_way covers the trims' thickness, count and heights; I did not change it.

Suite: test_station_dress.gd 27/27 passing, 42037 asserts, 5.6 s. tools/check.sh was not run (running in the background); raw output in pipeline/out/qa/station_dress.txt.

Not tested: how the ribs, frieze and cables look in a real window, and whether the pale ribs against the near-black ballast read well (needs a display; owner).
