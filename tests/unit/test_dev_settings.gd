extends GutTest
## The Dev tab (game/save/dev_settings.gd, the settings screen's Dev tab) and the maps' public and dev tags
## (game/map/map_catalog.gd, data/maps.md): saved and read back, always there and applied whenever set (FB3), an old
## save with the Dev settings box unticked reset once, Reset the save, End the round now only from a match, and dev
## maps listed only with Dev content on.

const ROOT := "user://test-dev-settings"

var dir := ""
var path := ""
var _n := 0
var s: Settings = null


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	path = dir.path_join("settings.save")
	s = Settings.new(PlayTuning.new())


func after_each() -> void:
	InputMap.load_from_project_settings()
	SettingsApply.apply_audio(Settings.new(PlayTuning.new()))


func after_all() -> void:
	_wipe(ROOT)


func _wipe(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p):
		return
	for d: String in DirAccess.get_directories_at(p):
		_wipe(p.path_join(d))
	for f: String in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)


func _screen(end_round: Callable = Callable()) -> SettingsScreen:
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = path
	screen.end_round = end_round
	add_child_autofree(screen)
	screen.open()
	return screen


func _dev_tab(screen: SettingsScreen) -> int:
	return screen._dev_page.get_parent().get_index()


func test_the_dev_settings_are_saved_and_read_back() -> void:
	s.dev.game_speed = 0.5
	s.dev.ghost = true
	s.dev.retro_pixels = true
	s.dev.dev_content = true
	assert_true(s.save(path))
	var again := Settings.new(PlayTuning.new())
	again.load_file(path)
	assert_eq(again.dev.game_speed, 0.5)
	assert_true(again.dev.ghost)
	assert_true(again.dev.retro_pixels)
	assert_true(again.dev.dev_content)
	assert_false(again.dev.bottomless)


func test_a_bad_dev_value_keeps_its_default_alone() -> void:
	var d := DevSettings.new()
	d.from_dict({"game_speed": 7.0, "ghost": "yes", "bottomless": true})
	assert_eq(d.game_speed, 1.0, "out of range")
	assert_false(d.ghost, "not a switch")
	assert_true(d.bottomless)
	d.from_dict({"game_speed": 0.6})
	assert_eq(d.game_speed, 0.5, "held to its 25 % steps")


## FB3: no box any more. Every switch is off for a new player and applies as soon as it is set, and the file no
## longer writes the box.
func test_the_dev_settings_start_off_and_apply_whenever_set() -> void:
	var fresh := Settings.new(PlayTuning.new())
	assert_eq(fresh.dev.to_dict(), DevSettings.new().to_dict(), "every switch at its default")
	assert_false(fresh.dev.cheats().any(), "a new player plays on the record")
	assert_false(fresh.dev.dev_content)
	s.dev.ghost = true
	assert_true(s.dev.cheats().ghost, "on as soon as set")
	assert_false(s.to_dict().has("dev_enabled"), "the box is gone from the file")


## FB3: a save from when the box ruled, with it unticked: its switches never applied, so they go back to off once at
## load and no stale cheat suddenly applies. With it ticked they carry on; saved again, the box key is gone and the
## switches set since stay.
func test_an_old_save_with_the_box_unticked_has_its_switches_reset_once() -> void:
	var stale := DevSettings.new()
	stale.ghost = true
	stale.bottomless = true
	stale.game_speed = 2.0
	stale.robots = true
	stale.dev_content = true
	stale.time_of_day = LightingConfig.NIGHT
	var old := Settings.new(PlayTuning.new()).to_dict()
	old["dev"] = stale.to_dict()
	old["dev_enabled"] = false
	assert_true(SaveFile.write(path, Settings.KIND, Settings.VERSION, old))
	var loaded := Settings.new(PlayTuning.new())
	loaded.load_file(path)
	assert_eq(loaded.load_message, "", "no complaint")
	assert_eq(loaded.dev.to_dict(), DevSettings.new().to_dict(), "every switch off")
	assert_false(loaded.dev.cheats().any(), "no stale cheat applies")
	loaded.dev.bot_intent = true
	assert_true(loaded.save(path))
	var again := Settings.new(PlayTuning.new())
	again.load_file(path)
	assert_true(again.dev.bot_intent, "a switch set after the reset survives the next load")
	assert_false(again.dev.ghost)
	old["dev_enabled"] = true
	assert_true(SaveFile.write(path, Settings.KIND, Settings.VERSION, old))
	var ticked := Settings.new(PlayTuning.new())
	ticked.load_file(path)
	assert_eq(ticked.dev.to_dict(), stale.to_dict(), "the box was ticked: the switches carry on")


func test_spectate_and_bot_intentions_keep_a_match_off_the_record_but_retro_does_not() -> void:
	var d := DevSettings.new()
	d.retro_pixels = true
	d.dev_content = true
	assert_false(d.cheats().any(), "a look and a list: no cheat")
	d.spectate_bots = true
	assert_true(d.cheats().any())
	d.spectate_bots = false
	d.bot_intent = true
	assert_true(d.cheats().any())


func test_reset_the_save_starts_again_as_a_new_player() -> void:
	s.sensitivity = 2.5
	s.dev.ghost = true
	s.bindings.rebind(&"jump", KEY_J)
	assert_true(s.save(path))
	s.reset_save(path)
	assert_false(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(path + ".bak"))
	assert_eq(s.sensitivity, 1.0)
	assert_false(s.dev.ghost)
	assert_eq(s.bindings.codes(&"jump"), KeyBindings.new().codes(&"jump"))
	var again := Settings.new(PlayTuning.new())
	again.load_file(path)
	assert_eq(again.load_message, "", "no file: silent defaults")


func test_the_dev_tab_is_always_there_with_no_box_under_the_tabs() -> void:
	var screen := _screen()
	var tab := _dev_tab(screen)
	assert_false(screen._tabs.is_tab_hidden(tab), "shown for a new player")
	assert_eq(tab, screen._tabs.get_tab_count() - 1, "the last tab")
	screen._tabs.current_tab = tab
	assert_eq(screen._tabs.current_tab, tab, "and it opens")
	assert_eq(screen.find_children("*", "CheckButton", true, false).filter(
			func(n: Node) -> bool: return (n as CheckButton).text == "Dev settings").size(), 0, "no Dev settings box")
	assert_eq(tr("DEV_SETTINGS_BOX"), "DEV_SETTINGS_BOX", "its words are gone from en.po")


func test_the_dev_tab_writes_its_switches_and_game_speed() -> void:
	var screen := _screen()
	var heard := [0]
	s.changed.connect(func() -> void: heard[0] += 1)
	for field: StringName in SettingsScreen.DEV_SWITCHES:
		screen._dev_checks[field].button_pressed = true
		assert_true(s.dev.get(field) as bool, String(field))
	screen._speed.value = 150.0
	assert_eq(s.dev.game_speed, 1.5)
	assert_gt(heard[0], 0, "a match hears every change")
	screen.close()
	var again := Settings.new(PlayTuning.new())
	again.load_file(path)
	assert_eq(again.dev.game_speed, 1.5)
	assert_true(again.dev.bots_hold_fire)


## RB1: robots are a hidden Easter egg. Dev › Robots is off by default, a look and no cheat, saved and read back; the
## settings show robots only on the Dev tab, and the game's text names them only in its Dev rows.
func test_dev_robots_is_off_by_default_and_saved_as_the_other_switches() -> void:
	assert_false(s.dev.robots, "off by default")
	assert_true(SettingsScreen.DEV_SWITCHES.has(&"robots"), "a Dev tab switch")
	s.dev.robots = true
	assert_false(s.dev.cheats().any(), "a look: the match still counts")
	assert_true(s.save(path))
	var again := Settings.new(PlayTuning.new())
	again.load_file(path)
	assert_true(again.dev.robots)
	again.dev.robots = false
	assert_true(again.save(path))
	var off := Settings.new(PlayTuning.new())
	off.load_file(path)
	assert_false(off.dev.robots)


func test_the_dev_tab_s_robots_row_reads_and_writes_the_switch() -> void:
	var screen := _screen()
	var check: CheckButton = screen._dev_checks[&"robots"]
	assert_false(check.button_pressed, "off to begin with")
	assert_eq(tr("DEV_ROBOTS"), "ROBOTS")
	check.button_pressed = true
	assert_true(s.dev.robots)
	screen.close()
	var again := Settings.new(PlayTuning.new())
	again.load_file(path)
	assert_true(again.dev.robots, "saved")


func test_no_public_tab_or_text_names_robots() -> void:
	var screen := _screen()
	for i in screen._tabs.get_tab_count():
		var page := screen._tabs.get_tab_control(i)
		if page == screen._dev_page.get_parent():
			continue
		assert_false(screen._tabs.get_tab_title(i).to_lower().contains("robot"), "tab %d" % i)
		for label: Label in page.find_children("*", "Label", true, false):
			assert_false(label.text.to_lower().contains("robot"), "%s on tab %d" % [label.text, i])
	var po := FileAccess.get_file_as_string("res://game/ui/text/en.po")
	var key := ""
	for line: String in po.split("\n"):
		if line.begins_with("msgid "):
			key = line
		elif line.begins_with("msgstr ") and line.to_lower().contains("robot"):
			assert_true(key.begins_with("msgid \"DEV_"), "only Dev rows name robots: %s" % key)


func test_end_the_round_needs_a_match() -> void:
	var screen := _screen()
	assert_true(screen._end_round.disabled, "from the title screen")
	screen.queue_free()
	var asked := [0]
	var live := _screen(func() -> bool:
		asked[0] += 1
		return asked[0] == 1)
	assert_false(live._end_round.disabled)
	live._end_round.pressed.emit()
	assert_eq(live._note.text, tr("DEV_DONE"))
	live._end_round.pressed.emit()
	assert_eq(live._note.text, tr("DEV_NO_ROUND"), "between rounds")


## Dev › Reset the save went with SV2 (Settings › Save file's Delete and start over does it, with Undo); Reset level
## stays.
func test_the_dev_tab_has_reset_level_and_no_reset_the_save() -> void:
	var screen := _screen()
	var words := PackedStringArray()
	for n: Node in screen._dev_page.find_children("*", "Label", true, false):
		words.append((n as Label).text)
	assert_has(words, tr("DEV_RESET_LEVEL"))
	assert_does_not_have(words, "RESET THE SAVE")
	assert_eq(tr("DEV_RESET_SAVE"), "DEV_RESET_SAVE", "its words are gone from en.po")


func test_every_map_file_is_in_the_catalogue_with_a_tag() -> void:
	var cat := MapCatalog.read_file()
	assert_eq(cat.problems, [] as Array[String])
	for f: String in DirAccess.get_files_at(MapData.DIR):
		if f.ends_with(".json"):
			assert_not_null(cat.find(f.get_basename()), f)


func test_every_shipped_field_is_listed_without_dev_content_and_a_dev_one_only_with_it() -> void:
	var cat := MapCatalog.read_file()
	var ids := func(list: Array[MapCatalog.Entry]) -> PackedStringArray:
		var out := PackedStringArray()
		for e in list:
			out.append(e.id)
		return out
	assert_eq(ids.call(cat.fields(false)), PackedStringArray(["depot", "woodland", "street"]),
			"every map is public (2026-10-29), The Street too (ST1)")
	assert_eq(ids.call(cat.fields(true)), PackedStringArray(["depot", "woodland", "street"]))
	assert_false(cat.is_dev("depot"))
	assert_false(cat.is_dev("woodland"))
	assert_false(cat.is_dev("street"))
	assert_null(cat.find("neonHeights"), "Neon Heights is out of the game")
	assert_true(cat.is_dev("neonHeights"), "so, with no row, it counts as dev")
	assert_true(cat.is_dev("nowhere"), "a map with no row counts as dev")
	cat.find("woodland").tag = &"dev"
	assert_eq(ids.call(cat.fields(false)), PackedStringArray(["depot", "street"]), "a dev map only with Dev content")
	assert_eq(ids.call(cat.fields(true)), PackedStringArray(["depot", "woodland", "street"]))


func test_a_bad_catalogue_row_is_left_out_and_reported() -> void:
	var text := "## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Blurb |\n|---|---|---|---|---|---|---|---|\n" \
			+ "| a | A | field | public | 1 | 3 | 3 | x |\n| b | B | field | secret | 1 | 3 | 3 | x |\n" \
			+ "| c | C | arena | dev | 1 | 3 | 3 | x |\n| a | A again | field | dev | 1 | 3 | 3 | x |\n" \
			+ "| | D | field | dev | 1 | 3 | 3 | x |\n"
	var cat := MapCatalog.parse(text)
	assert_eq(cat.entries.size(), 1)
	assert_eq(cat.problems.size(), 4)
	assert_string_contains(cat.problems[0], "maps.md:6")
	assert_eq(MapCatalog.parse("no table here").problems.size(), 1)
	assert_eq(MapCatalog.read_file("res://nowhere.md").fields(false).size(), 1, "no file: Depot alone")
