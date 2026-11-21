extends SceneTree
## Pictures of Subway's models for review (TQ1): a whole PlaySession on Subway, the play frozen, the players hidden,
## the camera put at fixed spots: round the north and south trains (outside from the platforms and the track, inside
## along the aisles, at the gangway and the cab fronts) or, with `station` after the folder, at each of the station's
## own models; each saved as `<n>-<name>.png`. Names after the folder (or after `station`) pick shots by name. Needs a
## display, so under xvfb (Forward+ on lavapipe in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/subway_pictures.gd -- <folder> [station] [shot ...]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1280, 720)
## The platforms' floor (the map file's: layout.py P), the track bed (its T) and the ticket hall's and concourse's
## floor (its C), and a standing eye over a floor.
const P := 0.9
const T := 0.0
const C := 8.9
const EYE := 1.65

## Each shot: its name, the eye, where it looks, its field of view.
const SHOTS: Array = [
	["side-quarter", Vector3(-20.0, P + EYE, -5.9), Vector3(-34.0, P + 1.0, -11.2), 70.0],
	["side-square", Vector3(-6.5, P + EYE, -5.7), Vector3(-6.5, P + 1.0, -12.0), 75.0],
	["side-door", Vector3(-10.4, P + EYE, -7.2), Vector3(-12.0, P + 1.1, -11.0), 70.0],
	["inside-aisle", Vector3(-42.6, P + EYE, -10.75), Vector3(-30.0, P + 1.3, -10.75), 75.0],
	["inside-seats", Vector3(-35.6, P + EYE, -9.9), Vector3(-36.6, P + 0.7, -12.2), 75.0],
	["inside-ceiling", Vector3(-25.0, P + 1.3, -10.75), Vector3(-19.0, P + 2.4, -10.75), 75.0],
	["inside-door", Vector3(-20.3, P + EYE, -11.6), Vector3(-19.7, P + 1.1, -9.0), 75.0],
	["gangway", Vector3(-25.6, P + EYE, -10.9), Vector3(-29.0, P + 1.2, -10.75), 75.0],
	["blank-end", Vector3(-10.0, P + EYE, -10.9), Vector3(-14.0, P + 1.2, -10.75), 75.0],
	["cab-front", Vector3(-50.5, T + 1.5, -10.0), Vector3(-44.0, P + 0.8, -10.75), 70.0],
	["cab-corner", Vector3(-48.5, P + EYE, -7.0), Vector3(-43.5, P + 0.6, -11.2), 70.0],
	["bogie", Vector3(19.0, T + 0.55, -9.5), Vector3(14.2, T + 0.35, -11.0), 70.0],
	["south-inside", Vector3(31.5, P + EYE, 10.75), Vector3(44.0, P + 1.0, 10.75), 75.0],
	["south-outer-end", Vector3(25.5, T + 1.6, 10.0), Vector3(30.0, P + 0.8, 10.75), 70.0],
	["south-cab-open", Vector3(58.6, P + EYE, 10.75), Vector3(61.0, P + 1.0, 10.75), 75.0],
	["south-side", Vector3(36.0, P + EYE, 6.0), Vector3(46.0, P + 1.0, 11.0), 70.0],
]


## The station's own models: each shot its name, the eye, where it looks, its field of view (map file positions).
const STATION: Array = [
	["escalators-top", Vector3(-9.0, C + EYE, 2.2), Vector3(2.0, C - 4.0, -0.4), 70.0],
	["escalators-foot", Vector3(13.0, P + EYE, 1.8), Vector3(2.0, P + 4.5, 0.0), 70.0],
	["ticket-gates", Vector3(-34.0, C + EYE, 3.8), Vector3(-38.7, C + 0.5, -1.0), 70.0],
	["ticket-machine", Vector3(-51.0, C + EYE, 3.0), Vector3(-54.7, C + 1.0, 5.2), 70.0],
	["kiosk", Vector3(-45.0, C + EYE, 4.6), Vector3(-47.5, C + 1.2, 8.7), 70.0],
	["kiosk-long", Vector3(-15.5, C + EYE, 3.6), Vector3(-11.4, C + 1.2, 0.0), 70.0],
	["ticket-office", Vector3(-48.6, C + EYE, -4.2), Vector3(-52.0, C + 1.3, -8.2), 70.0],
	["booking-counter", Vector3(-43.0, C + EYE, -6.0), Vector3(-45.5, C + 0.6, -9.6), 70.0],
	["help-point", Vector3(-11.0, C + EYE, -5.2), Vector3(-8.3, C + 1.1, -7.7), 70.0],
	["crowd-barrier", Vector3(-11.2, C + EYE, -2.6), Vector3(-13.7, C + 0.5, -4.6), 70.0],
	["bench-platform", Vector3(-37.4, P + EYE, -7.0), Vector3(-40.0, P + 0.4, -5.8), 70.0],
	["staff-booth", Vector3(1.0, P + EYE, -7.8), Vector3(5.0, P + 1.3, -6.6), 70.0],
	["works-hoarding", Vector3(-6.4, P + EYE, -6.6), Vector3(-2.5, P + 1.2, -8.1), 70.0],
	["skip-wagons", Vector3(-12.5, P + EYE, 7.6), Vector3(-17.0, T + 1.2, 10.8), 70.0],
	["engineering-wagon", Vector3(33.0, P + EYE, -7.4), Vector3(38.0, T + 1.2, -10.8), 70.0],
	["ballast-wagons", Vector3(52.0, T + 1.7, -10.0), Vector3(57.0, T + 1.0, -10.8), 70.0],
	["buffer-stop", Vector3(-47.2, T + 1.6, -10.4), Vector3(-51.8, T + 0.6, -10.8), 70.0],
	["platelayer-trolley", Vector3(-42.6, P + EYE, -7.6), Vector3(-45.8, T + 0.5, -10.8), 70.0],
	["tunnel-segments", Vector3(35.2, P + EYE, -6.2), Vector3(39.0, P + 0.6, -6.5), 70.0],
	["signal-cabinet", Vector3(46.0, P + EYE, -6.6), Vector3(49.0, P + 1.0, -7.0), 70.0],
	["cable-drums", Vector3(-27.0, C + EYE, -5.8), Vector3(-30.0, C + 0.8, -9.3), 70.0],
	["spiral-stair", Vector3(-29.0, P + EYE, 6.8), Vector3(-30.5, P + 2.0, 3.0), 75.0],
	["platform-stair", Vector3(23.0, C + EYE, 0.0), Vector3(32.0, C - 2.5, 0.0), 70.0],
	["lifts", Vector3(-43.6, C + EYE, 5.5), Vector3(-43.6, C + 1.0, 0.9), 70.0],
	["plant-room", Vector3(5.0, C + EYE, 3.0), Vector3(14.0, C + 0.8, -1.0), 75.0],
	["platform", Vector3(-20.0, P + EYE, 6.2), Vector3(5.0, P + 1.0, 7.5), 75.0],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://subway"
	var only := args.slice(1)
	var shots: Array = SHOTS
	if not only.is_empty() and only[0] == "station":
		shots = STATION
		only = only.slice(1)
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "subway"
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("subway_pictures: subway refused")
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
	var n := 0
	for i in shots.size():
		var shot: Array = shots[i]
		if not only.is_empty() and not only.has(shot[0]):
			continue
		camera.fov = shot[3]
		camera.look_at_from_position(shot[1], shot[2])
		for _f in 4:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%02d-%s.png" % [folder, i + 1, shot[0]])
		n += 1
	print("subway_pictures: %d pictures" % n)
	quit()
