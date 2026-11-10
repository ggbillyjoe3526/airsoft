extends SceneTree
## Pictures of Dev › Retro filter (RF1) in a real match, for review: a whole PlaySession with a bot playing you (the
## smoke test's autopilot), stepped one tick and one rendered frame at a time; at each of the named match times the
## same frame is saved with the filter off (`<map>_<n>_off.png`) and on (`<map>_<n>_on.png`), so a pair differs only
## in the filter. Needs a display, so under xvfb (Forward+ on lavapipe where the cloud has Vulkan; without it Godot falls
## back to the compatibility renderer, OpenGL on llvmpipe, as it did for RF1's pictures):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/retro_pictures.gd \
##       -- <folder> [map] [seconds,seconds,...]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const SECONDS: Array[float] = [4.0, 9.0, 16.0, 26.0]
## Rendered frames for the filter to settle after it is switched (its node is added a frame late).
const SETTLE := 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://retro"
	var map_id := args[1] if args.size() > 1 else "depot"
	var times: Array[float] = []
	if args.size() > 2:
		for t: String in args[2].split(","):
			times.append(t.to_float())
	else:
		times.assign(SECONDS)
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = map_id
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("retro_pictures: %s refused" % map_id)
		quit(1)
		return
	await process_frame
	session.set_physics_process(false)
	session.set_process(false)
	var shot := 0
	var last := roundi(times.max() / PlaySession.TICK)
	for i: int in last + 1:
		session._physics_process(PlaySession.TICK)
		# The view as the bot playing you aims (the autopilot leaves the input's view where it was).
		var me := session.state.characters[PlaySession.PLAYER_ID]
		session._input.view_yaw = me.yaw
		session._input.view_pitch = me.pitch
		session._process(PlaySession.TICK)
		await RenderingServer.frame_post_draw
		if shot >= times.size() or i != roundi(times[shot] / PlaySession.TICK):
			continue
		_save(folder, "%s_%d_off" % [map_id, shot])
		_switch(session, true)
		for f: int in SETTLE:
			session._process(0.0)
			await RenderingServer.frame_post_draw
		_save(folder, "%s_%d_on" % [map_id, shot])
		_switch(session, false)
		for f: int in SETTLE:
			session._process(0.0)
			await RenderingServer.frame_post_draw
		shot += 1
	print("retro_pictures: %d pairs" % shot)
	quit()


## The Dev filter on or off.
func _switch(session: PlaySession, on: bool) -> void:
	session.settings.dev.retro_filter = on
	session.settings.changed.emit()


func _save(folder: String, file: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, file])
