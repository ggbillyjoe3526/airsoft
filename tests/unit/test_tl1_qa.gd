extends GutTest
## TL1 QA: the three levels play exactly as the browser game's Normal, Hard and Pro did (every skill field pinned against
## origin/main's numbers), the kit weights move with them, a version 1 records file survives an odd entry and a restored
## save bundle, and the teammates, the records rule and the XP cap behave as the new names say.

const RECORDS := "user://test_tl1_qa_records.save"
const ROOT := "user://test-tl1-qa-bundle"
## origin/main's Normal, Hard and Pro skills, every field, as `str()` prints them; overtime_reaction (OV2) is the
## browser's for those three levels too.
const SKILLS := {
	"easy": "reaction_time=(0.35, 0.6);turn_rate=4.5;aim_error_start_deg=4.5;aim_error_settled_deg=1.1;aim_settle_time=1.0;aim_error_start_metres=0.75;aim_error_moving_deg=1.5;aim_error_tracking=0.11;lead_factor=0.5;burst=(0.2, 0.45);burst_pause=(0.3, 0.65);hold_time=(0.8, 2.5);hold_cover_chance=0.5;contact_cover_min_distance=8.0;search_walk_distance=12.0;flank_chance=0.25;hunt_memory=40.0;holds_angles=false;pre_aim_reaction_time=(0.35, 0.6);pre_aim_settled=0.0;slices_corners=false;peek_watch_time=(0.0, 0.0);team_play=false;overtime_reaction=(0.5, 1.2)",
	"normal": "reaction_time=(0.25, 0.45);turn_rate=5.5;aim_error_start_deg=4.0;aim_error_settled_deg=0.9;aim_settle_time=0.6;aim_error_start_metres=0.6;aim_error_moving_deg=1.2;aim_error_tracking=0.073;lead_factor=0.7;burst=(0.25, 0.55);burst_pause=(0.2, 0.5);hold_time=(0.4, 1.2);hold_cover_chance=0.8;contact_cover_min_distance=5.0;search_walk_distance=20.0;flank_chance=0.7;hunt_memory=50.0;holds_angles=false;pre_aim_reaction_time=(0.25, 0.45);pre_aim_settled=0.0;slices_corners=false;peek_watch_time=(0.0, 0.0);team_play=false;overtime_reaction=(0.3, 0.7)",
	"hard": "reaction_time=(0.25, 0.45);turn_rate=6.0;aim_error_start_deg=3.5;aim_error_settled_deg=0.75;aim_settle_time=0.5;aim_error_start_metres=0.5;aim_error_moving_deg=1.0;aim_error_tracking=0.061;lead_factor=0.85;burst=(0.15, 0.35);burst_pause=(0.2, 0.4);hold_time=(1.2, 3.0);hold_cover_chance=0.9;contact_cover_min_distance=4.0;search_walk_distance=30.0;flank_chance=0.7;hunt_memory=60.0;holds_angles=true;pre_aim_reaction_time=(0.18, 0.28);pre_aim_settled=0.5;slices_corners=true;peek_watch_time=(1.5, 3.0);team_play=true;overtime_reaction=(0.2, 0.5)",
}


func after_each() -> void:
	SaveFile.remove(RECORDS)


## Fields added after the levels moved, each held by its own task's tests: the bombs' chances (SF2, test_bot_bombs)
## and the team radio, pressing, the careful last bot and a knee to fire (BQ3, test_bq3_team_play).
const LATER_FIELDS: Array[String] = ["smoke_chance", "flash_chance", "share_radius", "share_delay", "presses_advantage",
		"careful_when_last", "kneels_to_fire"]


func _described(s: BotSkill) -> String:
	var out: PackedStringArray = []
	for p in s.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(p.name) in LATER_FIELDS:
			out.append("%s=%s" % [p.name, str(s.get(p.name))])
	return ";".join(out)


func test_every_skill_field_of_each_level_is_the_old_levels_one_name_up() -> void:
	var cfg := BotConfig.load_default()
	for level: String in MatchOptions.BOT_LEVELS:
		assert_eq(_described(cfg.skill_for(StringName(level))), SKILLS[level], "%s: Easy is the old Normal, Normal the old Hard, Hard the old Pro" % level)


func test_every_kit_weight_is_the_old_column_one_name_up() -> void:
	var k := BotKits.read_file(Pool.read_file())
	var old := {
		"Factory": [30, 10, 0], "Rifleman": [25, 20, 15], "Marksman": [10, 15, 20], "Support": [10, 20, 20],
		"Stealth": [10, 15, 20], "Pointman": [15, 18, 23], "Cyber": [0, 2, 2],
	}
	var seen := 0
	for p in k.kits:
		var w: Array = old[p.kit_name]
		for i in 3:
			assert_eq(p.weights.get(MatchOptions.BOT_LEVELS[i], -1.0), float(w[i]), "%s at %s" % [p.kit_name, MatchOptions.BOT_LEVELS[i]])
		seen += 1
	assert_eq(seen, old.size(), "every kit read")


func test_a_version_1_file_with_one_bad_entry_still_moves_the_rest_up() -> void:
	assert_true(SaveFile.write(RECORDS, Records.KIND, 1, {"results": {"hard.elimination": [5, 6], "pro.elimination": "x",
			"normal.elimination": [1, 1], "easy.elimination": [2, 0]}}))
	var r := Records.new()
	r.load_file(RECORDS)
	assert_eq(r.win_loss(&"normal", "elimination"), PackedInt32Array([5, 6]), "old Hard is Normal")
	assert_eq(r.win_loss(&"easy", "elimination"), PackedInt32Array([3, 1]), "old Easy and old Normal add up")
	assert_eq(r.win_loss(&"hard", "elimination"), PackedInt32Array([0, 0]), "the bad Pro entry is left out, not guessed")


func test_a_version_1_records_file_restored_from_a_save_bundle_is_moved_when_read() -> void:
	var paths: Array[String] = []
	DirAccess.make_dir_recursive_absolute(ROOT)
	for path: String in SaveBundle.PATHS:
		paths.append(ROOT.path_join(path.get_file()))
	var b := SaveBundle.new()
	b.stores[Records.KIND] = {"version": 1, "data": {"results": {"pro.elimination": [4, 2]}}}
	assert_eq(b.refusal(), "", "a version 1 store is readable")
	assert_true(b.write(paths))
	var r := Records.new()
	r.load_file(paths[SaveBundle.KINDS.find(Records.KIND)])
	assert_eq(r.win_loss(&"hard", "elimination"), PackedInt32Array([4, 2]))
	assert_eq(r.load_message, "")
	for p in paths:
		SaveFile.remove(p)
	DirAccess.remove_absolute(ROOT)


func test_a_level_nobody_names_in_the_records_is_kept_as_it_is() -> void:
	assert_true(SaveFile.write(RECORDS, Records.KIND, 1, {"results": {"master.elimination": [1, 0]}}))
	var r := Records.new()
	r.load_file(RECORDS)
	assert_eq(r.win_loss(&"master", "elimination"), PackedInt32Array([1, 0]))


func test_teammates_follow_the_opponents_at_every_level_and_only_a_matching_pair_counts() -> void:
	var s := PlaySession.new()
	for level: String in MatchOptions.BOT_LEVELS:
		s.difficulty = StringName(level)
		assert_eq(s.teammates_level(), StringName(level), "%s opponents: teammates follow" % level)
		assert_true(s.counts_for_records(), level)
		assert_eq(MatchOptions.teammates_level(level, ""), level)
	s.difficulty = &"easy"
	s.teammate_difficulty = &"normal"
	assert_false(s.counts_for_records(), "Easy opponents with Normal teammates no longer count (old Easy's special case is gone)")
	s.free()


func test_the_custom_cap_holds_a_raised_hard_and_the_lower_team_decides() -> void:
	var table := LevelTable.read_file(Pool.shared())
	assert_eq(MatchXp.multiplier(table, &"hard", &"", true), table.multiplier(LevelTable.CUSTOM), "Hard at the cap")
	assert_eq(MatchXp.multiplier(table, &"hard", &"easy", false), 0.5, "the lower team's")
	assert_eq(MatchXp.multiplier(table, &"normal", &"", true), 1.0, "Normal under the cap")
