extends GutTest
## QA for DF1: the records rule with no teammates, the player on Beta, and every skill field against the browser game.


func test_a_one_versus_one_match_counts_for_records_whatever_the_unused_teammate_level() -> void:
	var s := PlaySession.new()
	s.settings = Settings.new()
	s.difficulty = &"hard"
	s.teammate_difficulty = &"easy"
	# A copy: the loaded tuning is one cached resource, shared by every later load while anything holds it.
	var one := CustomRules.new()
	one.team_size = 1
	s._tuning = one.applied_to(SimTuning.load_default())
	assert_true(s.counts_for_records(), "with no teammates there is no pair to be non-standard")
	s.free()


func test_the_player_on_beta_gets_the_teammate_level_and_alpha_the_picked_one() -> void:
	var s := PlaySession.new()
	s.autopilot = true
	s.settings = Settings.new()
	s.player_team = PlaySession.TEAM_BETA
	s.difficulty = &"normal"
	s.teammate_difficulty = &"easy"
	s.match_seed = 5
	add_child_autofree(s)
	await wait_physics_frames(3)
	var config := BotConfig.load_default()
	for b in s._bots.world.bots:
		var want := &"easy" if b.character.team == PlaySession.TEAM_BETA else &"normal"
		# Its level's skill, under its personality (BN1): a personality changes how it plays, never how well.
		var level_skill := config.skill_for(want)
		assert_eq(b.skill.reaction_time, level_skill.reaction_time, "character %d" % b.character.id)
		assert_eq(b.skill.aim_error_settled_deg, level_skill.aim_error_settled_deg, "character %d" % b.character.id)
		assert_eq(b.skill.turn_rate, level_skill.turn_rate, "character %d" % b.character.id)


func test_every_level_skill_field_matches_the_browser_game() -> void:
	var config := BotConfig.load_default()
	var want := {
		# Each level moved up a name (TL1): Easy is the browser's Normal, Normal its Hard, Hard its Pro.
		# AIM3 (owner 2026-11-22): Normal's reaction and aim settling slower, Hard's surprised reaction Normal's.
		&"easy": {"burst": Vector2(0.2, 0.45), "burst_pause": Vector2(0.3, 0.65), "aim_error_moving_deg": 1.5,
			"aim_error_start_metres": 0.75, "aim_error_tracking": 0.11, "contact_cover_min_distance": 8.0,
			"search_walk_distance": 12.0, "hold_cover_chance": 0.5, "hunt_memory": 40.0, "aim_settle_time": 1.0,
			"turn_rate": 4.5, "aim_error_settled_deg": 1.1, "lead_factor": 0.5, "reaction_time": Vector2(0.35, 0.6),
			"aim_error_start_deg": 4.5, "flank_chance": 0.25, "hold_time": Vector2(0.8, 2.5)},
		&"normal": {"burst": Vector2(0.25, 0.55), "burst_pause": Vector2(0.2, 0.5), "aim_error_moving_deg": 1.2,
			"aim_error_start_metres": 0.7, "aim_error_tracking": 0.073, "contact_cover_min_distance": 5.0,
			"search_walk_distance": 20.0, "hold_cover_chance": 0.8, "hunt_memory": 50.0, "aim_settle_time": 0.95,
			"reaction_time": Vector2(0.35, 0.6), "aim_error_start_deg": 4.4, "flank_chance": 0.7},
		&"hard": {"burst": Vector2(0.15, 0.35), "burst_pause": Vector2(0.2, 0.4), "aim_error_moving_deg": 1.0,
			"aim_error_start_metres": 0.5, "aim_error_tracking": 0.061, "contact_cover_min_distance": 4.0,
			"search_walk_distance": 30.0, "hold_cover_chance": 0.9, "aim_settle_time": 0.5, "turn_rate": 6.0,
			"hold_time": Vector2(1.2, 3), "lead_factor": 0.85, "aim_error_start_deg": 3.5, "flank_chance": 0.7,
			"reaction_time": Vector2(0.35, 0.6)},
	}
	for level: StringName in want:
		for field: String in want[level]:
			var got: Variant = config.skill_for(level).get(field)
			if got is float:
				assert_almost_eq(got as float, want[level][field] as float, 1e-6, "%s %s" % [level, field])
			else:
				assert_eq(got, want[level][field], "%s %s" % [level, field])
