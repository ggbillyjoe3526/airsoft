extends SceneTree
## Pictures of Kingsmere's lifts for review (MT2): a whole PlaySession on Kingsmere, the play frozen, the cars posed
## and the camera put at fixed spots: the two lift doors from the ticket hall (the west car open there, the east's
## doorway shut), the west car's doors half open, inside the west car looking at its panel (the platforms called), the
## concourse's two doors, and the platforms' lift landing with the east car open. Needs a display, so under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/lift_pictures.gd -- <folder> [--graphics=high]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const EYE := 1.62
## Frames drawn before each picture (as eye_pictures.gd): the light (SDFGI) and the cars' reflection probes settling,
## longer before the first.
const SETTLE := 40
const FIRST_SETTLE := 60


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://lifts"
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.settings.graphics_forced = GraphicsPick.forced(args)
	session.map_id = "kingsmere"
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("lift_pictures: kingsmere refused")
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
	var view := session._lifts
	var lifts := session.state.lifts
	var specs := session._map.lifts
	var west := specs[0]
	var east := specs[1]
	var cfg := session._tuning.lifts
	var hall := west.stops[2]
	var mid := Vector3((west.well.get_center().x + east.well.get_center().x) * 0.5, 0.0, 0.0)
	var shots: Array[Array] = []
	# [name, camera, looking at, pose: [west y, west stop, west doors, west calls, east y, east stop, east doors]]
	shots.append(["1-hall-both-doors", Vector3(mid.x - 1.0, hall + EYE, -5.5), Vector3(mid.x, hall + 1.2, -1.2),
			[hall, 2, 1.0, 0, east.stops[0], 0, 1.0]])
	shots.append(["2-hall-west-doors-half-open", west.landing_point(2, cfg) + Vector3(0.6, EYE, -1.8),
			west.door_center(2), [hall, 2, 0.5, 0, east.stops[0], 0, 1.0]])
	shots.append(["3-inside-west-car-panel", west.car_point(hall) + Vector3(-0.5, EYE, 0.6),
			west.panel_button(1, hall, cfg), [hall, 2, 1.0, 1, east.stops[0], 0, 1.0]])
	shots.append(["4-concourse-doors", Vector3(mid.x - 0.5, west.stops[1] + EYE, -4.6),
			Vector3(mid.x, west.stops[1] + 1.1, -1.2), [hall, 2, 1.0, 0, east.stops[0], 0, 1.0]])
	shots.append(["5-platforms-east-car-open", east.landing_point(0, cfg) + Vector3(-1.2, EYE, -2.2),
			east.car_point(east.stops[0]) + Vector3(0.0, 1.2, 0.0), [hall, 2, 1.0, 0, east.stops[0], 0, 1.0]])
	for shot in shots:
		var pose: Array = shot[3]
		_pose(lifts, 0, pose[0], pose[1], pose[2], pose[3])
		_pose(lifts, 1, pose[4], pose[5], pose[6], 0)
		view.refresh(lifts, 1.0)
		camera.look_at_from_position(shot[1], shot[2])
		for i in FIRST_SETTLE if shot == shots[0] else SETTLE:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [folder, shot[0]])
	print("lift_pictures: %d pictures" % shots.size())
	quit()


func _pose(lifts: LiftState, i: int, y: float, stop: int, doors: float, calls: int) -> void:
	lifts.y[i] = y
	lifts.prev_y[i] = y
	lifts.stop[i] = stop
	lifts.doors[i] = doors
	lifts.calls[i] = calls
	lifts.phase[i] = LiftState.Phase.OPEN if doors >= 1.0 else LiftState.Phase.OPENING
