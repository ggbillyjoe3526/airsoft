Task: WR2 · head d646e35 (brief said ae6c160; wr2-work is d646e35) · Verdict: Pass
Run: Woodland, Attack/Defend 6v6 (custom, 180 s) and Elimination 5v5, seed 5, 1200 ticks x 3 runs per head, headless (no GPU), on a shared 4-core host (load 4-6) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and cr1-work (the stack base, standing in for origin/main)
Metrics (wr2 / cr1-work, ok = within 10 %):
- OBJECT_NODE_COUNT AD 6v6 1851 / 1818 (+33, +1.8 %, ok); EL 5v5 1761 / 1742 (+19, +1.1 %, ok). measured
- Orphan nodes 0 / 0 (ok); after queue_free the tree is back to 1 node on both heads, 4 build/free cycles in one process: nodes, objects and static memory flat after the first two cycles, same pattern as cr1-work. measured
- Census (AD): MeshInstance3D +12, Label3D +2 (both poles now carry a letter), MultiMeshInstance3D +1 (Doors, 16 leaves), StaticBody3D +8 and CollisionShape3D +8 (the doors' colliders). Candidate draws in the main pass about +15 (about 390 before); the huts and pole B sit far apart so most are culled. Draw calls are not measured (no GPU). judgment
- MEMORY_STATIC built, AD 497.5 / 489.2 MB (+8.3, +1.7 %); EL 488.1 / 488.0. Doors cost about 0.1 MB; the +8 MB is the two Label3D letters (the same +8.7 MB shows on Depot's AD vs EL on cr1-work), a one-time font cache, not growth. measured
- Per-tick script time (sim step plus session _process), mean over 3 runs: AD 6.8 / 7.1 ms, EL 6.6 / 6.7 ms; medians 9.9 / 10.1 ms. Noise (host load) is larger than any difference, so no regression shows. reported only
- Doors.shut_ahead on Woodland's 8 doors: 8.5 us/call measured under load, so 12 bots cost at most about 0.1 ms per tick (about 0.6 % of a 16.7 ms frame). measured
Regressions (> 10 % worse): none
Blocking findings: none
 - game/play/door_view.gd:60-67 refresh: 8 doors a frame, scalar compares, writes the MultiMesh only when a swing changes; no allocation (judgment, read).
 - game/sim/doors.gd:108-123 shut_ahead: early-outs on pack and axis distance, Vector2 values only, no heap allocation (judgment, read).
 - game/map/map_catalog.gd:98-148 _read_round runs once at catalog parse; match_options.gd:105-123 match_tuning runs once per match start (play_session.gd:293) and on Match page redraws, never per tick; its duplicate was already needed for Woodland's 5 a side (judgment, read).
 - Nothing new needs a prewarm: DoorView.materials() and FlagView.materials() already feed first_use (play_session.gd:693-712); the door and pole letter materials are the existing Depot ones. judgment
Advisory:
 - game/play/flag_view.gd:41-81 every pole builds its own 6 materials and about 7 meshes, so pole B doubles them; sharing them across poles (static cache) would save a few allocations and 8 draw-state changes. Trivial at 2 poles (AB1 design, not WR2's).
 - game/play/door_view.gd: doors cast shadows (one more shadow-pass draw per frame); follows the quality presets' shadow setting, no bypass.
 - The +8 MB static for the pole letters is on Woodland AD only; worth a look at Low preset if memory is tight (Label3D font cache).
 - Frame times and draw calls: confirm on the owner's hardware with F3 (Woodland Attack/Defend, standing at the Fort looking toward the Hut row).
Fixes: none required.
Unexplained: none (the +8.3 MB is attributed to the Label3D letters by the Depot comparison, not by an isolated test).
Scratch bench, census and cycle scripts live outside the repo in the session scratchpad; no game files were edited.
