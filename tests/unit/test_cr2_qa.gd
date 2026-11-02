extends GutTest
## QA hunt for CR2: the Rules section's keyboard, slider, odd saved values, switching back and forth, rebuilds and the
## copy a match is handed.

const SAVE := "user://test-cr2-qa.save"
const CUSTOM := MatchOptions.RULES_CUSTOM
const SKIRMISH := MatchOptions.RULES_SKIRMISH


func after_each() -> void:
	DirAccess.remove_absolute(SAVE)


func _page(picks: MatchPicks, settings: Settings) -> MatchPage:
	var page := MatchPage.new(picks, settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	return page


func test_switching_back_and_forth_leaves_skirmish_exactly_as_it_was() -> void:
	var picks := MatchPicks.new()
	var settings := Settings.new()
	var page := _page(picks, settings)
	var box := page.rules_box()
	var chips := page.chip_texts()
	var blurb := box.blurb_text()
	var elim := page.mode_blurb(MatchOptions.MODE_ELIMINATION)
	var summary := page.summary_text()
	var maps := page.map_check_size()
	box.rules_button(CUSTOM).pressed.emit()
	box.team_size_choice().button(5).pressed.emit()
	box.wins_choice().button(3).pressed.emit()
	box.friendly_fire_choice().button(0).pressed.emit()
	box.ricochets_choice().button(1).pressed.emit()
	box.round_time_slider().value = 300.0
	assert_eq(page.map_check_size(), 6)
	assert_ne(page.mode_blurb(MatchOptions.MODE_ELIMINATION), elim)
	box.rules_button(SKIRMISH).pressed.emit()
	assert_eq(page.chip_texts(), chips)
	assert_eq(box.blurb_text(), blurb)
	assert_eq(page.mode_blurb(MatchOptions.MODE_ELIMINATION), elim)
	assert_eq(page.summary_text(), summary)
	assert_eq(page.map_check_size(), maps)
	assert_ne(settings.custom_rules.to_dict(), CustomRules.new().to_dict(), "the Custom switches are kept")
	box.rules_button(CUSTOM).pressed.emit()
	assert_eq(box.team_size_choice().selected(), 5)
	assert_eq(box.wins_choice().selected(), 3)
	assert_eq(box.round_time_slider().value, 300.0)
	assert_eq(page.map_check_size(), 6)


func test_the_slider_keys_move_one_step_and_save_a_value_on_the_grid() -> void:
	var picks := MatchPicks.new()
	picks.rules = CUSTOM
	var settings := Settings.new()
	var page := _page(picks, settings)
	var slider := page.rules_box().round_time_slider()
	assert_eq(slider.value, 150.0)
	slider.value = 160.0
	assert_eq(slider.value, 150.0, "off-grid values snap")
	var seen: Array[float] = []
	for v: float in [90.0, 120.0, 180.0, 210.0, 240.0, 270.0, 300.0, 1000.0, -5.0]:
		slider.value = v
		seen.append(settings.custom_rules.round_time)
	assert_eq(seen, [90.0, 120.0, 180.0, 210.0, 240.0, 270.0, 300.0, 300.0, 90.0])
	for s: float in seen:
		assert_eq(fmod(s - 90.0, 30.0), 0.0)
	var back := Settings.new()
	back.load_file(SAVE)
	assert_eq(back.custom_rules.round_time, 90.0, "the last step reaches the file and loads back")


func test_odd_saved_custom_values_open_the_page_on_the_defaults() -> void:
	var odd := [{"team_size": 7, "wins_needed": 4, "round_time": 100.0, "friendly_fire": "yes", "ricochets_count": 3},
			{"team_size": 2.5, "wins_needed": -1, "round_time": NAN}, {"round_time": 1.0e9}, {}]
	for d: Dictionary in odd:
		var settings := Settings.new()
		settings.custom_rules.from_dict(d)
		var picks := MatchPicks.new()
		picks.rules = CUSTOM
		var page := _page(picks, settings)
		var box := page.rules_box()
		assert_gte(box.team_size_choice().selected(), 0, str(d))
		assert_gte(box.wins_choice().selected(), 0, str(d))
		assert_between(box.round_time_slider().value, 90.0, 300.0)
		assert_gte(box.friendly_fire_choice().selected(), 0)
		assert_gte(box.ricochets_choice().selected(), 0)
		assert_false(box.row_blurbs().has(""), "every row has its line")


func test_a_corrupt_settings_file_opens_the_custom_page() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{\"kind\":\"settings\",\"version\":1,\"data\":{\"custom_rules\":[1,2]}}")
	f.close()
	var settings := Settings.new()
	settings.load_file(SAVE)
	var picks := MatchPicks.new()
	picks.rules = CUSTOM
	var page := _page(picks, settings)
	assert_eq(page.rules_box().team_size_choice().selected(), CustomRules.TEAM_SIZES.find(6),
			"the default 3: Depot plays its standard 6v6")


func test_every_custom_team_size_leaves_the_depot_playable() -> void:
	var picks := MatchPicks.new()
	picks.rules = CUSTOM
	var settings := Settings.new()
	var page := _page(picks, settings)
	assert_eq(page.rules_box().offered_sizes(), [5, 6, 7, 8] as Array[int], "Depot's sizes")
	for n in page.rules_box().offered_sizes():
		page.rules_box().team_size_choice().button(CustomRules.TEAM_SIZES.find(n)).pressed.emit()
		assert_false(page.play_button().disabled)
		assert_eq(picks.map_id, "depot")
		assert_eq(page.map_check_size(), n)


func test_freeing_and_rebuilding_the_page_keeps_the_picks_and_leaks_nothing() -> void:
	var picks := MatchPicks.new()
	var settings := Settings.new()
	var page := MatchPage.new(picks, settings)
	page.rules_box().save_path = SAVE
	add_child(page)
	page.rules_box().rules_button(CUSTOM).pressed.emit()
	page.rules_box().team_size_choice().button(5).pressed.emit()
	remove_child(page)
	page.free()
	assert_false(settings.changed.get_connections().any(func(c: Dictionary) -> bool: return c.callable.get_object() == null),
			"no dead connection left on the settings")
	var again := _page(picks, settings)
	assert_true(again.rules_box().rows_visible())
	assert_eq(again.rules_box().team_size_choice().selected(), 5)
	assert_eq(again.summary_text(), "Depot · Elimination · Alpha · Normal bots · Custom 6v6")
	assert_eq(again.mode_blurb(MatchOptions.MODE_ELIMINATION), page_blurb(5))


func page_blurb(n: int) -> String:
	return tr(MatchOptions.MODE_BLURB[MatchOptions.MODE_ELIMINATION]) % n


func test_many_edits_do_not_grow_the_node_count() -> void:
	var picks := MatchPicks.new()
	picks.rules = CUSTOM
	var settings := Settings.new()
	var page := _page(picks, settings)
	var box := page.rules_box()
	box.wins_choice().button(0).pressed.emit()
	await wait_process_frames(2)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 40:
		box.wins_choice().button(i % 4).pressed.emit()
		box.round_time_slider().value = 90.0 + 30.0 * (i % 8)
		box.team_size_choice().button(i % 3).pressed.emit()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)


func test_resetting_the_save_while_the_page_lives_does_not_leave_stale_rows() -> void:
	var picks := MatchPicks.new()
	picks.rules = CUSTOM
	var settings := Settings.new()
	var page := _page(picks, settings)
	page.rules_box().team_size_choice().button(5).pressed.emit()
	settings.reset_save(SAVE)
	await wait_process_frames(2)
	var shown := page.rules_box().team_size_choice().selected()
	var depot := MapCatalog.shared().find("depot")
	var played := CustomRules.TEAM_SIZES.find(depot.team_size_for(settings.custom_rules.team_size))
	assert_eq(shown, played, "the rows show what a match would play")


func test_a_match_started_with_custom_ignores_later_edits_through_the_page() -> void:
	var picks := MatchPicks.new()
	picks.rules = CUSTOM
	var settings := Settings.new()
	var page := _page(picks, settings)
	var snap := picks.custom_rules(settings).copy()
	page.rules_box().wins_choice().button(0).pressed.emit()
	page.rules_box().round_time_slider().value = 90.0
	assert_eq(snap.wins_needed, 5)
	assert_eq(snap.round_time, 150.0)
	var tuned := snap.applied_to(SimTuning.load_default())
	assert_eq(tuned.rounds.wins_needed, 5)
	assert_eq(SimTuning.load_default().rounds.wins_needed, 5, "the shared tuning is untouched by applied_to")
