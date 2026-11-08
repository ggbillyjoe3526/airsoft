extends SceneTree
## Pictures of the in-match HUD for review (BP8): a real match drawn by a PlaySession, grabbed whole at the named moments
## to `<folder>/<tag>_<name>_<W>x<H>.png`: the start of a round (banner, countdown, bottom panel, weapon rail), the GO,
## the scoreboard held over a banner, a bomb in hand, the pause menu, and a hit call. Needs a display and OpenGL, so
## under xvfb:
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 -s res://tools/hud_pictures.gd \
##       -- <folder> <tag> <width> <height>
## Dev only: tools/ never ships.

const SETTLE := 12


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(folder: String, tag: String, name: String, size: Vector2i) -> void:
	await _frames(2)
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s_%s_%dx%d.png" % [folder, tag, name, size.x, size.y]
	image.save_png(path)
	print("[hud_pictures] ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0]
	var tag := args[1]
	var size := Vector2i(int(args[2]), int(args[3]))
	DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(size)
	root.size = size
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await _frames(4)
	var session := PlaySession.new()
	Engine.time_scale = 0.02
	root.add_child(session)
	await _frames(SETTLE)
	var hud: Hud = session._hud
	# the start of a round: the banner and (in a build with one) the countdown's 3
	await _grab(folder, tag, "round_start", size)
	# the scoreboard held while the banner is still up
	Input.action_press(&"scoreboard")
	await _frames(8)
	await _grab(folder, tag, "board_over_banner", size)
	Input.action_release(&"scoreboard")
	await _frames(2)
	await _grab(folder, tag, "countdown_two", size)
	Engine.time_scale = 0.1
	# the countdown ends: GO!
	var waited := 0
	while float(session.state.round_state.get(&"hold") if session.state.round_state.get(&"hold") != null else 0.0) > 0.0 \
			and waited < 600:
		await process_frame
		waited += 1
	await _frames(3)
	await _grab(folder, tag, "go", size)
	# the pause menu opened with the GO! still on the screen: the plate is not drawn through the panel
	var pause: PauseMenu = session._pause
	if pause != null:
		hud.set_paused(true)
		pause.set_match("Depot", "Attack / Defend", 3, 1384047683)
		pause.visible = true
		await _frames(6)
		await _grab(folder, tag, "pause", size)
		pause.visible = false
		hud.set_paused(false)
	await _frames(20)
	await _grab(folder, tag, "live", size)
	# a smoke bomb in hand
	session.player.grenades.readied = Grenade.Kind.SMOKE
	await _frames(10)
	await _grab(folder, tag, "bomb_in_hand", size)
	session.player.grenades.readied = Grenade.Kind.NONE
	session.player.armament.active = 1
	await _frames(10)
	await _grab(folder, tag, "sidearm_in_hand", size)
	# you are hit: the big HIT! under the score bar; then your side is wiped out and the round's result comes up
	session.player.armament.active = 0
	session.bots_active = false
	var st: GameState = session.state
	Elimination.eliminate(session.player, 1, st.characters, session._sim.ends)
	await _frames(1)
	await _grab(folder, tag, "you_are_hit", size)
	for c in st.characters:
		if c.team == session.player.team and c != session.player:
			Elimination.eliminate(c, 1, st.characters, session._sim.ends)
	# real time from here, until the round's result card is up (it waits a moment after the round ends)
	Engine.time_scale = 1.0
	var waited_result := 0
	while not hud.round_result().is_up() and waited_result < 900:
		await process_frame
		waited_result += 1
	await _frames(20)
	await _grab(folder, tag, "round_result", size)
	session.queue_free()
	await _frames(4)
	quit(0)
