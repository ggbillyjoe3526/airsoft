extends GutTest
## The end of a round (RR1; concept `round-result.png`): the WON / LOST / DRAW stamp from your side, the round's table
## table_delay later (your team first, you first in it, who hit whom), a click on it starting the next round without
## firing a shot, and the match's last table holding the results back until a click or table_hold.

const K := GameEvent.Kind

var session: PlaySession = null


func after_each() -> void:
	Input.action_release(&"fire")


func _session() -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	add_child_autofree(s)
	return s


## Ends the round in the HUD as the simulation would: `winner` (-1 a draw) took it with `clock` seconds left.
func _end_round(winner: int, clock: float, last: bool = false) -> void:
	var state := session.state
	var rs := state.round_state
	rs.phase = RoundState.Phase.OVER
	rs.timer = SimTuning.new().rounds.reset_delay
	rs.clock = clock
	state.events.clear()
	var e := state.events.add(K.ROUND_OVER)
	e.value = winner
	e.value2 = GameEvent.RoundEnd.ELIMINATED
	if last:
		state.events.add(K.MATCH_OVER).value = winner
	session.hud().on_tick(state)
	state.events.clear()


## `seconds` of simulation time pass, and the HUD shows them.
func _wait(seconds: float) -> void:
	session.state.time += seconds
	session.hud().update(session.state, 1.0, 0.0)


func _hit(shooter: int, victim: int) -> void:
	var state := session.state
	state.events.clear()
	var e := state.events.add(K.CHARACTER_HIT)
	e.actor = shooter
	e.target = victim
	session.match_stats().after_tick(state, 0.0)
	state.events.clear()


# --- the pieces ---

func test_the_wait_between_rounds_can_end_now_but_only_while_a_round_is_over() -> void:
	var rs := RoundState.new()
	rs.phase = RoundState.Phase.LIVE
	assert_false(Round.end_wait(rs))
	rs.phase = RoundState.Phase.OVER
	rs.timer = 5.0
	assert_true(Round.end_wait(rs))
	assert_eq(rs.timer, 0.0)


func test_the_numbers_remember_who_hit_each_player_this_round() -> void:
	var state := GameState.new(1)
	for i in 4:
		state.characters.append(Character.new(i, 0 if i < 2 else 1))
	var stats := MatchStats.new()
	state.events.add(K.ROUND_START).value = 1
	stats.after_tick(state, 0.0)
	assert_eq(stats.round_of(1).hit_by, -1, "nobody yet")
	state.events.clear()
	var e := state.events.add(K.CHARACTER_HIT)
	e.actor = 2
	e.target = 1
	stats.after_tick(state, 0.0)
	assert_eq(stats.round_of(1).hit_by, 2)
	state.events.clear()
	state.events.add(K.ROUND_START).value = 2
	stats.after_tick(state, 0.0)
	assert_eq(stats.round_of(1).hit_by, -1, "a new round starts clean")


func test_the_stamp_reads_from_your_side() -> void:
	var names := TeamConfig.new().names
	assert_eq(HudStyle.round_stamp(0, 0), "WON")
	assert_eq(HudStyle.round_stamp(1, 0), "LOST")
	assert_eq(HudStyle.round_stamp(-1, 0), "DRAW")
	assert_eq(HudStyle.round_stamp_sub(4, 0, names[0], false, GameEvent.RoundEnd.ELIMINATED),
			"ROUND 4 · ALPHA TAKE THE ROUND")
	assert_eq(HudStyle.round_stamp_sub(5, -1, "", false, GameEvent.RoundEnd.ELIMINATED),
			"ROUND 5 · THE ROUND IS PLAYED AGAIN")
	assert_eq(HudStyle.round_played(4, 90), "ROUND 4 · 1:30 PLAYED")


# --- in a match ---

func test_a_won_round_stamps_won_in_your_colour_and_the_table_follows() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	var them := session._tuning.rounds.team_size # their first player
	_hit(0, them)
	_hit(them, 1)
	_end_round(0, 60.0)
	assert_eq(hud.banner_text(), "WON / ROUND 1 · ALPHA TAKE THE ROUND")
	var table := hud.round_result()
	_wait(1.9)
	assert_false(table.is_up(), "not before table_delay")
	_wait(0.2)
	assert_true(table.is_up())
	assert_eq(table.table().title(), "ROUND 1 · 1:30 PLAYED")
	var lines := table.table().lines()
	assert_eq(lines.size(), session.state.characters.size())
	assert_string_starts_with(lines[0], "You | 1 | ", "you first, with your hit")
	assert_string_ends_with(lines[0], "Still in")
	var owl := session._bots.name_of(1)
	assert_true(lines[1].begins_with(owl + " OUT"), "your teammate next, out")
	assert_string_ends_with(lines[1], session._bots.name_of(them), "hit by the one who hit them")
	assert_eq(table.hint_text(), "CLICK FOR THE NEXT ROUND")


func test_a_lost_round_says_lost_and_the_stamp_lasts_until_the_next_round() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	_end_round(1, 30.0)
	assert_eq(hud.banner_text(), "LOST / ROUND 1 · BETA TAKE THE ROUND")
	_wait(5.0)
	assert_ne(hud.banner_text(), "", "held while the table is up")
	var state := session.state
	state.events.clear()
	state.events.add(K.ROUND_START).value = 2
	hud.on_tick(state)
	state.events.clear()
	assert_false(hud.round_result().is_up(), "the next round closes the table")


func test_a_click_on_the_table_starts_the_next_round_and_is_not_a_shot() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	_end_round(0, 60.0)
	_wait(2.1)
	session._input.active = true
	var click := InputEventAction.new()
	click.action = &"fire"
	click.pressed = true
	Input.action_press(&"fire")
	session._unhandled_input(click)
	assert_eq(session.state.round_state.timer, 0.0, "the next tick starts the next round")
	assert_false(hud.round_result().is_up())
	var cmd := PlayerCommand.new()
	session._input.fill(cmd)
	assert_false(cmd.fire, "the click that moved on is not a shot")
	Input.action_release(&"fire")
	session._input.fill(cmd)
	Input.action_press(&"fire")
	session._input.fill(cmd)
	assert_true(cmd.fire, "the next press fires")
	session._input.active = false


func test_the_last_round_holds_the_results_until_a_click_or_table_hold() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	var cfg := PlayTuning.new().hud
	_end_round(0, 60.0, true)
	_wait(cfg.table_delay + 0.1)
	assert_true(hud.holds_results())
	assert_eq(hud.round_result().hint_text(), "CLICK FOR THE RESULTS")
	session._rematch_left = 8.0
	session._process(1.0)
	assert_eq(session._rematch_left, 8.0, "the next match waits for the results")
	_wait(cfg.table_hold)
	assert_false(hud.holds_results(), "table_hold later it makes way")
	assert_false(hud.round_result().is_up())
	session._rematch_left = -1.0


func test_the_watching_line_steps_aside_while_the_round_result_is_up() -> void:
	# BP6: "WATCHING KITE" drew over the table's "CLICK FOR THE NEXT ROUND"
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	hud.set_watching("Kite")
	assert_true(hud.watching_shown(), "spectating in a live round")
	_end_round(1, 30.0)
	_wait(5.0)
	assert_true(hud.round_result().is_up())
	assert_false(hud.watching_shown(), "not under the click line")
	var state := session.state
	state.events.clear()
	state.events.add(K.ROUND_START).value = 2
	hud.on_tick(state)
	state.events.clear()
	_wait(0.1)
	assert_true(hud.watching_shown(), "back once the next round starts")
