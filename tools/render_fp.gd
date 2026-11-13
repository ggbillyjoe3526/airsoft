extends SceneTree
## Pictures of the first-person view (HA1): the replica in hand drawn as a match draws it (ReplicaView with your arms,
## the game's eye camera) on the Depot on High, one picture a shot. Each shot is `<name>:<replica id>` followed by any
## of `:aim=<0..1>` (the sight's raise), `:skin` (skin-only arms), `:reload=<0..1>` (that share through a reload),
## `:fire=<seconds>` (that long after a shot), `:sprint`, `:walk=<seconds>` (that long into a walk), `:grip=<key>`,
## `:optic=<key>` and `:out=<x>,<y>,<z>,<far>` (seen from outside: the camera that way from your right hand along the
## eye's axes, that far off). An argument `set:<property>[.<key>]=<value>` changes a ViewModelConfig value for every
## shot (a number, or three for a Vector3), for trying a pose before it goes in the config; `size:<w>x<h>` draws the
## pictures that large (1280x720 otherwise: a texture's fine detail wants 2560x1440). Needs a display; Forward+
## under xvfb with lavapipe (mesa-vulkan-drivers):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . -s res://tools/render_fp.gd -- <folder> [set:...] <shot> ...
## Dev only: tools/ never ships.

const SIZE := Vector2i(1280, 720)
const QUALITY := 0.92
const SETTLE_FRAMES := 90
const DT := 1.0 / 60.0
const MAP := "depot"
## Where you stand: x, z, yaw and pitch (degrees), as render_arms.gd's spot.
const SPOT := Vector4(0.0, 0.0, 0.0, 0.0)
const OUTSIDE_FOV := 40.0
const OUTSIDE_FILL := Vector2(1.2, 2.0)
const OPTIC_SLOT := &"optic"
const RIGHT_HAND := "Hand_R"
## A walk's speed (m/s) for `walk=`.
const WALK_SPEED := 3.0

var _size := SIZE
var _port: SubViewport = null
var _camera: Camera3D = null
var _outside: Camera3D = null
var _fill: OmniLight3D = null
var _play: PlayTuning = null
var _eye := Vector3.ZERO
var _feet := Vector3.ZERO
var _look := Vector3.FORWARD
var _yaw := 0.0
var _pitch := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("render_fp: <folder> <shot> ...")
		quit(1)
		return
	var folder := args[0].trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(folder)
	_play = PlayTuning.load_default()
	var shots: Array[String] = []
	for i in range(1, args.size()):
		if args[i].begins_with("set:"):
			_change(args[i].trim_prefix("set:"))
		elif args[i].begins_with("size:"):
			var sides := args[i].trim_prefix("size:").split("x")
			_size = Vector2i(int(sides[0]), int(sides[1]))
		else:
			shots.append(args[i])
	if not _build_scene():
		quit(1)
		return
	var failed := 0
	for shot in shots:
		failed += await _shoot(shot, folder)
	quit(1 if failed > 0 else 0)
	# Godot may not leave after quit() under xvfb.
	OS.kill(OS.get_process_id())


## Changes the ViewModelConfig value `spec` names: `<property>=<value>` or `<property>.<key>=<value>`.
func _change(spec: String) -> void:
	var halves := spec.split("=")
	var path := halves[0].split(".")
	var numbers := halves[1].split_floats(",")
	var value: Variant = numbers[0]
	if numbers.size() == 3:
		value = Vector3(numbers[0], numbers[1], numbers[2])
	elif numbers.size() == 2:
		value = Vector2(numbers[0], numbers[1])
	var cfg := _play.viewmodel
	if path.size() == 1:
		cfg.set(path[0], value)
	else:
		var table: Dictionary = cfg.get(path[0])
		table[StringName(path[1])] = value


func _build_scene() -> bool:
	var tuning := SimTuning.load_default()
	var map := MapData.load_map(MAP, _play.map_style, tuning.rounds.team_size)
	if not map.ok():
		push_error("render_fp: %s refused" % MAP)
		return false
	_port = SubViewport.new()
	_port.size = _size
	_port.msaa_3d = Viewport.MSAA_4X
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_port)
	var sun := LightingConfig.for_map(_play.lighting, null, map, LightingConfig.DAY)
	var level := MapLevel.new()
	_port.add_child(level)
	level.build(map, _play.map_style, tuning.body, _play.baked_light, sun, false, _play.site_look)
	level.set_baked_light(true)
	_play.look.push_globals()
	var lighting := FieldLighting.build(sun, _play.look)
	lighting.add_probes(map)
	_port.add_child(lighting)
	var site := SiteDress.build(map, _play.site_look, level.site_material())
	if site != null:
		_port.add_child(site)
		SiteDress.dress_sky(lighting, _play.site_look)
	var roof := RoofView.build(map, _play.roof)
	if roof != null:
		_port.add_child(roof)
	var values := GraphicsTable.shared().preset(&"high")
	GraphicsApply.apply(values, _port)
	GraphicsApply.apply_field(values, lighting, null, null, level)
	if site != null:
		level.set_detail(values.mesh_detail)
	_camera = Camera3D.new()
	_camera.near = _play.view.near
	_camera.far = _play.view.far
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_port.add_child(_camera)
	var ground := map.terrain.height_at(SPOT.x, SPOT.y) if map.terrain != null else 0.0
	_feet = Vector3(SPOT.x, ground, SPOT.y)
	_eye = _feet + Vector3.UP * tuning.body.stand_eye_height
	_yaw = deg_to_rad(SPOT.z)
	_pitch = deg_to_rad(SPOT.w)
	_camera.global_position = _eye
	_camera.global_rotation = Vector3(_pitch, _yaw, 0.0)
	_look = -_camera.global_basis.z
	_outside = Camera3D.new()
	_outside.near = 0.01
	_outside.fov = OUTSIDE_FOV
	_port.add_child(_outside)
	_fill = OmniLight3D.new()
	_fill.light_energy = OUTSIDE_FILL.x
	_fill.omni_range = OUTSIDE_FILL.y
	_fill.visible = false
	_port.add_child(_fill)
	return true


## Draws one shot (see the header) to `<folder>/<name>.jpg`; 1 if it failed.
func _shoot(shot: String, folder: String) -> int:
	var fields := shot.split(":")
	if fields.size() < 2:
		push_error("render_fp: bad shot %s" % shot)
		return 1
	var id := StringName(fields[1])
	var opts: Dictionary[String, String] = {}
	for i in range(2, fields.size()):
		var pair := fields[i].split("=")
		opts[pair[0]] = pair[1] if pair.size() > 1 else ""
	var r := ReplicaStats.load_replica(id)
	var loadout: Array[ReplicaConfig] = [r]
	var fitted: Dictionary = {}
	if opts.has("grip"):
		fitted[ReplicaParts.GRIP_SLOT] = StringName(opts["grip"])
	if opts.has("optic"):
		fitted[OPTIC_SLOT] = StringName(opts["optic"])
	var parts: Array[Dictionary] = [fitted]
	var outside := opts.has("out")
	var kept_depth := _play.viewmodel.depth_scale
	if outside:
		# Seen from outside, the hands draw at their true depth.
		_play.viewmodel.depth_scale = 1.0
	var hands := ReplicaView.new()
	hands.skin_arms = opts.has("skin")
	_camera.add_child(hands)
	hands.setup(_play.viewmodel, loadout, BoxWorld.new(), [], false, parts, _play.view, _camera)
	_play.viewmodel.depth_scale = kept_depth
	var c := Character.new(0, 0, _feet, _yaw, loadout)
	c.pitch = _pitch
	var aim := float(opts.get("aim", "0"))
	c.aim_raise = aim
	_camera.fov = _play.view.vertical_fov(lerpf(1.0, FirstPersonView.aimed_zoom(r, _play.view), aim))
	for i in SETTLE_FRAMES:
		hands.update(c, _yaw, _pitch, _eye, _look, DT, aim)
	if opts.has("sprint"):
		c.sprinting = true
		for i in SETTLE_FRAMES:
			hands.update(c, _yaw, _pitch, _eye, _look, DT, aim)
	if opts.has("walk"):
		c.velocity = -_camera.global_basis.z * WALK_SPEED
		for i in roundi(float(opts["walk"]) / DT):
			hands.update(c, _yaw, _pitch, _eye, _look, DT, aim)
	if opts.has("reload"):
		var share := float(opts["reload"])
		var length := r.reload_time
		var ticks := maxi(roundi(share * length / DT), 1)
		for i in ticks:
			c.armament.reload_left = maxf(length * (1.0 - float(i + 1) / ticks * share), 0.0001)
			hands.update(c, _yaw, _pitch, _eye, _look, DT, aim)
	if opts.has("fire"):
		hands.on_shot()
		var ticks := roundi(float(opts["fire"]) / DT)
		for i in ticks:
			# The replica's own clip moves on with the frames drawn; here by hand.
			for player: Node in hands.find_children("*", "AnimationPlayer", true, false):
				(player as AnimationPlayer).advance(DT)
			hands.update(c, _yaw, _pitch, _eye, _look, DT, aim)
	if outside:
		var way := opts["out"].split_floats(",")
		var at := _hand_place(hands)
		_outside.global_position = at + _camera.global_basis * Vector3(way[0], way[1], way[2]).normalized() * way[3]
		_outside.look_at(at, Vector3.UP)
		_outside.current = true
		_fill.global_position = _outside.global_position
		_fill.visible = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "%s/%s.jpg" % [folder, fields[0]]
	print("[render_fp] %s" % path)
	var failed := 1 if _port.get_texture().get_image().save_jpg(path, QUALITY) != OK else 0
	_fill.visible = false
	_camera.current = true
	hands.queue_free()
	return failed


## Where your right hand is in the world (the eye, without the arms' skeleton).
func _hand_place(hands: ReplicaView) -> Vector3:
	for node: Node in hands.find_children("*", "Skeleton3D", true, false):
		var bones := node as Skeleton3D
		var hand := bones.find_bone(RIGHT_HAND)
		if hand >= 0:
			bones.force_update_all_bone_transforms()
			return bones.global_transform * bones.get_bone_global_pose(hand).origin
	return _eye
