extends SceneTree
## Pictures of Dev › Lasers (LZ1) in a real match, for review: a whole PlaySession with Lasers on and a bot playing you
## (the smoke test's autopilot), stepped one tick and one rendered frame at a time, saving the frames where your own
## beam is on (`own_<n>.png`) and where someone else's is (`others_<n>.png`), at most COUNT of each at least GAP frames
## apart, and with `strip` a row of STRIP frames from your first full-auto or burst shot on (`strip_<n>.png`), which
## shows the beam held or flashing. Someone else's beam counts only with its shooter and its end in the view. Needs a
## display, so under xvfb (Forward+ on lavapipe in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/laser_pictures.gd -- <folder> [map] [strip]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const COUNT := 8
const GAP := 20
const STRIP := 12
## Match time (s) at most, and from when frames count (the bots leave their spawns first).
const SECONDS := 90.0
const WARM_SECONDS := 4.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://lasers"
	var map_id := args[1] if args.size() > 1 else "depot"
	var strip := args.has("strip")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.settings.dev.lasers = true
	session.map_id = map_id
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("laser_pictures: %s refused" % map_id)
		quit(1)
		return
	await process_frame
	session.set_physics_process(false)
	session.set_process(false)
	var own := 0
	var others := 0
	var last_saved := -GAP
	var strip_left := STRIP if strip else 0
	var strip_n := 0
	var warm := roundi(WARM_SECONDS / PlaySession.TICK)
	for i in roundi(SECONDS / PlaySession.TICK):
		session._physics_process(PlaySession.TICK)
		# The view as the bot playing you aims (the autopilot leaves the input's view where it was).
		var me := session.state.characters[PlaySession.PLAYER_ID]
		session._input.view_yaw = me.yaw
		session._input.view_pitch = me.pitch
		session._process(PlaySession.TICK)
		await RenderingServer.frame_post_draw
		if i < warm:
			continue
		var player := session.state.characters[PlaySession.PLAYER_ID]
		var mode := player.armament.fire_mode()
		var mine := session._lasers._left[PlaySession.PLAYER_ID] > 0.0
		if strip_left > 0 and (strip_n > 0 or (mine and mode != ReplicaConfig.FireMode.SEMI)):
			_save(folder, "strip_%02d" % strip_n)
			strip_n += 1
			strip_left -= 1
			continue
		if i - last_saved < GAP or session._lasers.shown_count() == 0:
			continue
		if not mine and not _other_in_view(session):
			continue
		if mine and own < COUNT:
			_save(folder, "own_%d" % own)
			own += 1
			last_saved = i
		elif not mine and others < COUNT:
			_save(folder, "others_%d" % others)
			others += 1
			last_saved = i
		if own >= COUNT and others >= COUNT and strip_left == 0:
			break
	print("laser_pictures: %d own, %d others, %d strip" % [own, others, strip_n])
	quit()


## Whether someone else's beam is on with both its shooter and its end in the view.
func _other_in_view(session: PlaySession) -> bool:
	var camera := session._eyes.camera
	for c in session.state.characters:
		if c.id == PlaySession.PLAYER_ID or session._lasers._left[c.id] <= 0.0:
			continue
		if camera.is_position_in_frustum(c.position + Vector3.UP) \
				and camera.is_position_in_frustum(session._lasers._ends[c.id]):
			return true
	return false


func _save(folder: String, file: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, file])
