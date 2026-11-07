# Perf 2: bp7-maps 082d04f..2c5aed6
Verdict: PASS. Headless, busy machine, 2 runs (25 ms slice): Depot 1 call 23-24 ms; Woodland 11-14 calls, worst piece 157-193 ms (grass
trimesh), total 474-615 ms; Street 1 call 46-51 ms. Same as 082d04f (Woodland 168-189, Depot 27-29). Shapes/nodes unchanged (409/1840/565).
Allocation: the only new allocation is one `PropDressConfig.new()` in _add_block_colliders when no site look is given (once per map load, in
the COLLIDERS piece, not per piece or frame; freed as RefCounted). RoundSteps.boxes adds only locals (a PackedVector2Array ref, no copy);
the `match` and model_of/lay_of dictionary reads are per block at setup. Nothing per frame/tick. Orphans: none seen in the tests.
# Performance 3: 3b06375
Verdict: PASS
- One field write, on a lost-toss path only; no allocation, no extra rays, no per-tick work.
- Spam bound: re-ask rate is limited by mag_press_gap (1 s), a giver's walk and a 0.3 s+ flight, so at worst events (3), one radio click and <=4+4 rays a cycle per bot every >1 s. Pool of 6 tosses bounds it further. Acceptable.
