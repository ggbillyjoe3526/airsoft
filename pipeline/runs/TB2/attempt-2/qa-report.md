Task: TB2 · QA commit 19475db · Verdict: Pass

Blocking: none. Advisory: none new (nav at x 45 z 11 inside the south car is unwalkable on both 41e8db5 and 4b5ebf2; not a regression, only the cabinet at x 52 explains part of it).

Hunt, all clean on 4b5ebf2:
- Car headroom: every sampled column of the south car (x 32-59, z 8.5-14.5) fits a crouched body (1.25 m); fewer than a quarter of columns are crouch-only (near the sides, 2.3 m ceiling over a 0.9 m floor).
- Holes: every sampled inside-the-car column (x 30.5-81.5, incl. 49.9/50.1 across the seam) has a roof above it; no BB path from car to tunnel.
- No two solid blocks overlap by more than 2 cm in all three axes in the south tunnel (x 30-82).
- Nav: a route runs from x 32 to x 58 along the car; both ends walkable; cab_steps room reachable or snaps to walkable.
- Lamps: attempt-2's lamp test pins position in the air, under the springing, reaching the crown, no shadow; orphan freeing covered by the existing fixtures test.

Tests added: tests/unit/test_tb2_car_arch_qa.gd (4 tests, all pass in about 20 s):
- :36 standing/crouch headroom in the car · fails if the car roof dropped below 1.25 m anywhere.
- :56 no roofless column inside the car · fails if a stepped roof leaves a gap.
- :70 no overlapping solid blocks · fails on z-fighting colliders.
- :90 car walkable end to end plus cab steps · fails on a walled car.
Honest note: I ran them against the 41e8db5 map data and they also pass there, so they are regression guards for attempt 2's geometry, not proofs of the feature; the feature itself is pinned by test_tb1_vault_qa.gd's car-roof and exemption-free tests.

Not tested (needs a display): how the car's stepped roof and the lamp glow look; the lamp's light on the arch.
Suite: not re-run (check.sh green on 4b5ebf2, 5944 tests, per the lead); my file alone 4/4. Raw output: pipeline/out/qa/car.txt.
