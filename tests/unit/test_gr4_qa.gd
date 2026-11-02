extends GutTest
## GR4 QA: what a normal quit, a trip and a Forward+ start must leave alone, and what the renderer file never leaves
## behind. Headless; every file lives under user://test-gr4-qa.

const ROOT := "user://test-gr4-qa"
const MAIN := preload("res://game/main.tscn")
const GRAPHICS_KEYS: Array[String] = ["graphics_choice", "graphics_base", "graphics_custom", "renderer"]

var _guard_path := ROOT.path_join("guard.save")
var _renderer_path := ROOT.path_join("renderer.cfg")
var _settings_path := ROOT.path_join("settings.save")
var _shared_before: Dictionary = {}
var _machine_before: GraphicsPick.Probe = null


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	_shared_before = Settings.shared().to_dict()
	_machine_before = GraphicsApply._machine


func after_each() -> void:
	var s := Settings.shared()
	s.from_dict(_shared_before)
	s.dirty = false
	GraphicsApply._machine = _machine_before
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))


func after_all() -> void:
	DirAccess.remove_absolute(ROOT)


func _main_with(guard: GraphicsGuard) -> Node:
	guard.save(_guard_path)
	var main := MAIN.instantiate()
	var graphics: GraphicsStartUp = main.graphics
	graphics.guard_path = _guard_path
	graphics.renderer_path = _renderer_path
	graphics.settings_path = _settings_path
	graphics.restart = func() -> void: main.set_meta(&"restarted", true)
	return main


func _state_on_disk() -> GraphicsGuard.State:
	return GraphicsGuard.load_file(_guard_path).state


func _compat_probe() -> GraphicsPick.Probe:
	var p := GraphicsPick.Probe.new()
	p.rendering_method = GraphicsPick.COMPATIBILITY
	p.driver = "opengl3"
	p.adapter_name = "Test card"
	p.preset = &"low"
	return p


# --- A normal quit never trips the next start ---

func test_a_normal_start_and_quit_leaves_the_record_settled() -> void:
	var main := _main_with(GraphicsGuard.new())
	add_child(main)
	assert_eq(_state_on_disk(), GraphicsGuard.State.STARTING, "written before anything draws")
	assert_false(main.has_meta(&"restarted"))
	main.free()
	assert_eq(_state_on_disk(), GraphicsGuard.State.SETTLED, "a clean quit settles")
	var again := _main_with(GraphicsGuard.load_file(_guard_path))
	add_child(again)
	assert_false(again.has_meta(&"restarted"), "the next start trips nothing")
	again.free()


func test_quitting_with_the_question_open_asks_again_and_never_restarts() -> void:
	var s := Settings.shared()
	var g := GraphicsGuard.new()
	g.state = GraphicsGuard.State.RESTARTING
	g.trip(s, &"high")
	var main := _main_with(g)
	add_child(main)
	await wait_process_frames(1)
	main.free()
	var back := GraphicsGuard.load_file(_guard_path)
	assert_eq(back.state, GraphicsGuard.State.SETTLED)
	assert_true(back.asking(), "the question waits")
	var next := _main_with(back)
	add_child(next)
	await wait_process_frames(1)
	assert_false(next.has_meta(&"restarted"), "asking, never restarting")
	assert_not_null((next.get("_menus") as MenuScreen).notice())
	next.free()


# --- A trip keeps everything but the graphics ---

func test_a_trip_changes_only_the_graphics_and_the_renderer() -> void:
	var s := Settings.shared()
	s.sensitivity = 2.5
	s.fov = 95.0
	s.choose_graphics(&"high", &"high")
	var before := s.to_dict()
	var main := _main_with(GraphicsGuard.new())
	add_child(main)
	main.free()
	# a start that never settled: the record stays STARTING when the process dies; stand in for the kill
	var dead := GraphicsGuard.new()
	dead.state = GraphicsGuard.State.STARTING
	var crashed := _main_with(dead)
	add_child(crashed)
	assert_true(crashed.has_meta(&"restarted"))
	crashed.free()
	var saved := Settings.new(PlayTuning.new())
	saved.load_file(_settings_path)
	var after := saved.to_dict()
	for key: String in before:
		if GRAPHICS_KEYS.has(key):
			continue
		assert_eq(after[key], before[key], "%s is untouched by the trip" % key)
	assert_eq(saved.graphics_choice, &"low")
	assert_eq(saved.renderer, Settings.Renderer.COMPATIBILITY)
	var g := GraphicsGuard.load_file(_guard_path)
	assert_eq(str(g.previous["graphics_choice"]), "high", "the player's own choice is kept")
	assert_eq(int(g.previous["renderer"]), int(Settings.Renderer.AUTO))


func test_a_crash_on_the_restarted_start_asks_and_never_restarts_again() -> void:
	var s := Settings.shared()
	s.choose_graphics(&"high", &"high")
	var dead := GraphicsGuard.new()
	dead.state = GraphicsGuard.State.STARTING
	var first := _main_with(dead)
	add_child(first)
	assert_true(first.has_meta(&"restarted"))
	first.free()
	# the restarted start dies at once (never settles): load the record as it is on disk
	var second := _main_with(GraphicsGuard.load_file(_guard_path))
	add_child(second)
	await wait_process_frames(1)
	assert_false(second.has_meta(&"restarted"))
	assert_eq(_state_on_disk(), GraphicsGuard.State.STARTING)
	# killed again, and again: still no restart, still the question
	for i in 3:
		var again := _main_with(GraphicsGuard.load_file(_guard_path))
		add_child(again)
		await wait_process_frames(1)
		assert_false(again.has_meta(&"restarted"), "start %d" % i)
		assert_not_null((again.get("_menus") as MenuScreen).notice(), "asks on start %d" % i)
		again.free()
	second.free()


# --- The notices come at the right time ---

func test_the_question_comes_back_on_the_menus_after_a_match() -> void:
	var s := Settings.shared()
	var g := GraphicsGuard.new()
	g.state = GraphicsGuard.State.RESTARTING
	g.trip(s, &"high")
	var main := _main_with(g)
	add_child_autofree(main)
	await wait_process_frames(1)
	assert_not_null((main.get("_menus") as MenuScreen).notice())
	main.call("_free_screens")
	main.call("_build_screens")
	await wait_process_frames(2)
	assert_not_null((main.get("_menus") as MenuScreen).notice(), "still unanswered after a match")


func test_the_simpler_renderer_notice_shows_once_and_not_after_a_match() -> void:
	GraphicsApply._machine = _compat_probe()
	var main := _main_with(GraphicsGuard.new())
	add_child(main)
	await wait_process_frames(1)
	var title := main.get("_menus") as MenuScreen
	assert_not_null(title.notice(), "the first start says why")
	assert_ne(GraphicsGuard.load_file(_guard_path).renderer_notice, "", "remembered")
	main.call("_free_screens")
	main.call("_build_screens")
	await wait_process_frames(2)
	assert_null((main.get("_menus") as MenuScreen).notice(), "not again after a match")
	main.free()
	var next := _main_with(GraphicsGuard.load_file(_guard_path))
	add_child(next)
	await wait_process_frames(1)
	assert_null((next.get("_menus") as MenuScreen).notice(), "nor on the next start")
	next.free()


func test_no_notice_on_forward_plus() -> void:
	var p := _compat_probe()
	p.rendering_method = RendererOverride.FORWARD_PLUS
	p.driver = "vulkan"
	GraphicsApply._machine = p
	var main := _main_with(GraphicsGuard.new())
	add_child(main)
	await wait_process_frames(1)
	assert_null((main.get("_menus") as MenuScreen).notice())
	main.free()


# --- The renderer file ---

func test_the_renderer_file_is_one_key_and_leaves_no_temp_file() -> void:
	assert_true(RendererOverride.put(Settings.Renderer.COMPATIBILITY, _renderer_path))
	assert_true(RendererOverride.put(Settings.Renderer.COMPATIBILITY, _renderer_path), "again, over itself")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(_renderer_path), OK)
	assert_eq(cfg.get_sections(), PackedStringArray(["rendering"]))
	assert_eq(cfg.get_section_keys("rendering"), PackedStringArray(["renderer/rendering_method"]))
	assert_false(FileAccess.file_exists(_renderer_path + RendererOverride.TMP))
	assert_true(RendererOverride.put(Settings.Renderer.AUTO, _renderer_path))
	assert_eq(DirAccess.get_files_at(ROOT).size(), 0, "Auto leaves nothing behind")


func test_a_stale_temp_file_is_cleared_by_auto_and_overwritten_by_compatibility() -> void:
	var tmp := _renderer_path + RendererOverride.TMP
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	assert_true(RendererOverride.put(Settings.Renderer.COMPATIBILITY, _renderer_path))
	assert_false(FileAccess.file_exists(tmp))
	var stale := FileAccess.open(tmp, FileAccess.WRITE)
	stale.store_string("garbage")
	stale.close()
	RendererOverride.put(Settings.Renderer.AUTO, _renderer_path)
	assert_false(FileAccess.file_exists(tmp))


func test_an_unwritable_folder_fails_cleanly() -> void:
	var path := ROOT.path_join("no-such-folder/renderer.cfg")
	assert_false(RendererOverride.put(Settings.Renderer.COMPATIBILITY, path))
	assert_false(FileAccess.file_exists(path))
	assert_false(RendererOverride.asks_compatibility(path))


func test_a_damaged_file_reads_as_not_asking() -> void:
	var f := FileAccess.open(_renderer_path, FileAccess.WRITE)
	f.store_string("[rendering\nrenderer/rendering_method=")
	f.close()
	assert_false(RendererOverride.asks_compatibility(_renderer_path))
	assert_true(RendererOverride.sync(Settings.Renderer.COMPATIBILITY, _renderer_path), "put right")
	assert_true(RendererOverride.asks_compatibility(_renderer_path))
	assert_engine_error_count(2, "the engine's own parse errors for the damaged file (read twice)")


# --- Forward+ greys nothing ---

func test_forward_plus_draws_every_preset_as_it_is_and_greys_nothing() -> void:
	var table := GraphicsTable.shared()
	for preset: StringName in GraphicsTable.PRESETS:
		var values := table.preset(preset)
		assert_true(GraphicsApply.drawable(values, "forward_plus", table).equals(values), "%s on Forward+" % preset)
	var screen := SettingsScreen.new()
	screen.settings = Settings.new(PlayTuning.new())
	screen.save_path = _settings_path
	var page := SettingsGraphicsPage.new()
	var p := GraphicsPick.Probe.new()
	p.rendering_method = "forward_plus"
	p.driver = "vulkan"
	p.preset = &"high"
	page.probe = p
	page.renderer_path = _renderer_path
	add_child_autofree(screen)
	page.build(screen)
	add_child_autofree(page)
	page.refresh()
	for id: StringName in GraphicsQuality.ROWS:
		var line := page.line(id)
		assert_false(line.shut, "%s is not shut on Forward+" % id)
		if line.choice != null:
			for i in line.levels.size():
				assert_false(line.choice.button(i).disabled, "%s level %d" % [id, i])
		if line.check != null:
			assert_false(line.check.disabled, String(id))
		if line.slider != null:
			assert_true(line.slider.editable, String(id))
