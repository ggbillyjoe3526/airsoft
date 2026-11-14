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


## The bug hunt: a page hidden with the knob still held gets no release from the slider, so the drag's steps stayed
## unsaved and every later step, taken for part of the drag, was not saved either.
func test_a_drag_cut_short_by_the_page_hiding_is_saved_and_ended() -> void:
	var settings := Settings.new()
	var page := _page(settings)
	var slider := page.rules_box().round_time_slider()
	slider.drag_started.emit()
	slider.value = 210.0
	assert_true(settings.dirty, "held: not written yet")
	page.hide()
	assert_false(settings.dirty, "hidden mid-drag: written")
	assert_eq(_saved_time(), 210.0)
	page.show()
	slider.value = 150.0
	assert_eq(_saved_time(), 150.0, "and a step afterwards saves at once, the drag being over")


# --- row 29: the drawing dips, the control does not ---

func test_the_dip_transform_is_the_one_a_scale_about_the_middle_gives() -> void:
	var b := Button.new()
	add_child_autofree(b)
	b.position = Vector2(30.0, 50.0)
	b.size = Vector2(500.0, 120.0)
	for d: float in [0.95, 0.98, 0.9]:
		b.scale = Vector2.ONE
		b.pivot_offset_ratio = ButtonPress.PIVOT
		var base := b.get_transform()
		b.scale = Vector2.ONE * d
		var engine := b.get_transform()
		var ours := ButtonPress.dipped(base, b.size, d)
		assert_true(engine.is_equal_approx(ours), "dip %s: %s against %s" % [d, ours, engine])


func test_a_dipped_button_keeps_its_control_full_size_for_a_click() -> void:
	var b := Button.new()
	b.size = Vector2(500.0, 120.0)
	add_child_autofree(b)
	var ring := ButtonPress.new()
	b.add_child(ring, false, Node.INTERNAL_MODE_BACK)
	await wait_process_frames(2)
	var base := b.get_transform()
	ring.play()
	var low := 1.0
	for i: int in 10:
		await wait_process_frames(1)
		low = minf(low, ring.dip())
		assert_eq(b.get_transform(), base, "the control's transform is untouched at every frame")
	assert_lt(low, 1.0, "drawn smaller")
	assert_eq(b.scale, Vector2.ONE, "the control keeps its scale")
	var hit := b.get_global_transform().affine_inverse()
	assert_true(Rect2(Vector2.ZERO, b.size).has_point(hit * Vector2(1.0, 60.0)), "the outer pixel still takes the click")
	assert_true(Rect2(Vector2.ZERO, b.size).has_point(hit * Vector2(499.0, 60.0)))


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


# --- rows 111, 113: typing into the note box and the keyboard's way round the panel, driven with input events ---

func _type(view: Viewport, text: String) -> void:
	for ch in text:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = ch.unicode_at(0)
		e.keycode = e.unicode as Key
		view.push_input(e)
		var up := e.duplicate() as InputEventKey
		up.pressed = false
		view.push_input(up)


func test_typing_reaches_the_note_box_and_the_report_follows_it() -> void:
	var config := ReportConfig.load_default().duplicate() as ReportConfig
	var panel := _report_panel(config)
	await wait_process_frames(2)
	assert_true(panel.note_box().has_focus(), "the box is focused as the panel opens")
	_type(panel.get_viewport(), "Door stuck")
	assert_eq(panel.note_text(), "Door stuck", "typed keys land in the note")
	await wait_process_frames(2)
	assert_eq(panel.count_text(), "10 / %d" % config.note_chars)
	assert_string_contains(panel.report_text(), "Door stuck", "and in the report beside it")


func test_tab_walks_the_panel_in_reading_order_and_back_closes_it() -> void:
	var panel := _report_panel(ReportConfig.load_default().duplicate() as ReportConfig)
	await wait_process_frames(2)
	var order: Array[Control] = [panel.note_box(), panel.report_button(), panel.copy_button(), panel.back_button()]
	for i in order.size() - 1:
		var next := order[i].find_next_valid_focus()
		assert_eq(next, order[i + 1], "%s, then %s" % [order[i].name, order[i + 1].name])
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(esc)
	await wait_process_frames(2)
	assert_false(panel.visible, "Esc closes it")


## Every visible control `root` holds that can take the keyboard's focus.
func _focusables(root: Node, out: Array[Control]) -> void:
	for c in root.get_children():
		var control := c as Control
		if control != null and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL \
				and (not (control is BaseButton) or not (control as BaseButton).disabled):
			out.append(control)
		_focusables(c, out)


func test_the_keyboard_reaches_every_control_of_the_menus_pages_and_comes_back_round() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), Settings.new())
	add_child_autofree(menus)
	await wait_process_frames(2)
	for show: Callable in [menus.show_match, menus.show_loadout, menus.show_armory]:
		show.call()
		await wait_process_frames(2)
		var all: Array[Control] = []
		_focusables(menus, all)
		assert_gt(all.size(), 5, "the page has controls")
		var seen: Dictionary[Control, bool] = {}
		var at := all[0]
		for i in all.size() * 2:
			seen[at] = true
			var next := at.find_next_valid_focus()
			assert_not_null(next)
			at = next
		for c in all:
			assert_true(seen.has(c), "%s is reached by Tab" % c.get_path())
