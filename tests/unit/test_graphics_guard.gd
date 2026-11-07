extends GutTest
## GR4: the safe start (GraphicsGuard), the renderer file (RendererOverride), the notices on the title, the Renderer
## row and the first match's warm shaders. Headless: the files, states and words, never a real crash or restart.

const ROOT := "user://test-gr4"
const MAIN := preload("res://game/main.tscn")
const COMPATIBILITY := "gl_compatibility"
## The stand-in project that proves Godot reads the renderer file before any script, and its user folder's name.
const PROBE_NAME := "AirsoftGr4RendererProbe"
const PROBE_SCRIPT := """extends SceneTree
func _init() -> void:
	print("method=%s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	quit()
"""

var _guard_path := ROOT.path_join("guard.save")
var _renderer_path := ROOT.path_join("renderer.cfg")
var _settings_path := ROOT.path_join("settings.save")
var _shared_before: Dictionary = {}


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	_shared_before = Settings.shared().to_dict()


func after_each() -> void:
	_restore_shared()
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))


func after_all() -> void:
	DirAccess.remove_absolute(ROOT)


func _restore_shared() -> void:
	var s := Settings.shared()
	s.from_dict(_shared_before)
	s.dirty = false


func _settings(choice: StringName = &"high") -> Settings:
	var s := Settings.new(PlayTuning.new())
	s.choose_graphics(choice, &"high")
	return s


func _guard(state: GraphicsGuard.State, previous: Dictionary = {}) -> GraphicsGuard:
	var g := GraphicsGuard.new()
	g.state = state
	g.previous = previous
	return g


# --- GraphicsGuard: every state ---

func test_a_missing_file_is_settled_and_a_start_writes_starting() -> void:
	var g := GraphicsGuard.load_file(ROOT.path_join("none.save"))
	assert_eq(g.state, GraphicsGuard.State.SETTLED)
	assert_eq(g.start(false), GraphicsGuard.Action.NONE)
	assert_eq(g.state, GraphicsGuard.State.STARTING)
	assert_true(g.settle(), "the first match warm, or a clean quit")
	assert_eq(g.state, GraphicsGuard.State.SETTLED)
	assert_false(g.settle(), "once")


func test_a_start_that_finds_starting_trips_once_and_the_next_asks() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	assert_eq(g.start(false), GraphicsGuard.Action.RESTART_SAFE)
	assert_eq(g.state, GraphicsGuard.State.RESTARTING)
	var s := _settings(&"ultra")
	g.trip(s, &"high")
	assert_eq(s.renderer, Settings.Renderer.COMPATIBILITY)
	assert_eq(s.graphics_choice, &"low")
	assert_eq(str(g.previous["graphics_choice"]), "ultra")
	assert_eq(int(g.previous["renderer"]), Settings.Renderer.AUTO)
	assert_false(g.settle(), "the trip's own quit is not a clean one")
	assert_eq(g.state, GraphicsGuard.State.RESTARTING)
	assert_eq(g.start(true), GraphicsGuard.Action.ASK, "the restarted start asks")
	assert_eq(g.state, GraphicsGuard.State.STARTING)
	assert_true(g.asking())


func test_a_second_crash_never_restarts_again() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	g.start(false)
	g.trip(_settings(), &"high")
	g.start(true)
	# the safe start closed while drawing too
	assert_eq(g.start(true), GraphicsGuard.Action.ASK, "asks again, no restart")
	assert_eq(g.start(false), GraphicsGuard.Action.ASK, "even off the safe graphics while an answer waits")
	assert_eq(g.state, GraphicsGuard.State.STARTING)


func test_a_crash_on_graphics_already_safe_trips_nothing() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	assert_eq(g.start(true), GraphicsGuard.Action.NONE)
	assert_eq(g.state, GraphicsGuard.State.STARTING)


func test_a_settled_start_still_asks_while_an_answer_waits() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	g.start(false)
	g.trip(_settings(), &"high")
	g.start(true)
	assert_true(g.settle())
	assert_eq(g.start(true), GraphicsGuard.Action.ASK, "the player left from the title without answering")


func test_keep_and_try_again() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	g.start(false)
	var s := _settings(GraphicsQuality.CUSTOM)
	s.change_graphics_row(GraphicsQuality.SHADOW_RANGE, 90, &"high")
	g.trip(s, &"high")
	g.start(true)
	g.keep()
	assert_false(g.asking())
	g.try_again(s)
	assert_eq(s.renderer, Settings.Renderer.COMPATIBILITY, "nothing to restore once kept")
	g.previous = {}
	var back := _settings(GraphicsQuality.CUSTOM)
	back.change_graphics_row(GraphicsQuality.SHADOW_RANGE, 90, &"high")
	var g2 := _guard(GraphicsGuard.State.STARTING)
	g2.start(false)
	g2.trip(back, &"high")
	# through the file, as the restarted start reads it
	assert_true(g2.save(_guard_path))
	var read := GraphicsGuard.load_file(_guard_path)
	read.start(true)
	read.try_again(back)
	assert_eq(back.renderer, Settings.Renderer.AUTO)
	assert_eq(back.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(back.graphics_in_force(&"high").shadow_range, 90, "Custom's rows back")
	assert_false(read.asking())
	assert_eq(read.state, GraphicsGuard.State.SETTLED, "the restart after starts settled")


func test_try_again_brings_back_the_automatic_pick() -> void:
	var s := Settings.new(PlayTuning.new())
	var g := _guard(GraphicsGuard.State.STARTING)
	g.start(false)
	g.trip(s, &"medium")
	assert_eq(s.graphics_choice, &"low")
	g.start(true)
	g.try_again(s)
	assert_eq(s.graphics_choice, Settings.GRAPHICS_AUTOMATIC)


func test_damaged_and_odd_files_read_as_settled() -> void:
	var f := FileAccess.open(_guard_path, FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	var g := GraphicsGuard.load_file(_guard_path)
	assert_eq(g.state, GraphicsGuard.State.SETTLED)
	g.from_dict({"state": "exploded", "previous": {"graphics_choice": "high"}, "renderer_notice": 3})
	assert_eq(g.state, GraphicsGuard.State.SETTLED, "an unknown state")
	assert_false(g.asking(), "a previous without every key")
	assert_eq(g.renderer_notice, "")
	g.from_dict({"state": "restarting", "previous": "high"})
	assert_eq(g.state, GraphicsGuard.State.RESTARTING)
	assert_false(g.asking())


func test_the_record_round_trips_through_save_file() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	g.start(false)
	g.trip(_settings(), &"high")
	g.renderer_notice = RendererOverride.REASON_SETTINGS
	assert_true(g.save(_guard_path))
	assert_true(SaveFile.read_text(_guard_path).begins_with("ASAVE graphics_guard 1 "))
	var read := GraphicsGuard.load_file(_guard_path)
	assert_eq(read.state, GraphicsGuard.State.RESTARTING)
	assert_true(read.asking())
	assert_eq(read.renderer_notice, RendererOverride.REASON_SETTINGS)


func test_the_renderer_notice_shows_once_per_change() -> void:
	var g := GraphicsGuard.new()
	assert_false(g.notice_due(""), "not on the simpler renderer")
	assert_true(g.notice_due(RendererOverride.REASON_FALLBACK))
	assert_false(g.notice_due(RendererOverride.REASON_FALLBACK), "once")
	assert_true(g.notice_due(RendererOverride.REASON_SETTINGS), "a new reason")
	assert_false(g.notice_due(""), "back on the normal renderer")
	assert_true(g.notice_due(RendererOverride.REASON_SETTINGS), "and on the simpler one again")


# --- RendererOverride ---

func test_compatibility_writes_one_key_and_auto_deletes_it() -> void:
	assert_true(RendererOverride.put(Settings.Renderer.COMPATIBILITY, _renderer_path))
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(_renderer_path), OK)
	assert_eq(cfg.get_sections(), PackedStringArray(["rendering"]))
	assert_eq(cfg.get_section_keys("rendering"), PackedStringArray(["renderer/rendering_method"]))
	assert_eq(cfg.get_value("rendering", "renderer/rendering_method"), COMPATIBILITY)
	assert_false(FileAccess.file_exists(_renderer_path + RendererOverride.TMP), "no temp file left")
	assert_true(RendererOverride.asks_compatibility(_renderer_path))
	assert_true(RendererOverride.put(Settings.Renderer.AUTO, _renderer_path))
	assert_false(FileAccess.file_exists(_renderer_path))
	assert_true(RendererOverride.put(Settings.Renderer.AUTO, _renderer_path), "no file is Auto already")


func test_sync_puts_a_missing_or_stale_file_right() -> void:
	assert_true(RendererOverride.sync(Settings.Renderer.COMPATIBILITY, _renderer_path), "deleted by hand")
	assert_true(RendererOverride.asks_compatibility(_renderer_path))
	assert_false(RendererOverride.sync(Settings.Renderer.COMPATIBILITY, _renderer_path))
	assert_true(RendererOverride.sync(Settings.Renderer.AUTO, _renderer_path), "the settings were reset")
	assert_false(FileAccess.file_exists(_renderer_path))


func test_the_project_reads_the_file_and_falls_back_by_itself() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/project_settings_override"), RendererOverride.PATH)
	assert_true(ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3"))


## Godot reads the file RendererOverride writes before any script runs: a stand-in project with the same override
## setting, started headless with and without the file.
func test_godot_reads_the_file_before_any_script() -> void:
	var dir := ProjectSettings.globalize_path(ROOT.path_join("probe"))
	DirAccess.make_dir_recursive_absolute(dir)
	var project := FileAccess.open(dir.path_join("project.godot"), FileAccess.WRITE)
	project.store_string("config_version=5\n\n[application]\n\nconfig/name=\"%s\"\nconfig/use_custom_user_dir=true\n"
			% PROBE_NAME + "config/custom_user_dir_name=\"%s\"\nconfig/project_settings_override=\"%s\"\n"
			% [PROBE_NAME, RendererOverride.PATH])
	project.close()
	var script := FileAccess.open(dir.path_join("probe.gd"), FileAccess.WRITE)
	script.store_string(PROBE_SCRIPT)
	script.close()
	var user := OS.get_user_data_dir().get_base_dir().path_join(PROBE_NAME)
	DirAccess.make_dir_recursive_absolute(user)
	var file := user.path_join(RendererOverride.PATH.get_file())
	var without := _probe_method(dir)
	assert_true(RendererOverride.put(Settings.Renderer.COMPATIBILITY, file))
	var with := _probe_method(dir)
	DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(user)
	for f: String in ["project.godot", "probe.gd"]:
		DirAccess.remove_absolute(dir.path_join(f))
	OS.move_to_trash(dir)
	assert_eq(without, "forward_plus")
	assert_eq(with, COMPATIBILITY)


func _probe_method(dir: String) -> String:
	var out: Array = []
	OS.execute(OS.get_executable_path(), ["--headless", "--path", dir, "-s", "res://probe.gd"], out, true)
	for line: String in "\n".join(PackedStringArray(out)).split("\n"):
		if line.begins_with("method="):
			return line.substr("method=".length())
	return ""


func test_the_reason_for_the_simpler_renderer() -> void:
	var none := PackedStringArray()
	assert_eq(RendererOverride.reason("forward_plus", none, "forward_plus"), "")
	assert_eq(RendererOverride.reason(COMPATIBILITY, none, "forward_plus"), RendererOverride.REASON_FALLBACK)
	assert_eq(RendererOverride.reason(COMPATIBILITY, none, COMPATIBILITY), RendererOverride.REASON_SETTINGS)
	var shortcut := PackedStringArray(["--rendering-method", COMPATIBILITY])
	assert_eq(RendererOverride.reason(COMPATIBILITY, shortcut, "forward_plus"), RendererOverride.REASON_LAUNCH)
	assert_eq(RendererOverride.reason("forward_plus", shortcut, "forward_plus"), "", "a shortcut to Forward+")


func test_the_boot_line() -> void:
	var p := GraphicsPick.Probe.new()
	p.rendering_method = "forward_plus"
	p.driver = "vulkan"
	p.adapter_name = "NVIDIA GeForce RTX 3060"
	p.adapter_type = RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	assert_eq(RendererOverride.boot_line(p),
			"[boot] renderer forward_plus (vulkan) · NVIDIA GeForce RTX 3060 · discrete")
	p.adapter_name = ""
	p.adapter_type = 99
	assert_eq(RendererOverride.boot_line(p), "[boot] renderer forward_plus (vulkan) · unknown card · other")


# --- The notices ---

func test_the_safe_start_notice_says_what_the_concept_says() -> void:
	var n := GraphicsNotice.safe_start("High · Forward+", "Low · Compatibility")
	add_child_autofree(n)
	var words := n.words()
	assert_true(words.has("SAFE GRAPHICS"))
	assert_true(words.has("THE GAME CLOSED WHILE DRAWING"))
	assert_true(words.has("High · Forward+ (kept, not in use)"))
	assert_true(words.has("Low · Compatibility"))
	assert_eq(n.button(0).text, "KEEP SAFE GRAPHICS")
	assert_eq(n.button(1).text, "TRY MY SETTINGS AGAIN")
	assert_eq(n.edge_colour(), GraphicsNotice.WARN)
	watch_signals(n)
	n.button(1).pressed.emit()
	assert_signal_emitted_with_parameters(n, "chosen", [1])


func test_the_simpler_renderer_notice_names_the_reason() -> void:
	for reason: String in GraphicsNotice.REASON_KEYS:
		var n := GraphicsNotice.simpler_renderer(reason, "Card · integrated", "Compatibility · OpenGL 3")
		add_child_autofree(n)
		var text := " ".join(n.words())
		assert_string_contains(text, tr(GraphicsNotice.REASON_KEYS[reason]).replace("[b]", "").replace("[/b]", ""))
		assert_string_contains(text, "Compatibility · OpenGL 3")
		assert_eq(n.button(0).text, "OK")


func test_graphics_words() -> void:
	assert_eq(GraphicsNotice.graphics_words(&"", &"high", Settings.Renderer.AUTO), "High · Forward+")
	assert_eq(GraphicsNotice.graphics_words(&"low", &"high", Settings.Renderer.COMPATIBILITY), "Low · Compatibility")
	assert_eq(GraphicsNotice.graphics_words(GraphicsQuality.CUSTOM, &"high", Settings.Renderer.AUTO), "Custom · Forward+")


# --- The entry scene ---

func _main_with(guard: GraphicsGuard) -> Node:
	guard.save(_guard_path)
	var main := MAIN.instantiate()
	var graphics: GraphicsStartUp = main.graphics
	graphics.guard_path = _guard_path
	graphics.renderer_path = _renderer_path
	graphics.settings_path = _settings_path
	graphics.restart = func() -> void: main.set_meta(&"restarted", true)
	return main


func test_the_smoke_run_and_headless_runs_guard_nothing() -> void:
	var main := MAIN.instantiate()
	add_child_autofree(main)
	await wait_process_frames(1)
	assert_null((main.graphics as GraphicsStartUp).guard)
	assert_null((main.get("_menus") as MenuScreen).notice())


func test_a_start_after_a_crash_writes_safe_graphics_and_restarts() -> void:
	var main := _main_with(_guard(GraphicsGuard.State.STARTING))
	add_child(main)
	assert_true(main.has_meta(&"restarted"))
	assert_null(main.get("_menus"), "nothing built")
	assert_true(RendererOverride.asks_compatibility(_renderer_path))
	var saved := Settings.new(PlayTuning.new())
	saved.load_file(_settings_path)
	assert_eq(saved.renderer, Settings.Renderer.COMPATIBILITY)
	assert_eq(saved.graphics_choice, &"low")
	main.free()
	var g := GraphicsGuard.load_file(_guard_path)
	assert_eq(g.state, GraphicsGuard.State.RESTARTING, "its own quit didn't settle")
	assert_true(g.asking())


func test_the_restarted_start_asks_and_try_again_restores_and_restarts() -> void:
	var s := Settings.shared()
	var g := _guard(GraphicsGuard.State.STARTING)
	g.start(false)
	s.choose_graphics(&"high", &"high")
	g.trip(s, &"high")
	g.start(true)
	g.state = GraphicsGuard.State.RESTARTING
	RendererOverride.put(s.renderer, _renderer_path)
	var main := _main_with(g)
	add_child_autofree(main)
	await wait_process_frames(1)
	var notice := (main.get("_menus") as MenuScreen).notice()
	assert_not_null(notice, "the safe start's question")
	var words := notice.words()
	assert_true(words.has("High · Forward+ (kept, not in use)"), "your settings")
	assert_true(words.has("Low · Compatibility"), "now")
	notice.button(1).pressed.emit()
	assert_true(main.has_meta(&"restarted"))
	assert_eq(s.graphics_choice, &"high")
	assert_eq(s.renderer, Settings.Renderer.AUTO)
	assert_false(FileAccess.file_exists(_renderer_path), "Auto: the file is gone")
	var read := GraphicsGuard.load_file(_guard_path)
	assert_false(read.asking())
	assert_eq(read.state, GraphicsGuard.State.SETTLED)
	assert_null((main.get("_menus") as MenuScreen).notice())


func test_keep_safe_graphics_closes_the_question_for_good() -> void:
	var s := Settings.shared()
	var g := _guard(GraphicsGuard.State.RESTARTING)
	g.trip(s, &"high")
	var main := _main_with(g)
	add_child_autofree(main)
	await wait_process_frames(1)
	var notice := (main.get("_menus") as MenuScreen).notice()
	notice.button(0).pressed.emit()
	assert_false(main.has_meta(&"restarted"))
	assert_eq(s.renderer, Settings.Renderer.COMPATIBILITY, "kept")
	var read := GraphicsGuard.load_file(_guard_path)
	assert_false(read.asking())
	assert_eq(read.renderer_notice, RendererOverride.REASON_SETTINGS, "the notice said why already")
	(main.graphics as GraphicsStartUp).settle()
	assert_eq(GraphicsGuard.load_file(_guard_path).state, GraphicsGuard.State.SETTLED)


func test_the_first_match_s_warm_shaders_settle_the_start() -> void:
	var play := PlaySession.new()
	play.settings = Settings.new(PlayTuning.new())
	play.match_seed = 41
	watch_signals(play)
	add_child_autofree(play)
	await wait_process_frames(ShaderPrewarm.FRAMES + 3)
	assert_signal_emit_count(play, "shaders_warmed", 1)


func test_leaving_before_the_shaders_warm_says_nothing() -> void:
	var play := PlaySession.new()
	play.settings = Settings.new(PlayTuning.new())
	play.match_seed = 42
	var heard: Array[bool] = []
	play.shaders_warmed.connect(func() -> void: heard.append(true))
	add_child(play)
	play.queue_free()
	await wait_process_frames(ShaderPrewarm.FRAMES + 3)
	assert_eq(heard.size(), 0)


# --- Settings › Graphics ---

func _page(method: String = "forward_plus") -> SettingsGraphicsPage:
	var screen := SettingsScreen.new()
	screen.settings = Settings.new(PlayTuning.new())
	screen.save_path = _settings_path
	var page := SettingsGraphicsPage.new()
	var p := GraphicsPick.Probe.new()
	p.rendering_method = method
	p.driver = "vulkan"
	p.preset = GraphicsPick.pick(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, method)
	page.probe = p
	page.renderer_path = _renderer_path
	add_child_autofree(screen)
	page.build(screen)
	page.changed.connect(screen._changed)
	add_child_autofree(page)
	page.refresh()
	return page


func test_the_renderer_row_writes_the_file_for_the_next_start() -> void:
	var page := _page()
	var choice := page.renderer_choice()
	assert_eq(choice.selected(), Settings.Renderer.AUTO)
	choice.button(Settings.Renderer.COMPATIBILITY).pressed.emit()
	assert_true(RendererOverride.asks_compatibility(_renderer_path))
	var saved := Settings.new(PlayTuning.new())
	saved.load_file(_settings_path)
	assert_eq(saved.renderer, Settings.Renderer.COMPATIBILITY, "saved at once")
	choice.button(Settings.Renderer.AUTO).pressed.emit()
	assert_false(FileAccess.file_exists(_renderer_path))


func test_the_simpler_renderer_greys_with_its_own_words_and_shows_what_it_draws() -> void:
	var page := _page(COMPATIBILITY)
	var line := page.line(GraphicsQuality.UPSCALER)
	var fsr1 := line.choice.button(line.levels.find(GraphicsQuality.Upscaler.FSR1))
	assert_true(fsr1.disabled)
	assert_eq(fsr1.tooltip_text, "Not with the simpler renderer.")
	assert_eq(line.choice.selected(), line.levels.find(GraphicsQuality.Upscaler.BILINEAR), "Low's FSR 1 draws bilinear")
	var edges := page.line(GraphicsQuality.EDGE_SMOOTHING)
	assert_true(edges.choice.button(edges.levels.find(GraphicsQuality.EdgeSmoothing.FXAA)).disabled, "as checked")
	assert_eq(edges.choice.selected(), edges.levels.find(GraphicsQuality.EdgeSmoothing.OFF))
	assert_eq(page.line(GraphicsQuality.TEMPORAL_SMOOTHING).check.tooltip_text, "Not with the simpler renderer.")
	var forward := _page()
	var fsr2 := forward.line(GraphicsQuality.UPSCALER).choice.button(2)
	assert_false(fsr2.disabled)
	assert_eq(forward.line(GraphicsQuality.UPSCALER).choice.selected(), 1, "FSR 1 on Forward+")


# --- A second copy, and the restart's options (critic's pass over QA's advisories) ---

func test_a_second_copy_beside_a_running_one_leaves_its_record_alone() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	g.pid = OS.get_process_id() + 1
	var main := _main_with(g)
	(main.graphics as GraphicsStartUp).process_running = (func(_id: int) -> bool: return true)
	add_child_autofree(main)
	assert_false(main.has_meta(&"restarted"))
	assert_null((main.graphics as GraphicsStartUp).guard)
	var kept := GraphicsGuard.load_file(_guard_path)
	assert_eq(kept.state, GraphicsGuard.State.STARTING)
	assert_eq(kept.pid, OS.get_process_id() + 1)
	var saved := Settings.new(PlayTuning.new())
	saved.load_file(_settings_path)
	assert_ne(saved.renderer, Settings.Renderer.COMPATIBILITY, "the player's settings untouched")


func test_a_start_whose_writer_is_gone_still_trips() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	g.pid = OS.get_process_id() + 1
	var main := _main_with(g)
	(main.graphics as GraphicsStartUp).process_running = (func(_id: int) -> bool: return false)
	add_child(main)
	assert_true(main.has_meta(&"restarted"))
	main.free()
	assert_eq(GraphicsGuard.load_file(_guard_path).pid, OS.get_process_id(), "the record names its writer")


func test_only_a_start_under_way_can_belong_to_another_copy() -> void:
	var yes := func(_id: int) -> bool: return true
	for state: GraphicsGuard.State in [GraphicsGuard.State.SETTLED, GraphicsGuard.State.RESTARTING]:
		var g := _guard(state)
		g.pid = 42
		assert_false(g.held_by_other(7, yes, 1000), "the restart's own parent may still be closing")
	var mine := _guard(GraphicsGuard.State.STARTING)
	mine.pid = 7
	assert_false(mine.held_by_other(7, yes, 1000))
	var unknown := _guard(GraphicsGuard.State.STARTING)
	assert_false(unknown.held_by_other(7, yes, 1000))


## BP7 (row 85): a start under way whose writer stopped beating crashed, even if another copy of the game holds its id.
func test_a_stale_start_is_a_crash_though_another_copy_holds_the_id() -> void:
	var yes := func(_id: int) -> bool: return true
	var g := _guard(GraphicsGuard.State.STARTING)
	g.pid = 42
	g.at = 1000
	assert_true(g.held_by_other(7, yes, 1000 + RunRecord.STALE_SECONDS), "just started: a second copy")
	assert_false(g.held_by_other(7, yes, 1001 + RunRecord.STALE_SECONDS), "stale: a crash")
	assert_true(g.held_by_other(7, yes, 5000, PackedInt64Array([42, 4990])), "its run beats: still going")
	assert_false(g.held_by_other(7, yes, 5000, PackedInt64Array([43, 4990])), "another process's beat")
	assert_true(g.held_by_other(7, yes, 900), "a start ahead of the clock is fresh")
	var back := GraphicsGuard.new()
	back.from_dict(g.to_dict())
	assert_eq(back.at, 1000, "kept in the file")
	var before_bp7 := g.to_dict()
	before_bp7.erase("at")
	back.from_dict(before_bp7)
	assert_eq(back.at, -1)
	assert_true(back.held_by_other(7, yes, 999999), "a record from before BP7: its process id alone decides")


func test_a_start_names_when_it_began_and_a_stale_one_beside_a_running_id_still_trips() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	g.pid = OS.get_process_id() + 1
	g.at = 1000
	var main := _main_with(g)
	var graphics := main.graphics as GraphicsStartUp
	graphics.process_running = (func(_id: int) -> bool: return true)
	graphics.run_path = _guard_path + ".no-run"
	add_child(main)
	assert_true(main.has_meta(&"restarted"), "an id held by another copy, but no beat for an hour: a crash")
	main.free()
	var kept := GraphicsGuard.load_file(_guard_path)
	assert_almost_eq(float(kept.at), Time.get_unix_time_from_system(), 5.0, "the new start's time")


func test_the_pid_survives_the_file_and_a_bad_one_reads_as_unknown() -> void:
	var g := _guard(GraphicsGuard.State.STARTING)
	g.pid = 1234
	var back := GraphicsGuard.new()
	back.from_dict(g.to_dict())
	assert_eq(back.pid, 1234)
	back.from_dict({"state": "starting", "pid": "x"})
	assert_eq(back.pid, 0)


func test_the_restart_drops_a_renderer_option() -> void:
	var args := PackedStringArray(["--rendering-method", "gl_compatibility", "--fullscreen"])
	assert_eq(GraphicsStartUp.restart_args(args), PackedStringArray(["--fullscreen"]))
	args = PackedStringArray(["--rendering-method=gl_compatibility", "--seed", "4"])
	assert_eq(GraphicsStartUp.restart_args(args), PackedStringArray(["--seed", "4"]))
	assert_eq(GraphicsStartUp.restart_args(PackedStringArray()), PackedStringArray())
