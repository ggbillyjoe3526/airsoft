extends GutTest
## QA for CR1 (Custom rules): the matches the worker's tests leave out (1v1 Attack / Defend, 2v2 Elimination, a Custom
## team size on the larger maps), odd saved values, and a live PlaySession playing a Custom copy of the tuning.

const SAVE := "user://test-cr1-qa.save"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE)


func _rules(team_size: int, wins: int = 3) -> CustomRules:
	var c := CustomRules.new()
	c.team_size = team_size
	c.wins_needed = wins
	c.friendly_fire = false
	return c


func _play_out(team_size: int, mode: RoundState.Mode, map_id: String, seed_value: int = 11) -> void:
	var r := MatchRunner.new(self, map_id, _rules(team_size).applied_to(SimTuning.load_default()))
	r.mode = mode
	await wait_physics_frames(2)
	assert_true(r.map.ok(), "%s holds %d a side: %s" % [map_id, team_size, "; ".join(r.map.problems)])
	var t := r.play(seed_value, 2400.0)
	r.free_level()
	assert_true(t.finished, "%s %dv%d mode %d: the match ends" % [map_id, team_size, team_size, mode])
	assert_eq(t.friendly_hits, 0, "friendly fire off")
	assert_eq(t.self_hits, 0)
	assert_eq(t.rescued, 0)
	if mode == RoundState.Mode.ATTACK_DEFEND:
		for rt: MatchRunner.RoundTally in t.rounds:
			assert_true(rt.attackers == 0 or rt.attackers == 1, "someone attacks every round")


func test_one_against_one_attack_defend_plays_out() -> void:
	await _play_out(1, RoundState.Mode.ATTACK_DEFEND, "depot")


func test_two_a_side_elimination_plays_out() -> void:
	await _play_out(2, RoundState.Mode.ELIMINATION, "depot")


func test_every_team_size_a_field_offers_fits_it() -> void:
	for e in MapCatalog.shared().fields(true):
		for n: int in CustomRules.TEAM_SIZES:
			if not e.allows(n):
				continue
			var m := MapData.load_map(e.id, PlayTuning.load_default().map_style, n)
			assert_true(m.ok(), "%s at %d a side: %s" % [e.id, n, "; ".join(m.problems)])


func test_odd_saved_values_fall_back_each_on_its_own() -> void:
	var d := CustomRules.new()
	var c := CustomRules.new()
	c.from_dict({"team_size": INF, "wins_needed": NAN, "round_time": INF, "friendly_fire": 1, "ricochets_count": null})
	assert_eq(c.to_dict(), d.to_dict(), "inf, NaN, an int for a bool, null")
	c.from_dict({"team_size": "2", "wins_needed": [5], "round_time": "120", "friendly_fire": {}, "ricochets_count": 0})
	assert_eq(c.to_dict(), d.to_dict(), "strings, arrays, dictionaries")
	c.from_dict({"team_size": -1, "wins_needed": 0, "round_time": -90.0})
	assert_eq(c.to_dict(), d.to_dict(), "negative and zero")
	c.from_dict({"team_size": 2.0, "round_time": 90.0, "wins_needed": 3.0})
	assert_eq([c.team_size, c.round_time, c.wins_needed], [2, 90.0, 3], "the range's ends and floats of whole numbers")
	c.from_dict({"round_time": 299.9999})
	assert_eq(c.round_time, d.round_time)


func test_a_load_of_one_bad_custom_rules_entry_keeps_the_rest_of_the_settings() -> void:
	var s := Settings.new(PlayTuning.new())
	s.fov = 100.0
	var data := s.to_dict()
	for junk: Variant in ["junk", 5, [1, 2], null]:
		data["custom_rules"] = junk
		var back := Settings.new(PlayTuning.new())
		back.custom_rules.team_size = 1
		back.from_dict(data)
		assert_eq(back.custom_rules.to_dict(), CustomRules.new().to_dict(), "custom_rules = %s" % str(junk))
		assert_eq(back.fov, 100.0)


func test_reset_save_puts_the_switches_back_to_skirmish() -> void:
	var s := Settings.new(PlayTuning.new())
	s.custom_rules.team_size = 1
	s.custom_rules.friendly_fire = false
	s.reset_save(SAVE)
	assert_eq(s.custom_rules.to_dict(), CustomRules.new().to_dict())


func test_applying_twice_and_in_a_row_never_leaks_into_the_loaded_tuning() -> void:
	var loaded := SimTuning.load_default()
	var before := [loaded.rounds.team_size, loaded.rounds.wins_needed, loaded.hits.friendly_fire]
	var t1 := _rules(1, 10).applied_to(loaded)
	var t2 := _rules(2, 7).applied_to(loaded)
	assert_ne(t1.rounds, t2.rounds)
	assert_eq(t1.rounds.team_size, 1)
	assert_eq(t2.rounds.team_size, 2)
	assert_eq([loaded.rounds.team_size, loaded.rounds.wins_needed, loaded.hits.friendly_fire], before)
	assert_eq([SimTuning.load_default().rounds.team_size, SimTuning.load_default().rounds.wins_needed], [3, 5])


func test_a_session_plays_a_custom_copy_and_the_skirmish_one_after_it() -> void:
	var s := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = s
	session.map_id = "depot"
	session.match_seed = 3
	session.autopilot = true
	session.custom_rules = _rules(8, 7)
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_eq(session.state.characters.size(), 16, "8v8: sixteen characters")
	assert_eq(session._tuning.rounds.wins_needed, 7)
	assert_false(session._tuning.hits.friendly_fire)
	assert_false(session.counts_for_records())
	assert_eq(SimTuning.load_default().rounds.team_size, 3, "the shared tuning is still Skirmish's")
	var again := PlaySession.new()
	again.settings = s
	again.map_id = "depot"
	again.match_seed = 3
	again.autopilot = true
	add_child_autofree(again)
	await wait_physics_frames(2)
	assert_eq(again.state.characters.size(), 12, "the next Skirmish is 6v6 again")
	assert_eq(again._tuning.rounds.wins_needed, 5)
	assert_true(again._tuning.hits.friendly_fire)


func test_a_six_a_side_attack_defend_session_sets_up() -> void:
	var s := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = s
	session.map_id = "depot"
	session.match_seed = 4
	session.mode = MatchOptions.MODE_ATTACK_DEFEND
	session.autopilot = true
	session.custom_rules = _rules(6)
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_eq(session.state.round_state.mode, RoundState.Mode.ATTACK_DEFEND)
	assert_eq(session.state.characters.size(), 12)
	await wait_physics_frames(120)
	assert_true(session.state.round_state.number >= 1)
