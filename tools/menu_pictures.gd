extends SceneTree
## Pictures of the menus at a chosen window size (AUD2, KNOWN_ISSUES 111 to 119): the Match page (Skirmish and Custom),
## Loadout, Customise (each tab), the Armory, the Settings, Report a Bug, the loading screen, the pause menu, and the
## end-of-match XP, grabbed whole to `<folder>/<name>_<W>x<H>.png`. Needs a display and OpenGL, and a scratch save
## folder (the menus read and write the player's own); under xvfb:
##   XDG_DATA_HOME=/tmp/x XDG_CONFIG_HOME=/tmp/xc xvfb-run -a -s "-screen 0 3840x2160x24" godot --path . \
##       --rendering-driver opengl3 -s res://tools/menu_pictures.gd -- <folder> <width> <height> [names...]
## With names (woodland: the Match page's Woodland picked first; match custom loadout customise armory settings report loading pause xp), only those. Dev only.

const SETTLE := 10

var _folder: String = ""
var _size: Vector2i = Vector2i.ZERO
var _main: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(name: String) -> void:
	await _frames(SETTLE)
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s_%dx%d.png" % [_folder, name, _size.x, _size.y]
	image.save_png(path)
	print("[menu_pictures] ", path, " ", image.get_size())


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_folder = args[0]
	_size = Vector2i(int(args[1]), int(args[2]))
	var only := PackedStringArray(args.slice(3))
	DirAccess.make_dir_recursive_absolute(_folder)
	DisplayServer.window_set_size(_size)
	root.size = _size
	await _frames(4)
	var main: Node = load("res://game/main.tscn").instantiate()
	_main = main
	root.add_child(main)
	await _frames(SETTLE)
	var menus: MenuScreen = main._menus
	# the notice of the simpler renderer (this tool draws OpenGL) is for the player's own card: not in the pictures
	menus.close_notice()
	if only.has("woodland"):
		menus.match_page().picks.map_id = "woodland"
		menus.match_page()._pick_map("woodland")
		await _frames(SETTLE)
	if only.is_empty() or only.has("match"):
		await _grab("match")
	if only.is_empty() or only.has("custom"):
		menus.match_page().rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
		await _grab("match_custom")
		menus.match_page().rules_box().rules_button(MatchOptions.RULES_SKIRMISH).pressed.emit()
	if only.is_empty() or only.has("loadout") or only.has("customise"):
		main._on_tab(NavRail.Tab.LOADOUT)
		await _frames(SETTLE)
		if only.is_empty() or only.has("loadout"):
			await _grab("loadout")
		if only.is_empty() or only.has("customise"):
			var page := menus.loadout_page()
			page.show_customise()
			await _frames(SETTLE)
			var view: CustomiseView = page._customise
			for t: int in CustomiseView.Tab.values():
				view.show_tab(t as CustomiseView.Tab)
				await _grab("customise_%d" % t)
			page.show_gear()
	if only.is_empty() or only.has("armory"):
		main._on_tab(NavRail.Tab.ARMORY)
		await _grab("armory")
	if only.is_empty() or only.has("settings"):
		main._on_tab(NavRail.Tab.SETTINGS)
		await _grab("settings")
	if only.is_empty() or only.has("report"):
		main._show_report()
		await _grab("report")
	main.queue_free()
	await _frames(4)
	if only.is_empty() or only.has("loading"):
		var loading := LoadingScreen.new()
		root.add_child(loading)
		loading.visible = true
		loading.show_continue()
		await _grab("loading")
		loading.queue_free()
		await _frames(2)
	if only.is_empty() or only.has("pause") or only.has("xp"):
		await _play_pictures(only)
	quit()


func _play_pictures(only: PackedStringArray) -> void:
	var session := PlaySession.new()
	Engine.time_scale = 0.02
	root.add_child(session)
	await _frames(SETTLE)
	var hud: Hud = session._hud
	if only.is_empty() or only.has("pause"):
		var pause: PauseMenu = session._pause
		hud.set_paused(true)
		pause.set_match("Depot", "Attack / Defend", 3, 1384047683)
		pause.set_weather(session.state.air_temperature, session.state.wind.speed)
		pause.visible = true
		await _grab("pause")
		pause.visible = false
		hud.set_paused(false)
	if only.is_empty() or only.has("xp"):
		var pool := Pool.read_file()
		var levels := LevelTable.read_file(pool)
		var progress := Progress.new(levels)
		var outcome := MatchXp.Outcome.new()
		outcome.won = true
		outcome.rounds_won = 3
		outcome.hits = 4
		var settled := PlayerTally.Settled.new()
		settled.earned = MatchXp.earned(levels, outcome)
		settled.level_up = progress.add_xp(settled.earned.total)
		hud.show_xp(settled, progress)
		hud.open_summary(session.state, true, "Hold the angle")
		hud.update(session.state, 1.0, 0.0)
		await _grab("xp")
	session.queue_free()
