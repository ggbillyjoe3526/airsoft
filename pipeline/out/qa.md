# QA 2: bp7-maps 082d04f..2c5aed6
Verdict: PASS. GUT: test_round_steps, test_staged_level, test_bb_walls, test_map_level, test_props, test_terrain, test_site_dress,
test_play_session: 8 scripts, 97 tests, 97 pass, 30506 asserts, no script errors.
- Same steps in guards and play: MapLevel._props = site.props whenever a site look is passed (even for a map with no site dress), else
  null -> PropDressConfig.new() in _add_block_colliders. play_tuning.tres overrides props (Resource_pdc01), so the two could differ; 
  test_a_level_without_a_site_look_steps_as_the_game_s compares every block of Depot/Woodland/Street (game vs built-in): 0 differ, >0 stepped.
  Shape counts unchanged vs 082d04f (Depot 409, Woodland 1840, Street 565). Risk: an owner edit of the tres props would be caught by that test.
- RoundSteps now keyed by model (trunk/drum/barrel) via props.model_of/lay_of; FIT -> fitted, CLUSTER -> cluster_cell + pallet box, ROW,
  anything else -> no steps (box). A map with no round props or a non-round model returns empty, as before.
- Piece.TILES guard is right: empty plan skips the add, then `_next (0) >= 0` moves on to COLLIDERS; non-empty adds each tile and the last
  call advances in the same step (no extra empty call, no off-by-one).
- Deadline passed still progresses (unchanged). Vault of barrels, feel at corners: still playtest items.
