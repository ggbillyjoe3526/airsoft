extends GutTest
## Levels, XP and unlocks (LV1): data/levels.md read against the pool, what a match gives, the player's progress and
## records saved apart, locked items in the loadout rules, and a match settled once (none off the record). Ported from
## the browser game's progress/levels.test.ts, xp.test.ts, progress.test.ts and stats/records.test.ts.

const PROGRESS := "user://test_lv1_progress.save"
const RECORDS := "user://test_lv1_records.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const STANDARD := "000003"
const GREEN := "000004"
const LIPO := "000015"
const RED_DOT := "000007"
const SCOPE := "000010"
const SILENCER := "000018"
const HEAD := """| Level | XP | Unlocks |
|---|---|---|
"""

var pool: Pool
var table: LevelTable


func before_all() -> void:
	pool = Pool.read_file()
	table = LevelTable.read_file(pool)


func before_each() -> void:
	SaveFile.remove(PROGRESS)
	SaveFile.remove(RECORDS)


func after_each() -> void:
	SaveFile.remove(PROGRESS)
	SaveFile.remove(RECORDS)
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("test_lv1_") and f.contains(".corrupt-"):
			DirAccess.remove_absolute("user://" + f)


func test_the_shipped_levels_read_clean_and_unlock_every_item_once() -> void:
	assert_eq(table.problems, [] as Array[String])
	assert_eq(table.cap(), 10)
	assert_eq(table.levels[0].total, 0)
	assert_eq(table.levels[1].total, 100)
	assert_eq(table.levels[10].total, 6500)
	assert_eq(table.unlock_level(AEG), 0)
	assert_eq(table.unlock_level(RED_DOT), 1)
	assert_eq(table.unlock_level(SCOPE), 5, "with the Sniper Rifle it comes on (SN1)")
	assert_eq(table.unlock_level("000021"), 5)
	assert_eq(table.unlock_level(CYBER), 10)
	var count := 0
	for l in table.levels:
		count += l.unlocks.size()
	assert_eq(count, pool.replicas.size() + pool.powers.size() + pool.parts.size() + pool.waiting.size())
	assert_eq(table.earn, {&"match_played": 100, &"match_won": 100, &"round_won": 20, &"hit": 10})
	assert_eq(table.multiplier(&"hard"), 1.5)


func test_a_gap_ends_the_levels_and_a_bad_name_is_left_out_of_its_row() -> void:
	var t := LevelTable.parse("## Levels\n" + HEAD + "| 0 | | AEG Rifle, Nonsense |\n| 1 | 100 | red dot |\n"
			+ "| 3 | 200 | Silencer |\n", pool)
	assert_eq(t.cap(), 1)
	assert_eq(t.unlock_level(RED_DOT), 1, "names match whatever their case")
	assert_eq(t.unlock_level(SILENCER), -1)
	var text := "\n".join(t.problems)
	assert_string_contains(text, "levels.md:4: \"Nonsense\" isn't a Name or ID in pool.md")
	assert_string_contains(text, "levels.md:6: Level must be 2 here")
	assert_string_contains(text, "no level unlocks the GBB Pistol")
	assert_false(text.contains("no level unlocks the Silencer"), "named in a row left out: said there instead")


func test_an_item_twice_and_bad_xp_are_problems_with_their_lines() -> void:
	var t := LevelTable.parse("## Levels\n" + HEAD + "| 0 | | AEG Rifle |\n| 1 | 100 | 000002 |\n| 2 | lots | Red Dot |\n",
			pool)
	assert_eq(t.cap(), 1)
	var text := "\n".join(t.problems)
	assert_string_contains(text, "levels.md:5: the AEG Rifle is already unlocked at level 0")
	assert_string_contains(text, "levels.md:6: XP must be a whole number")
	assert_string_contains(text, "no XP table")


func test_no_level_0_unlocks_everything_from_the_start() -> void:
	var t := LevelTable.parse("", pool)
	assert_eq(t.cap(), 0)
	assert_eq(t.unlock_level(CYBER), 0)
	assert_string_contains("\n".join(t.problems), "no readable level 0")


func test_the_xp_tables_override_the_built_in_numbers_and_refuse_bad_ones() -> void:
	var t := LevelTable.parse("""## XP
| Event | XP |
|---|---|
| Match played | 50 |
| Hit on an opponent | -3 |
| Kills | 5 |

| Difficulty | Multiplier |
|---|---|
| Easy | 0.05 |
| Hard | 3 |
| Pro | 2 |
""", pool)
	assert_eq(t.earn[&"match_played"], 50)
	assert_eq(t.earn[&"hit"], 10, "a bad number keeps the built-in one")
	assert_eq(t.multiplier(&"easy"), 0.5, "below 0.1 is refused")
	assert_eq(t.multiplier(&"hard"), 3.0)
	var text := "\n".join(t.problems)
	assert_string_contains(text, "\"Pro\" isn't a difficulty (Easy, Normal, Hard or Custom)", "no Pro since TL1")
	assert_string_contains(text, "\"Kills\" isn't one of")
	assert_string_contains(text, "Multiplier must be a number from 0.1")


func test_standing_counts_xp_into_the_level_and_stops_at_the_cap() -> void:
	var s := table.standing(920)
	assert_eq([s.level, s.into, s.next], [3, 120, 500])
	var top := table.standing(99999)
	assert_eq(top.level, 10)
	assert_true(top.at_cap())


func test_a_standard_win_gives_its_lines_times_the_lower_difficulty() -> void:
	var o := MatchXp.Outcome.new()
	o.won = true
	o.rounds_won = 5
	o.hits = 4
	o.difficulty = &"hard"
	o.teammate_difficulty = &"normal"
	var e := MatchXp.earned(table, o)
	assert_eq(e.lines.map(func(l: MatchXp.Line) -> Array: return [l.key, l.count, l.xp]),
			[[&"match_played", 1, 100], [&"match_won", 1, 100], [&"round_won", 5, 100], [&"hit", 4, 40]])
	assert_eq(e.multiplier, 1.0, "Normal teammates hold Hard opponents to x1")
	assert_eq(e.total, 340)
	o.teammate_difficulty = &""
	assert_eq(MatchXp.earned(table, o).total, 510)


func test_a_shorter_match_gives_its_match_lines_scaled_but_hits_in_full() -> void:
	var o := MatchXp.Outcome.new()
	o.won = true
	o.rounds_won = 2
	o.hits = 3
	o.wins_needed = 2
	assert_eq(MatchXp.earned(table, o).total, 40 + 40 + 16 + 30)


func test_xp_unlocks_what_its_levels_give_and_stops_at_the_cap() -> void:
	var p := Progress.new(table)
	assert_eq(p.level(), 0)
	assert_true(p.has(AEG) and p.has(GREEN), "the starting kit")
	assert_false(p.has(RED_DOT))
	var up := p.add_xp(450)
	assert_eq([up.from, up.to], [0, 2])
	assert_true(up.unlocked.has(RED_DOT))
	assert_true(p.has(RED_DOT))
	p.add_xp(100000)
	assert_eq(p.xp, 6500, "XP stops at the cap's total")
	assert_true(p.has(CYBER))
	p.reset()
	assert_eq(p.xp, 0)
	assert_false(p.has(RED_DOT))


func test_progress_saves_apart_and_a_damaged_file_starts_again_set_aside() -> void:
	var p := Progress.new(table)
	p.add_xp(150)
	assert_true(p.save(PROGRESS))
	var again := Progress.new(table)
	again.load_file(PROGRESS)
	assert_eq(again.xp, 150)
	assert_true(again.has(RED_DOT))
	var f := FileAccess.open(PROGRESS, FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	var broken := Progress.new(table)
	broken.load_file(PROGRESS)
	assert_eq(broken.xp, 0)
	assert_ne(broken.load_message, "")
	assert_false(FileAccess.file_exists(PROGRESS), "set aside, not read again")


func test_the_last_matchs_map_and_team_are_kept_across_launches_and_open_the_match_page_on_them() -> void:
	var p := Progress.new(table)
	p.add_xp(150)
	assert_true(p.save(PROGRESS))
	p.remember_picks("woodland", PlaySession.TEAM_BETA)
	assert_true(p.dirty, "a change of picks is saved")
	p.save_if_dirty(PROGRESS)
	var again := Progress.new(table)
	again.load_file(PROGRESS)
	assert_eq([again.last_map, again.last_team], ["woodland", PlaySession.TEAM_BETA])
	assert_eq(again.xp, 150, "kept with the progress")
	again.remember_picks("woodland", PlaySession.TEAM_BETA)
	assert_false(again.dirty, "the same picks: nothing to save")
	var picks := MatchPicks.new()
	picks.recall(again)
	assert_eq([picks.map_id, picks.team], ["woodland", PlaySession.TEAM_BETA])
	# A map removed since, or a team that isn't one: the first card (Depot) and Alpha; a new player the same.
	SaveFile.write(PROGRESS, Progress.KIND, Progress.VERSION, {"xp": 0, "last_map": "neon_heights", "last_team": 7})
	var gone := Progress.new(table)
	gone.load_file(PROGRESS)
	assert_eq(gone.last_team, -1)
	for from: Progress in [gone, Progress.new(table)]:
		var fresh := MatchPicks.new()
		fresh.recall(from)
		assert_eq([fresh.map_id, fresh.team], ["depot", PlaySession.TEAM_ALPHA])
	SaveFile.write(PROGRESS, Progress.KIND, Progress.VERSION, {"xp": 0, "last_map": 5, "last_team": "beta"})
	var wild := Progress.new(table)
	wild.load_file(PROGRESS)
	assert_eq([wild.last_map, wild.last_team], ["", -1], "not a name or a team: none kept")


func test_progress_from_a_newer_build_is_never_written_over() -> void:
	SaveFile.write(PROGRESS, Progress.KIND, Progress.VERSION + 1, {"xp": 9000})
	var p := Progress.new(table)
	p.load_file(PROGRESS)
	p.add_xp(100)
	assert_false(p.save(PROGRESS))
	assert_eq(int(SaveFile.read(PROGRESS, Progress.KIND).data.xp), 9000)


func test_unlocks_are_never_taken_away_and_an_item_moved_down_arrives() -> void:
	var p := Progress.new(table)
	p.from_dict({"xp": 0, "unlocked": [SCOPE, "junk"]})
	assert_true(p.has(SCOPE), "kept though level 0 doesn't give it")
	assert_false(p.unlocked.has("junk"))
	var moved := LevelTable.parse("## Levels\n" + HEAD + "| 0 | | AEG Rifle |\n| 1 | 100 | Silencer |\n", pool)
	var q := Progress.new(moved)
	q.from_dict({"xp": 150, "unlocked": [AEG]})
	assert_eq(q.grant_reached(), PackedStringArray([SILENCER]))


func test_records_count_wins_losses_streaks_and_best_accuracy() -> void:
	var r := Records.new()
	var m := Records.Result.new()
	m.won = true
	m.hits = 5
	m.bbs_fired = 50
	assert_true(r.add(m).best_accuracy)
	r.add(m)
	m.won = false
	m.hits = 1
	m.bbs_fired = 10
	var news := r.add(m)
	assert_false(news.best_accuracy, "too few BBs to count")
	assert_eq(r.win_loss(&"normal", "elimination"), PackedInt32Array([2, 1]))
	assert_eq([r.streak, r.best_streak], [0, 2])
	assert_almost_eq(r.best_accuracy, 0.1, 0.0001)
	assert_true(r.save(RECORDS))
	var again := Records.new()
	again.load_file(RECORDS)
	assert_eq(again.win_loss(&"normal", "elimination"), PackedInt32Array([2, 1]))
	assert_eq(again.best_streak, 2)
	assert_almost_eq(again.best_accuracy, 0.1, 0.0001)


func test_records_drop_bad_fields_one_by_one() -> void:
	var r := Records.new()
	var problems := r.from_dict({"results": {"normal.elimination": [3, 1], "bad key": [1, 1], "hard.x": [-1, 0]},
			"best_accuracy": 2.0, "streak": 4, "best_streak": 1})
	assert_eq(r.results.keys(), ["normal.elimination"])
	assert_eq(problems.size(), 2)
	assert_eq(r.best_accuracy, 1.0)
	assert_eq(r.best_streak, 4, "never below the streak now")


func test_locked_items_are_listed_but_cannot_be_picked_and_play_as_they_come() -> void:
	var rules := LoadoutRules.new(pool, ReplicaStats.read_file(), ReplicaRulesConfig.new())
	var l := rules.default_loadout("Test")
	assert_true(rules.set_part(l, AEG, &"optic", SCOPE), "everything unlocked without progress")
	assert_true(rules.set_power(l, AEG, LIPO))
	var p := Progress.new(table)
	rules.follow_progress(p, false)
	assert_true(rules.is_locked(SCOPE))
	assert_eq(rules.unlock_level(SCOPE), 5)
	assert_false(rules.set_part(l, AEG, &"optic", RED_DOT))
	assert_false(rules.set_power(l, AEG, STANDARD) and rules.set_power(l, AEG, LIPO))
	var kit := rules.carried(l)
	assert_eq(kit.parts[0], {}, "the saved scope plays as not fitted")
	assert_eq(rules.tune_of(l, AEG).parts[&"optic"], SCOPE, "and stays saved")
	rules.follow_progress(p, true)
	assert_false(rules.is_locked(SCOPE), "Disable levelling unlocks it all")
	assert_eq(rules.carried(l).parts[0], {&"optic": &"scope2x"})


func test_disable_levelling_is_a_cheat_that_keeps_a_match_off_the_record() -> void:
	var dev := DevSettings.new()
	dev.disable_levelling = true
	assert_true(dev.cheats().any())
	var again := DevSettings.new()
	again.from_dict(dev.to_dict())
	assert_true(again.disable_levelling)


func test_a_match_is_tallied_and_settled_once_and_none_off_the_record() -> void:
	var state := GameState.new(1)
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var mate := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var them := Character.new(2, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	state.characters.append_array([me, mate, them])
	var tally := PlayerTally.new(0)
	_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 1], [GameEvent.Kind.SHOT, 0, -1, 0],
			[GameEvent.Kind.CHARACTER_HIT, 0, 2, 0], [GameEvent.Kind.CHARACTER_HIT, 0, 1, 0]])
	tally.on_tick(state)
	me.status = Character.Status.OUT
	_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, 0], [GameEvent.Kind.ROUND_START, -1, -1, 2]])
	tally.on_tick(state)
	_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, 0], [GameEvent.Kind.MATCH_OVER, -1, -1, 0]])
	tally.on_tick(state)
	assert_eq([tally.hits, tally.bbs_fired, tally.rounds_won], [1, 1, 1],
			"a teammate hit isn't counted; a round won while out with no hit in it isn't yours")
	var p := Progress.new(table)
	var r := Records.new()
	var s := tally.settle(p, r, false, 0, 5, "elimination", &"normal", &"normal")
	assert_eq(s.earned.total, 100 + 100 + 20 + 10)
	assert_eq(p.xp, 230)
	assert_eq(s.level_up.to, 1)
	assert_eq(r.win_loss(&"normal", "elimination"), PackedInt32Array([1, 0]))
	assert_null(tally.settle(p, r, false, 0, 5, "elimination", &"normal", &"normal"), "once")
	_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 1]])
	tally.on_tick(state)
	_events(state, [[GameEvent.Kind.MATCH_OVER, -1, -1, 1]])
	tally.on_tick(state)
	var off := tally.settle(p, r, true, 0, 5, "elimination", &"normal", &"normal")
	assert_null(off.earned)
	assert_eq(off.why_none, "XP_NONE_DEV")
	assert_eq(p.xp, 230)
	assert_eq(r.win_loss(&"normal", "elimination"), PackedInt32Array([1, 0]))



func test_a_drawn_round_1_played_again_keeps_the_tally() -> void:
	var state := GameState.new(1)
	state.characters.append_array([Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()),
			Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())])
	var tally := PlayerTally.new(0)
	_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 1], [GameEvent.Kind.SHOT, 0, -1, 0],
			[GameEvent.Kind.CHARACTER_HIT, 0, 1, 0]])
	tally.on_tick(state)
	state.round_state.draws = 1
	_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, -1], [GameEvent.Kind.ROUND_START, -1, -1, 1]])
	tally.on_tick(state)
	assert_eq([tally.hits, tally.bbs_fired], [1, 1], "the drawn round's hit and BB stay in the match")

## Replaces the state's events with `list`: each [kind, actor, target, value].
func _events(state: GameState, list: Array) -> void:
	state.events.clear()
	for spec: Array in list:
		var e := state.events.add(spec[0])
		e.actor = spec[1]
		e.target = spec[2]
		e.value = spec[3]
