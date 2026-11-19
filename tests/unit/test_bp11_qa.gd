extends GutTest
## BP11 QA, second pass: the edges of a field's own Attack / Defend wait against Hard bots.


func _field(own: float, hard: float) -> MapCatalog.Entry:
	var e := MapCatalog.Entry.new()
	e.id = "edge"
	e.kind = &"field"
	e.defender_respawn = own
	e.defender_respawn_hard = hard
	return e


func _hard_delay(own: float, hard: float, level: StringName = &"hard") -> float:
	var base := SimTuning.load_default()
	var t := MatchOptions.match_tuning(base, _field(own, hard), null)
	return MatchOptions.level_tuning(t, level).rounds.defender_respawn_delay


func test_a_hard_wait_shorter_than_the_fields_own_is_played_as_set() -> void:
	assert_eq(_hard_delay(15.0, 5.0), 5.0, "not the field's 15 times 1.9")
	assert_eq(_hard_delay(15.0, 5.0, &"normal"), 15.0, "Normal keeps the field's own")


func test_a_hard_wait_is_not_held_to_the_scaled_ceiling() -> void:
	var most := SimTuning.load_default().rounds.defender_respawn_most
	assert_eq(_hard_delay(7.0, 30.0), 30.0, "the field's own Hard wait passes the %s s ceiling up to the column's 30" % most)


func test_the_hard_wait_does_not_reach_plant_the_bomb_defenders() -> void:
	var base := SimTuning.load_default()
	var t := MatchOptions.level_tuning(MatchOptions.match_tuning(base, _field(7.0, 15.2), null), &"hard")
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.attackers = 0
	assert_eq(Respawns.delay(rs, t.rounds, 1), base.rounds.plant_defender_respawn_delay)
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	assert_eq(Respawns.delay(rs, t.rounds, 1), 15.2, "Attack / Defend defenders wait it")
	assert_eq(Respawns.delay(rs, t.rounds, 0), base.rounds.respawn_delay, "attackers keep theirs")


func test_a_null_map_and_an_unknown_level_leave_the_tuning_alone() -> void:
	var base := SimTuning.load_default()
	assert_eq(MatchOptions.match_tuning(base, null, null).rounds.defender_respawn_hard, 0.0)
	assert_same(MatchOptions.level_tuning(base, &"nonsense"), base)
