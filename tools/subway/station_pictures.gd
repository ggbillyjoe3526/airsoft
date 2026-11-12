extends SceneTree
## Pictures of Subway's station dress for review (MT3): a whole PlaySession on Subway, the play frozen, the HUD,
## arms and players hidden, the camera at eye height at fixed spots (SHOTS), one picture each (`<n>-<name>.png`).
## At the graphics preset named (High unless one is given). For a before picture, run it in a checkout from before
## MT3. `fixtures` after the preset takes FIXTURE_SHOTS instead (SM5: the lamps and extras up close), `trains`
## TRAIN_SHOTS (SM1: the trains' models). Needs a display
## (the cloud's lavapipe Vulkan draws Forward+):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan -s \
##       res://tools/subway/station_pictures.gd -- <folder> [low|medium|high|ultra] [fixtures|trains]
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
	["departures-on-rods", Vector3(-17.0, 2.4, -6.2), Vector3(-10.75, 4.2, -7.25)],
	# TB2: the running tunnels' arches, from the track at a mouth, inside, and over the south train's roof.
	["north-tunnel-mouth", Vector3(42.0, 1.7, -10.8), Vector3(60.0, 2.6, -10.8)],
	["north-tunnel-arch", Vector3(56.0, 1.7, -10.4), Vector3(78.0, 2.6, -10.8)],
	["south-tunnel-arch", Vector3(70.0, 2.2, 9.6), Vector3(56.0, 3.0, 11.2)],
]

## SM5's: the strip lamps, the tunnel lamps, the signs, posters, clocks, bins, extinguishers, cameras, edge warnings.
const FIXTURE_SHOTS: Array[Array] = [
	["south-platform-names", Vector3(-40.0, 2.6, 7.0), Vector3(-12.0, 1.9, 12.0)],
	["north-platform-east", Vector3(18.0, 2.6, -6.4), Vector3(45.0, 1.6, -11.0)],
	["platform-clock", Vector3(-16.5, 2.5, -7.4), Vector3(-13.0, 3.3, -5.9)],
	["edge-warning", Vector3(-24.5, 2.3, -7.4), Vector3(-21.1, 0.9, -8.85)],
	["bin-extinguisher", Vector3(-33.8, 2.0, -7.5), Vector3(-37.5, 1.2, -5.6)],
	["west-passage-lamps", Vector3(-35.0, 10.6, -8.0), Vector3(-24.0, 11.6, -8.6)],
	["way-out-sign", Vector3(-24.5, 10.4, -8.6), Vector3(-28.0, 11.8, -8.25)],
	["cctv-camera", Vector3(-46.0, 2.2, -7.8), Vector3(-49.0, 3.5, -5.6)],
	["north-tunnel-lamps", Vector3(51.0, 1.7, -10.4), Vector3(76.0, 2.2, -11.8)],
	["ticket-hall-clock", Vector3(-55.0, 20.8, 6.0), Vector3(-51.0, 22.0, 9.5)],
	["strip-lamp-from-below", Vector3(-17.5, 1.7, -6.8), Vector3(-14.875, 3.85, -7.25)],
	["tunnel-lamp-close", Vector3(60.4, 2.1, -10.4), Vector3(62.0, 2.55, -12.3)],
	["trackside-posters-north", Vector3(43.0, 2.4, -8.6), Vector3(33.0, 2.4, -12.5)],
	["trackside-posters-south", Vector3(-41.0, 2.3, 7.4), Vector3(-34.0, 2.4, 12.5)],
	["escalator-posters", Vector3(-36.5, 19.85, 0.0), Vector3(-24.0, 13.9, -1.0)],
	["departure-board", Vector3(-15.0, 2.3, -6.6), Vector3(-10.75, 3.45, -7.25)],
	["line-map", Vector3(-28.5, 2.5, -8.4), Vector3(-28.5, 2.5, -5.5)],
	["concourse-way-out", Vector3(-11.0, 10.6, 1.0), Vector3(-18.0, 12.2, 0.0)],
	["hall-notices", Vector3(-51.5, 20.5, 6.6), Vector3(-51.5, 20.7, 10.0)],
	["lower-hall-info", Vector3(16.5, 2.6, -1.0), Vector3(22.0, 2.5, 2.4)],
]
## The trains' pictures (SM1), with `trains` as the third argument instead of the station's.
const TRAIN_SHOTS: Array[Array] = [
	["north-train-from-platform", Vector3(-19.0, 2.6, -6.2), Vector3(-30.0, 1.9, -9.3)],
	["north-train-along-platform", Vector3(-41.0, 2.6, -6.6), Vector3(0.0, 2.0, -9.4)],
	["north-train-inside", Vector3(-42.6, 2.6, -10.75), Vector3(-30.0, 1.9, -10.75)],
	["north-gangway", Vector3(-23.0, 2.6, -10.2), Vector3(-34.0, 1.8, -10.9)],
	["north-blank-end", Vector3(-5.0, 2.6, -11.2), Vector3(-14.0, 1.7, -10.6)],
	["north-cab-front", Vector3(-48.6, 1.5, -9.9), Vector3(-44.0, 1.3, -10.75)],
	["north-joint-from-platform", Vector3(-27.0, 2.5, -7.4), Vector3(-29.0, 1.9, -9.0)],
	["south-train-from-platform", Vector3(41.0, 2.6, 6.4), Vector3(36.0, 1.9, 9.2)],
	["south-train-inside", Vector3(31.0, 2.6, 10.3), Vector3(44.0, 1.9, 10.9)],
	["south-cab-open", Vector3(65.0, 1.6, 10.0), Vector3(60.0, 1.3, 10.75)],
	["south-outer-end", Vector3(26.0, 1.5, 10.2), Vector3(30.0, 1.1, 10.75)],
	["tool-cart", Vector3(37.4, 2.3, 9.7), Vector3(39.9, 1.5, 10.75)],
	["south-cab-wheels", Vector3(62.6, 0.55, 9.6), Vector3(59.0, 0.4, 10.75)],
	["north-cab-wheels", Vector3(-44.7, 0.6, -9.4), Vector3(-42.3, 0.35, -10.75)],
	["south-bogie-close", Vector3(59.7, 0.5, 9.3), Vector3(57.6, 0.35, 10.75)],
	["south-outer-end-wheels", Vector3(27.4, 0.55, 9.7), Vector3(31.0, 0.4, 10.75)],
	["north-car-two-inside", Vector3(-15.0, 2.6, -10.75), Vector3(-28.0, 1.9, -10.75)],
	["north-window-close", Vector3(-35.2, 2.5, -7.4), Vector3(-36.6, 2.1, -11.0)],
	["south-looking-out", Vector3(46.5, 2.5, 11.9), Vector3(44.0, 2.2, 6.5)],
	["north-cab-from-platform-end", Vector3(-50.0, 2.6, -7.0), Vector3(-44.0, 1.8, -10.75)],
	["north-east-cab", Vector3(24.0, 2.0, -11.0), Vector3(16.0, 1.6, -10.75)],
	["south-cab-down-tunnel", Vector3(72.0, 1.8, 10.75), Vector3(60.0, 1.4, 10.75)],
	["north-cab-trackside-corner", Vector3(-45.5, 1.4, -12.2), Vector3(-30.0, 1.4, -12.4)],
	["south-cab-car-under-arch", Vector3(48.0, 2.5, 10.75), Vector3(59.5, 2.0, 10.75)],
	["south-tunnel-over-cab", Vector3(66.0, 3.0, 11.8), Vector3(56.0, 2.6, 10.2)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://station"
	var preset := StringName(args[1]) if args.size() > 1 else &"high"
	var shots: Array[Array] = SHOTS
	if args.size() > 2:
		shots = FIXTURE_SHOTS if args[2] == "fixtures" else TRAIN_SHOTS if args[2] == "trains" else SHOTS
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
	for i in shots.size():
		var shot: Array = shots[i]
		camera.look_at_from_position(shot[1], shot[2])
		for _f in 4:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%02d-%s.png" % [folder, i + 1, shot[0]])
	print("station_pictures: %d pictures" % shots.size())
	quit()
