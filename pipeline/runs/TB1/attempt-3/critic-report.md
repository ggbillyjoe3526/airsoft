Task: TB1 · Subway's platforms like the Tube
Attempt: 3 of 4
Head: cc301af (full check.sh passed on 30d4c24; the gates the later delta touches were re-run green on cc301af)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
Passed, briefly:
1. Vaults, edge-only yellow, white trackside wall, clean floor and detail as in attempt 2. The attempt-2 must-fixes are
   done: rebased on SM5/SM5B; the frieze sits at 3.96 m, over the wide posters' 3.95 m tops
   (tests/unit/test_station_dress.gd:384); the "Morrin Street" ask is met (tools/blender/maps/station_signs.py:+37,
   +529, +533); the name sheet is #c0652f (signs.png name cell samples 187,102,51); rods are added at
   tools/subway/build_map.py:+600, +613. No .glb is added or reshaped, so the model rule does not apply.
2. No contract is touched. Station data and tools only.
3. Rods, trims and words are built once at map load (StationSurface.mesh). There is no _process and no connect in
   the changed scripts. Perf passed (+8 boxes since then, load-time only).
4. test_station_fixtures.gd:+318 gives ends [0,0] with no rods. test_station_dress.gd:367 fails without the vault
   zones (verified by the build thread). test_no_fixture_is_drawn_through_a_trim fails with the attempt-2 frieze at 3.88 m.
5. Typed throughout. Rod sizes are named (ROD, ROD_IN, ROD_INTO, fixtures.VAULT_DROP). Look values live in StationLook.
6. The v7 renders read like the Tube: tiled barrel vault with rings, an orange name board, boards on long rods,
   yellow only at the edge. Toy tone is kept, no gore and no military look.
7. Scripts are 80 to 370 lines and add no nodes. Advisory: game/config/station_look.gd:52 still says the ribs are
   "pale grey paint", but they render as dark rings (record and PLAYTEST were fixed). Fix it with the next touch.
8. Record, KNOWN_ISSUES row, PLAYTEST and README rows are in place. The changelog/FEATURES pass is still to come.
   Subway has no wiki page beyond the Roadmap.
Must-fix for the next attempt: none. Advisory: the station_look.gd:52 comment. QA's _stripe band also lets off any
   dull orange on the whole sign sheet, so a future dull orange team colour would slip past that test.
Owner should test in the game (at most 6):
- Name boards read dark rust-brown in the fallback renders (71,34,15). Check they match the trains' stripe on Forward+.
- The frieze and shaded floors render navy (about 30,75,105) in the fallback renders, near Alpha's blue. Check they read grey-green, not team blue.
- Departure-board rods meet the vault cleanly, with no gap or poke-through at either end, on both platforms.
- The vault is still a mid-grey against the white walls (the KNOWN_ISSUES row): is it acceptable?
- The top edge of the wide trackside posters under the frieze: no flicker at a distance.
- F3 on Low along a platform: still 60 FPS with about 67 % more station triangles.
