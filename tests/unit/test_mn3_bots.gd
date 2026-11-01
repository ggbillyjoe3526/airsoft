extends GutTest
## The BOTS section of the Match page (MN3, concepts `bots-follow.png` and `bots-picked-dev.png`): the Opponents and
## Teammates rows with the browser game's words, the teammates following the opponents until one is picked, the picks
## reaching a PlaySession, the summary line naming both levels, a 1v1 having no teammates, and the XP multiplier shown.

const MAIN := preload("res://game/main.tscn")
const SAVE := "user://test-mn3-bots.save"
const LEVELS: Array[String] = ["easy", "normal", "hard"]

var _picks: MatchPicks = null
var _shipped: MapCatalog = null


## Depot as it was until DR1 (1v1 to 3v3), so the page's Custom 1v1 can be picked: no shipped field offers one now.
func before_all() -> void:
	_shipped = MapCatalog.shared()
	MapCatalog._shared = MapCatalog.parse(FileAccess.get_file_as_string(MapCatalog.PATH).replace(
			"| depot | Depot | field | public | 5 | 6 | 8 |", "| depot | Depot | field | public | 1 | 3 | 3 |"))
	assert_eq(MapCatalog._shared.find("depot").team_min, 1)


func after_all() -> void:
	MapCatalog._shared = _shipped


func after_each() -> void:
	DirAccess.remove_absolute(SAVE)


func _page(custom_size: int = 0) -> MatchPage:
	_picks = MatchPicks.new()
	var settings := Settings.new()
	if custom_size > 0:
		_picks.rules = MatchOptions.RULES_CUSTOM
		settings.custom_rules.team_size = custom_size
	var page := MatchPage.new(_picks, settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	return page


func _picked_row(page: MatchPage, teammates: bool) -> Array[String]:
	var out: Array[String] = []
	for level in LEVELS:
		var b := page.teammate_button(level) if teammates else page.bot_button(level)
		if b.is_picked():
			out.append(level)
	return out


# --- the rows ---

func test_two_rows_with_a_button_for_each_of_the_three_levels() -> void:
	var page := _page()
	assert_eq(MatchOptions.BOT_LEVELS, PackedStringArray(LEVELS))
	for level in LEVELS:
		for teammates: bool in [false, true]:
			var b := page.teammate_button(level) if teammates else page.bot_button(level)
			assert_eq(b.text, level.to_upper())
			assert_false(b.disabled, level)
			assert_true(b.visible, level)
	assert_ne(page.bot_button("easy"), page.teammate_button("easy"))


func test_the_words_are_the_browser_games_blurbs() -> void:
	var page := _page()
	var words := {
		"easy": ["A fair fight to learn on: their first BBs up close can miss.", "They hold their own in a fair fight."],
		"normal": ["Quick and steady, each on kit of its own. Get seen first and you're out.",
				"Quick and steady: they win fights for you."],
		"hard": ["Tournament-sharp: patient, accurate and well kitted. Slow down and slice every corner.",
				"Patient and accurate: they hold their angles and win their duels."],
	}
	for level: String in words:
		_picks.bots = level
		_picks.teammates = level
		page.bots_box().show_picks(3, false)
		assert_string_starts_with(page.bots_box().opponents_text(), words[level][0])
		assert_eq(page.bots_box().teammates_text(), words[level][1], level)


func test_the_opponents_line_ends_with_the_xp_multiplier() -> void:
	var page := _page()
	page.bot_button("hard").pressed.emit()
	assert_eq(page.bots_box().opponents_text(),
			"Tournament-sharp: patient, accurate and well kitted. Slow down and slice every corner. XP ×1.5")
	page.bot_button("easy").pressed.emit()
	assert_string_ends_with(page.bots_box().opponents_text(), "XP ×0.5")
	page.bot_button("normal").pressed.emit()
	assert_string_ends_with(page.bots_box().opponents_text(), "XP ×1")


# --- following until picked ---

func test_teammates_follow_the_opponents_until_one_is_picked() -> void:
	var page := _page()
	assert_eq(_picks.teammates, "", "following")
	assert_true(page.bots_box().says_follows())
	assert_false(page.bots_box().follow_button().visible)
	assert_eq(_picked_row(page, true), ["normal"], "Normal against Normal")
	page.bot_button("hard").pressed.emit()
	assert_eq(_picked_row(page, true), ["hard"], "they follow Hard")
	page.bot_button("easy").pressed.emit()
	assert_eq(_picked_row(page, true), ["easy"], "they follow Easy too (TL1)")
	assert_eq(_picks.teammates, "", "following never writes a pick")


func test_a_picked_level_is_kept_until_you_follow_again() -> void:
	var page := _page()
	page.bot_button("hard").pressed.emit()
	page.teammate_button("easy").pressed.emit()
	assert_eq(_picks.teammates, "easy")
	assert_false(page.bots_box().says_follows())
	assert_true(page.bots_box().follow_button().visible)
	page.bot_button("normal").pressed.emit()
	assert_eq(_picked_row(page, true), ["easy"], "the opponents' pick no longer moves them")
	page.bots_box().follow_button().pressed.emit()
	assert_eq(_picks.teammates, "")
	assert_eq(_picked_row(page, true), ["normal"], "following again")
	assert_true(page.bots_box().says_follows())
	assert_false(page.bots_box().follow_button().visible)


func test_the_picks_are_kept_when_the_page_is_built_again() -> void:
	var page := _page()
	page.bot_button("hard").pressed.emit()
	page.teammate_button("normal").pressed.emit()
	var again := MatchPage.new(_picks, Settings.new())
	add_child_autofree(again)
	assert_eq(_picked_row(again, false), ["hard"])
	assert_eq(_picked_row(again, true), ["normal"])
	assert_false(again.bots_box().says_follows())


# --- the picks reach the match ---

func test_the_picks_reach_the_play_session() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.bots = "hard"
	main._picks.teammates = "easy"
	main._start_play()
	await wait_process_frames(2)
	assert_eq(main._play.difficulty, &"hard")
	assert_eq(main._play.teammate_difficulty, &"easy")
	assert_eq(main._play.teammates_level(), &"easy")
	assert_false(main._play.counts_for_records(), "Easy teammates against Hard are off the record")
	main._end_play()
	await wait_process_frames(2)


func test_following_hands_the_session_no_teammate_level() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.bots = "easy"
	main._start_play()
	await wait_process_frames(2)
	assert_eq(main._play.teammate_difficulty, &"")
	assert_eq(main._play.teammates_level(), &"easy", "Easy against Easy")
	assert_true(main._play.counts_for_records())
	main._end_play()
	await wait_process_frames(2)


# --- the summary line ---

func test_the_summary_names_both_levels_when_they_differ() -> void:
	var page := _page()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots", "the same level: said once")
	page.bot_button("hard").pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Hard bots", "following Hard")
	page.teammate_button("normal").pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Hard bots · Normal teammates")
	page.bot_button("easy").pressed.emit()
	page.bots_box().follow_button().pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Easy bots", "following Easy: said once")
	page.teammate_button("easy").pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Easy bots", "picked the same level")


func test_the_summary_keeps_custom_last() -> void:
	assert_eq(MatchOptions.summary_rest(MatchOptions.MODE_ELIMINATION, 0, "hard", CustomRules.new(), "easy"),
			"Elimination · Alpha · Hard bots · Easy teammates · Custom 3v3")


# --- a 1v1 ---

func test_a_1v1_has_no_teammates_and_the_row_keeps_its_place() -> void:
	var page := _page()
	await wait_process_frames(2)
	var row := page.teammate_button("normal")
	var top := row.global_position.y
	var height := row.size.y
	var alone := _page(1)
	await wait_process_frames(2)
	for level in LEVELS:
		assert_true(alone.teammate_button(level).disabled, level)
		assert_true(alone.teammate_button(level).visible, level)
		assert_false(alone.teammate_button(level).is_picked(), level)
		assert_false(alone.bot_button(level).disabled, level)
	assert_eq(alone.bots_box().teammates_text(), "No teammates in a 1v1.")
	assert_false(alone.bots_box().says_follows())
	assert_false(alone.bots_box().follow_button().visible)
	assert_eq(alone.teammate_button("normal").size.y, height)
	assert_almost_eq(alone.teammate_button("normal").global_position.y, top, 0.5, "the row stays where it was")
	assert_eq(alone.summary_text(), "Depot · Elimination · Alpha · Normal bots · Custom 1v1", "no teammates named")


func test_a_pick_made_before_a_1v1_is_not_named_and_comes_back_after() -> void:
	var page := _page()
	page.teammate_button("easy").pressed.emit()
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	page.rules_box().team_size_choice().button(0).pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots · Custom 1v1")
	assert_eq(_picks.teammates, "easy", "kept")
	page.rules_box().team_size_choice().button(2).pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots · Easy teammates · Custom 3v3")
	assert_false(page.teammate_button("easy").disabled)
	assert_true(page.teammate_button("easy").is_picked())


# --- the XP note ---

func test_the_xp_follows_the_lower_of_the_two_levels() -> void:
	var page := _page()
	page.bot_button("hard").pressed.emit()
	assert_string_ends_with(page.bots_box().opponents_text(), "XP ×1.5")
	page.teammate_button("normal").pressed.emit()
	assert_string_ends_with(page.bots_box().opponents_text(), "XP ×1", "Normal teammates hold Hard's XP at ×1")
	page.bot_button("easy").pressed.emit()
	page.teammate_button("hard").pressed.emit()
	assert_string_ends_with(page.bots_box().opponents_text(), "XP ×0.5", "Easy opponents hold Hard teammates")


func test_the_xp_is_held_to_the_custom_cap_and_a_1v1_counts_the_opponents_alone() -> void:
	var page := _page()
	page.bot_button("hard").pressed.emit()
	assert_string_ends_with(page.bots_box().opponents_text(), "XP ×1.5")
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	assert_string_ends_with(page.bots_box().opponents_text(), "XP ×1.5", "Custom's cap, Hard's own since TL1")
	page.teammate_button("easy").pressed.emit()
	page.rules_box().team_size_choice().button(0).pressed.emit()
	assert_string_ends_with(page.bots_box().opponents_text(), "XP ×1.5", "no teammates to hold it down")


func test_the_note_and_the_match_agree() -> void:
	var table := LevelTable.shared()
	for opponents in LEVELS:
		for mates in LEVELS:
			var o := MatchXp.Outcome.new()
			o.difficulty = StringName(opponents)
			o.teammate_difficulty = StringName(mates)
			var earned := MatchXp.earned(table, o)
			assert_eq(earned.multiplier, MatchXp.multiplier(table, o.difficulty, o.teammate_difficulty, false))
			assert_eq(earned.multiplier, minf(table.multiplier(o.difficulty), table.multiplier(o.teammate_difficulty)))
