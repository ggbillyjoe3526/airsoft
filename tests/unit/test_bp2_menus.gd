extends GutTest
## BP2 menus and saves: the crash screen's note lets Tab move on (game/ui/crash_screen.gd); the XP card names the level
## its multiplier came from (game/ui/xp_card.gd, MatchXp); a newer build's loadouts or settings file is never written
## over, and Settings keeps keys it doesn't know (game/loadout/saved_loadouts.gd, game/save/settings.gd); a levels.md
## with no readable level 0 unlocks nothing into the save (game/progress/progress.gd); a load message goes once a save
## wrote a good file (Settings, Progress, Records, the Settings screen); the en.po keys nothing uses are gone; a rename
## open when the Loadout page goes is kept (game/ui/loadout_page.gd); the data guides point at Godot; the menus and play
## draw at the same scale at 4K (MenuScale).

const ROOT := "user://test-bp2-menus"
const LOGS := "user://test-bp2-menus/logs"
const LOADOUTS := "user://test-bp2-menus/loadouts.save"
const SETTINGS := "user://test-bp2-menus/settings.save"
const PROGRESS := "user://test-bp2-menus/progress.save"
const PO := "res://game/ui/text/en.po"
const UNUSED_KEYS: Array[String] = [
	"GRAPHICS_CUSTOM_NONE", "GRAPHICS_CUSTOM_ONE", "GRAPHICS_CUSTOM_MANY", "SETTINGS_UNLIMITED", "PLAY_CLICK",
]
## A process id nothing runs as.
const GONE := 999999
const STARTED := 1792765160


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(LOGS)


func after_each() -> void:
	await wait_process_frames(2)
	for dir: String in [LOGS, ROOT]:
		for f: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))


func after_all() -> void:
	DirAccess.remove_absolute(LOGS)
	DirAccess.remove_absolute(ROOT)


func _tab() -> InputEventKey:
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	return tab


# --- 1. The crash screen's note ---

func _crash_screen() -> CrashScreen:
	var r := RunRecord.new()
	r.start("0.1 Dev 3", STARTED, GONE)
	r.play(48213, "depot", "elimination", {}, 0, "normal", "normal", [3, 3] as Array[int])
	var tail := LogTail.new()
	tail.dir = LOGS
	var scrub := ReportScrub.new("/save/folder", "/home/tester", "tester", "testbox", ReportConfig.new())
	var screen := CrashScreen.new(r.to_dict(), tail, Settings.new(), ReportConfig.new(), scrub)
	screen.open_url = func(_url: String) -> int: return OK
	screen.copy_text = func(_text: String) -> void: pass
	screen.log_dir = LOGS
	add_child_autofree(screen)
	return screen


func test_tab_from_a_crash_note_with_words_moves_on_and_types_no_tab() -> void:
	var screen := _crash_screen()
	await wait_process_frames(1)
	var note := screen.note_box()
	assert_false(note.tab_input_mode)
	note.text = "It froze"
	note.text_changed.emit()
	assert_true(note.has_focus())
	get_viewport().push_input(_tab())
	assert_true(screen.report_button().has_focus(), "Tab goes on to Report a Bug")
	assert_eq(note.text, "It froze", "and types no tab into the note")


func test_the_crash_screen_s_tab_ring_goes_round() -> void:
	var screen := _crash_screen()
	var report := screen.find_child("Report", true, false) as Control
	assert_eq(screen.continue_button().find_next_valid_focus(), report)
	assert_eq(report.find_next_valid_focus(), screen.seed_button(), "on to Copy beside the seed in a match")
	assert_eq(screen.seed_button().find_next_valid_focus(), screen.note_box(), "and round to the note")
	assert_eq(screen.note_box().find_prev_valid_focus(), screen.seed_button(), "Shift+Tab goes round")
	assert_not_null(report.get_theme_stylebox("focus"), "the report lights when it has the focus")


# --- 2. The XP card's multiplier line ---

func _settled(table: LevelTable, opponents: StringName, mates: StringName, custom: bool) -> PlayerTally.Settled:
	var o := MatchXp.Outcome.new()
	o.won = true
	o.rounds_won = 5
	o.difficulty = opponents
	o.teammate_difficulty = mates
	o.custom = custom
	var s := PlayerTally.Settled.new()
	s.earned = MatchXp.earned(table, o)
	return s


func _card_words(table: LevelTable, opponents: StringName, mates: StringName, custom: bool) -> PackedStringArray:
	var card := XpCard.new(_settled(table, opponents, mates, custom), Progress.new(table), Pool.shared())
	add_child_autofree(card)
	var out := PackedStringArray()
	for l in card.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func test_the_xp_card_names_the_level_its_multiplier_came_from() -> void:
	var table := LevelTable.shared()
	var words := _card_words(table, &"hard", &"easy", false)
	assert_true(words.has("Easy teammates"), "Hard bots with Easy teammates pay Easy's: %s" % str(words))
	assert_false(words.has("Hard bots"))
	assert_true(words.has("× 0.5"))
	words = _card_words(table, &"easy", &"hard", false)
	assert_true(words.has("Easy bots"), str(words))
	words = _card_words(table, &"hard", &"hard", false)
	assert_true(words.has("Hard bots"), "a tie names the opponents")
	words = _card_words(table, &"normal", &"", false)
	assert_true(words.has("Normal bots"), "no teammates: the opponents")


func test_a_custom_cap_below_the_bots_says_custom_rules() -> void:
	var table := LevelTable.read_file(Pool.shared())
	table.multipliers[LevelTable.CUSTOM] = 0.25
	assert_eq(MatchXp.multiplier_from(table, &"hard", &"normal", true), MatchXp.FROM_CUSTOM)
	assert_eq(MatchXp.multiplier_from(table, &"hard", &"normal", false), MatchXp.FROM_TEAMMATES)
	var e := _settled(table, &"hard", &"normal", true).earned
	assert_eq(e.multiplier_level, LevelTable.CUSTOM)
	assert_true(_card_words(table, &"hard", &"normal", true).has("Custom rules"))


# --- 3 and 4. Newer files and unknown keys ---

func test_a_newer_loadouts_file_is_never_written_over() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	assert_true(SaveFile.write(LOADOUTS, SavedLoadouts.KIND, SavedLoadouts.VERSION + 1, {"future": true}))
	saved.load_file(LOADOUTS)
	assert_ne(saved.load_message, "")
	saved.rename(saved.current, "Edited")
	assert_false(saved.save(LOADOUTS), "the save is refused")
	saved.save_if_dirty(LOADOUTS)
	var r := SaveFile.read(LOADOUTS, SavedLoadouts.KIND)
	assert_eq(int(r.version), SavedLoadouts.VERSION + 1, "the newer build's file is as it was")
	assert_true((r.data as Dictionary).has("future"))
	SaveFile.remove(LOADOUTS)
	saved.load_file(LOADOUTS)
	assert_true(saved.save(LOADOUTS), "a later file of this build's saves again")


func test_a_newer_settings_file_is_never_written_over() -> void:
	var s := Settings.new(PlayTuning.new())
	assert_true(SaveFile.write(SETTINGS, Settings.KIND, Settings.VERSION + 1, {"fov": 80.0}))
	s.load_file(SETTINGS)
	assert_ne(s.load_message, "")
	s.fov = 100.0
	s.mark_changed()
	assert_false(s.save(SETTINGS))
	s.save_if_dirty(SETTINGS)
	var r := SaveFile.read(SETTINGS, Settings.KIND)
	assert_eq(int(r.version), Settings.VERSION + 1)
	assert_eq(float((r.data as Dictionary)["fov"]), 80.0)
	assert_ne(s.load_message, "", "still said: the changes don't save")


func test_settings_keep_keys_they_do_not_know_and_drop_the_retired_ones() -> void:
	assert_true(SaveFile.write(SETTINGS, Settings.KIND, Settings.VERSION,
			{"fov": 100.0, "future_thing": 7, "future_box": {"a": "b"}, "dev_enabled": false, "robots": true}))
	var s := Settings.new(PlayTuning.new())
	s.load_file(SETTINGS)
	assert_eq(s.fov, 100.0)
	assert_true(s.save(SETTINGS))
	var data: Dictionary = SaveFile.read(SETTINGS, Settings.KIND).data
	assert_eq(int(data["future_thing"]), 7, "an unknown key is written back as it was")
	assert_eq(data["future_box"], {"a": "b"})
	assert_false(data.has("dev_enabled"), "a key read once is not written back")
	assert_false(data.has("robots"))
	assert_eq(float(data["fov"]), 100.0)
	var known := s.to_dict()
	for k: String in Settings.new(PlayTuning.new()).to_dict():
		assert_true(Settings.KNOWN_KEYS.has(k), "%s is a known key" % k)
	known.erase("future_thing")
	known.erase("future_box")
	for k: String in known:
		assert_true(Settings.KNOWN_KEYS.has(k), "%s is a known key" % k)


# --- 5. No readable level 0 ---

func test_a_levels_md_with_no_level_0_unlocks_everything_for_the_session_only() -> void:
	var table := LevelTable.parse("", Pool.shared())
	assert_true(table.everything_unlocked)
	assert_false(LevelTable.shared().everything_unlocked, "the shipped file reads")
	var p := Progress.new(table)
	assert_eq(p.from_dict({"xp": 1200, "unlocked": ["000002"]}), [] as Array[String])
	assert_eq(p.grant_reached(), PackedStringArray(), "nothing granted")
	assert_false(p.dirty)
	for it: Pool.Item in Pool.shared().replicas + Pool.shared().powers + Pool.shared().parts:
		assert_true(p.has(it.id), "%s usable this session" % it.id)
	p.remember_picks("depot", 0)
	assert_true(p.save(PROGRESS))
	var data: Dictionary = SaveFile.read(PROGRESS, Progress.KIND).data
	assert_eq(data["unlocked"], ["000002"], "the player's own list, as it was")
	assert_eq(int(data["xp"]), 1200, "and the XP")
	p.reset()
	assert_eq(p.unlocked, PackedStringArray(), "a reset saves no stand-in either")


# --- 6. A load message goes once a good file is written ---

func test_a_load_message_goes_once_a_save_writes_a_good_file() -> void:
	var s := Settings.new(PlayTuning.new())
	s.load_message = tr("SETTINGS_DAMAGED")
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = SETTINGS
	add_child_autofree(screen)
	screen.open()
	assert_true(screen._load_message.visible, "said when Settings opens")
	screen.close()
	screen.open()
	assert_true(screen._load_message.visible, "and again while nothing was saved")
	screen.close()
	assert_true(s.save(SETTINGS))
	screen.open()
	assert_false(screen._load_message.visible, "gone once a good file is written")
	var p := Progress.new(LevelTable.shared())
	p.load_message = tr("PROGRESS_DAMAGED")
	assert_true(p.save(PROGRESS))
	assert_eq(p.load_message, "")
	var kept := Records.new()
	kept.load_message = "damaged"
	assert_true(kept.save(ROOT.path_join("records.save")))
	assert_eq(kept.load_message, "")


# --- 7. Unused keys ---

func test_the_unused_keys_are_gone_and_the_new_ones_are_there() -> void:
	var po := FileAccess.get_file_as_string(PO)
	for k: String in UNUSED_KEYS:
		assert_false(po.contains("msgid \"%s\"" % k), k)
	for k: String in ["XP_LINE_DIFFICULTY_MATES", "XP_LINE_CUSTOM"]:
		assert_ne(tr(k), k, k)


# --- 8. A rename open when the Loadout page goes ---

func test_a_rename_open_when_the_page_is_freed_is_kept_and_saved() -> void:
	for in_tree: bool in [true, false]:
		var saved := SavedLoadouts.new(LoadoutRules.standard())
		var page := LoadoutPage.new(saved, Settings.new())
		page.save_path = LOADOUTS
		page.settings_path = SETTINGS
		add_child(page)
		page.strip().start_rename()
		page.strip().edit().text = "Typed Then Quit"
		if not in_tree:
			remove_child(page)
		page.free()
		assert_eq(saved.carried().name, "Typed Then Quit", "kept (in the tree: %s)" % in_tree)
		var again := SavedLoadouts.new(LoadoutRules.standard())
		again.load_file(LOADOUTS)
		assert_eq(again.carried().name, "Typed Then Quit", "and saved")
		SaveFile.remove(LOADOUTS)


func test_the_window_closing_mid_rename_keeps_the_name() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	var page := LoadoutPage.new(saved, Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	page.strip().start_rename()
	page.strip().edit().text = "Closed"
	page.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(saved.carried().name, "Closed")
	assert_eq(page.strip().mode, LoadoutStrip.Mode.NORMAL)
	assert_false(saved.dirty, "saved")


# --- 9. The data guides ---

func test_the_data_guides_point_at_godot() -> void:
	for path: String in ["res://data/stats.md", "res://data/pool.md"]:
		var text := FileAccess.get_file_as_string(path)
		for stale: String in ["npm run", "src/", "browser console"]:
			assert_false(text.contains(stale), "%s: %s" % [path, stale])
		assert_true(text.contains("tools/unit_tests.sh"), path)


# --- 10. The menu scale at 4K ---

func test_the_menus_and_play_draw_at_one_scale_at_4k() -> void:
	var uhd := Vector2(3840.0, 2160.0)
	assert_eq(MenuScale.scale_for(uhd), 2.0)
	assert_eq(MenuScale.content_factor(uhd), 1.0, "the plain stretch: the pause menu's settings draw as the menus'")
