extends SceneTree
## Pictures of an indoor field's roof lamps as real lights (Settings › Graphics › Lamp light) for review: a whole
## PlaySession on the map at one graphics preset, the play frozen, the camera at fixed spots in the hall
## (`<preset>_<n>.png`), the figures left where they start so their shadows show. Needs a display, so under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/lamp_pictures.gd -- <folder> <preset> [map]
## Dev only: tools/ never ships. The software renderer the cloud has is slow, so give it a few minutes.

const SIZE := Vector2i(1600, 900)
const EYE := 1.7
## Frames drawn before each picture, so the bounce light and the fog settle.
const SETTLE_FRAMES := 24


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://lamps"
	var preset := StringName(args[1]) if args.size() > 1 else &"ultra"
	var map_id := args[2] if args.size() > 2 else "depot"
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var settings := Settings.new(PlayTuning.new())
	settings.graphics_choice = preset
	GraphicsApply.apply_settings(settings, root)
	var session := PlaySession.new()
	session.settings = settings
	session.map_id = map_id
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("lamp_pictures: %s refused" % map_id)
		_quit(1)
		return
	await process_frame
	session.set_physics_process(false)
	session.set_process(false)
	for child in session.find_children("*", "CanvasLayer", true, false):
		(child as CanvasLayer).visible = false
	var camera := session._eyes.camera
	camera.fov = 75.0
	var shots: Array[Array] = [
		[Vector3(-3.0, EYE, 9.0), Vector3(-6.0, 1.0, -14.0)],
		[Vector3(0.0, EYE, -6.0), Vector3(40.0, 1.5, -6.0)],
		[Vector3(0.0, 5.2, 30.0), Vector3(0.0, 1.0, -36.0)],
		[Vector3(-20.0, EYE, 2.0), Vector3(-30.0, 3.0, 2.0)],
		[Vector3(46.0, 6.5, -30.0), Vector3(54.0, 1.0, 10.0)],
	]
	var n := 0
	for shot in shots:
		camera.look_at_from_position(shot[0], shot[1])
		for i in SETTLE_FRAMES:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%d.png" % [folder, preset, n])
		n += 1
	print("lamp_pictures: %d pictures at %s" % [n, preset])
	_quit(0)


## Godot doesn't always exit after quit() with a session this size under xvfb, so the process ends itself.
func _quit(code: int) -> void:
	quit(code)
	OS.kill(OS.get_process_id())
