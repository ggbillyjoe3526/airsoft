extends SceneTree
## Pictures of an Attack / Defend round start as a defender (BP8, note 21): the DEFEND banner, the countdown, the flag
## gauge and warning, with and without the scoreboard held, and the weapon rail with its notes up. Grabbed whole to
## `<folder>/<tag>_<name>_<W>x<H>.png`. Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 \
##       -s res://tools/hud_defend_pictures.gd -- <folder> <tag> <width> <height>
## Dev only: tools/ never ships.

const SETTLE := 12


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(folder: String, tag: String, name: String, size: Vector2i) -> void:
	await _frames(2)
	var path := "%s/%s_%s_%dx%d.png" % [folder, tag, name, size.x, size.y]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[hud_defend_pictures] ", path)


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
	session.mode = MatchOptions.MODE_ATTACK_DEFEND
	session.bots_active = false
	Engine.time_scale = 0.02
	root.add_child(session)
	await _frames(SETTLE)
	var hud: Hud = session._hud
	var st: GameState = session.state
	var rs := st.round_state
	# you defend: the other side attacks and is raising the flag
	rs.attackers = 1 - session.player.team
	rs.flag.status = FlagState.Status.RAISING
	rs.flag.progress = 0.4
	st.events.clear()
	st.events.add(GameEvent.Kind.ROUND_START).value = 1
	st.events.add(GameEvent.Kind.ROUND_COUNT).value = 2
	hud.on_tick(st)
	await _frames(6)
	await _grab(folder, tag, "defend_countdown", size)
	Input.action_press(&"scoreboard")
	await _frames(8)
	await _grab(folder, tag, "defend_board_held", size)
	Input.action_release(&"scoreboard")
	await _frames(4)
	# the notes over the weapon rail: the hop-up dial and a reload
	hud._replica.show_hop("HOP-UP 60%")
	hud._replica._status.text = "RELOADING"
	hud._replica._status.visible = true
	await _frames(4)
	await _grab(folder, tag, "rail_with_notes", size)
	session.queue_free()
	await _frames(4)
	quit(0)
