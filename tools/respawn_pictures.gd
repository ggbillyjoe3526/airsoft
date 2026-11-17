extends SceneTree
## Pictures of the respawn panel (RS1): you are out in an Attack / Defend round on Depot with a respawn coming, as an
## attacker (the start area and your end's two forward spawns, the second picked) and with an enemy near the first
## (dimmed, "ENEMY NEAR"), then as a defender (the start area only). Grabbed whole to
## `<folder>/<tag>_<name>_<W>x<H>.png`. Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 \
##       -s res://tools/respawn_pictures.gd -- <folder> <tag> <width> <height>
## Dev only: tools/ never ships.

const SETTLE := 12


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(folder: String, tag: String, name: String, size: Vector2i) -> void:
	await _frames(3)
	var path := "%s/%s_%s_%dx%d.png" % [folder, tag, name, size.x, size.y]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[respawn_pictures] ", path)


func _show(session: PlaySession, rs: RoundState, attackers: int, pick: int, seconds: float) -> void:
	var you := session.player
	rs.attackers = attackers
	rs.phase = RoundState.Phase.LIVE
	rs.hold = 0.0
	you.status = Character.Status.OUT
	you.respawn_left = seconds
	you.spawn_pick = pick
	session._spawn_pick = pick
	session._hud.update(session.state, 0.0, 0.0)
	await _frames(3)


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
	Engine.time_scale = 0.0
	var st: GameState = session.state
	var rs := st.round_state
	var you := session.player
	await _show(session, rs, you.team, 2, 7.2)
	await _grab(folder, tag, "attacker_pick_second", size)
	# an enemy stands by your end's first forward spawn: it dims and says so
	var front: ForwardSpawn = session._sim.ends[you.end].forward[0]
	for c in st.characters:
		if c.team != you.team:
			c.position = front.centre
			break
	await _show(session, rs, you.team, 1, 4.6)
	await _grab(folder, tag, "attacker_enemy_near", size)
	await _show(session, rs, 1 - you.team, 0, 9.1)
	await _grab(folder, tag, "defender_start_only", size)
	session.queue_free()
	await _frames(4)
	quit(0)
