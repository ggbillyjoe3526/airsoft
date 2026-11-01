extends GutTest
## The Rules section of the Match page (CR2, concepts `rules-skirmish.png` and `rules-custom.png`): the SKIRMISH |
## CUSTOM picker with its blurb, Skirmish's chips, Custom's five rows saving into the settings at once, the summary
## line's "Custom 6v6", what reads the round tuning following Custom, and a match being handed a copy of the switches.

const MAIN := preload("res://game/main.tscn")
const SAVE := "user://test-cr2-rules.save"
const CUSTOM := MatchOptions.RULES_CUSTOM
const SKIRMISH := MatchOptions.RULES_SKIRMISH

var _picks: MatchPicks = null
var _settings: Settings = null


func after_each() -> void:
	DirAccess.remove_absolute(SAVE)


func _page() -> MatchPage:
	_picks = MatchPicks.new()
	_settings = Settings.new()
	var page := MatchPage.new(_picks, _settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	return page


func _saved() -> CustomRules:
	var back := Settings.new()
	back.load_file(SAVE)
	return back.custom_rules


func _custom(page: MatchPage) -> void:
	page.rules_box().rules_button(CUSTOM).pressed.emit()


# --- the picker ---

func test_skirmish_shows_the_chips_and_its_blurb_and_no_rows() -> void:
	var page := _page()
	var box := page.rules_box()
	assert_true(box.rules_button(SKIRMISH).is_picked())
	assert_false(box.rules_button(CUSTOM).is_picked())
	assert_true(box.chips_visible())
	assert_false(box.rows_visible())
	assert_eq(box.blurb_text(), "The match as you know it: 6v6, first to 5, 2:30 rounds, friendly fire on.")
	assert_eq(page.chip_texts(), PackedStringArray(["6 v 6", "First to 5", "Rounds 2:30", "Ends swap after 4",
			"Ricochets Don't count", "Friendly fire On"]))
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots")


func test_picking_custom_shows_the_rows_and_its_blurb_and_reaches_the_picks() -> void:
	var page := _page()
	var box := page.rules_box()
	_custom(page)
	assert_eq(_picks.rules, CUSTOM)
	assert_true(box.rules_button(CUSTOM).is_picked())
	assert_false(box.rules_button(SKIRMISH).is_picked())
	assert_false(box.chips_visible())
	assert_true(box.rows_visible())
	var cap := LevelTable.shared().multiplier(LevelTable.CUSTOM)
	assert_eq(box.blurb_text(), "Stays out of the records; XP at most ×%s." % ArmoryFacts.multiplier_text(cap))
	assert_eq(_settings.custom_rules.to_dict(), CustomRules.new().to_dict(), "picking saves nothing and changes nothing")
	box.rules_button(SKIRMISH).pressed.emit()
	assert_eq(_picks.rules, SKIRMISH)
	assert_true(box.chips_visible())
	assert_false(box.rows_visible())


func test_the_rows_start_on_the_settings_and_carry_their_blurbs() -> void:
	_picks = MatchPicks.new()
	_picks.rules = CUSTOM
	_settings = Settings.new()
	_settings.custom_rules.team_size = 6
	_settings.custom_rules.wins_needed = 7
	_settings.custom_rules.round_time = 180.0
	_settings.custom_rules.friendly_fire = false
	_settings.custom_rules.ricochets_count = true
	var page := MatchPage.new(_picks, _settings)
	add_child_autofree(page)
	var box := page.rules_box()
	assert_true(box.rows_visible(), "a page built with Custom picked opens on it")
	assert_eq(box.team_size_choice().selected(), 5)
	assert_eq(box.wins_choice().selected(), 2)
	assert_eq(box.round_time_slider().value, 180.0)
	assert_eq(box.clock_text(), "3:00")
	assert_eq(box.friendly_fire_choice().selected(), 0)
	assert_eq(box.ricochets_choice().selected(), 1)
	assert_eq(box.row_blurbs(), PackedStringArray(["You and five bot teammates against six bots.",
			"A long match: first to 7 round wins.",
			"BBs pass your teammates by: only the other team can knock you out.",
			"A bounced BB still knocks out whoever it hits, as at fields that count ricochets."]))
	var words := PackedStringArray()
	for b in box.team_size_choice().find_children("*", "Button", true, false):
		if (b as Button).visible:
			words.append((b as Button).text)
	assert_eq(words, PackedStringArray(["5v5", "6v6", "7v7", "8v8"]), "Depot's sizes")


func test_the_rows_offer_the_browser_games_choices() -> void:
	var page := _page()
	var box := page.rules_box()
	assert_eq(box.wins_choice().get_child_count(), CustomRules.WINS_NEEDED.size())
	assert_eq(box.team_size_choice().get_child_count(), CustomRules.TEAM_SIZES.size())
	assert_eq(box.friendly_fire_choice().get_child_count(), 2)
	assert_eq(box.ricochets_choice().get_child_count(), 2)
	assert_eq(box.round_time_slider().min_value, 90.0)
	assert_eq(box.round_time_slider().max_value, 300.0)
	assert_eq(box.round_time_slider().step, 30.0)


# --- a change saves at once ---

func test_the_team_size_saves_into_the_settings_and_the_file() -> void:
	var page := _page()
	_custom(page)
	for size in page.rules_box().offered_sizes():
		var i := CustomRules.TEAM_SIZES.find(size)
		page.rules_box().team_size_choice().button(i).pressed.emit()
		assert_eq(_settings.custom_rules.team_size, CustomRules.TEAM_SIZES[i])
		assert_eq(_saved().team_size, CustomRules.TEAM_SIZES[i], "in the file as soon as it is picked")
		assert_false(_settings.dirty)
		assert_eq(page.rules_box().team_size_choice().selected(), i)


func test_first_to_saves_into_the_settings_and_the_file() -> void:
	var page := _page()
	_custom(page)
	for i in CustomRules.WINS_NEEDED.size():
		page.rules_box().wins_choice().button(i).pressed.emit()
		assert_eq(_settings.custom_rules.wins_needed, CustomRules.WINS_NEEDED[i])
		assert_eq(_saved().wins_needed, CustomRules.WINS_NEEDED[i])


func test_the_round_time_slider_saves_and_shows_its_clock() -> void:
	var page := _page()
	_custom(page)
	var slider := page.rules_box().round_time_slider()
	slider.value = 90.0
	assert_eq(_settings.custom_rules.round_time, 90.0)
	assert_eq(_saved().round_time, 90.0)
	assert_eq(page.rules_box().clock_text(), "1:30")
	slider.value = 300.0
	assert_eq(_saved().round_time, 300.0)
	assert_eq(page.rules_box().clock_text(), "5:00")
	slider.value = 200.0
	assert_eq(slider.value, 210.0, "the slider keeps to its half-minute steps")
	assert_eq(_saved().round_time, 210.0)
	assert_eq(page.rules_box().clock_text(), "3:30")


func test_friendly_fire_and_ricochets_save_into_the_settings_and_the_file() -> void:
	var page := _page()
	_custom(page)
	var box := page.rules_box()
	box.friendly_fire_choice().button(0).pressed.emit()
	assert_false(_settings.custom_rules.friendly_fire)
	assert_false(_saved().friendly_fire)
	box.friendly_fire_choice().button(1).pressed.emit()
	assert_true(_saved().friendly_fire)
	box.ricochets_choice().button(1).pressed.emit()
	assert_true(_settings.custom_rules.ricochets_count)
	assert_true(_saved().ricochets_count)
	assert_eq(box.row_blurbs()[3], "A bounced BB still knocks out whoever it hits, as at fields that count ricochets.")
	box.ricochets_choice().button(0).pressed.emit()
	assert_false(_saved().ricochets_count)
	assert_eq(box.row_blurbs()[3], "A BB that has bounced off a wall or the floor ticks you, but you're still in.")


func test_a_change_tells_the_settings_listeners_once() -> void:
	var page := _page()
	_custom(page)
	var heard := [0]
	_settings.changed.connect(func() -> void: heard[0] += 1)
	page.rules_box().wins_choice().button(3).pressed.emit()
	assert_eq(heard[0], 1)


# --- the summary line ---

func test_the_summary_line_adds_custom_and_its_team_size() -> void:
	var page := _page()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots")
	_custom(page)
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots · Custom 6v6")
	page.rules_box().team_size_choice().button(7).pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots · Custom 8v8")
	page.bot_button("hard").pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Hard bots · Custom 8v8")
	page.rules_box().rules_button(SKIRMISH).pressed.emit()
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Hard bots")


func test_the_summary_in_attack_defend_keeps_custom_last() -> void:
	assert_eq(MatchOptions.summary_rest(MatchOptions.MODE_ATTACK_DEFEND, 0, "hard", CustomRules.new()),
			"Attack / Defend · Alpha attacks first · Hard bots · Custom 3v3")


# --- what reads the round tuning follows Custom ---

func test_the_elimination_card_and_the_chips_follow_the_custom_switches() -> void:
	var page := _page()
	assert_eq(page.mode_blurb(MatchOptions.MODE_ELIMINATION), "Knock out the other team. First to 5 rounds.")
	_custom(page)
	page.rules_box().wins_choice().button(2).pressed.emit()
	assert_eq(page.mode_blurb(MatchOptions.MODE_ELIMINATION), "Knock out the other team. First to 7 rounds.")
	page.rules_box().team_size_choice().button(5).pressed.emit()
	page.rules_box().round_time_slider().value = 95.0
	page.rules_box().ricochets_choice().button(1).pressed.emit()
	page.rules_box().friendly_fire_choice().button(0).pressed.emit()
	assert_eq(page.chip_texts(), PackedStringArray(["6 v 6", "First to 7", "Rounds 1:30", "Ends swap after 6",
			"Ricochets Count", "Friendly fire Off"]))
	page.rules_box().rules_button(SKIRMISH).pressed.emit()
	assert_eq(page.mode_blurb(MatchOptions.MODE_ELIMINATION), "Knock out the other team. First to 5 rounds.")
	assert_eq(page.chip_texts()[0], "6 v 6", "back on Skirmish the page plays Depot's standard")
	assert_eq(SimTuning.load_default().rounds.wins_needed, 5, "and the loaded tuning was never written into")


func test_the_map_check_reads_the_custom_team_size() -> void:
	var page := _page()
	assert_eq(page.map_check_size(), 6)
	_custom(page)
	page.rules_box().team_size_choice().button(7).pressed.emit()
	assert_eq(page.map_check_size(), 8)
	assert_true(page.map_ids().has("depot"), "Depot holds an 8v8")
	assert_false(page.is_unloadable("depot"))
	page.rules_box().team_size_choice().button(4).pressed.emit()
	assert_eq(page.map_check_size(), 5)
	page.rules_box().rules_button(SKIRMISH).pressed.emit()
	assert_eq(page.map_check_size(), 6, "Skirmish checks for its own team size again")
	assert_eq(_picks.map_id, "depot")
	assert_false(page.play_button().disabled)


func test_a_page_built_with_custom_picked_reads_custom_from_the_start() -> void:
	_picks = MatchPicks.new()
	_picks.rules = CUSTOM
	_settings = Settings.new()
	_settings.custom_rules.team_size = 6
	_settings.custom_rules.wins_needed = 10
	var page := MatchPage.new(_picks, _settings)
	add_child_autofree(page)
	assert_eq(page.map_check_size(), 6)
	assert_eq(page.mode_blurb(MatchOptions.MODE_ELIMINATION), "Knock out the other team. First to 10 rounds.")
	assert_eq(page.summary_text(), "Depot · Elimination · Alpha · Normal bots · Custom 6v6")


# --- the words and the code behind them ---

func test_rule_sets_are_built_from_the_two_ids() -> void:
	assert_eq(MatchOptions.RULE_SETS, PackedStringArray([MatchOptions.RULES_SKIRMISH, MatchOptions.RULES_CUSTOM]))
	for rules in MatchOptions.RULE_SETS:
		assert_true(MatchOptions.RULES_NAME.has(rules))
		assert_true(MatchOptions.RULES_BLURB.has(rules))


func test_every_choice_has_its_blurb_in_en_po() -> void:
	var po := FileAccess.get_file_as_string("res://game/ui/text/en.po")
	for n in CustomRules.TEAM_SIZES:
		assert_true(po.contains("msgid \"RULE_TEAM_BLURB_%d\"" % n), "team size %d" % n)
	for n in CustomRules.WINS_NEEDED:
		assert_true(po.contains("msgid \"RULE_WINS_BLURB_%d\"" % n), "first to %d" % n)
	for row: String in ["FRIENDLY_FIRE", "RICOCHETS"]:
		for v in 2:
			assert_true(po.contains("msgid \"RULE_%s_BLURB_%d\"" % [row, v]), "%s %d" % [row, v])


func test_copy_is_a_snapshot_of_the_switches() -> void:
	var c := CustomRules.new()
	c.team_size = 2
	c.wins_needed = 10
	c.round_time = 270.0
	c.friendly_fire = false
	c.ricochets_count = true
	var snap := c.copy()
	assert_ne(snap, c)
	assert_eq(snap.to_dict(), c.to_dict())
	c.team_size = 1
	assert_eq(snap.team_size, 2, "a later change doesn't reach the snapshot")


# --- the match gets a copy ---

func test_main_hands_a_match_a_copy_of_the_custom_switches() -> void:
	var shared := Settings.shared()
	var before := shared.custom_rules.to_dict()
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.rules = CUSTOM
	shared.custom_rules.team_size = 2
	shared.custom_rules.wins_needed = 3
	main._start_play()
	await wait_process_frames(2)
	var handed: CustomRules = main._play.custom_rules
	assert_not_null(handed)
	assert_ne(handed, shared.custom_rules, "not the live object")
	assert_eq(handed.to_dict(), shared.custom_rules.to_dict())
	shared.custom_rules.team_size = 1
	assert_eq(handed.team_size, 2, "changing the settings mid-match leaves the match's rules alone")
	shared.custom_rules.from_dict(before)
	main._end_play()
	await wait_process_frames(2)


func test_main_hands_a_skirmish_match_no_custom_rules() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._start_play()
	await wait_process_frames(2)
	assert_null(main._play.custom_rules)
	main._end_play()
	await wait_process_frames(2)
