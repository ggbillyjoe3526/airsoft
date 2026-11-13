Task: PB3 · QA commit cadff13e · Verdict: Pass

Blocking: none.
Advisory:
- game/sim/plant.gd:100 set_down uses the planter's feet y; on stairs/slopes the point 0.55 m ahead can float or sink slightly (not testable without a display). KNOWN_ISSUES candidate.
- game/sim/plant.gd:167 set_at is fixed once when arming begins; the planter walking off the spot is not an issue (they must stay in the site), but a lift site is not covered.

Tests added (tests/unit/test_pb3_qa.gd, 6, all pass; each fails on origin/main: hands_on_bomb, set_at, Carry, rail_carry do not exist there):
- test_a_carrier_hit_mid_plant_drops_it_at_rest_not_where_it_would_stand · Plant.step with the carrier OUT mid-arm · drop position is ps.rest, planter cleared
- test_a_new_attempt_measures_the_set_down_afresh · stop and restart arming with new yaw/room · set_at and facing re-taken
- test_the_set_down_stands_at_the_carriers_height · set_at.y equals feet y (step/lift)
- test_a_bots_carry_never_lights_the_players_rail · HudPlant.rail_carry for a bot carrier or armed bomb is NONE (the HUD's c is always the player)
- test_a_rail_without_a_bomb_row_ignores_the_carry_without_error · SETTING lights the bomb row, NONE hides it
- test_in_a_session_hands_on_the_bomb_put_the_replica_away_and_a_crouch_is_not_forced · PlaySession depot: pick up, key at site, replica holstered, no forced crouch, set_at within set_ahead, replica drawn on letting go

Checked by reading (no defect): respawn clears hands_on_bomb/bomb_was_holstered; an OUT character gets hands_on(false) with no redraw; a readied grenade keeps the replica away (bomb_was_holstered); weapon switch is blocked by the _working command; set_room is re-measured every tick before planter is set; Elimination returns NONE.
Suite counts: test_pb3_qa 6/6 passing. Full suite and tools/check.sh not run by me (running in background). Not tested: BOMB ARMED gauge fit at 96 px in a real window, window modes, stairs visuals (need a display).
