extends GutTest
## Three bot levels (TL1, owner 2026-10-25): each level moved up a name and Pro became Hard. Records saved before keep
## the bots they were won against (records version 2), the multipliers and the default stay with the names, and the
## bots' kits follow the tuning (game/progress/records.gd, game/config/bot_config.gd, data/levels.md, data/bot-kits.md).

const RECORDS := "user://test_tl1_records.save"


func after_each() -> void:
	SaveFile.remove(RECORDS)


func _old_file(results: Dictionary) -> void:
	assert_true(SaveFile.write(RECORDS, Records.KIND, 1, {"results": results, "streak": 2, "best_streak": 4,
			"best_accuracy": 0.25, "best_challenge": {"range": 9}}))


func test_a_version_1_file_reads_each_record_against_the_same_bots() -> void:
	_old_file({"easy.elimination": [1, 2], "normal.elimination": [3, 4], "hard.elimination": [5, 6],
			"pro.elimination": [7, 8], "pro.attack_defend": [1, 0], "hard.attack_defend": [0, 3],
			"custom.elimination": [2, 2]})
	var r := Records.new()
	r.load_file(RECORDS)
	assert_eq(r.load_message, "", "no warning: nothing was lost")
	assert_eq(r.win_loss(&"easy", "elimination"), PackedInt32Array([4, 6]), "old Easy and old Normal both now Easy's")
	assert_eq(r.win_loss(&"normal", "elimination"), PackedInt32Array([5, 6]), "old Hard is Normal")
	assert_eq(r.win_loss(&"hard", "elimination"), PackedInt32Array([7, 8]), "old Pro is Hard")
	assert_eq(r.win_loss(&"hard", "attack_defend"), PackedInt32Array([1, 0]), "Attack / Defend moves too")
	assert_eq(r.win_loss(&"normal", "attack_defend"), PackedInt32Array([0, 3]))
	assert_eq(r.win_loss(&"custom", "elimination"), PackedInt32Array([2, 2]), "an id it doesn't move is kept")
	assert_false(r.results.has("pro.elimination"))
	assert_eq([r.streak, r.best_streak, r.challenge_best("range")], [2, 4, 9], "the rest as it was")
	assert_almost_eq(r.best_accuracy, 0.25, 1e-6)


func test_a_moved_file_saves_as_version_2_and_reads_back_unmoved() -> void:
	_old_file({"hard.elimination": [5, 6]})
	var r := Records.new()
	r.load_file(RECORDS)
	assert_true(r.save(RECORDS))
	var read := SaveFile.read(RECORDS, Records.KIND)
	assert_eq(int(read.version), 2)
	var again := Records.new()
	again.load_file(RECORDS)
	assert_eq(again.win_loss(&"normal", "elimination"), PackedInt32Array([5, 6]), "moved once, never twice")
	assert_eq(again.win_loss(&"easy", "elimination"), PackedInt32Array([0, 0]))


func test_a_version_2_file_is_read_as_it_stands() -> void:
	assert_eq(Records.VERSION, 2)
	assert_true(SaveFile.write(RECORDS, Records.KIND, 2, {"results": {"normal.elimination": [3, 1]}}))
	var r := Records.new()
	r.load_file(RECORDS)
	assert_eq(r.win_loss(&"normal", "elimination"), PackedInt32Array([3, 1]))


func test_the_multipliers_and_the_default_stay_with_the_names() -> void:
	var table := LevelTable.read_file(Pool.shared())
	assert_eq(table.problems, [] as Array[String])
	assert_eq(table.multiplier(&"easy"), 0.5)
	assert_eq(table.multiplier(&"normal"), 1.0)
	assert_eq(table.multiplier(&"hard"), 1.5)
	assert_false(table.multipliers.has(&"pro"), "no Pro row")
	assert_eq(MatchOptions.DEFAULT_LEVEL, "normal")
	var session := PlaySession.new()
	assert_eq(session.difficulty, &"normal")
	session.free()


func test_the_kits_follow_the_tuning() -> void:
	var k := BotKits.read_file(Pool.read_file())
	assert_eq(k.problems, [] as Array[String])
	var factory: BotKits.Plan = null
	for p in k.kits:
		if p.kit_name == "Factory":
			factory = p
	assert_eq(factory.weights, {&"easy": 30.0, &"normal": 10.0, &"hard": 0.0} as Dictionary[StringName, float],
			"the old Normal, Hard and Pro columns")


func test_every_level_keeps_out_of_the_light_and_holds_fire_through_leaves() -> void:
	var cfg := BotConfig.load_default()
	for level: String in MatchOptions.BOT_LEVELS:
		var s := cfg.skill_for(StringName(level))
		assert_false("keeps_dark" in s or "fires_into_leaves" in s, "%s: the old Easy's habits are gone" % level)
	assert_eq(MatchOptions.TIPS_LEVEL, &"hard", "the Pro tips follow Pro to Hard")


func test_an_attack_defend_record_survives_a_save_and_a_load() -> void:
	var r := Records.new()
	var m := Records.Result.new()
	m.difficulty = &"hard"
	m.mode = MatchOptions.MODE_ATTACK_DEFEND
	m.won = true
	r.add(m)
	m.mode = MatchOptions.MODE_ELIMINATION
	r.add(m)
	assert_true(r.save(RECORDS))
	var again := Records.new()
	again.load_file(RECORDS)
	assert_eq(again.load_message, "")
	assert_eq(again.win_loss(&"hard", MatchOptions.MODE_ATTACK_DEFEND), PackedInt32Array([1, 0]), "kept, \"_\" and all")
	assert_eq(again.win_loss(&"hard", MatchOptions.MODE_ELIMINATION), PackedInt32Array([1, 0]))
