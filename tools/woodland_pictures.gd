extends SceneTree
## Pictures of Woodland's structures for review (WG3, Dev 3 map models): a whole PlaySession on Woodland, the play
## frozen and the players hidden, the camera put at fixed spots round the watch tower, the North bridge, the Sawmill's
## shed, the huts' roofs and the palisade, each named after what it shows (`tower_stair.png`, ...); a spot's height is
## over the ground under it, or absolute where it says. Needs a display, so under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/woodland_pictures.gd -- <folder> [name...]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const EYE := 1.7
## Each shot: its name, the camera's spot (x, height, z: the height over the ground, or absolute with `abs`), the
## point it looks at (absolute), and whether its height is absolute.
const SHOTS: Array = [
	["tower_quarter", Vector3(29.0, EYE, -33.0), Vector3(20.0, 3.4, -43.0), false],
	["tower_stair", Vector3(32.0, EYE, -44.5), Vector3(21.0, 3.8, -43.0), false],
	["tower_under", Vector3(23.0, EYE, -38.0), Vector3(19.0, 3.3, -43.0), false],
	["tower_up", Vector3(19.0, EYE, -43.0), Vector3(19.6, 9.0, -43.4), false],
	["tower_up_side", Vector3(23.5, EYE, -46.5), Vector3(19.0, 4.3, -43.0), false],
	["tower_deck", Vector3(20.2, 5.9, -42.0), Vector3(8.0, 4.0, -52.0), true],
	["tower_far", Vector3(40.0, EYE, -50.0), Vector3(19.0, 3.0, -43.0), false],
	["tower_west", Vector3(8.0, EYE, -50.0), Vector3(18.0, 4.0, -43.0), false],
	["tower_north", Vector3(16.0, EYE, -55.0), Vector3(19.0, 4.2, -43.0), false],
	["tower_corner", Vector3(14.5, 5.0, -47.5), Vector3(17.0, 4.8, -45.0), true],
	["tower_deck_east", Vector3(17.6, 5.9, -43.0), Vector3(26.0, 3.5, -43.0), true],
	["bridge_side", Vector3(-1.0, EYE, -33.5), Vector3(-1.0, 4.4, -41.5), false],
	["bridge_on", Vector3(-7.0, EYE, -41.5), Vector3(2.2, 4.8, -41.5), false],
	["bridge_far", Vector3(18.0, EYE, -34.0), Vector3(-1.0, 4.6, -41.5), false],
	["bridge_low", Vector3(-1.0, 3.3, -36.0), Vector3(-1.0, 3.9, -41.5), true],
	["bridge_under", Vector3(-0.2, 3.2, -39.6), Vector3(-1.6, 4.15, -41.5), true],
	["fort_window", Vector3(53.8, EYE, -53.0), Vector3(53.8, 3.9, -46.0), false],
	["shed_quarter", Vector3(43.0, EYE, 27.0), Vector3(56.0, 1.8, 36.0), false],
	["shed_inside", Vector3(52.5, EYE, 35.0), Vector3(60.0, 2.9, 38.5), false],
	["shed_far", Vector3(68.0, EYE, 27.0), Vector3(56.0, 1.8, 36.0), false],
	["roof_box_hut", Vector3(52.0, 9.0, -50.0), Vector3(59.5, 4.8, -41.5), true],
	["roof_cabin", Vector3(33.0, 8.0, 6.0), Vector3(27.0, 4.5, -0.5), true],
	["roof_inside", Vector3(36.6, EYE, 6.4), Vector3(40.6, 2.6, 9.8), false],
	["palisade_boundary", Vector3(-80.0, EYE, 4.0), Vector3(-88.0, 1.8, -2.0), false],
	["palisade_camp", Vector3(-62.0, EYE, 6.0), Vector3(-72.0, 1.5, -2.0), false],
	["palisade_close", Vector3(-69.5, EYE, -6.0), Vector3(-72.0, 1.6, -9.0), false],
	# WS1: the stream, the woodpiles' log ends, the far treelines and a thicket's spruces
	["stream_bridge", Vector3(-7.0, EYE, -31.0), Vector3(-0.5, 1.6, -42.0), false],
	["stream_bed", Vector3(-1.0, 3.0, -35.5), Vector3(-4.0, 0.2, -24.0), true],
	["stream_under_bridge", Vector3(-4.5, 0.2, -27.0), Vector3(-1.0, -1.4, -46.0), true],
	["stream_ridge", Vector3(-18.0, EYE, -42.0), Vector3(2.0, -0.5, -41.5), false],
	["bridge_side", Vector3(-3.0, -0.4, -33.0), Vector3(-1.0, -0.9, -41.5), true],
	["bridge_west_end", Vector3(-9.0, EYE, -43.0), Vector3(-1.0, -0.6, -41.5), false],
	["bridge_under", Vector3(-0.5, -1.2, -37.0), Vector3(-1.0, -1.4, -41.5), true],
	["stream_ford", Vector3(1.0, EYE, 7.0), Vector3(10.0, -1.6, 0.0), false],
	["stream_down", Vector3(13.5, EYE, 14.0), Vector3(8.5, -1.6, 30.0), false],
	["stream_culvert", Vector3(9.5, EYE, 37.0), Vector3(8.0, -1.4, 47.0), false],
	["woodpile_quarter", Vector3(-30.0, EYE, 3.0), Vector3(-34.5, 1.0, 8.0), false],
	["woodpile_close", Vector3(-32.6, 1.3, 7.2), Vector3(-34.0, 0.9, 9.0), false],
	["logstacks_b", Vector3(31.5, EYE, 31.0), Vector3(29.7, 1.0, 35.9), false],
	["treeline_west", Vector3(-78.0, EYE, 30.0), Vector3(-100.0, 7.0, 26.0), false],
	["treeline_north", Vector3(-20.0, EYE, -50.0), Vector3(-20.0, 9.0, -75.0), false],
	["treeline_east", Vector3(84.0, EYE, -40.0), Vector3(100.0, 8.0, -20.0), false],
	["thicket_spruces", Vector3(50.0, EYE, 7.0), Vector3(50.0, 3.0, 20.0), false],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://woodland"
	var only := args.slice(1)
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "woodland"
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("woodland_pictures: woodland refused")
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
	var terrain := session._map.terrain
	var n := 0
	for shot: Array in SHOTS:
		if not only.is_empty() and not only.has(shot[0]):
			continue
		var at: Vector3 = shot[1]
		if not shot[3]:
			at.y += terrain.height_clamped(at.x, at.z) if terrain != null else 0.0
		camera.look_at_from_position(at, shot[2])
		for i in 3:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [folder, shot[0]])
		n += 1
	print("woodland_pictures: %d pictures" % n)
	quit()
