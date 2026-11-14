extends GutTest
## The second audit's fixes to the menus and reports (AUD2, group ui): the Match rules retune the page once a click and
## save a dragged round-time slider once, on release.

const SAVE := "user://test-aud2-ui.save"

var _heard: int = 0


func after_each() -> void:
	DirAccess.remove_absolute(SAVE)


func _count() -> void:
	_heard += 1


func _page(settings: Settings) -> MatchPage:
	var page := MatchPage.new(MatchPicks.new(), settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	return page


func _saved_time() -> float:
	var back := Settings.new()
	back.load_file(SAVE)
	return back.custom_rules.round_time


# --- row 133: one retune a click, one save a drag ---

func test_a_custom_click_tells_the_page_once() -> void:
	var settings := Settings.new()
	var page := _page(settings)
	var box := page.rules_box()
	box.changed.connect(_count)
	settings.changed.connect(_count)
	_heard = 0
	box.ricochets_choice().button(1).pressed.emit()
	assert_eq(_heard, 1, "the settings' change only: the box sends none of its own for a Custom switch")
	assert_true(settings.custom_rules.ricochets_count)


func test_a_rule_set_pick_still_sends_the_boxs_changed() -> void:
	var settings := Settings.new()
	var page := MatchPage.new(MatchPicks.new(), settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	page.rules_box().changed.connect(_count)
	_heard = 0
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	assert_eq(_heard, 1)


func test_a_dragged_round_time_is_saved_once_on_release() -> void:
	var settings := Settings.new()
	var page := _page(settings)
	var slider := page.rules_box().round_time_slider()
	slider.value = 120.0
	assert_eq(_saved_time(), 120.0, "a step with no drag (a key) saves at once")
	slider.drag_started.emit()
	slider.value = 180.0
	slider.value = 240.0
	assert_eq(settings.custom_rules.round_time, 240.0, "the settings follow the knob")
	assert_eq(page.rules_box().clock_text(), "4:00", "and the readout")
	assert_true(settings.dirty, "nothing written while the knob is held")
	assert_eq(_saved_time(), 120.0)
	slider.drag_ended.emit(true)
	assert_false(settings.dirty)
	assert_eq(_saved_time(), 240.0, "one write, on release")
	slider.value = 270.0
	assert_eq(_saved_time(), 270.0, "a step after the release saves again")


# --- row 28: a field's own flag raise is said on the Match page ---

func _note_page(map_id: String, mode: String) -> MatchPage:
	var picks := MatchPicks.new()
	picks.map_id = map_id
	picks.mode = mode
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	return page


func test_field_raise_is_the_fields_own_only_where_it_differs_in_attack_defend() -> void:
	var woodland := MapCatalog.shared().find("woodland")
	var depot := MapCatalog.shared().find("depot")
	assert_eq(MatchOptions.field_raise(MatchOptions.MODE_ATTACK_DEFEND, woodland, 7.0), 9.0)
	assert_eq(MatchOptions.field_raise(MatchOptions.MODE_ATTACK_DEFEND, depot, 7.0), 0.0, "Depot plays the game's")
	assert_eq(MatchOptions.field_raise("elimination", woodland, 7.0), 0.0, "no flag in Elimination")
	assert_eq(MatchOptions.field_raise(MatchOptions.MODE_ATTACK_DEFEND, null, 7.0), 0.0)
	assert_eq(MatchOptions.field_raise(MatchOptions.MODE_ATTACK_DEFEND, woodland, 9.0), 0.0, "nothing to say at the game's own")


func test_the_match_page_says_woodlands_nine_seconds() -> void:
	var page := _note_page("woodland", MatchOptions.MODE_ATTACK_DEFEND)
	assert_eq(page.rules_box().flag_note_text(), "The flag takes 9 s to raise on this field (7 s on the others).")
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	assert_ne(page.rules_box().flag_note_text(), "", "under Custom too: the raise is Woodland's in both")


func test_the_match_page_says_nothing_on_depot_or_in_other_modes() -> void:
	assert_eq(_note_page("depot", MatchOptions.MODE_ATTACK_DEFEND).rules_box().flag_note_text(), "")
	var page := _note_page("woodland", MatchOptions.MODE_ATTACK_DEFEND)
	page._pick_mode("elimination")
	assert_eq(page.rules_box().flag_note_text(), "", "a mode with no flag")
	page._pick_mode(MatchOptions.MODE_ATTACK_DEFEND)
	assert_ne(page.rules_box().flag_note_text(), "")


# --- row 110: a long address the system refuses is sent again short ---

var _asked: PackedStringArray = PackedStringArray()
var _refuse_over: int = 0


func _refusing(url: String) -> int:
	_asked.append(url)
	return FAILED if url.length() > _refuse_over else OK


func _long_info(config: ReportConfig) -> BugReport.ReportInfo:
	var info := BugReport.ReportInfo.new()
	info.version = "0.1 Dev 3 (exported, release)"
	info.note_chars = config.note_chars
	info.note = "Bot walked through a shut door"
	for i in 150:
		info.events.append("t%d Beta 2 SHOT x4 GBB Pistol" % (12000 + i))
	info.scrub = ReportScrub.for_this_machine(config)
	return info


func _report_panel(config: ReportConfig) -> ReportPanel:
	_asked = PackedStringArray()
	var panel := ReportPanel.new()
	panel.config = config
	panel.opener = _refusing
	panel.clipboard = func(_text: String) -> void: pass
	add_child_autofree(panel)
	panel.open(_long_info(config))
	return panel


func test_an_address_the_system_refuses_is_sent_again_at_the_short_length() -> void:
	var config := ReportConfig.load_default().duplicate() as ReportConfig
	_refuse_over = config.retry_url_chars
	var panel := _report_panel(config)
	panel.report_button().pressed.emit()
	assert_eq(_asked.size(), 2, "the long address, then the short one")
	assert_gt(_asked[0].length(), config.retry_url_chars, "the first was long")
	assert_lte(_asked[1].length(), config.retry_url_chars)
	assert_string_contains(panel.status_text(), "Part of the report didn't fit the link", "and says it was cut")
	assert_true(panel.status_text().begins_with("✓"))


func test_a_short_address_the_system_refuses_is_not_sent_twice() -> void:
	var config := ReportConfig.load_default().duplicate() as ReportConfig
	config.max_url_chars = config.retry_url_chars
	_refuse_over = 0
	var panel := _report_panel(config)
	panel.report_button().pressed.emit()
	assert_eq(_asked.size(), 1, "nothing shorter to try")
	assert_false(panel.status_text().begins_with("✓"))


# --- row 109: a seen crash is not shown again where the record cannot be written ---

const RUN_DIR := "user://test-aud2-ui-run"
const GONE := 999999


func _crashed_start(path: String) -> RunRecord:
	var first := RunRecord.new()
	first.start("0.1 Dev 3", 1000, GONE)
	assert_true(first.save(path))
	var second := RunRecord.load_file(path)
	second.start("0.1 Dev 3", 2000, OS.get_process_id())
	return second


func _clean_run_dir() -> void:
	for f: String in DirAccess.get_files_at(RUN_DIR):
		DirAccess.remove_absolute(RUN_DIR.path_join(f))


func test_a_crash_seen_where_the_record_cannot_be_written_is_marked_and_not_shown_again() -> void:
	DirAccess.make_dir_recursive_absolute(RUN_DIR)
	_clean_run_dir()
	var path := RUN_DIR.path_join("run.save")
	var run := _crashed_start(path)
	assert_true(run.crashed_before(), "the run before it never closed")
	SaveFile.hold(PackedStringArray([path]))
	assert_false(run.save(path), "this start can't write its record")
	assert_true(run.crash_seen(path), "the seen crash is marked beside the record instead")
	SaveFile.release(PackedStringArray([path]))
	var next := RunRecord.load_file(path)
	next.start("0.1 Dev 3", 3000, OS.get_process_id())
	assert_false(next.crashed_before(), "the next start shows no crash again")
	_clean_run_dir()
	DirAccess.remove_absolute(RUN_DIR)


func test_a_crash_seen_in_a_folder_that_takes_no_file_says_so() -> void:
	DirAccess.make_dir_recursive_absolute(RUN_DIR)
	_clean_run_dir()
	var path := RUN_DIR.path_join("run.save")
	var run := _crashed_start(path)
	var mark := RunRecord.closed_mark(path, GONE, 1000)
	SaveFile.hold(PackedStringArray([path, mark]))
	assert_false(run.crash_seen(path), "nothing can be written: false, for main to warn of it")
	SaveFile.release(PackedStringArray([path, mark]))
	assert_true(RunRecord.load_file(path).state == RunRecord.State.RUNNING, "the old record stands")
	_clean_run_dir()
	DirAccess.remove_absolute(RUN_DIR)


func test_a_crash_seen_with_a_writable_folder_is_written_as_before() -> void:
	DirAccess.make_dir_recursive_absolute(RUN_DIR)
	_clean_run_dir()
	var path := RUN_DIR.path_join("run.save")
	var run := _crashed_start(path)
	assert_true(run.crash_seen(path))
	var next := RunRecord.load_file(path)
	assert_true(next.state == RunRecord.State.RUNNING, "this run's own record, under way")
	assert_false(next.crashed_before(), "with no crash in it")
	_clean_run_dir()
	DirAccess.remove_absolute(RUN_DIR)
