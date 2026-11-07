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
# QA 3: 3b06375 (bp7-maps-r vs 514e8bd)
Verdict: PASS
- GUT test_mag_share, test_bot_mag_share, test_mh1_qa, test_mh3_qa, test_mag_hand_off_hud: 98/98 pass.
- Cleanup is correct: coming is decremented first; only when the ask stands and coming reaches 0 is it ended, then next_ask is zeroed only if met. A path-lost toss with another still in the air changes nothing (ask stays); met needs the catcher in play, so no out-of-play write; caught and lapsed asks keep their gap.
- Bot loop: no per-tick storm. A bot re-ask is gated by mag_press_gap (1 s) and by _anyone_to_ask, then needs a giver to take the job, walk, pass the pre-check (same pieces as in flight) and toss (flight 0.3+ s). With nobody moving, pre-check == flight, so a lost toss repeating needs the catcher to keep moving. Worst case is a repeating cycle of at most ~1 per 1.5 s per bot: one MAG_ASK, MAG_TOSS, MAG_LOST and one radio click per cycle (before: once per 20 s). No same-tick re-ask (the press runs after step in the same tick at most once, and a second ask needs a taker).
- Player: the 4 s gap is skipped only after a loss, and each ask is one key press (WAIT refusals still hold after catches and lapses). No storm unless the player mashes the key against a wall, at one ask per press and a toss needing a giver.
- Suggestion (not blocking): if the guard shows ping-pong, a short floor (e.g. 1 s) instead of 0 would bound it; none seen.
