extends GutTest
## QA's probes of MN3 (the BOTS section): the teammates' level reaching the bots' skill and the records rule, the picks
## surviving the menus being freed for a match and built again, the page's XP note matching what a match earns over
## every pair, Custom 1v1 greying the row and 2v2 restoring it, and the keyboard's way through the new buttons.

const MAIN := preload("res://game/main.tscn")
const SAVE := "user://test-mn3-qa.save"
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
	# A copy of the settings, never the shared ones: the Custom rows are written into it.
	var settings := Settings.new()
	if custom_size > 0:
		_picks.rules = MatchOptions.RULES_CUSTOM
		settings.custom_rules.team_size = custom_size
	var page := MatchPage.new(_picks, settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	return page


func _picked(page: MatchPage, teammates: bool) -> Array[String]:
	var out: Array[String] = []
	for level in LEVELS:
		var b := page.teammate_button(level) if teammates else page.bot_button(level)
		if b.is_picked():
			out.append(level)
	return out


# --- the picks reach the bots and the records rule ---

func test_the_teammates_pick_sets_the_bots_skill_of_your_team() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.bots = "easy"
	main._picks.teammates = "hard"
	main._start_play()
	await wait_until(func() -> bool: return main._play != null and main._play._bots != null, 30.0)
	var config := BotConfig.load_default()
	var mates := 0
	var foes := 0
	for b: Bot in main._play._bots.world.bots:
		var want: BotSkill = config.skill_for(&"hard" if b.character.team == main._play.player_team else &"easy")
		assert_eq(b.skill.aim_error_start_deg, want.aim_error_start_deg, "bot %d" % b.character.id)
		assert_eq(b.skill.turn_rate, want.turn_rate, "bot %d" % b.character.id)
		if b.character.team == main._play.player_team:
			mates += 1
		else:
			foes += 1
	assert_gt(mates, 0, "your teammates are bots")
	assert_gt(foes, 0)
	assert_ne(config.skill_for(&"hard").aim_error_start_deg, config.skill_for(&"easy").aim_error_start_deg,
			"the two levels differ, or this proves nothing")
	main._end_play()
	await wait_process_frames(2)


func test_following_gives_your_team_the_following_level_skill() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.bots = "hard"
	main._start_play()
	await wait_until(func() -> bool: return main._play != null and main._play._bots != null, 30.0)
	var config := BotConfig.load_default()
	for b: Bot in main._play._bots.world.bots:
		assert_eq(b.skill.aim_error_start_deg, config.skill_for(&"hard").aim_error_start_deg)
	main._end_play()
	await wait_process_frames(2)


func test_the_records_rule_over_every_pair() -> void:
	var counted := 0
	for opponents in LEVELS:
		for mates in LEVELS:
			var s: PlaySession = autofree(PlaySession.new())
			s.difficulty = StringName(opponents)
			s.teammate_difficulty = StringName(mates)
			var want := mates == opponents
			assert_eq(s.counts_for_records(), want, "%s vs %s teammates" % [opponents, mates])
			counted += int(want)
		var following: PlaySession = autofree(PlaySession.new())
		following.difficulty = StringName(opponents)
		assert_true(following.counts_for_records(), "%s with teammates following" % opponents)
	assert_eq(counted, 3, "the three same-level pairs")


# --- the picks survive the menus being freed ---

func test_the_picks_survive_the_menus_being_freed_for_a_match() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var page: MatchPage = main._menus.match_page()
	page.bot_button("hard").pressed.emit()
	page.teammate_button("easy").pressed.emit()
	main._start_play()
	await wait_process_frames(2)
	assert_null(main._menus, "the menus are freed during a match")
	main._end_play()
	await wait_process_frames(2)
	var again: MatchPage = main._menus.match_page()
	assert_eq(_picked(again, false), ["hard"])
	assert_eq(_picked(again, true), ["easy"])
	assert_false(again.bots_box().says_follows())
	assert_true(again.bots_box().follow_button().visible)
	assert_eq(again.summary_text(), "Depot · Elimination · Alpha · Hard bots · Easy teammates")


func test_a_following_teammate_still_follows_after_the_menus_are_rebuilt() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._menus.match_page().bot_button("hard").pressed.emit()
	main._start_play()
	await wait_process_frames(2)
	main._end_play()
	await wait_process_frames(2)
	var again: MatchPage = main._menus.match_page()
	assert_eq(_picked(again, true), ["hard"])
	assert_true(again.bots_box().says_follows())
	again.bot_button("easy").pressed.emit()
	assert_eq(_picked(again, true), ["easy"])


# --- the XP on the page is the XP the match gives ---

func test_the_page_xp_matches_what_the_match_earns_over_every_pair() -> void:
	var table := LevelTable.shared()
	for sized: bool in [false, true]:
		var page := _page()
		for custom: bool in [false, true]:
			for opponents in LEVELS:
				for picked: String in ["", "easy", "normal", "hard"]:
					_picks.bots = opponents
					_picks.teammates = picked
					page.bots_box().show_picks(1 if sized else 3, custom)
					# What the session hands the tally.
					var s: PlaySession = autofree(PlaySession.new())
					s.difficulty = StringName(opponents)
					s.teammate_difficulty = StringName(picked)
					var o := MatchXp.Outcome.new()
					o.difficulty = s.difficulty
					o.teammate_difficulty = &"" if sized else s.teammates_level()
					o.custom = custom
					var got := MatchXp.earned(table, o).multiplier
					var label := "%s vs %s (%s) alone=%s custom=%s" % [opponents, picked, s.teammates_level(), sized,
							custom]
					assert_string_ends_with(page.bots_box().opponents_text(),
							"XP ×" + ArmoryFacts.multiplier_text(got), label)


# --- Custom 1v1 and back ---

func test_custom_1v1_greys_the_row_and_2v2_restores_the_pick() -> void:
	var page := _page()
	page.bot_button("normal").pressed.emit()
	page.teammate_button("hard").pressed.emit()
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	page.rules_box().team_size_choice().button(0).pressed.emit()
	for level in LEVELS:
		assert_true(page.teammate_button(level).disabled, level)
	assert_eq(_picked(page, true), [])
	assert_eq(_picks.teammates, "hard", "the pick is kept")
	page.rules_box().team_size_choice().button(1).pressed.emit()
	for level in LEVELS:
		assert_false(page.teammate_button(level).disabled, level)
	assert_eq(_picked(page, true), ["hard"])
	assert_true(page.bots_box().follow_button().visible)
	assert_eq(page.teammate_button("hard").modulate.a, 1.0, "not faded")
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots · Hard teammates · Custom 2v2")
	await wait_process_frames(2)


func test_leaving_custom_1v1_for_skirmish_restores_the_row() -> void:
	var page := _page()
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	page.rules_box().team_size_choice().button(0).pressed.emit()
	assert_true(page.teammate_button("normal").disabled)
	page.rules_box().rules_button(MatchOptions.RULES_SKIRMISH).pressed.emit()
	assert_false(page.teammate_button("normal").disabled)
	assert_true(page.teammate_button("normal").is_picked())
	assert_true(page.bots_box().says_follows())
	await wait_process_frames(2)


# --- the keyboard ---

func test_the_follow_button_is_reachable_by_focus_and_keeps_focus_somewhere_after_it_hides() -> void:
	var page := _page()
	page.teammate_button("easy").pressed.emit()
	await wait_process_frames(2)
	var follow := page.bots_box().follow_button()
	assert_eq(follow.focus_mode, Control.FOCUS_ALL)
	follow.grab_focus()
	assert_true(follow.has_focus(), "focusable while shown")
	follow.pressed.emit()
	await wait_process_frames(2)
	assert_false(follow.visible)
	var owner := follow.get_viewport().gui_get_focus_owner()
	assert_eq(owner, page.teammate_button("normal"), "pressing it hides it: focus moves to the level now played")
	for key: Key in [KEY_DOWN, KEY_TAB]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = true
		follow.get_viewport().push_input(ev)
		await wait_process_frames(2)
		gut.p("focus owner after key %s: %s" % [OS.get_keycode_string(key), follow.get_viewport().gui_get_focus_owner()])


func test_every_new_button_is_in_the_tab_chain() -> void:
	var page := _page()
	await wait_process_frames(2)
	var seen: Array[Control] = []
	var c: Control = page.bot_button("easy")
	for i in 40:
		c.grab_focus()
		seen.append(c)
		var next := c.find_next_valid_focus()
		if next == null or seen.has(next):
			break
		c = next
	for level in LEVELS:
		assert_true(seen.has(page.bot_button(level)), "opponents " + level)
		assert_true(seen.has(page.teammate_button(level)), "teammates " + level)
	var alone := _page(1)
	await wait_process_frames(2)
	var seen_alone: Array[Control] = []
	c = alone.bot_button("easy")
	for i in 40:
		seen_alone.append(c)
		var next := c.find_next_valid_focus()
		if next == null or seen_alone.has(next):
			break
		c = next
	var stops := 0
	for level in LEVELS:
		stops += int(seen_alone.has(alone.teammate_button(level)))
	# Greyed cards are focusable in Godot 4 as the LATER mode cards already are; reported, not asserted.
	gut.p("greyed Teammates buttons left in the tab chain of a 1v1: %d" % stops)
