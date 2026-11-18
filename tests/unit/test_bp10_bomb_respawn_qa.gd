extends GutTest
## BP10 part 3b: Depot's Hard bomb wait reaches the match a player starts, whatever the Custom switches and teammates.


func _played(level: StringName, mates: StringName, custom: CustomRules) -> SimTuning:
	var s := PlaySession.new()
	s.map_id = "depot"
	s.difficulty = level
	s.teammate_difficulty = mates
	s.custom_rules = custom
	s._load_map()
	var t := s._tuning
	s.free()
	return t


func test_a_skirmish_on_depot_against_hard_bots_waits_the_fields_time_even_with_easy_teammates() -> void:
	var depot := MapCatalog.shared().find("depot")
	for mates: StringName in [&"", &"easy", &"hard"]:
		assert_eq(_played(&"hard", mates, null).rounds.plant_defender_respawn_delay, depot.bomb_respawn_hard,
				"mates %s" % mates)


func test_a_custom_match_with_respawns_on_keeps_depot_s_hard_wait_and_other_levels_the_games() -> void:
	var c := CustomRules.new()
	c.respawns = RoundConfig.RespawnRule.ALWAYS
	var games := SimTuning.load_default().rounds.plant_defender_respawn_delay
	assert_eq(_played(&"hard", &"", c).rounds.plant_defender_respawn_delay, MapCatalog.shared().find("depot").bomb_respawn_hard)
	for level: StringName in [&"easy", &"normal"]:
		assert_eq(_played(level, &"", c).rounds.plant_defender_respawn_delay, games, String(level))


func test_applying_the_level_twice_or_to_a_runner_tuning_does_not_change_the_bomb_wait() -> void:
	var depot := MapCatalog.shared().find("depot")
	var once := MatchOptions.level_tuning(MatchRunner.sized_for("depot"), &"hard")
	var twice := MatchOptions.level_tuning(once, &"hard")
	assert_eq(twice.rounds.plant_defender_respawn_delay, depot.bomb_respawn_hard)
	assert_eq(MatchOptions.level_tuning(once, &"easy").rounds.plant_defender_respawn_delay, depot.bomb_respawn_hard,
			"a tuning already at Hard keeps it (level_tuning is for a fresh tuning)")
