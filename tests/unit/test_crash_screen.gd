extends GutTest
## SV6: the crash screen (CrashScreen) and the entry scene showing it. A record with `previous` shows the screen before
## the title with its facts and the crash report; none shows the title at once; Continue, Report a Bug and quitting from
## it clear `previous`; Match is worded for a match, practice and the menus; the note's trim and count; Report, Copy and
## Open log folder through injected openers and clipboards; Dev › Crash the game now behind its confirm and Log a test
## error. Headless: never a real crash, a real browser or a real clipboard.

const ROOT := "user://test-sv6-crash"
const MAIN := preload("res://game/main.tscn")
const LOG_NAME := "godot2026-10-23T14.40.00.log"
## A process id nothing runs as (the record is checked through an injected `running`).
const GONE := 999999
## 2026-10-23 14:32:00 UTC, and that run's start 12:40 before.
const CLOSED := 1792765920
const STARTED := CLOSED - 760

var _logs := ROOT.path_join("logs")
var _run_path := ROOT.path_join("run.save")
var _guard_path := ROOT.path_join("guard.save")
var _renderer_path := ROOT.path_join("renderer.cfg")
var _settings_path := ROOT.path_join("settings.save")
var _shared_before: Dictionary = {}
var _opened: Array[String] = []
var _copied: Array[String] = []
var _open_answer: int = OK


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(_logs)
	_shared_before = Settings.shared().to_dict()
	_opened.clear()
	_copied.clear()
	_open_answer = OK


func after_each() -> void:
	var s := Settings.shared()
	s.from_dict(_shared_before)
	s.dirty = false
	for dir: String in [_logs, ROOT]:
		for f: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))


func after_all() -> void:
	DirAccess.remove_absolute(_logs)
	DirAccess.remove_absolute(ROOT)


func _open(url: String) -> int:
	_opened.append(url)
	return _open_answer


func _copy(text: String) -> void:
	_copied.append(text)


func _no(_id: int) -> bool:
	return false


## The crashed run's log: a few lines, an error, Godot's crash handler and its message.
func _write_log() -> void:
	var f := FileAccess.open(_logs.path_join(LOG_NAME), FileAccess.WRITE)
	for line: String in ["[boot] Airsoft 0.1 Dev 3 on Godot 4.7.2", "[play] round 4 live",
			"SCRIPT ERROR: Invalid access to key \"name\"", "   at: _add_row (res://game/ui/hud_feed.gd:88)",
			"================================================================", "CrashHandlerException: Program crashed",
			"Airsoft crashed. Start it again: it offers to report the bug."]:
		f.store_line(line)
	f.close()


func _tail() -> LogTail:
	var t := LogTail.new()
	t.dir = _logs
	return t


func _scrub() -> ReportScrub:
	return ReportScrub.new("/save/folder", "/home/tester", "tester", "testbox", ReportConfig.new())


## A run that crashed in a match on Depot, round 4 started at 2-1.
func _in_match() -> Dictionary:
	var r := RunRecord.new()
	r.start("0.1 Dev 3", STARTED, GONE)
	r.play(48213, "depot", "elimination", {}, 0, "normal", "normal", [3, 3] as Array[int])
	r.round_started(4, PackedInt32Array([2, 1]))
	return r.to_dict()


func _screen(previous: Dictionary) -> CrashScreen:
	var screen := CrashScreen.new(previous, _tail(), Settings.new(), ReportConfig.new(), _scrub())
	screen.open_url = _open
	screen.copy_text = _copy
	screen.log_dir = _logs
	add_child_autofree(screen)
	return screen


# --- The words ---

func test_when_says_today_yesterday_or_the_date_and_how_long_after_the_start() -> void:
	assert_eq(CrashScreen.when_text(CLOSED, STARTED, CLOSED + 600, 0), "Today about 14:32, 12:40 after it started")
	assert_eq(CrashScreen.when_text(CLOSED, STARTED, CLOSED + 86400, 0), "Yesterday about 14:32, 12:40 after it started")
	assert_eq(CrashScreen.when_text(CLOSED, 0, CLOSED + 3 * 86400, 0), "2026-10-23 about 14:32", "no start known")
	assert_eq(CrashScreen.when_text(CLOSED, STARTED, CLOSED + 600, 120), "Today about 16:32, 12:40 after it started",
			"local time, two hours east")
	assert_eq(CrashScreen.when_text(CLOSED, STARTED, CLOSED + 3600, -15 * 60),
			"Yesterday about 23:32, 12:40 after it started", "local midnight passed between the crash and now")
	assert_eq(CrashScreen.when_text(0, STARTED, CLOSED, 0), "Not known: that run's log wasn't found")


func test_match_is_worded_for_a_match_practice_and_the_menus() -> void:
	var catalog := MapCatalog.shared()
	assert_eq(CrashScreen.match_words(_in_match(), catalog), "Depot · Elimination · round 4, 2–1")
	var before := _in_match()
	before["round"] = 0
	assert_eq(CrashScreen.match_words(before, catalog), "Depot · Elimination", "before the first round")
	var r := RunRecord.new()
	r.start("0.1 Dev 3", STARTED, GONE)
	r.practise("range")
	assert_eq(CrashScreen.match_words(r.to_dict(), catalog), "Practice · %s" % catalog.find("range").display_name)
	assert_eq(CrashScreen.seed_text(r.to_dict()), "", "no seed in practice")
	r.to_menus()
	assert_eq(CrashScreen.match_words(r.to_dict(), catalog), "In the menus")
	assert_eq(CrashScreen.seed_text(r.to_dict()), "")
	assert_eq(CrashScreen.match_words({}, catalog), "In the menus", "an empty record")
	var no_mode := _in_match()
	(no_mode["match"] as Dictionary)["mode"] = ""
	assert_eq(CrashScreen.match_words(no_mode, catalog), "Depot · round 4, 2–1", "no mode, no empty part")
	assert_eq(CrashScreen.seed_text(_in_match()), "48213")


# --- The screen ---

func test_the_screen_shows_the_crash_s_facts_and_its_report_with_the_last_log_lines() -> void:
	_write_log()
	var screen := _screen(_in_match())
	var facts := screen.facts()
	var tail := _tail()
	var closed := FileAccess.get_modified_time(tail.path())
	assert_eq(facts[0], CrashScreen.when_text(closed, STARTED, int(Time.get_unix_time_from_system()),
			int(Time.get_time_zone_from_system().get("bias", 0))), "When: the old log's last write")
	assert_eq(facts[1], "0.1 Dev 3")
	assert_eq(facts[2], "Depot · Elimination · round 4, 2–1")
	assert_eq(facts[3], "48213")
	assert_not_null(screen.seed_button(), "the seed's COPY in a match")
	var report := screen.report_text()
	assert_true(report.begins_with(BugReport.CRASH_TITLE), report)
	assert_string_contains(report, "Seed: 48213")
	assert_string_contains(report, "Round: 4 had started, score 2–1")
	assert_string_contains(report, "Last log lines (last 7 of 7):")
	assert_string_contains(report, "Airsoft crashed. Start it again: it offers to report the bug.")
	assert_string_contains(report, "res://game/ui/hud_feed.gd:88 (_add_row)", "the old log's error")
	assert_eq(screen.report_button().text, "REPORT A BUG")
	assert_eq(screen.copy_button().text, "COPY REPORT")
	assert_eq(screen.logs_button().text, "OPEN LOG FOLDER")
	assert_eq(screen.continue_button().text, "CONTINUE")


func test_in_the_menus_without_a_log_the_seed_row_goes_and_when_is_not_known() -> void:
	var r := RunRecord.new()
	r.start("0.1 Dev 3", STARTED, GONE)
	var screen := _screen(r.to_dict())
	assert_eq(screen.facts()[0], "Not known: that run's log wasn't found")
	assert_eq(screen.facts()[2], "In the menus")
	assert_null(screen.seed_button())
	assert_string_contains(screen.report_text(), "Last log lines: -", "no log, no lines")


func test_the_note_is_held_to_its_length_counted_and_goes_in_the_report() -> void:
	var screen := _screen(_in_match())
	var config := ReportConfig.new()
	var note := screen.note_box()
	note.text = "Threw myself over the low wall"
	note.text_changed.emit()
	assert_string_contains(screen.report_text(), "Note: Threw myself over the low wall")
	assert_eq((screen.find_child("Note", true, false).get_parent().get_child(1) as Label).text,
			"30 / %d" % config.note_chars)
	note.text = "x".repeat(config.note_chars + 40)
	note.text_changed.emit()
	assert_eq(note.text.length(), config.note_chars, "trimmed in script")
	note.text = "  "
	note.text_changed.emit()
	assert_false(screen.report_text().contains("Note:"), "a blank note is none")


func test_report_opens_the_issue_once_and_copies_the_whole_report() -> void:
	_write_log()
	var screen := _screen(_in_match())
	watch_signals(screen)
	screen.note_box().text = "Crashed as round 4 started"
	screen.note_box().text_changed.emit()
	screen.report_button().pressed.emit()
	assert_eq(_opened.size(), 1)
	assert_eq(_copied.size(), 1)
	var info := ReportFacts.crash(_in_match(), _tail(), Settings.new(), "Crashed as round 4 started", ReportConfig.new(),
			_scrub())
	assert_eq(_opened[0], IssueLink.make(info, ReportConfig.new()).url, "IssueLink's address")
	assert_eq(_copied[0], screen.report_text())
	assert_string_contains(_copied[0], "Note: Crashed as round 4 started")
	assert_eq(screen.status_text(), "Opened GitHub in your browser. The whole report is copied too.")
	assert_signal_emitted(screen, "reported")
	assert_signal_not_emitted(screen, "continued")


func test_the_report_is_scrubbed() -> void:
	var f := FileAccess.open(_logs.path_join(LOG_NAME), FileAccess.WRITE)
	f.store_line("ERROR: Cannot open /home/tester/notes.txt on testbox")
	f.close()
	var screen := _screen(_in_match())
	assert_false(screen.report_text().contains("tester"), "the account name")
	assert_false(screen.report_text().contains("testbox"), "the machine's name")


func test_copy_report_copy_seed_and_open_log_folder() -> void:
	var screen := _screen(_in_match())
	screen.copy_button().pressed.emit()
	assert_eq(_copied, [screen.report_text()] as Array[String])
	assert_eq(screen.status_text(), "The report is copied.")
	screen.seed_button().pressed.emit()
	assert_eq(_copied[1], "48213")
	assert_eq(screen.status_text(), "The seed is copied.")
	screen.logs_button().pressed.emit()
	assert_eq(_opened, [ProjectSettings.globalize_path(_logs)] as Array[String])
	_open_answer = ERR_CANT_OPEN
	screen.logs_button().pressed.emit()
	assert_eq(screen.status_text(), "The log folder couldn't be opened.")
	assert_eq(_opened.size(), 2, "nothing else opened")


func test_continue_and_esc_continue() -> void:
	var screen := _screen(_in_match())
	watch_signals(screen)
	screen.continue_button().pressed.emit()
	assert_signal_emit_count(screen, "continued", 1)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	assert_signal_emit_count(screen, "continued", 2)
	assert_eq(_opened.size() + _copied.size(), 0, "Continue opens and copies nothing")


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	return k


## QA attempt 1's probes: Esc through real input, from the note box and from a button.
func test_esc_with_the_note_focused_reaches_continue_through_real_input() -> void:
	var screen := _screen(_in_match())
	await wait_process_frames(2)
	watch_signals(screen)
	assert_true(screen.note_box().has_focus(), "the note focused")
	get_viewport().push_input(_key(KEY_ESCAPE), false)
	await wait_process_frames(1)
	assert_signal_emit_count(screen, "continued", 1)


func test_esc_with_a_button_focused_reaches_continue() -> void:
	var screen := _screen(_in_match())
	await wait_process_frames(2)
	screen.continue_button().grab_focus()
	watch_signals(screen)
	get_viewport().push_input(_key(KEY_ESCAPE), false)
	await wait_process_frames(1)
	assert_signal_emit_count(screen, "continued", 1)


func test_esc_never_throws_a_typed_note_away() -> void:
	var screen := _screen(_in_match())
	await wait_process_frames(2)
	screen.note_box().text = "Threw myself over the low wall"
	screen.note_box().text_changed.emit()
	watch_signals(screen)
	get_viewport().push_input(_key(KEY_ESCAPE), false)
	await wait_process_frames(1)
	assert_signal_not_emitted(screen, "continued")
	assert_eq(screen.note_box().text, "Threw myself over the low wall")
	screen.continue_button().pressed.emit()
	assert_signal_emit_count(screen, "continued", 1, "Continue still leaves")


func test_a_report_that_could_not_open_the_browser_says_so_and_keeps_the_crash() -> void:
	var screen := _screen(_in_match())
	_open_answer = ERR_CANT_OPEN
	watch_signals(screen)
	screen.report_button().pressed.emit()
	assert_eq(_opened.size(), 1)
	assert_eq(_copied, [screen.report_text()] as Array[String], "copied, to paste elsewhere")
	assert_false(screen.status_text().begins_with("Opened GitHub"), "the browser did not open")
	assert_eq(screen.status_text(), tr("CRASH_REPORT_FAILED"))
	assert_signal_not_emitted(screen, "reported")


func test_the_note_s_line_goes_into_the_report_as_bug_report_writes_it() -> void:
	_write_log()
	var screen := _screen(_in_match())
	var note := "  Crashed  as /home/tester left\tthe range  "
	screen.note_box().text = note
	screen.note_box().text_changed.emit()
	var info := ReportFacts.crash(_in_match(), _tail(), Settings.new(), note.strip_edges(), ReportConfig.new(),
			_scrub())
	assert_eq(screen.report_text(), BugReport.write(info))
	assert_false(screen.report_text().contains("tester"), "the note scrubbed")


func test_a_screen_freed_leaves_nothing_behind() -> void:
	_write_log()
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var screen := CrashScreen.new(_in_match(), _tail(), Settings.new(), ReportConfig.new(), _scrub())
	add_child(screen)
	await wait_process_frames(1)
	screen.free()
	assert_lte(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), before)


# --- The entry scene ---

## The entry scene recording a headless run at the test's record, the safe start guarded at the test's own files, the
## crash screen's opener, clipboard and log folder the test's.
func _main() -> Node:
	var main := MAIN.instantiate()
	main.run_path = _run_path
	main.run_process_running = _no
	main.crash_open = _open
	main.crash_copy = _copy
	main.crash_log_dir = _logs
	var graphics: GraphicsStartUp = main.graphics
	graphics.guard_path = _guard_path
	graphics.renderer_path = _renderer_path
	graphics.settings_path = _settings_path
	graphics.restart = func() -> void: main.set_meta(&"restarted", true)
	return main


## A record left by a run that crashed in a match (`previous` at the next start).
func _left_crashed() -> void:
	var r := RunRecord.new()
	r.from_dict(_in_match())
	assert_true(r.save(_run_path))


func test_a_start_after_a_crash_shows_the_screen_before_the_menus() -> void:
	_left_crashed()
	_write_log()
	var main: Node = _main()
	add_child_autofree(main)
	await wait_process_frames(1)
	var screen: CrashScreen = main.crash_screen
	assert_not_null(screen)
	assert_true(screen.is_visible_in_tree())
	assert_false(main._menus.visible, "the menus wait")
	assert_null(main._menus.notice(), "the graphics notices wait too")
	assert_eq(screen.facts()[2], "Depot · Elimination · round 4, 2–1")
	assert_eq(screen.facts()[3], "48213")
	assert_true(RunRecord.load_file(_run_path).crashed_before(), "kept until it is seen")


func test_a_start_after_a_clean_quit_shows_the_menus_at_once() -> void:
	var r := RunRecord.new()
	r.start("0.1 Dev 3", STARTED, GONE)
	r.close()
	r.save(_run_path)
	var main: Node = _main()
	add_child_autofree(main)
	await wait_process_frames(1)
	assert_null(main.crash_screen)
	assert_true(main._menus.visible)
	assert_null(main.find_child("CrashScreen", true, false))


func test_continue_clears_the_crash_and_opens_the_menus_with_their_notices() -> void:
	_left_crashed()
	var s := Settings.shared()
	s.first_start_seen = false
	s.graphics_choice = Settings.GRAPHICS_AUTOMATIC
	s.graphics_forced = &""
	var main: Node = _main()
	var graphics: GraphicsStartUp = main.graphics
	graphics.headless_notices = true
	add_child_autofree(main)
	await wait_process_frames(1)
	var screen: CrashScreen = main.crash_screen
	assert_null(main._menus.notice())
	screen.continue_button().pressed.emit()
	await wait_process_frames(1)
	assert_null(main.crash_screen)
	assert_false(is_instance_valid(screen), "freed")
	assert_true(main._menus.visible)
	assert_not_null(main._menus.notice(), "the first start's notice, as on any start")
	assert_false(RunRecord.load_file(_run_path).crashed_before(), "shown once")
	assert_eq(RunRecord.load_file(_run_path).state, RunRecord.State.RUNNING, "the run goes on")


func test_report_clears_the_crash_and_the_screen_stays() -> void:
	_left_crashed()
	var main: Node = _main()
	add_child_autofree(main)
	await wait_process_frames(1)
	main.crash_screen.report_button().pressed.emit()
	assert_eq(_opened.size(), 1)
	assert_false(RunRecord.load_file(_run_path).crashed_before())
	assert_not_null(main.crash_screen, "Continue still to press")


func test_two_continues_in_one_frame_do_nothing_twice() -> void:
	_left_crashed()
	var main: Node = _main()
	add_child_autofree(main)
	await wait_process_frames(1)
	var screen: CrashScreen = main.crash_screen
	screen.continue_button().pressed.emit()
	screen.continue_button().pressed.emit()
	await wait_process_frames(1)
	assert_null(main.crash_screen)
	assert_true(main._menus.visible)


func test_a_failed_report_keeps_the_crash_for_the_next_start() -> void:
	_left_crashed()
	_open_answer = ERR_CANT_OPEN
	var main: Node = _main()
	add_child_autofree(main)
	await wait_process_frames(1)
	main.crash_screen.report_button().pressed.emit()
	assert_true(RunRecord.load_file(_run_path).crashed_before(), "nothing was reported")


func test_quitting_from_the_screen_clears_the_crash() -> void:
	_left_crashed()
	var main: Node = _main()
	add_child(main)
	await wait_process_frames(1)
	assert_not_null(main.crash_screen)
	main.free()
	var r := RunRecord.load_file(_run_path)
	assert_false(r.crashed_before())
	assert_eq(r.state, RunRecord.State.CLOSED, "a clean quit")


# --- Dev › Actions ---

func _settings_screen() -> SettingsScreen:
	var screen := SettingsScreen.new()
	screen.settings = Settings.new()
	screen.save_path = _settings_path
	add_child_autofree(screen)
	return screen


func test_crash_the_game_now_crashes_only_once_confirmed() -> void:
	var screen := _settings_screen()
	var crashes: Array[int] = [0]
	screen.crash_now = func() -> void: crashes[0] += 1
	var button := screen.find_child("CrashNow", true, false) as Button
	assert_not_null(button)
	button.pressed.emit()
	assert_eq(crashes[0], 0, "the confirm first")
	assert_true(screen._confirm_crash.visible)
	await wait_process_frames(1)
	assert_true(screen._confirm_crash.get_cancel_button().has_focus(), "Cancel focused, not Crash")
	screen._confirm_crash.canceled.emit()
	assert_eq(crashes[0], 0, "cancelled")
	screen._confirm_crash.confirmed.emit()
	assert_eq(crashes[0], 1)


func test_log_a_test_error_logs_one_error() -> void:
	var screen := _settings_screen()
	var button := screen.find_child("LogTestError", true, false) as Button
	assert_not_null(button)
	button.pressed.emit()
	assert_push_error(SettingsScreen.DEV_TEST_ERROR)
	var errors: Array[int] = [0]
	screen.log_test_error = func() -> void: errors[0] += 1
	button.pressed.emit()
	assert_eq(errors[0], 1, "the injected one")
