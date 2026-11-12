Task: TB2 · Subway's running tunnels arched like the trains
Attempt: 3 of 4
Head: 7b2332f (checks passed on it)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (one non-blocking check failed)
QA attempt 2 Pass (a1353d0; the attempt-3 delta after it is the lamp gating and the record, which performance attempt 3
passed). Performance attempt 3 Pass: the attempt-2 blocker is fixed. Lights start hidden (station_fixtures.gd:+113),
and play_session.gd:+2066 shows them only when the Lamp lights setting isn't Off.
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
8. [judgment] The record leaves two issues: the stepped shoulders on the greybox car, and the arch dark above the walls
   on Low and Medium (docs/records/TB2.md › Known issues). Neither is added to docs/KNOWN_ISSUES.md. The existing
   Graphics row (KNOWN_ISSUES.md:19) still says "Low ... is lit", but picture 4 shows the running tunnel black above
   its walls on Low even with lamp lights on, so that row is now wrong for these tunnels.
Passed, briefly: 1 the arch follows the car's profile. layout.py:+207-216 RUN_VAULTS springs at 2.7 with a rise of
   1.4. The south car is shaped under it (build_map.py:+457 under_arch, +487 car_shoulders, CAR_CLEAR 0.12). The
   train exemptions are gone, and test_tb1_vault_qa.gd:+138 checks the car's roof. Picture 2 reads as a clean curved
   lining on High, the default preset. The attempt-1 assert and comment are fixed (station_look.gd:+52). No .glb, so
   the model rule doesn't apply.
   2 no contract changed. The vault keys are optional, and a malformed one is dropped with a warning
   (station_dressing.gd:+334).
   3 the lights, mouth faces and colliders are all built at load. set_lamps runs only from _apply_graphics.
   4 test_station_fixtures.gd:+200 fails without lamps()/set_lamps and without the lights starting hidden. The
   4-vault counts fail on main.
   5 the rules live in tools/ and data, and the nodes only draw. Types are complete, and the light values are in
   StationFixturesConfig.
   6 a cosy Tube-style tunnel, not militaristic.
   7 the lights are children of the view and freed with it, and no scene was edited by hand.
Must-fix (non-blocking; do it in the records commit): add the two KNOWN_ISSUES rows (Graphics: the running arch is dark
   above the walls on Low and Medium, playtest; Maps: the greybox car's stepped shoulders until SM1, can wait), and
   correct the "Low is lit" wording of row 19 for the tunnels. The Low picture is stale (rendered with the lights on);
   replace it with the new Low render before the PR.
Owner should test in the game (at most 6, one line each):
- High: walk both running tunnels. Does the arch read as a smooth curve, and do the lamps light it evenly?
- Low and Medium: is the dark arch over the walls acceptable, or should these presets get a cheap fill (ruling)?
- From the south track at x 62 looking west: the car's stepped roof edges and the cab doorway slot up to the arch.
- Shoot up into the arch and over the car's shoulders: every BB stops on the surface you see.
- The north mouth at x 50: no seam or gap where the arch meets the platform vault.
- F3 on High along a running tunnel with its 12 lamp lights, and on Low: 60 FPS.
