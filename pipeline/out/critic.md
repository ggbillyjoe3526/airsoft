Task: none (BP7 maps: rows 35, 92 deleted; 34, 49, 28, 29, 30 narrowed) · bug pass
Attempt: 2 of 4
Head: 2c5aed6 (= git rev-parse HEAD; one commit over 082d04f; targeted GUT re-run here: test_round_steps, test_staged_level,
test_bb_walls 11/11, 2326 asserts)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept, on condition that QA and performance re-pass on 2c5aed6 (both passed 082d04f, maps-qa.md and maps-perf.md;
the retry touches round_steps.gd, map_level.gd:166-229 and tests only).
Must-fix list from attempt 1, each checked:
1. One source: done. RoundSteps.boxes takes the block's model, lay, cluster_cell, pallet and pallet_height from PropDressConfig
   (round_steps.gd @@ +11-38); MapStyle.round_cells and round_feet are gone and round_steps is keyed by model (map_style.gd @@ +118).
   MapLevel uses the site look's props, or PropDressConfig.new() without one (map_level.gd:225-229), and
   test_a_level_without_a_site_look_steps_as_the_game_s shows the two agree on all three maps. test_every_step_s_sides_hug_the_props_it_holds
   (outline no wider than the props on x and z, each side within 0.12 of the step's width of a vertex) now fails oversized steps;
   the worker reports sabotage runs (a 4 % wider step, a doubled cell) failing it. Reading it, I agree: a wider cell moves the outline.
2. Loading note: done. changelog.d/bp7-maps.md is one bullet on Woodland's longest stop, and it says that shorter stops remain.
3. Round props: done. woodland-cc0-props.md:4 and depot-props.md:5 now say a trunk, drum or barrel is met at its curve, and a
   spruce still at its block. Both notes are unreleased and right relative to 0.1 Dev 1.
4. Docs: done. Row 49 gives the woods view's reason (WoodsView builds in one call; a part a frame would still leave about 0.3 s).
   game/map/README.md has a round_steps.gd row and an updated map_level.gd row. A new "document" KNOWN_ISSUES row says what still
   takes the box (nav, cover spots, knocks and rings, bake, minimap). The Piece.TILES guard covers an empty tile plan.
Sim agreement and determinism (unchanged from attempt 1): BBs, sight, lean and cover acceptance all ray the same Jolt bodies.
Cover candidates and nav come from the box, and that is documented now. Steps look the same after a quarter turn, so the seeded
turns don't change collision. The staged build is the whole build (the node test).
Notes (not blocking):
- bp7-maps.md "Shorter stops remain": the views and HUD step is 0.5 to 1.7 s across maps (Woodland's about 0.9 s on main), so
  "shorter" is about equal, not clearly less. "Other stops of up to about a second remain" would be safer.
- Merge with bp7-bots: that branch adds every body to the tree after all its shapes, terrain included (the 5e-7 m first-step
  drift). Here the terrain trimeshes join bodies already in the tree (map_level.gd, the `for sb in made` loop, then
  _add_terrain_shape). Whoever merges second should add `made` after Piece.TERRAIN.
- Merge with bp7-graphics: no bake conflict (hash_of reads no round-step data). There will be text conflicts in map_style.gd (both
  insert after `railing`), in prop_dress.gd and in play_session.gd's _build_level: MapOccluders needs a _dress_part arm.
- The Woodland Normal guard ran on 082d04f. Its steps match 2c5aed6's (the equality test), so it stands.
Owner should test in the game (at most 6, one line each):
- Woodland and The Street: graze BBs past a trunk's front corners (fly on) and its back (roots stop them).
- Depot: shoot past a drum pallet's corner and between two barrels; walk along a drum row: smooth slide or snag?
- Load Woodland: how long and how often does the loading screen stop now?
- Depot's Attack / Defend and The Street's Elimination: does either lean show in play?
Task: none (BP7 maps, rebased as bp7-maps-r) · merge-resolution review only
Head: 831f737 on d76f6aa (git diff d76f6aa 831f737, compared with 2c5aed6)
Verdict: the Accept stands (8/8). The resolution keeps everything all three branches meant.
- Maps' own files: round_steps.gd, test_round_steps, test_staged_level and terrain_grid.gd are byte-identical to 2c5aed6.
  map_style.gd and greybox_faces.gd differ only by graphics' additions (occluder_kinds, Tiles.grids).
- Bots' row-95 order survives. Every static body (surface, clear, railing) is built out of the tree. It joins in _add_rest
  only after its block steps, terrain trimeshes and the ceiling (map_level.gd:266-281), in bots' order. A door takes its shape
  before add_child (:434-435). This also resolves my attempt-2 merge note.
- Graphics survives. The dim-room relight (baked_light_at in the bake draw) and baked_lights/BakedLightNear are kept as
  d76f6aa has them. MapOccluders is part 5 of _dress_part, with DRESS_PARTS = 6. The staged loop dresses parts 0 to 4 a frame
  each and _build_level does part 5, so occluders are still built on every path.
- Maps' staged build survives (begin/build_some, the Piece machine, the TILES guard). The bodies now stay out of the tree from
  COLLIDERS through TERRAIN, across frames. The new NOTIFICATION_PREDELETE frees every body that never joined
  (map_level.gd:390-397). A body that did join has a parent and is skipped, so nothing is freed twice.
- Orphans, which I measured myself (scratch probe on an export of 831f737, not committed): freeing a level after 40 pieces on
  Woodland (in FACES: 1838 nodes out of the tree), and on Depot and The Street before REST (404 and 575 nodes), leaves 0
  orphans. test_staged_level and test_round_steps also pass there (11/11 with the probe, 2326 asserts).
Notes (not blocking):
- test_a_level_left_part_built_frees_whole stops after 30 Woodland pieces, which is still in TILES, before any body exists. It
  never tests the new out-of-tree window that the predelete code handles. Building past COLLIDERS (about 40 pieces) would
  cover it.
- I did not re-run test_seed_replay or test_bp7_graphics; the worker reports them passing.
Task: none (BP7 maps, CI magazine-guard fix) · commit 3b06375 on bp7-maps-r (parent 514e8bd)
Attempt: short review of one commit
Head: 3b06375
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Root cause:
- The loss itself is the rule working. BP7 decided that a toss whose path meets the level is lost, and the
  catcher moved, so the arc met the trunk. What broke the guard is what came after: an asker whose magazine was lost
  to the level, through no fault of its own, sat out the full bot_ask_gap (20 s) empty-handed.
- Ending the ask with no wait matches the BP7 rule for a giver that asks for one of its own (mag_share.gd, the
  `_giver_asking` branch). This fixes the guard's real failure, not a symptom.
- Refusing tosses to a moving catcher would be wrong:
  - Players toss to and catch on the move as a matter of course.
  - The catcher can move after the release anyway, so the check would block most tosses without preventing this.
  - Neither path (the check before the toss or the one in flight) can know where the catcher will go.
Optional, Beta polish: a bot catcher with mag.coming > 0 could hold still while it flies. BotMagShare.waiting
already returns true for it, but fights, cover, orders and the pole come first.
Players: the rule is sound.
- The gap stops ask spam. A loss to the level costs the giver a whole magazine of BBs, so asking again at once gains
  the catcher nothing.
- A player who dodges behind walls can drain a bot giver only down to keep_mags.
- Caught tosses and lapsed asks keep their gaps. The reset fires only when the last toss in the air was the one lost
  (inside `coming == 0`).
Test: it fails without the fix. In the wall test s.time stays 0 and the catcher is not a player (mag.player is false),
so the old code sets next_ask to 20.0, not 0, and the assert_eq fails. The follow-up press would then be refused as
WAIT, leaving asked at -1, not 0.
Docs: the note and the wiki are true. The note says "A teammate whose magazine was lost". "You or a teammate" would
also cover the player case that the wiki states. That is wording only, not a fail.
Before merge: CI's magazine guard (Woodland seed 5) must pass on this head. The commit doesn't say it was re-run.
