extends SceneTree
## Pictures of the replica in your hands in first person (BP8), for review: a field drawn at eye height on High by day
## (as tools/render_held_bomb.gd draws it), the replica as a match draws it (ReplicaView with your arms and its optic's
## glass), at the hip, raised, or part way through an inspect, and optionally one of your own BBs just fired (BBView),
## each shot to `<folder>/<name>.jpg`. Needs a display, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . -s res://tools/render_replica_view.gd \
##       -- <folder> <name>:<replica id>:<parts>:<aim>:<inspect>[:<bb seconds>[:<turn>]] ...
## `parts` is `-` or pool ids by slot joined with `+` (`optic=000025+laser=000005`); `aim` the sight's raise (0..1);
## `inspect` the share of an inspect (-1: none); `bb seconds` draws one BB that long after the shot (none if left out),
## fired `turn` degrees left of the view (a turn the view made since the tick: `:<bb seconds>:<turn>`).
## A shot named `part_<name>` instead draws one part alone from a parts file, close up: `part_<name>:<file>:<node>:
## <x>,<y>,<z>:<x>,<y>,<z>` (camera place and the point it looks at, in the part's space, m). Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const QUALITY := 0.92
const SETTLE_FRAMES := 30
const DT := 1.0 / 60.0
const MAP := "depot"
const SPOT := Vector4(0.0, 0.0, -90.0, 2.0)
## The part close-ups' field of view (deg) and how far their camera's near plane reaches (m).
const PART_FOV := 40.0
const PART_NEAR := 0.005


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("render_replica_view: give a folder and at least one shot")
		quit(1)
		return
	var folder := args[0].trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(folder)
	var play := PlayTuning.load_default()
	var tuning := SimTuning.load_default()
	var map := MapData.load_map(MAP, play.map_style, tuning.rounds.team_size)
	var port := SubViewport.new()
	port.size = SIZE
	port.msaa_3d = Viewport.MSAA_4X
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var sun := LightingConfig.for_map(play.lighting, null, map, LightingConfig.DAY)
	var level := MapLevel.new()
	port.add_child(level)
	level.build(map, play.map_style, tuning.body, play.baked_light, sun, false, play.site_look)
	level.set_baked_light(true)
	play.look.push_globals()
	var lighting := FieldLighting.build(sun, play.look)
	lighting.add_probes(map)
	port.add_child(lighting)
	var roof := RoofView.build(map, play.roof)
	if roof != null:
		port.add_child(roof)
	var values := GraphicsTable.shared().preset(&"high")
	GraphicsApply.apply(values, port)
	GraphicsApply.apply_field(values, lighting, null, null, level)
	var ground := map.terrain.height_at(SPOT.x, SPOT.y) if map.terrain != null else 0.0
	var eye := Vector3(SPOT.x, ground + tuning.body.stand_eye_height, SPOT.y)
	var rules := LoadoutRules.standard()
	var failed := 0
	for shot: String in args.slice(1):
		var f := shot.split(":")
		var path := "%s/%s.jpg" % [folder, f[0]]
		if f[0].begins_with("part_"):
			failed += await _part(port, f, path)
			continue
		var camera := Camera3D.new()
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.near = play.view.near
		camera.far = play.view.far
		port.add_child(camera)
		camera.global_position = eye
		camera.global_rotation = Vector3(deg_to_rad(SPOT.w), deg_to_rad(SPOT.z), 0.0)
		var loadout := rules.default_loadout("render")
		loadout.equipped[Loadout.Slot.PRIMARY] = f[1]
		if f[2] != "-":
			for pair: String in f[2].split("+"):
				var kv := pair.split("=")
				if not rules.set_part(loadout, f[1], StringName(kv[0]), kv[1]):
					push_error("render_replica_view: %s won't take %s" % [f[1], pair])
		var kit := rules.carried(loadout)
		var c := Character.new(0, 0, Vector3(SPOT.x, ground, SPOT.y), deg_to_rad(SPOT.z), kit.replicas)
		var hands := ReplicaView.new()
		camera.add_child(hands)
		hands.setup(play.viewmodel, kit.replicas, level.query(), kit.paints, false, kit.parts, play.view, camera)
		var aim := f[3].to_float()
		var r := c.armament.replica()
		camera.fov = play.view.vertical_fov(lerpf(1.0, FirstPersonView.aimed_zoom(r, play.view), aim))
		var look := -camera.global_basis.z
		var yaw := deg_to_rad(SPOT.z)
		var pitch := deg_to_rad(SPOT.w)
		for i in SETTLE_FRAMES:
			hands.update(c, yaw, pitch, eye, look, DT, aim)
		var inspect := f[4].to_float()
		if inspect >= 0.0:
			hands.inspect()
			var pose: InspectPose = play.viewmodel.inspect_poses.get(r.id, play.viewmodel.inspect_pose_default)
			var steps := roundi(inspect * pose.duration / DT)
			for i in maxi(steps, 1):
				hands.update(c, yaw, pitch, eye, look, DT, aim)
		var bbs: BBView = null
		if f.size() > 5:
			# The shot kicks the replica as it goes (on_shot), the BB that long on.
			hands.on_shot()
			hands.update(c, yaw, pitch, eye, look, f[5].to_float(), aim)
			var off := f[6].to_float() if f.size() > 6 else 0.0
			bbs = _shot(port, play, tuning, c, eye, look.rotated(Vector3.UP, deg_to_rad(off)), hands, f[5].to_float())
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		print("[render_replica_view] %s" % path)
		failed += 1 if port.get_texture().get_image().save_jpg(path, QUALITY) != OK else 0
		camera.free()
		if bbs != null:
			bbs.free()
	quit(1 if failed > 0 else 0)


## One BB of `c`'s fired from `eye` along `look` `age` s ago, drawn as a match draws your own (BBView, from the muzzle).
func _shot(port: SubViewport, play: PlayTuning, tuning: SimTuning, c: Character, eye: Vector3, look: Vector3,
		hands: ReplicaView, age: float) -> BBView:
	var pool := BBPool.new(1)
	var r := c.armament.replica()
	var speed := Ballistics.muzzle_velocity(r, tuning.replica_rules)
	var bb := pool.spawn(c.id, eye, look, speed, 0.0, r.bb_weight * 0.001, 0.0)
	var ticks := floori(age / PlaySession.TICK)
	var fraction := age / PlaySession.TICK - ticks
	bb.prev_position = eye + look * speed * ticks * PlaySession.TICK
	bb.position = bb.prev_position + look * speed * PlaySession.TICK
	bb.age = ticks * PlaySession.TICK
	var view := BBView.new()
	view.setup(play.effects, 1)
	port.add_child(view)
	view.update(pool, c.id, hands.muzzle_position() - eye, fraction, PlaySession.TICK, eye)
	var at := BBView.drawn_at(play.effects, bb, c.id, hands.muzzle_position() - eye, fraction, PlaySession.TICK)
	print("[render_replica_view] muzzle %s from the eye, BB drawn at %s from the eye" % [hands.muzzle_position() - eye,
			at - eye])
	return view


## Part `f[2]` of parts file `f[1]` alone on a grey backdrop, seen from `f[3]` towards `f[4]` (its space, m).
func _part(port: SubViewport, f: PackedStringArray, path: String) -> int:
	var scene := load("res://assets/models/replicaParts/%s.glb" % f[1]) as PackedScene
	var holder := scene.instantiate() as Node3D
	var part := holder.get_node_or_null(f[2]) as Node3D
	if part == null:
		push_error("render_replica_view: no %s in %s" % [f[2], f[1]])
		holder.free()
		return 1
	holder.remove_child(part)
	holder.free()
	var figure := part.get_node_or_null(f[2] + "_Figure") as Node3D
	if figure != null:
		figure.visible = false
	var stage := Node3D.new()
	stage.position = Vector3(0.0, 50.0, 0.0)
	port.add_child(stage)
	part.transform = Transform3D.IDENTITY
	stage.add_child(part)
	ReplicaPaint.apply(part, &"", false)
	var backdrop := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 3.0
	box.flip_faces = true
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.62, 0.64, 0.68)
	box.material = grey
	backdrop.mesh = box
	stage.add_child(backdrop)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(30.0), 0.0)
	stage.add_child(key)
	var camera := Camera3D.new()
	camera.fov = PART_FOV
	camera.near = PART_NEAR
	stage.add_child(camera)
	var from := f[3].split_floats(",")
	var to := f[4].split_floats(",")
	camera.position = Vector3(from[0], from[1], from[2])
	camera.look_at(stage.to_global(Vector3(to[0], to[1], to[2])), Vector3.UP)
	camera.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("[render_replica_view] %s" % path)
	var bad := 1 if port.get_texture().get_image().save_jpg(path, QUALITY) != OK else 0
	stage.free()
	return bad
