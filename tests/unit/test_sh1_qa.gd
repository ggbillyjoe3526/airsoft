extends GutTest
## QA for the Pump Shotgun (SH1): edge cases around the data cells, a partial and an empty pull, the laser flag, the
## pool at its cap, bot ammo bookkeeping and the Performance sheet.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const SHOTGUN_ROW := "| shotgun | Pump Shotgun | rifle | 0.65 | 0.2 | 1.7 | 30 | 5 | 1.2 | 0.5 | 0.5 | 0.45 | 0.7 | 1 | 1 | 3 | 1.2 |"


func _text() -> String:
	return FileAccess.get_file_as_string(ReplicaStats.PATH)


func _with_row(row: String) -> ReplicaStats:
	var text := _text()
	assert_true(text.contains(SHOTGUN_ROW), "the shipped row is as this test expects")
	return ReplicaStats.parse(text.replace(SHOTGUN_ROW, row))


func _cfg(s: ReplicaStats) -> ReplicaConfig:
	return s.replica_config(&"shotgun")


func _holding(r: ReplicaConfig) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	c.grounded = true
	return c


func _rules() -> LoadoutRules:
	var rules := LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	return rules


func _shotgun() -> ReplicaConfig:
	var rules := _rules()
	return rules.config(rules.pool.item("000027"))


func _pull(c: Character, pool: BBPool, events: SimEvents, tuning: SimTuning, tick: int = 0) -> void:
	var cmd := PlayerCommand.new()
	cmd.fire = true
	events.clear()
	Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3 + tick), events, tuning, DT)


func _flying(pool: BBPool) -> int:
	return pool.active_count()


func test_shot_bbs_cell_out_of_range_keeps_the_built_in_three_and_warns() -> void:
	for bad: String in ["0", "10", "x", "-1", "2.5", ""]:
		var s := _with_row(SHOTGUN_ROW.replace("| 3 | 1.2 |", "| %s | 1.2 |" % bad))
		var r := _cfg(s)
		assert_eq(r.shot_bbs, 3, "cell '%s' keeps the built-in value" % bad)
		assert_gt(s.problems.size(), 0, "cell '%s' warns" % bad)


func test_pattern_cell_out_of_range_keeps_the_built_in_and_warns() -> void:
	for bad: String in ["-1", "9", "wide"]:
		var s := _with_row(SHOTGUN_ROW.replace("| 3 | 1.2 |", "| 3 | %s |" % bad))
		assert_almost_eq(_cfg(s).pattern_deg, 1.2, 1e-6, "cell '%s'" % bad)
		assert_gt(s.problems.size(), 0, "cell '%s' warns" % bad)


func test_a_stats_file_without_the_two_columns_still_reads_without_a_problem() -> void:
	var lines := _text().split("\n")
	var out: PackedStringArray = []
	var in_replicas := false
	for line in lines:
		if line.begins_with("## "):
			in_replicas = line == "## Replicas"
		if in_replicas and line.begins_with("|"):
			var cells := line.split("|")
			# "" | cells... | "": drop the last two cells
			cells = cells.slice(0, cells.size() - 3) + PackedStringArray([""])
			line = "|".join(cells)
		out.append(line)
	var s := ReplicaStats.parse("\n".join(out))
	assert_eq(s.problems.size(), 0, "optional columns may be left out quietly: %s" % [s.problems])
	assert_eq(s.replica_config(&"aeg").shot_bbs, 1)
	assert_almost_eq(s.replica_config(&"aeg").pattern_deg, 0.0, 1e-6)
	assert_not_null(_cfg(s), "the shotgun row still reads")


func test_a_one_bb_left_pull_sends_one_bb_and_empties_the_shell() -> void:
	var c := _holding(_shotgun())
	c.armament.ammo[0].mag = 1
	var pool := BBPool.new(16)
	var events := SimEvents.new()
	_pull(c, pool, events, SimTuning.new())
	assert_eq(events.count_of(GameEvent.Kind.SHOT), 1)
	assert_eq(_flying(pool), 1)
	assert_eq(c.armament.mag(), 0)


func test_a_pull_on_an_empty_shell_is_a_dry_click_with_no_bbs() -> void:
	var c := _holding(_shotgun())
	c.armament.ammo[0].mag = 0
	var pool := BBPool.new(16)
	var events := SimEvents.new()
	_pull(c, pool, events, SimTuning.new())
	assert_eq(events.count_of(GameEvent.Kind.SHOT), 0)
	assert_eq(events.count_of(GameEvent.Kind.DRY_FIRE), 1)
	assert_eq(_flying(pool), 0)
	assert_eq(c.armament.mag(), 0)


func _release(c: Character, pool: BBPool, tuning: SimTuning) -> void:
	Armament.step(c, PlayerCommand.new(), EYE, 1.0, true, pool, Seeds.stream(1), SimEvents.new(), tuning, DT)


func test_a_shell_of_four_gives_a_pull_of_three_then_a_pull_of_one_never_below_empty() -> void:
	var c := _holding(_shotgun())
	c.armament.ammo[0].mag = 4
	var pool := BBPool.new(16)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	_pull(c, pool, events, tuning)
	assert_eq([_flying(pool), c.armament.mag()], [3, 1])
	_release(c, pool, tuning)
	c.armament.cooldown = 0.0
	_pull(c, pool, events, tuning, 1)
	assert_eq(events.count_of(GameEvent.Kind.SHOT), 1)
	assert_eq([_flying(pool), c.armament.mag()], [4, 0])


func test_a_laser_pull_is_still_one_shot_event_and_marks_the_shot_as_a_laser() -> void:
	var c := _holding(_shotgun())
	c.lasers = true
	var pool := BBPool.new(16)
	var events := SimEvents.new()
	_pull(c, pool, events, SimTuning.new())
	assert_eq(events.count_of(GameEvent.Kind.SHOT), 1)
	assert_eq(events.first(GameEvent.Kind.SHOT).value2, GameEvent.SHOT_LASER)
	assert_eq(c.armament.mag(), 27)


func test_a_laser_pull_that_lands_all_three_on_one_body_is_one_hit() -> void:
	var tuning := SimTuning.new()
	tuning.hits.fit = null
	var r := _shotgun()
	r.spread_deg = 0.0
	var shooter := _holding(r)
	shooter.lasers = true
	shooter.pitch = deg_to_rad(-2.0)
	var target := Character.new(2, 1, Vector3(0.0, 0.0, -3.0), 0.0)
	var roster: Array[Character] = [shooter, target]
	var pool := BBPool.new(16)
	var events := SimEvents.new()
	_pull(shooter, pool, events, tuning)
	var hits := 0
	var ends: Array[MapEnd] = []
	for i in 5:
		events.clear()
		BBStep.step(pool, roster, WorldQuery.new(), tuning, -10.0, false, ends, events, DT)
		hits += events.count_of(GameEvent.Kind.CHARACTER_HIT)
	assert_eq(hits, 1)


func test_a_pool_smaller_than_a_pull_still_fires_without_error() -> void:
	for size: int in [0, 1, 2]:
		var c := _holding(_shotgun())
		var pool := BBPool.new(size)
		var events := SimEvents.new()
		_pull(c, pool, events, SimTuning.new())
		assert_eq(events.count_of(GameEvent.Kind.SHOT), 1, "pool of %d" % size)
		assert_lte(_flying(pool), size)
		assert_eq(c.armament.mag(), 27, "the shell still gives up its three")


func test_a_full_pool_gives_up_its_oldest_bbs_for_a_pull_not_the_pulls_own() -> void:
	var c := _holding(_shotgun())
	var pool := BBPool.new(5)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	_pull(c, pool, events, tuning)
	_release(c, pool, tuning)
	c.armament.cooldown = 0.0
	_pull(c, pool, events, tuning, 1)
	assert_eq(_flying(pool), 5)
	var serials: Array[int] = []
	for bb in pool.bbs:
		serials.append(bb.serial)
	serials.sort()
	assert_eq(serials, [2, 3, 4, 5, 6], "the first pull's first BB made room, the new three all live")


func test_a_bot_with_three_bbs_a_pull_reloads_empty_and_counts_low_by_bbs() -> void:
	var rules := _rules()
	var r := rules.config(rules.pool.item("000027"))
	var b := Bot.new(_holding(r), 1, BotSkill.new(), 2)
	var cfg := BotConfig.new()
	assert_false(BotCombat.low_on_bbs(b, cfg.tactical_reload_fraction), "full")
	b.character.armament.ammo[0].mag = 2
	assert_true(BotCombat.low_on_bbs(b, cfg.tactical_reload_fraction), "two BBs left of thirty is low")
	b.character.armament.ammo[0].mag = 0
	var w := BotWorld.new()
	var cmd := PlayerCommand.new()
	BotCombat.reload_when_due(b, w, cmd)
	assert_true(cmd.reload, "an empty shell reloads while a spare is carried")


func test_press_kept_is_true_during_the_pump_for_a_bot_and_false_once_home() -> void:
	var c := _holding(_shotgun())
	var pool := BBPool.new(16)
	_pull(c, pool, SimEvents.new(), SimTuning.new())
	_release(c, pool, SimTuning.new())
	assert_true(BotCombat.press_kept(c, DT), "the pump is still being worked")
	for i in 120:
		var cmd := PlayerCommand.new()
		Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(1), SimEvents.new(), SimTuning.new(), DT)
	assert_false(BotCombat.press_kept(c, DT))


func test_the_performance_sheet_reads_the_rate_times_bbs_and_shows_pattern_only_for_it() -> void:
	var rules := _rules()
	var tuning := SimTuning.new()
	var gun := rules.config(rules.pool.item("000027"))
	var aeg := rules.config(rules.pool.item("000002"))
	var fg := LoadoutPerformance.measure(gun, gun.bb_weight, 0.0, tuning, 0.5, 60.0, 1.0)
	var fa := LoadoutPerformance.measure(aeg, aeg.bb_weight, 0.0, tuning, 0.5, 60.0, 1.0)
	assert_eq(fg.shot_bbs, 3)
	assert_almost_eq(fg.pattern, 1.2, 1e-6)
	assert_eq(fa.shot_bbs, 1)
	assert_almost_eq(fa.pattern, 0.0, 1e-6)
	var sg := LoadoutPerformance.compare(fg, fg, false, 0.0)
	var sa := LoadoutPerformance.compare(fa, fa, false, 0.0)
	assert_true(sg.row(&"pattern").present, "a Pattern row for the shotgun")
	assert_false(sa.row(&"pattern").present, "none for the AEG")
	assert_true(sg.row(&"rate").text.contains("3"), "the rate reads with its BB count: %s" % sg.row(&"rate").text)
	assert_false(sa.row(&"rate").text.contains("×"))
