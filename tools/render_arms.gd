extends SceneTree
## Pictures of your first-person arms (BP8, the owner's playtest notes 6, 9 and 11), for review: the replica in hand
## drawn as a match draws it (ReplicaView with your arms, the game's eye camera) on the Depot by day on High, as
## tools/render_held_bomb.gd draws it.
## `grips`: each replica that takes a grip with none, the vertical and the angled one fitted, at the hip and aimed, to
## `<folder>/grip_<id>_<grip>_<hip|aim>.jpg`; `reload`: every frame of a reload at 30 a second for each replica (the
## AEG Rifle with a vertical grip too), to `<folder>/reload_<id>[_<grip>]_<frame>.jpg`; `skin`: each replica at the hip
## (and the AEG Rifle aimed) with gloves and skin only, to `<folder>/skin_<id>_<view>_<gloves|skin>.jpg`; `outside`:
## a close-up of your left hand from outside, in front of it and to its left (OUTSIDE), on each grip at the hip and at
## each share of a reload in OUTSIDE_SHARES, to `<folder>/outside_<id>_<grip|reload>[_<share>].jpg`. Replica ids after
## the mode draw only those. Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 -s res://tools/render_arms.gd \
##       -- <folder> [grips|reload|skin|outside] [ids...]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1280, 720)
const QUALITY := 0.92
const SETTLE_FRAMES := 90
const DT := 1.0 / 60.0
const MAP := "depot"
## Where you stand: x, z, yaw and pitch (degrees), as render_held_bomb.gd's spot.
const SPOT := Vector4(0.0, 0.0, 0.0, 0.0)
const GRIPPED: Array[StringName] = [&"aeg", &"sniper"]
const GRIPS: Array[StringName] = [&"", &"vertical", &"angled"]
const HELD: Array[StringName] = [&"aeg", &"pistol", &"cyber", &"sniper"]
## Reload frames a second.
const RELOAD_RATE := 30.0
## The outside camera: this far from your left hand (m, along the eye camera's axes: to the left, down, forward), its
## vertical field of view (degrees), and the shares of a reload it draws (the magazine coming out, carried away, the
## fresh one going in).
const OUTSIDE := Vector3(-0.1, -0.1, -0.3)
## On a grip it looks from in front, a little to the left and below, at the fingers round the grip.
const GRIP_OUTSIDE := Vector3(-0.14, -0.08, -0.26)
const OUTSIDE_FOV := 40.0
const OUTSIDE_SHARES: Array[float] = [0.2, 0.26, 0.65, 0.75]

var _port: SubViewport = null
var _camera: Camera3D = null
var _outside: Camera3D = null
var _only: Array[StringName] = []
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
	var folder := (args[0] if not args.is_empty() else "user://arms").trim_suffix("/")
	var what := args[1] if args.size() > 1 else "grips"
	for i in range(2, args.size()):
		_only.append(StringName(args[i]))
	DirAccess.make_dir_recursive_absolute(folder)
	_play = PlayTuning.load_default()
	if what == "outside":
		# Seen from outside, the hands draw at their true depth.
		_play.viewmodel.depth_scale = 1.0
	if not _build_scene():
		quit(1)
		return
	var failed := 0
	match what:
		"grips":
			for id in _ids(GRIPPED):
				for grip in GRIPS:
					for aim: float in [0.0, 1.0]:
						var view := "aim" if aim > 0.0 else "hip"
						var path := "%s/grip_%s_%s_%s.jpg" % [folder, id, grip if grip != &"" else &"none", view]
						failed += await _still(id, grip, false, aim, -1.0, path)
		"reload":
			for id in _ids(HELD):
				failed += await _reload(id, &"", folder)
			if _ids(GRIPPED).has(&"aeg"):
				failed += await _reload(&"aeg", &"vertical", folder)
		"skin":
			for id in _ids(HELD):
				for skin: bool in [false, true]:
					var path := "%s/skin_%s_hip_%s.jpg" % [folder, id, "skin" if skin else "gloves"]
					failed += await _still(id, &"", skin, 0.0, -1.0, path)
			for skin: bool in [false, true]:
				var path := "%s/skin_aeg_aim_%s.jpg" % [folder, "skin" if skin else "gloves"]
				failed += await _still(&"aeg", &"", skin, 1.0, -1.0, path)
		"outside":
			for id in _ids(GRIPPED):
				for grip: StringName in [&"vertical", &"angled"]:
					failed += await _from_outside(id, grip, -1.0, "%s/outside_%s_%s.jpg" % [folder, id, grip])
			for id in _ids(HELD):
				for share in OUTSIDE_SHARES:
					var path := "%s/outside_%s_reload_%02d.jpg" % [folder, id, roundi(share * 100.0)]
					failed += await _from_outside(id, &"", share, path)
	quit(1 if failed > 0 else 0)


## `ids` less any not asked for.
func _ids(ids: Array[StringName]) -> Array[StringName]:
	return ids.filter(func(id: StringName) -> bool: return _only.is_empty() or _only.has(id))


func _build_scene() -> bool:
	var tuning := SimTuning.load_default()
	var map := MapData.load_map(MAP, _play.map_style, tuning.rounds.team_size)
	if not map.ok():
		push_error("render_arms: %s refused" % MAP)
		return false
	_port = SubViewport.new()
	_port.size = SIZE
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
	# The game's eye camera (FirstPersonView): its clip planes, its height kept.
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
	return true


## Your hands holding replica `id` (with grip part `grip` fitted, skin only if `skin`) under the camera, and a
## character carrying it: [view, character]. The caller frees the view once drawn.
func _hands(id: StringName, grip: StringName, skin: bool) -> Array:
	var r := ReplicaStats.load_replica(id)
	var loadout: Array[ReplicaConfig] = [r]
	var parts: Array[Dictionary] = [{ReplicaParts.GRIP_SLOT: grip} if grip != &"" else {}]
	var hands := ReplicaView.new()
	hands.skin_arms = skin
	_camera.add_child(hands)
	hands.setup(_play.viewmodel, loadout, BoxWorld.new(), [], false, parts, _play.view, _camera)
	var c := Character.new(0, 0, _feet, _yaw, loadout)
	c.pitch = _pitch
	return [hands, c]


## `hands` held by `c`, raised `aim` (0..1) and `reload` of the way through a reload (below 0: none), for `frames` ticks.
func _pose(hands: ReplicaView, c: Character, aim: float, reload: float, frames: int) -> void:
	var r := c.armament.replica()
	c.armament.reload_left = r.reload_time * (1.0 - reload) if reload >= 0.0 else 0.0
	_camera.fov = _play.view.vertical_fov(lerpf(1.0, FirstPersonView.aimed_zoom(r, _play.view), aim))
	for i in frames:
		hands.update(c, _yaw, _pitch, _eye, _look, DT, aim)


func _still(id: StringName, grip: StringName, skin: bool, aim: float, reload: float, path: String) -> int:
	var made := _hands(id, grip, skin)
	var hands: ReplicaView = made[0]
	_pose(hands, made[1] as Character, aim, reload, SETTLE_FRAMES)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var failed := _save(path)
	hands.queue_free()
	return failed


## Every frame of a reload of `id` (with `grip` fitted) at RELOAD_RATE, settled at the hip first.
func _reload(id: StringName, grip: StringName, folder: String) -> int:
	var made := _hands(id, grip, false)
	var hands: ReplicaView = made[0]
	var c: Character = made[1]
	_pose(hands, c, 0.0, -1.0, SETTLE_FRAMES)
	# A fresh view's first draw is not the settled one.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var length := c.armament.replica().reload_time
	var count := ceili(length * RELOAD_RATE)
	var failed := 0
	var stem := "%s/reload_%s%s" % [folder, id, "_" + String(grip) if grip != &"" else ""]
	for frame in count + 1:
		_pose(hands, c, 0.0, minf(float(frame) / count, 0.9999) if frame < count else -1.0, 1)
		await RenderingServer.frame_post_draw
		failed += _save("%s_%03d.jpg" % [stem, frame])
	hands.queue_free()
	return failed


## Your left hand on `id` (with `grip` fitted), at the hip and `reload` of the way through a reload (below 0: none),
## seen from outside (OUTSIDE).
func _from_outside(id: StringName, grip: StringName, reload: float, path: String) -> int:
	var made := _hands(id, grip, false)
	var hands: ReplicaView = made[0]
	var c: Character = made[1]
	_pose(hands, c, 0.0, -1.0, SETTLE_FRAMES)
	if reload >= 0.0:
		var length := c.armament.replica().reload_time
		var ticks := roundi(reload * length / DT)
		c.armament.reload_left = length
		for i in ticks:
			c.armament.reload_left = maxf(length * (1.0 - float(i + 1) / ticks * reload), 0.0001)
			hands.update(c, _yaw, _pitch, _eye, _look, DT, 0.0)
	var bones: Skeleton3D = null
	for node: Node in hands.find_children("*", "Skeleton3D", true, false):
		if (node as Skeleton3D).find_bone("Hand_L") >= 0:
			bones = node as Skeleton3D
	var failed := 0
	if bones == null:
		push_error("render_arms: no arms on %s" % id)
		failed = 1
	else:
		var at := bones.global_transform * bones.get_bone_global_pose(bones.find_bone("Hand_L")).origin
		_outside.global_position = at + _camera.global_basis * (OUTSIDE if reload >= 0.0 else GRIP_OUTSIDE)
		_outside.look_at(at, Vector3.UP)
		_outside.current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		failed = _save(path)
		_camera.current = true
	hands.queue_free()
	return failed


func _save(path: String) -> int:
	print("[render_arms] %s" % path)
	return 1 if _port.get_texture().get_image().save_jpg(path, QUALITY) != OK else 0
