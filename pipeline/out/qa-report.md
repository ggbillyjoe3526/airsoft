Task: TB2 · QA commit pending · Verdict: Pass

Blocking: none. Advisory: none found.
Hunted and found sound: no gap behind either running arch at any x (existing test, now with 4 vaults); colliders within 8 cm of the arc along the whole length (arc pieces); platform/running seam at x 50 (no block in the opening above the car roof, arc sealed at 50.03); west mouth has no end cap, east is closed; cross passage (x 75.5, z +-8..10) has body and head room; a car's crown (3.6) clears the arch crown (4.1); malformed finish/mouth drop the vault with a warning.
Findings that were test artifacts, not bugs: 15 cm slabs at x 59.85 are the train's own roof shell; 8 cm slivers of the platform vault's end cap at the crown (x 50-50.3) are within VAULT_PROUD.

Tests added:
- tests/unit/test_tb1_vault_qa.gd · no collider more than 8 cm proud of a running arch · fails on main (no open_west vaults, size assert 2 running = 0)
- same · running arch air open 10 cm under the arc along its length · fails if inner air is not cut from shells
- same · junction at x 50: open air and sealed arc · fails without vault_inner cuts
- same · no west end cap, closed east end · fails without the mouth rule
- same · cross passage mouths stay walkable at z +-9
- tests/unit/test_station_dress.gd · malformed finish/mouth leave the vault out; good ones read; no finish = look's own · fails on main (finish/mouth ignored)
(checked by the properties of the change, not by stubbing it out.)

Suite: the two touched files 7/7 and 30/30 pass. tools/check.sh left to the background run; smoke not run by me.
Not tested: bots routing through run_n/run_s/xpass (no nav test written), cab_steps headroom by play, lamp fittings against the lid, visuals of the mouth corner fans (need a display), the car's shoulders against the arch (needs SM1's car shape).
