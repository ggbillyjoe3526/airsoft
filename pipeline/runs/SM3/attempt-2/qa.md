Task: SM3 · QA commit none (no tests added) · Verdict: Fail

Blocking
- tests/unit/test_props.gd:257 test_no_prop_colour_reads_as_a_team fails: ticket_machine 16162a, booking_counter 2a0d16 and 2e0d16 read as a team hue (not dull enough). The models changed in 8a5d277 (ticket_machine.glb, booking_counter via the new `mahogany` 501c30 in tools/blender/maps/prop.py:37 and game/config/look_config.gd:166). The other three files pass. I did not re-run the test on HEAD~1; the colours come from the glbs and the palette entry this commit changed.
  Fix: darken/desaturate those vertex colours, or move mahogany away from the team hues.

Advisory
- None found. GatePaddles.build returns null with fewer than 2 gates, no lane, or a missing mesh (warns); play_session null-guards _paddles in the build, _build_views, _process and _relight. Depot has none (tested). refresh() takes every character, so eliminated bots walking to the dead zone open a lane only if they pass within reach, which is harmless. Materials are added once (first_use) and a frame allocates nothing in refresh. The node is a child of the session and is freed with it.

Tests run
- test_station_hall_props.gd 11/11 (1395 asserts, 2.7s), test_look.gd 22/22, test_station_dress.gd 22/22, test_props.gd 18/19 (the failure above).
- Existing paddle tests (test_station_hall_props.gd:232, :250) cover paddles shut across each lane, and a lane's two paddles opening and closing. No gap that needs a new test.
- No tests added or changed, so there is no QA commit.

Not tested
- How the paddles look and swing in play (needs a display); owner to check in the Subway eye pictures/playtest.
- tools/check.sh and the smoke test were not run, as instructed.

**Re-check after the fix (7b9859a):** mahogany moved to 0x501c38 and the dim screens to `ink*0.6`; test_props 19/19, test_look 22/22. Verdict now Pass.
