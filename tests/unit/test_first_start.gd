extends GutTest
## GR5's first start (concept `first-run.png`): on the first menus with the automatic pick, a notice names the preset
## the card picked (Medium on integrated graphics, High on a dedicated card, never Ultra), the card and the screen, with
## OK or Graphics settings (Settings › Graphics); START works under it; it shows once (first_start_seen, saved) and
## never in the smoke run or a headless one. Headless; every file lives under user://test-first-start.

const ROOT := "user://test-first-start"
const MAIN := preload("res://game/main.tscn")

var _settings_path := ROOT.path_join("settings.save")
var _shared_before: Dictionary = {}
var _forced_before: StringName = &""
var _machine_before: GraphicsPick.Probe = null


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var s := Settings.shared()
	_shared_before = s.to_dict()
	_forced_before = s.graphics_forced
	_machine_before = GraphicsApply._machine
	s.choose_graphics(Settings.GRAPHICS_AUTOMATIC, &"high")
	s.graphics_forced = &""
	s.first_start_seen = false
	GraphicsApply._machine = _probe(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU)


func after_each() -> void:
	var s := Settings.shared()
	s.from_dict(_shared_before)
	s.graphics_forced = _forced_before
	s.dirty = false
	GraphicsApply._machine = _machine_before
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))


func after_all() -> void:
	DirAccess.remove_absolute(ROOT)


func _probe(kind: int) -> GraphicsPick.Probe:
	var p := GraphicsPick.Probe.new()
	p.adapter_type = kind
	p.adapter_name = "Test Card 3000"
	p.rendering_method = RendererOverride.FORWARD_PLUS
	p.driver = "vulkan"
	p.preset = GraphicsPick.pick(kind, p.rendering_method)
	return p


func _main() -> Node:
	var main := MAIN.instantiate()
	var graphics: GraphicsStartUp = main.graphics
	graphics.settings_path = _settings_path
	graphics.headless_notices = true
	return main


func _words(notice: GraphicsNotice) -> PackedStringArray:
	return notice.words()


# --- The notice ---

func test_the_notice_names_the_pick_the_card_and_the_screen() -> void:
	var n := GraphicsNotice.first_start(&"high", "Test Card 3000 · dedicated",
			GraphicsNotice.screen_words(Vector2i(2560, 1440), 144.0, Settings.WindowMode.BORDERLESS))
	add_child_autofree(n)
	assert_eq(_words(n), PackedStringArray(["FIRST START", "GRAPHICS SET TO HIGH",
			"Picked for your graphics card. If the game stutters in a match it steps down a preset between rounds by"
			+ " itself, until you pick one.", "Graphics card", "Test Card 3000 · dedicated", "Screen",
			"2560 × 1440 · 144 Hz · borderless fullscreen", "OK", "GRAPHICS SETTINGS"]))
	assert_eq(n.edge_colour(), GameTheme.ACCENT)


func test_the_screen_in_words() -> void:
	assert_eq(GraphicsNotice.screen_words(Vector2i(1920, 1080), 59.94, Settings.WindowMode.WINDOWED),
			"1920 × 1080 · 60 Hz · windowed")
	assert_eq(GraphicsNotice.screen_words(Vector2i(1920, 1080), -1.0, Settings.WindowMode.EXCLUSIVE),
			"1920 × 1080 · exclusive fullscreen", "a screen that gives no rate")


func test_when_it_is_due() -> void:
	var s := Settings.new(PlayTuning.new())
	assert_true(GraphicsStartUp.first_start_due(s, false), "a fresh settings file, the automatic pick")
	assert_false(GraphicsStartUp.first_start_due(s, true), "the smoke run or a headless one")
	s.first_start_seen = true
	assert_false(GraphicsStartUp.first_start_due(s, false), "seen")
	s.first_start_seen = false
	s.choose_graphics(&"low", &"high")
	assert_false(GraphicsStartUp.first_start_due(s, false), "a preset of the player's own")
	s.choose_graphics(Settings.GRAPHICS_AUTOMATIC, &"high")
	s.graphics_forced = &"ultra"
	assert_false(GraphicsStartUp.first_start_due(s, false), "a --graphics= preset")


# --- On the menus ---

func test_the_first_title_shows_it_once_and_saves_it_seen() -> void:
	var main := _main()
	add_child(main)
	await wait_process_frames(1)
	var menus := main.get("_menus") as MenuScreen
	assert_not_null(menus.notice())
	var words := _words(menus.notice())
	assert_eq(words[1], "GRAPHICS SET TO HIGH", "a dedicated card: High")
	assert_eq(words[4], "Test Card 3000 · dedicated")
	assert_true(Settings.shared().first_start_seen)
	var saved := Settings.new(PlayTuning.new())
	saved.load_file(_settings_path)
	assert_true(saved.first_start_seen, "saved as it shows")
	assert_eq(saved.graphics_choice, Settings.GRAPHICS_AUTOMATIC, "the pick isn't saved")
	menus.notice().button(0).pressed.emit()
	await wait_process_frames(1)
	assert_null(menus.notice(), "OK closes it")
	main.call("_free_screens")
	main.call("_build_screens")
	await wait_process_frames(1)
	assert_null((main.get("_menus") as MenuScreen).notice(), "not again after a match")
	main.free()
	var next := _main()
	add_child(next)
	await wait_process_frames(1)
	assert_null((next.get("_menus") as MenuScreen).notice(), "nor on the next start")
	next.free()


func test_integrated_graphics_start_on_medium() -> void:
	GraphicsApply._machine = _probe(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU)
	var main := _main()
	add_child(main)
	await wait_process_frames(1)
	var menus := main.get("_menus") as MenuScreen
	assert_eq(_words(menus.notice())[1], "GRAPHICS SET TO MEDIUM")
	assert_eq(_words(menus.notice())[4], "Test Card 3000 · integrated")
	main.free()


func test_the_menus_work_under_it() -> void:
	var main := _main()
	add_child(main)
	await wait_process_frames(1)
	var menus := main.get("_menus") as MenuScreen
	assert_not_null(menus.notice())
	assert_true(menus.visible, "the menus show under the notice")
	menus.nav_rail().tab_button(NavRail.Tab.LOADOUT).pressed.emit()
	assert_eq(menus.page_tab(), NavRail.Tab.LOADOUT, "and their tabs work")
	main.free()


func test_graphics_settings_opens_the_graphics_tab() -> void:
	var main := _main()
	add_child(main)
	await wait_process_frames(1)
	var menus := main.get("_menus") as MenuScreen
	menus.notice().button(1).pressed.emit()
	await wait_process_frames(1)
	assert_null(menus.notice())
	var screen := main.get("_settings_screen") as SettingsScreen
	assert_not_null(screen, "the settings open")
	assert_true(screen.visible)
	assert_true((main.get("_menus") as Control).visible, "over the menus")
	var graphics := screen.find_children("*", "SettingsGraphicsPage", true, false)
	assert_eq(graphics.size(), 1)
	assert_eq(screen.current_tab(), (graphics[0] as Node).get_parent().get_parent().get_index(), "on Graphics")
	main.free()


func test_a_players_own_preset_or_a_headless_run_shows_nothing() -> void:
	Settings.shared().choose_graphics(&"medium", &"high")
	var main := _main()
	add_child(main)
	await wait_process_frames(1)
	assert_null((main.get("_menus") as MenuScreen).notice(), "a preset of the player's own")
	assert_false(Settings.shared().first_start_seen)
	main.free()
	Settings.shared().choose_graphics(Settings.GRAPHICS_AUTOMATIC, &"high")
	var headless := MAIN.instantiate()
	(headless.graphics as GraphicsStartUp).settings_path = _settings_path
	add_child(headless)
	await wait_process_frames(1)
	assert_null((headless.get("_menus") as MenuScreen).notice(), "a headless run (the smoke run is one)")
	assert_false(Settings.shared().first_start_seen)
	assert_false(FileAccess.file_exists(_settings_path), "nothing saved")
	headless.free()


func test_the_smoke_run_never_shows_it() -> void:
	var g := GraphicsStartUp.new()
	g.headless_notices = true
	g.settings_path = _settings_path
	g.start(true)
	var menus := MenuScreen.new()
	add_child_autofree(menus)
	g.show_boot_notices(menus)
	assert_null(menus.notice())
	assert_false(Settings.shared().first_start_seen)
