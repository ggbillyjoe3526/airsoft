Task: CR1 · QA commit none (no tests added; review only, nothing committed) · Verdict: Pass

Reviewed: origin/main..cr1-work (e9cd944). The worktree also holds the worker's uncommitted edits in flight (CR1 to CT1 rename in comments, a SKIN constant in BoxMover.room_to_stand, a new bot-through-tunnel test); test_crouch_body.gd in that state: 9 tests, 48 asserts, all pass.

Blocking: none.

Advisory:
1. Woodland has a fourth low area the record and wiki don't mention: under the North bridge (about x 0, z -42) the dry stream bed is now 168 walkable low nodes (crouch-walkable; it was blocked under a 1.8 m body). Bots will route through it and so can players, which changes lane flow and sightlines on the stream. Confirm it is wanted (then name it in the wiki and record) or block it. Nodes counted by a scratch probe of NavGrid.low, clustered by 6 m cell: bridge, Crawl box, Badger run and Culvert only.
2. PracticeSpot.restore (game/play/practice_spot.gd:48) sets crouch_amount = 1 but not Character.low, so for one tick a restored crouched body is the tall one. Self-heals in the next Movement.step; no roof exists at a spot (practice_spots.gd skips low nodes). Harmless.
3. Perf (for the performance agent): Movement.step now makes one extra Jolt body_test_motion per tick for every low character (movement.gd:39, jolt_mover.gd:59). Bots hold crouch cover often, so a 6v6 match adds several sweeps a tick.
4. Toggled crouch: pressing Sprint or Jump under a roof clears the toggle (player_input.gd:208-217) while the body stays down (kept_down); after the exit the player stands without pressing again. Matches the record; noting as UX.

Bugs hunted, none found (probes in scratchpad, run on the real Jolt level, Woodland):
- Stuck or standing into a roof: from the middle of Crawl, Badger and Culvert with crouch released and sprint+jump held for 120 ticks the body stays low and crouched, rises under 4 cm (slope settle). Walking out with the same keys held ends outside, standing, never standing on a low node.
- Walking in crouched then releasing at the mouth, and bot-style walking (nav route, sprint held, crouch = low_ahead 1 m): all three tunnels crossed both ways in 300-390 ticks, no stall at either mouth, no tick standing on a low node.
- room_to_stand false "no room" in the open: 0 of about 69,000 sampled walkable non-low nodes on Depot (16,665), Range (5,250) and Woodland (47,165). On 88 sampled low nodes 4 report room (the grid's low mark is grown by the clearance, so it is conservative at mouths).
- Depot and Range: 0 low nodes on both; the headroom and merge rule changes leave their grids unchanged.
- Respawn and round reset: Character.respawn clears low (character.gd:165) with crouch_amount; Round.reset goes through it. Vault: refused while crouched, never starts or lands on low floors (NavVaults), vault ticks keep the tall body and Movement recomputes low after.
- Woodland terrain: build_map.py rerun from the committed sources reproduces the committed data/maps/woodland.json byte for byte.
- Mover bodies: the new low kinematic body is on CHARACTER_LAYER with the world mask, freed with the level (map_level.gd:262-267); no collision with the other mover bodies.

Tests: tests/unit/test_crouch_body.gd (8 committed, 9 with the in-flight bot test) and tests/unit/test_woodland_layout.gd:324,354 (low floor all along each roof; crouched Jolt body passes each tunnel, a standing one stops at the mouth). Each names behaviour that does not compile or run without Character.low, crouch_height and NavGrid.low, so they fail without the feature; I did not stub each out.

Counts: only test_crouch_body.gd run by me (9/9, 48 asserts). Full suite and tools/check.sh are run elsewhere; test_woodland_layout.gd (includes the bot match) not run by me.

Could not test: how the 1.25 m body, the lowered eye and the tunnel mouths feel to play, and the figure's look in the tunnels (needs a display); owner to try each tunnel crouched, releasing crouch inside, and the stream under the North bridge.
