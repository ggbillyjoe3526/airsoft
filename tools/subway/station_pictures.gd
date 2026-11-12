extends SceneTree
## Pictures of Subway's station dress for review (MT3): a whole PlaySession on Subway, the play frozen, the HUD,
## arms and players hidden, the camera at eye height at fixed spots (SHOTS), one picture each (`<n>-<name>.png`).
## At the graphics preset named (High unless one is given). For a before picture, run it in a checkout from before
## MT3. Needs a display (the cloud's lavapipe Vulkan draws Forward+):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan -s \
##       res://tools/subway/station_pictures.gd -- <folder> [low|medium|high|ultra]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
## Each picture: its name, the eye and the point it looks at (the game's metres: track 0, platforms 0.9, landing 4.9,
## concourse 8.9, ticket hall 18.9).
const SHOTS: Array[Array] = [
	["ticket-hall", Vector3(-60.0, 20.6, 1.0), Vector3(-44.0, 19.6, -1.0)],
	["escalators-down", Vector3(-38.6, 20.6, 2.0), Vector3(-24.0, 12.5, 2.0)],
	["spiral-stair", Vector3(-39.0, 20.6, -3.4), Vector3(-41.0, 15.5, -8.0)],
	["concourse", Vector3(-17.0, 10.6, 1.0), Vector3(-6.0, 10.0, -5.0)],
	["north-platform", Vector3(-50.0, 2.6, -7.0), Vector3(30.0, 2.2, -8.0)],
	["south-train-inside", Vector3(31.0, 2.6, 10.75), Vector3(44.0, 2.0, 10.75)],
	["stair-to-landing", Vector3(27.5, 10.6, 0.0), Vector3(36.0, 6.0, 0.0)],
	["south-tunnel", Vector3(80.0, 1.7, 10.8), Vector3(62.0, 1.2, 10.8)],
	["south-platform-train", Vector3(18.0, 2.6, 7.6), Vector3(44.0, 1.8, 9.5)],
	["south-track", Vector3(-28.0, 1.7, 10.0), Vector3(-6.0, 0.4, 10.75)],
	["north-train-inside", Vector3(-42.0, 2.6, -10.75), Vector3(-30.0, 2.0, -10.75)],
	["lower-hall", Vector3(11.0, 2.6, 2.0), Vector3(21.0, 1.6, -2.0)],
	["lifts-ticket-hall", Vector3(-43.5, 20.6, -6.0), Vector3(-43.5, 19.9, -0.9)],
	# TB1: across the south platform's tunnel to the trackside wall, and down it to the tunnel mouth at its east end.
	["south-platform-across", Vector3(-47.0, 2.5, 5.9), Vector3(-38.0, 3.9, 12.5)],
	["north-platform-east-end", Vector3(24.0, 2.5, -6.2), Vector3(50.0, 3.4, -9.5)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://station"
	var preset := StringName(args[1]) if args.size() > 1 else &"high"
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.settings.graphics_forced = preset
	session.map_id = "subway"
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("station_pictures: subway refused")
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
	for i in SHOTS.size():
		var shot: Array = SHOTS[i]
		camera.look_at_from_position(shot[1], shot[2])
		for _f in 4:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%02d-%s.png" % [folder, i + 1, shot[0]])
	print("station_pictures: %d pictures" % SHOTS.size())
	quit()
