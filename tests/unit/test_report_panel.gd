extends GutTest
## Report a Bug's panel (SV5, game/ui/report_panel.gd; concept step22 `report-bug.png`) and the way in from Settings › About. The URL
## opener and the clipboard are always injected here: no test opens a browser or touches the real clipboard.

const MAIN := preload("res://game/main.tscn")
const NOTE := "Bot on Beta walked through the container door while it was shut"

var config: ReportConfig = null
var panel: ReportPanel = null
## Each address the opener was given, and each text put on the clipboard.
var opened: PackedStringArray = PackedStringArray()
var copied: PackedStringArray = PackedStringArray()
## What the opener answers.
var open_answer: int = OK


func before_each() -> void:
	# a copy: a test changing the limits must not change the game's cached config for the tests after it
	config = ReportConfig.load_default().duplicate() as ReportConfig
	opened = PackedStringArray()
	copied = PackedStringArray()
	open_answer = OK
	panel = ReportPanel.new()
	panel.config = config
	panel.opener = _open
	panel.clipboard = _copy
	add_child_autofree(panel)


func _open(url: String) -> int:
	opened.append(url)
	return open_answer


func _copy(text: String) -> void:
	copied.append(text)


## A live report as ReportFacts would gather it in a match, scrubbed for this machine.
func _info() -> BugReport.ReportInfo:
	var info := BugReport.ReportInfo.new()
	info.version = "0.1 Dev 3 (exported, release)"
	info.godot = "4.7.2.stable.official.ed1daf0bf"
	info.language = "en"
	info.seed_text = "48213"
	info.match_text = "Depot · Elimination · Standard rules · 3v3 · Normal"
	info.screen = "in play"
	info.dev_settings = "none"
	info.settings_changed = "fov 100"
	info.note_chars = config.note_chars
	info.errors = PackedStringArray(["SCRIPT ERROR res://game/ui/hud_feed.gd:88 (_add_row): Invalid access ×3"])
	info.events = PackedStringArray(["t11402 Beta 2 SHOT ×4 GBB Pistol", "t11455 You RELOAD_START AEG Rifle"])
	info.scrub = ReportScrub.for_this_machine(config)
	return info


func _labels(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _esc() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = &"ui_cancel"
	e.pressed = true
	return e


# --- the panel's words ---

func test_it_has_the_pictures_words_and_buttons() -> void:
	panel.open(_info())
	var words := _labels(panel)
	assert_true(words.has("REPORT A BUG"))
	assert_true(words.has("WHAT WENT WRONG?"))
	assert_true(words.has("YOUR NOTE"))
	assert_true(words.has("Optional · its first line is the issue's title"))
	assert_true(words.has("THE REPORT"))
	assert_true(words.has("Exactly what gets sent: no names, no file paths"))
	assert_eq(panel.report_button().text, "REPORT ON GITHUB")
	assert_eq(panel.copy_button().text, "COPY REPORT")
	assert_eq(panel.back_button().text, "BACK")
	var fine := ""
	for r in panel.find_children("*", "RichTextLabel", true, false):
		fine += (r as RichTextLabel).get_parsed_text()
	assert_string_contains(fine, "nothing is sent until you press Submit there")
	assert_string_contains(fine, "the issue is public")
	assert_eq(panel.status_text(), "", "no line before Report or Copy")


func test_the_report_beside_is_bug_reports_text_and_follows_the_note() -> void:
	var info := _info()
	panel.open(info)
	assert_eq(panel.report_text(), BugReport.write(info), "the whole report, no note yet")
	assert_false(panel.report_text().contains("Note:"))
	assert_eq(panel.count_text(), "0 / 500")
	panel.set_note(NOTE)
	assert_eq(panel.report_text(), BugReport.write(info), "rebuilt with the note")
	assert_string_contains(panel.report_text(), "Note: " + NOTE)
	assert_eq(panel.report_text().split("\n")[1], "Note: " + NOTE, "the note is the line after the title")
	assert_eq(panel.count_text(), "%d / 500" % NOTE.length())
	assert_true(panel.note_box().has_focus(), "the note box takes the typing")
	assert_false((panel.find_child("Report", true, false) as TextEdit).editable, "the report is read-only")


func test_typing_in_the_box_rebuilds_the_report() -> void:
	panel.open(_info())
	panel.note_box().text = "It froze"
	panel.note_box().text_changed.emit()
	assert_string_contains(panel.report_text(), "Note: It froze")
	assert_eq(panel.count_text(), "8 / 500")


func test_the_note_is_cut_to_its_length_in_script() -> void:
	panel.open(_info())
	panel.set_note("a".repeat(config.note_chars + 120))
	assert_eq(panel.note_text().length(), config.note_chars, "a long paste is cut to 500")
	assert_eq(panel.count_text(), "500 / 500")
	panel.set_note("b".repeat(config.note_chars))
	assert_eq(panel.note_text().length(), config.note_chars, "exactly 500 stays whole")
	panel.set_note("short")
	assert_eq(panel.note_text(), "short", "a short note is left as typed")


func test_typing_into_a_full_note_keeps_it_and_the_caret() -> void:
	panel.open(_info())
	var full := "a".repeat(config.note_chars)
	panel.set_note(full)
	panel.note_box().set_caret_line(0)
	panel.note_box().set_caret_column(10)
	panel.note_box().insert_text_at_caret("Z")
	await wait_process_frames(2)
	assert_eq(panel.note_text(), full, "the key past the length is lost, the last character kept")
	assert_eq(panel.note_box().get_caret_column(), 10, "the caret stays where it was")
	panel.set_note("b".repeat(config.note_chars - 2))
	panel.note_box().set_caret_column(5)
	panel.note_box().insert_text_at_caret("XYZW")
	await wait_process_frames(2)
	assert_eq(panel.note_text(), "b".repeat(5) + "XY" + "b".repeat(config.note_chars - 7),
			"a paste keeps what fits, at the caret")
	assert_eq(panel.note_box().get_caret_column(), 7)


func test_tab_from_the_note_moves_round_the_panel() -> void:
	panel.open(_info())
	panel.set_note("It froze")
	assert_true(panel.note_box().has_focus())
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab)
	assert_true(panel.report_button().has_focus(), "Tab goes on to Report on GitHub")
	assert_eq(panel.note_text(), "It froze", "and types no tab into the note")


func test_focus_stays_inside_the_panel_over_the_pause_menu() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.open()
	menu.report_button().pressed.emit()
	var over := menu.report_panel()
	var escaped: Array[String] = []
	for b: Control in [over.back_button(), over.report_button(), over.copy_button(), over.note_box(),
			over.find_child("Report", true, false) as Control]:
		for n: Control in [b.find_next_valid_focus(), b.find_prev_valid_focus(), b.find_valid_focus_neighbor(SIDE_RIGHT),
				b.find_valid_focus_neighbor(SIDE_BOTTOM), b.find_valid_focus_neighbor(SIDE_LEFT),
				b.find_valid_focus_neighbor(SIDE_TOP)]:
			if n != null and not over.is_ancestor_of(n):
				escaped.append("%s -> %s" % [b.name, n.name])
	assert_eq(escaped.size(), 0, "focus escapes: %s" % str(escaped))
	assert_eq(over.back_button().find_next_valid_focus(), over.find_child("Report", true, false))
	assert_eq(over.note_box().find_prev_valid_focus(), over.find_child("Report", true, false), "Shift+Tab goes round")


# --- Report and Copy ---

func test_report_opens_issue_links_address_once_and_copies_the_whole_report_once() -> void:
	var info := _info()
	panel.open(info)
	panel.set_note(NOTE)
	panel.report_button().pressed.emit()
	assert_eq(opened.size(), 1, "the opener once")
	assert_eq(opened[0], IssueLink.make(info, config).url, "IssueLink's address")
	assert_string_contains(opened[0], "https://github.com/ggbillyjoe3526/airsoft/issues/new?title=Bug%3A+Bot")
	assert_eq(copied.size(), 1, "the clipboard once")
	assert_eq(copied[0], BugReport.write(info), "the whole report, note and all")
	assert_eq(panel.status_text(), "✓ Opened GitHub in your browser. The whole report is copied too.")
	assert_true(panel.visible, "the panel stays open")


func test_a_cut_address_says_so_and_the_whole_report_is_still_copied() -> void:
	config.max_url_chars = 900
	var info := _info()
	for i in 30:
		info.events.append("t%d Beta 2 SHOT ×4 GBB Pistol" % (12000 + i))
	panel.open(info)
	panel.report_button().pressed.emit()
	assert_true(IssueLink.make(info, config).cut, "this address had to be cut")
	assert_eq(opened.size(), 1)
	assert_lte(opened[0].length(), 900)
	assert_eq(copied.size(), 1)
	assert_eq(copied[0], BugReport.write(info), "the whole report, uncut")
	assert_string_contains(panel.status_text(), "Part of the report didn't fit the link")


func test_a_browser_that_doesnt_open_says_so_and_the_report_is_copied() -> void:
	open_answer = FAILED
	panel.open(_info())
	panel.report_button().pressed.emit()
	assert_eq(copied.size(), 1)
	assert_string_contains(panel.status_text(), "Your browser didn't open")
	assert_false(panel.status_text().begins_with("✓"))


func test_copy_report_copies_and_opens_nothing() -> void:
	var info := _info()
	panel.open(info)
	panel.set_note(NOTE)
	panel.copy_button().pressed.emit()
	assert_eq(opened.size(), 0)
	assert_eq(copied, PackedStringArray([BugReport.write(info)]))
	assert_eq(panel.status_text(), "✓ The whole report is copied.")


func test_the_report_names_no_folder_or_account() -> void:
	var info := _info()
	info.scrub = ReportScrub.new("", "/home/zandra", "zandra", "zandra-laptop", config)
	info.errors = PackedStringArray(["ERROR /home/zandra/Airsoft/game.gd:1 (f): zandra's save"])
	panel.open(info)
	panel.set_note("Seen by zandra")
	panel.report_button().pressed.emit()
	for text: String in [panel.report_text(), copied[0], opened[0].uri_decode()]:
		assert_false(text.contains("zandra"), text)


# --- closing ---

func test_back_and_esc_close_it() -> void:
	panel.open(_info())
	watch_signals(panel)
	panel.back_button().pressed.emit()
	assert_false(panel.visible)
	assert_signal_emit_count(panel, "closed", 1)
	panel.open(_info())
	assert_eq(panel.status_text(), "", "a new open starts without the last line")
	assert_eq(panel.note_text(), "", "and with an empty note")
	get_viewport().push_input(_esc())
	assert_false(panel.visible, "Esc closes it")
	assert_signal_emit_count(panel, "closed", 2)


# --- Settings › About (UR1: the title screen is gone) ---

func _about(main: Node) -> Button:
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(1)
	main._settings_screen.show_about()
	return main._settings_screen.about_report_button()


func test_report_a_bug_from_about_opens_the_panel_and_back_frees_it() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var report: Button = await _about(main)
	assert_eq(report.text.to_lower(), "report a bug")
	report.pressed.emit()
	var opened_panel: ReportPanel = main.find_child("ReportPanel", true, false)
	assert_not_null(opened_panel, "the panel over the menus")
	assert_true(opened_panel.visible)
	assert_true(opened_panel.report_text().begins_with(BugReport.TITLE))
	assert_string_contains(opened_panel.report_text(), "Screen: menus")
	assert_string_contains(opened_panel.report_text(), "Version: " + Version.current())
	opened_panel.back_button().pressed.emit()
	await wait_process_frames(2)
	assert_null(main.find_child("ReportPanel", true, false), "freed once closed")
	assert_true(report.has_focus(), "the focus back on the button")


func test_opening_and_closing_it_from_about_leaves_no_nodes() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var report: Button = await _about(main)
	report.pressed.emit()
	(main.find_child("ReportPanel", true, false) as ReportPanel).close()
	await wait_process_frames(2)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 5:
		report.pressed.emit()
		(main.find_child("ReportPanel", true, false) as ReportPanel).close()
		await wait_process_frames(2)
	assert_lte(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)
	assert_lte(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)
