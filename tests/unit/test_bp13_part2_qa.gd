extends GutTest
## BP13 part 2: Subway's Hard Attack / Defend wait comes from the field's wait times the Hard scale, from the real row.


func _delay(level: StringName, mode: RoundState.Mode, team: int) -> float:
	var base := SimTuning.load_default()
	var entry := MapCatalog.read_file().find("subway")
	var t := MatchOptions.level_tuning(MatchOptions.match_tuning(base, entry, null), level)
	var rs := RoundState.new()
	rs.mode = mode
	rs.attackers = 0
	return Respawns.delay(rs, t.rounds, team)


func test_subway_has_no_own_hard_defender_wait() -> void:
	assert_eq(MapCatalog.read_file().find("subway").defender_respawn_hard, 0.0)


func test_subway_hard_attack_defend_defenders_wait_the_fields_wait_times_the_hard_scale() -> void:
	var base := SimTuning.load_default()
	var field := MapCatalog.read_file().find("subway").defender_respawn
	var want := minf(field * base.rounds.defender_respawn_scale[&"hard"], maxf(field, base.rounds.defender_respawn_most))
	assert_almost_eq(_delay(&"hard", RoundState.Mode.ATTACK_DEFEND, 1), want, 0.001)
	assert_almost_eq(want, 13.3, 0.001)


func test_subway_normal_and_easy_waits_are_the_fields_own() -> void:
	var field := MapCatalog.read_file().find("subway").defender_respawn
	assert_almost_eq(_delay(&"normal", RoundState.Mode.ATTACK_DEFEND, 1), field, 0.001)
	assert_lt(_delay(&"easy", RoundState.Mode.ATTACK_DEFEND, 1), field + 0.001)
