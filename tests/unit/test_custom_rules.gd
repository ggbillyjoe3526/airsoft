extends GutTest
## The Custom rule set (CR1): its switches saved with the settings and read back each on its own (CustomRules), played
## by a match (applied_to) without touching the loaded tuning, kept out of the records and its XP capped by levels.md's
## Custom row, and whole matches at the smaller team sizes.

const SAVE := "user://test-custom-rules.save"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE)


func test_the_switches_start_as_skirmish() -> void:
	var c := CustomRules.new()
	var t := SimTuning.load_default()
	assert_eq(c.team_size, t.rounds.team_size)
	assert_eq(c.wins_needed, t.rounds.wins_needed)
	assert_eq(c.round_time, t.rounds.round_time)
	assert_eq(c.friendly_fire, t.hits.friendly_fire)
	assert_eq(c.ricochets_count, t.hits.ricochets_count)
	assert_true(CustomRules.TEAM_SIZES.has(c.team_size), "Skirmish's team size is one of the choices")
	assert_true(CustomRules.WINS_NEEDED.has(c.wins_needed))


func test_the_switches_survive_a_save_and_a_load() -> void:
	var s := Settings.new(PlayTuning.new())
	s.custom_rules.team_size = 2
	s.custom_rules.wins_needed = 7
	s.custom_rules.round_time = 180.0
	s.custom_rules.friendly_fire = false
	s.custom_rules.ricochets_count = true
	assert_true(s.save(SAVE))
	var back := Settings.new(PlayTuning.new())
	back.load_file(SAVE)
	assert_eq(back.custom_rules.to_dict(), s.custom_rules.to_dict())


func test_a_bad_value_falls_back_on_its_own() -> void:
	var c := CustomRules.new()
	var d := CustomRules.new()
	c.from_dict({"team_size": 9, "wins_needed": 10.0, "round_time": 100, "friendly_fire": "no", "ricochets_count": true})
	assert_eq(c.team_size, d.team_size, "9v9 isn't offered")
	assert_eq(c.wins_needed, 10, "a whole number read back as a float")
	assert_eq(c.round_time, d.round_time, "off the half-minute steps")
	assert_eq(c.friendly_fire, d.friendly_fire, "not a bool")
	assert_true(c.ricochets_count)
	c.from_dict({"round_time": 330.0, "wins_needed": 2.5})
	assert_eq(c.round_time, d.round_time, "past 5:00")
	assert_eq(c.wins_needed, d.wins_needed)
	c.from_dict({"round_time": 300})
	assert_eq(c.round_time, 300.0)


func test_an_old_save_without_them_keeps_skirmish() -> void:
	var s := Settings.new(PlayTuning.new())
	var data := s.to_dict()
	data.erase("custom_rules")
	var back := Settings.new(PlayTuning.new())
	back.custom_rules.team_size = 1
	back.from_dict(data)
	assert_eq(back.custom_rules.to_dict(), CustomRules.new().to_dict())


func test_a_match_plays_them_and_the_loaded_tuning_keeps_skirmish() -> void:
	var loaded := SimTuning.load_default()
	var skirmish := [loaded.rounds.team_size, loaded.rounds.wins_needed, loaded.rounds.round_time,
			loaded.rounds.half_time_after, loaded.hits.friendly_fire, loaded.hits.ricochets_count]
	var c := CustomRules.new()
	c.team_size = 1
	c.wins_needed = 10
	c.round_time = 90.0
	c.friendly_fire = false
	c.ricochets_count = true
	var t := c.applied_to(loaded)
	assert_eq([t.rounds.team_size, t.rounds.wins_needed, t.rounds.round_time, t.hits.friendly_fire,
			t.hits.ricochets_count], [1, 10, 90.0, false, true])
	assert_eq(t.rounds.half_time_after, 9, "the ends swap one round short of the win")
	assert_eq(t.rounds.reset_delay, loaded.rounds.reset_delay, "the rest of the rounds as tuned")
	assert_eq(t.hits.call_time, loaded.hits.call_time, "the rest of the hits as tuned")
	assert_same(t.body, loaded.body, "the parts no rule touches are shared")
	var again := SimTuning.load_default()
	assert_eq([again.rounds.team_size, again.rounds.wins_needed, again.rounds.round_time,
			again.rounds.half_time_after, again.hits.friendly_fire, again.hits.ricochets_count], skirmish)
	c.wins_needed = 5
	assert_eq(c.applied_to(loaded).rounds.half_time_after, loaded.rounds.half_time_after, "first to 5 swaps as Skirmish")


func test_levels_reads_the_custom_row() -> void:
	var table := LevelTable.read_file(Pool.shared())
	assert_eq(table.multiplier(LevelTable.CUSTOM), LevelTable.DEFAULT_MULTIPLIERS[LevelTable.CUSTOM])
	assert_eq(table.problems.size(), 0, "read cleanly: %s" % "; ".join(table.problems))


func test_custom_xp_is_capped_and_never_raised() -> void:
	var table := LevelTable.read_file(Pool.shared())
	var cap := table.multiplier(LevelTable.CUSTOM)
	assert_eq(table.multiplier(&"hard"), cap, "as shipped, Hard's ×1.5 is the cap (TL1)")
	table.multipliers[&"hard"] = cap + 0.5
	var o := MatchXp.Outcome.new()
	o.won = true
	o.difficulty = &"hard"
	o.custom = true
	assert_eq(MatchXp.earned(table, o).multiplier, cap, "a Hard above the cap held to it")
	o.custom = false
	assert_eq(MatchXp.earned(table, o).multiplier, cap + 0.5, "Skirmish Hard as ever")
	o.difficulty = &"easy"
	o.custom = true
	assert_eq(MatchXp.earned(table, o).multiplier, table.multiplier(&"easy"), "Easy stays under it")


func test_a_custom_match_settles_capped_and_off_the_records() -> void:
	var s: PlaySession = autofree(PlaySession.new())
	s.difficulty = &"hard"
	assert_true(s.counts_for_records(), "Skirmish")
	s.custom_rules = CustomRules.new()
	assert_false(s.counts_for_records(), "Custom, even with its switches as Skirmish's")
	var tally := PlayerTally.new(0)
	tally.winner = 0
	var progress := Progress.new(LevelTable.read_file(Pool.shared()))
	var settled := tally.settle(progress, null, false, 0, 5, MatchOptions.MODE_ELIMINATION, &"hard", &"hard", true)
	assert_eq(settled.earned.multiplier, progress.table.multiplier(LevelTable.CUSTOM))
	assert_null(settled.news, "no records")


func test_the_picks_hand_over_the_custom_switches_only_for_custom() -> void:
	var s := Settings.new(PlayTuning.new())
	var picks := MatchPicks.new()
	assert_eq(picks.rules, MatchOptions.RULES_SKIRMISH, "Skirmish by default")
	assert_null(picks.custom_rules(s))
	picks.rules = MatchOptions.RULES_CUSTOM
	assert_same(picks.custom_rules(s), s.custom_rules)


func test_one_against_one_plays_out() -> void:
	await _play_out(1, RoundState.Mode.ELIMINATION, "depot")


func test_two_a_side_attack_defend_plays_out_without_friendly_hits() -> void:
	await _play_out(2, RoundState.Mode.ATTACK_DEFEND, "depot")


func _play_out(team_size: int, mode: RoundState.Mode, map_id: String) -> void:
	var c := CustomRules.new()
	c.team_size = team_size
	c.wins_needed = 3
	c.friendly_fire = false
	var r := MatchRunner.new(self, map_id, c.applied_to(SimTuning.load_default()))
	r.mode = mode
	await wait_physics_frames(2)
	assert_true(r.map.ok(), "%s holds %d a side" % [map_id, team_size])
	var t := r.play(7, 1800.0)
	r.free_level()
	assert_true(t.finished, "%dv%d: the match ends" % [team_size, team_size])
	assert_gte(t.rounds.size(), 3)
	assert_eq(t.friendly_hits, 0, "friendly fire off: BBs pass teammates by")
