extends SceneTree
## Pictures of the Range's props in the game for review (RM2): a whole PlaySession on the Range, the play frozen and
## the players hidden, the camera put at fixed spots by the backstop's sandbag line, the firing point's low wall, the
## site toilet and the water tote, each named after what it shows (`backstop_line.png`, ...). Needs a display, so
## under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/range_pictures.gd -- <folder> [name...]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
## Each shot: its name, the camera's spot and the point it looks at (absolute, m).
const SHOTS: Array = [
	["backstop_line", Vector3(-2.0, 1.7, -54.0), Vector3(0.0, 0.5, -65.4)],
	["backstop_near", Vector3(2.0, 1.4, -62.6), Vector3(3.6, 0.45, -64.8)],
	["firing_wall", Vector3(3.0, 1.5, 1.2), Vector3(4.6, 0.45, 3.4)],
	["firing_wall_end", Vector3(7.4, 1.3, 2.0), Vector3(5.4, 0.45, 3.4)],
	["toilet", Vector3(-8.4, 1.6, 3.4), Vector3(-10.4, 1.2, 5.4)],
	["tote", Vector3(8.4, 1.5, 4.6), Vector3(10.4, 0.5, 5.4)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://range"
	var only := args.slice(1)
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "range"
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("range_pictures: the range refused")
		quit(1)
		return
	await process_frame
	session.set_physics_process(false)
	session.set_process(false)
	for child in session.find_children("*", "CanvasLayer", true, false):
		(child as CanvasLayer).visible = false
	for child in session.find_children("*", "", true, false):
		if child is FigureView:
			(child as Node3D).visible = false
	var camera := session._eyes.camera
	camera.fov = 75.0
	var n := 0
	for shot: Array in SHOTS:
		if not only.is_empty() and not only.has(shot[0]):
			continue
		camera.look_at_from_position(shot[1], shot[2])
		for i in 3:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [folder, shot[0]])
		n += 1
	print("range_pictures: %d pictures" % n)
	quit()
