Task: SM4 · QA commit none (no test committed) · Verdict: Pass (one advisory)

Scope: c5ff3d4, vehicles and buffer stops centred on TRACK_Z (±10.75). Ran only tests/unit/test_sm4_subway_models.gd (the box-fit test passes against the rebuilt models). No full suite, no check.sh.

Blocking: none.

Advisory (nav grid, bots; physics bodies unaffected):
- A probe test (written, run, then discarded) counted walkable nav cells across each track room at each vehicle's x. An empty pit is walkable from about z 9.4 to 12.1 (3.5 m room, platform wall at 9, outer wall at 12.5).
- The 0.75 m side gap is wider than the 0.64 m capsule but narrower than the grid's wall margin. Nothing is walkable beside these vehicles: skip wagons at x -17, -1, 7 (south trench, tools/subway/layout.py:188-190); engineering wagon at x 38 (north track, layout.py:192); platelayer trolley at x -45.75 (west pit, layout.py:191).
- Before the change the staggered skips left 1.3 m on one side, which the nav accepted. So the pits are now cut into separate pieces for bots, and a bot or body in a pit cannot walk past those vehicles inside it.
- Bots do not look stuck: climb links run all along the pits (test_bot_climbs), so a bot leaves over the platform edge. I could not confirm a vaulting route past a vehicle, because my probe start points fell on unwalkable cells and snapped away. Not proven either way.
- Passable by nav on at least one side: ballast wagons (x 57, 66.5; the 0.9 m half-width leaves about 0.95 m to the wall), the short and long trolleys, the small cable drum. These are in the 3.6 m tunnels (9 to 12.6), so the lane is wider.
- Suggested fix for the worker: narrow the skips, the engineering wagon and the west trolley to about 1.6 m (about 0.95 m a side), or accept the pits as nav dead ends and note it in KNOWN_ISSUES.

Overlaps (read from layout.py, no tool run): none found.
- Skips x -18..8 sit inside the trench (-52..30), clear of the south train (30..60).
- Engineering wagon x 36..40 sits in track_n_e (16..50); the north train ends at 16.
- West trolley x -46.5..-45 and buffer stops x -52..-51.5 sit in track_n_w (-52..-44); the train starts at -44.
- Short trolley x 60.5..61.8, ballast wagons, cable drum (x 69.5..70.9, short of the cross passage at 74) and long trolley (x 66..68, south) sit inside their tunnel rooms.
- Cab steps and cab_n/cab_s (x 60..62, south) do not touch the north-side blocks, and the south trolley starts at x 66.
- The lift shafts are at z ±1.2, far from all of them.

Old positions pinned in tests: none found. A grep of tests/unit for the old z values (10.1, 11.4, -11.65, 9.95) near subway or track found nothing. The box-fit test reads the data, so it moved with the change.

Tests added: none committed. Why: the nav-pass test fails by design on the four pit vehicles, so it should come with a decision on the fix. It is a worker call.

Could not test: whether a first-person body physically squeezes the 0.75 m lane, and the wheel-on-rail look. Both need a real play session (owner list).
