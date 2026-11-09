extends SceneTree
## Pictures of Depot's hall shell for review (Dev 3 map models): a whole PlaySession on Depot, the play frozen, the
## camera put at fixed spots: square on to each feature bay of the hall walls (`feature_<n>.png`), beside each pillar
## (`pillar_<n>.png`), along each camouflage net (`net_<n>.png`), up into the roof (`roof_<n>.png`) and across the
## hall from high and from eye height (`hall_<n>.png`). Needs a display, so under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/hall_pictures.gd -- <folder> [map]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const EYE := 1.7


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://hall"
	var map_id := args[1] if args.size() > 1 else "depot"
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = map_id
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("hall_pictures: %s refused" % map_id)
		quit(1)
		return
	await process_frame
	session.set_physics_process(false)
	session.set_process(false)
	# the HUD and the first-person arms out of the way
	for child in session.find_children("*", "CanvasLayer", true, false):
		(child as CanvasLayer).visible = false
	# and the players, so nobody stands in a picture of the building
	for child in session.find_children("*", "", true, false):
		if child is FigureView:
			(child as Node3D).visible = false
	var camera := session._eyes.camera
	camera.fov = 75.0
	var shots: Array[Array] = []
	var props := session._props if session._props != null else \
			(session._site._props if session._site != null else null)
	if props != null:
		var placed := props.placed()
		var n := 0
		for model: StringName in [&"hall_shutter", &"hall_exit"]:
			if not placed.has(model):
				continue
			for t: Transform3D in placed[model].transforms:
				var front := (t.basis * Vector3.BACK).normalized()
				var at := t.origin + Vector3(0.0, 2.2, 0.0)
				shots.append(["feature_%d" % n, at + front * 9.0 + Vector3(0.0, -0.5, 0.0), at])
				n += 1
	var k := 0
	for b in session._map.blocks:
		if b.kind == &"pillar":
			var foot := b.center - Vector3(0.0, b.size.y * 0.5, 0.0)
			shots.append(["pillar_%d" % k, foot + Vector3(2.2, EYE, 2.6), foot + Vector3(0.0, 1.6, 0.0)])
			k += 1
	k = 0
	for b in session._map.blocks:
		if b.kind == &"net":
			var along_x := b.size.x >= b.size.z
			var side := Vector3(0.0, 0.0, 2.5) if along_x else Vector3(2.5, 0.0, 0.0)
			var end := Vector3(b.size.x * 0.5 + 1.0, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, b.size.z * 0.5 + 1.0)
			shots.append(["net_%d" % k, b.center + side + end + Vector3(0.0, EYE - b.center.y, 0.0), b.center])
			k += 1
	shots.append(["roof_0", Vector3(0.0, EYE, 0.0), Vector3(-6.0, 8.0, -14.0)])
	shots.append(["roof_1", Vector3(-20.0, EYE, 2.0), Vector3(-30.0, 7.5, 2.0)])
	shots.append(["floor_0", Vector3(0.0, EYE, -6.0), Vector3(2.5, 0.0, -3.0)])
	shots.append(["hall_0", Vector3(0.0, 5.2, 30.0), Vector3(0.0, 3.0, -36.0)])
	shots.append(["hall_1", Vector3(46.0, 6.5, -30.0), Vector3(54.0, 3.0, 10.0)])
	shots.append(["hall_2", Vector3(0.0, EYE, -6.0), Vector3(40.0, 3.0, -6.0)])
	for shot in shots:
		camera.look_at_from_position(shot[1], shot[2])
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [folder, shot[0]])
	print("hall_pictures: %d pictures" % shots.size())
	quit()
