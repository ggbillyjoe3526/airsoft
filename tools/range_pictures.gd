extends SceneTree
## Pictures of the Range's props in the game for review (RM2): a whole PlaySession on the Range, the play frozen and
## the players hidden, the camera put at fixed spots by the backstop's sandbag line, the firing point's low wall, the
## site toilet and the water tote, each named after what it shows (`backstop_line.png`, ...). Needs a display, so
## under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/range_pictures.gd -- <folder> [name...]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
## Frames drawn at each spot before its picture: the scene's bounced light (SDFGI, High and Ultra) and eye adaptation
## need a few dozen to settle.
const FRAMES := 40
## Each shot: its name, the camera's spot and the point it looks at (absolute, m).
const SHOTS: Array = [
	["backstop_line", Vector3(-2.0, 1.7, -54.0), Vector3(0.0, 0.5, -65.4)],
	["backstop_near", Vector3(2.0, 1.4, -62.6), Vector3(3.6, 0.45, -64.8)],
	["firing_wall", Vector3(3.0, 1.5, 1.2), Vector3(4.6, 0.45, 3.4)],
	["firing_wall_end", Vector3(7.4, 1.3, 2.0), Vector3(5.4, 0.45, 3.4)],
	["toilet", Vector3(-8.4, 1.6, 3.4), Vector3(-10.4, 1.2, 5.4)],
	["tote", Vector3(8.4, 1.5, 4.6), Vector3(10.4, 0.5, 5.4)],
	["downrange", Vector3(0.0, 1.65, 2.0), Vector3(0.0, 1.2, -40.0)],
	["downrange_left", Vector3(4.0, 1.65, 1.0), Vector3(-9.0, 1.0, -25.0)],
	["midrange", Vector3(2.0, 1.65, -28.0), Vector3(-3.0, 1.2, -60.0)],
	["uprange", Vector3(0.0, 1.8, -45.0), Vector3(0.0, 1.2, 6.0)],
	["firing_point", Vector3(-3.0, 1.8, -6.0), Vector3(2.0, 1.0, 5.0)],
	["overview", Vector3(9.0, 7.0, 4.0), Vector3(-2.0, 0.0, -40.0)],
	["floor_close", Vector3(1.5, 1.6, -8.0), Vector3(-1.0, 0.0, -13.0)],
	["wall_close", Vector3(-6.0, 1.6, -18.0), Vector3(-11.0, 1.2, -22.0)],
	["targets_close", Vector3(-3.5, 1.6, -5.0), Vector3(-5.0, 0.9, -10.0)],
	["bench", Vector3(-4.6, 1.7, 2.6), Vector3(-2.5, 0.7, 0.4)],
	["chrono", Vector3(-2.6, 1.7, 3.6), Vector3(-4.0, 1.1, 5.8)],
	["sky_east", Vector3(8.0, 3.2, -16.0), Vector3(50.0, 7.0, -24.0)],
	["sky_west", Vector3(-8.0, 3.2, -24.0), Vector3(-40.0, 8.0, -34.0)],
	["sky_north_east", Vector3(8.0, 3.2, -12.0), Vector3(60.0, 5.0, 12.0)],
	["sky_south_east", Vector3(6.0, 3.2, -40.0), Vector3(50.0, 7.0, -80.0)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var forced := GraphicsPick.forced(args)
	var frames := FRAMES
	for a: String in args:
		if a.begins_with("--frames="):
			frames = maxi(1, a.trim_prefix("--frames=").to_int())
	var rest: Array[String] = []
	for a: String in args:
		if not a.begins_with("--"):
			rest.append(a)
	var folder: String = rest[0] if not rest.is_empty() else "user://range"
	var only := rest.slice(1)
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.settings.graphics_forced = forced if forced != &"" else GraphicsTable.DEFAULT_PRESET
	session.map_id = "range"
	session.practice = true
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
		for i in frames:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [folder, shot[0]])
		n += 1
	print("range_pictures: %d pictures" % n)
	quit()
