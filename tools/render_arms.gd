extends SceneTree
## Pictures of your first-person arms (BP8, the owner's playtest notes 6, 9 and 11), for review: the replica in hand
## drawn as a match draws it (ReplicaView with your arms, the game's eye camera) on the Depot by day on High, as
## tools/render_held_bomb.gd draws it.
## `grips`: each replica that takes a grip with none, the vertical and the angled one fitted, at the hip and aimed, to
## `<folder>/grip_<id>_<grip>_<hip|aim>.jpg`; `reload`: every frame of a reload at 30 a second for each replica (the
## AEG Rifle with a vertical grip too), to `<folder>/reload_<id>[_<grip>]_<frame>.jpg`; `skin`: each replica at the hip
## (and the AEG Rifle aimed) with gloves and skin only, to `<folder>/skin_<id>_<view>_<gloves|skin>.jpg`; `outside`:
## a close-up of your left hand from outside, about half a metre in front of it, left and below (OUTSIDE), on each
## grip at the hip and at each share of a reload in OUTSIDE_SHARES, to
## `<folder>/outside_<id>_<grip|reload>[_<share>].jpg`; `laser`: the AEG Rifle with the Red Laser fitted (LASER) and
## each grip, at the hip, in view and from outside, and from outside at each share of a reload, to `<folder>/laser_aeg_<grip>_<hip|outside>.jpg` and `<folder>/laser_aeg_reload_<share>.jpg`.
## Replica ids after the mode draw only those. Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 -s res://tools/render_arms.gd \
##       -- <folder> [grips|reload|skin|outside|laser] [ids...]
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
## The outside camera: OUTSIDE_FAR m from what it looks at, that way from it (along the eye camera's axes: to the
## left, down, forward), its vertical field of view (degrees), a fill light by it (OUTSIDE_FILL: energy, range m) so
## the hand isn't lit only from behind, looking at a point OUTSIDE_LIFT m above what it shows. On a reload it looks
## from the left, a little below and in front, at the middle of your left hand and the magazine, at the shares
## OUTSIDE_SHARES has for the replica: the old magazine taken out of the well, carried down (out of your view), the
## fresh one brought up in the hand, and pushed home. On a grip it looks at the hand from in front, left and below, so
## the fingers round the grip and the grip show whole.
const OUTSIDE := Vector3(-0.45, -0.35, -1.0)
const GRIP_OUTSIDE := Vector3(-0.6, -0.3, -1.0)
const OUTSIDE_FAR := 0.55
const OUTSIDE_FOV := 40.0
const OUTSIDE_FILL := Vector2(1.2, 2.0)
const OUTSIDE_LIFT := 0.07
const OUTSIDE_SHARES: Dictionary[StringName, Array] = {&"aeg": [0.18, 0.3, 0.47, 0.62],
		&"sniper": [0.18, 0.3, 0.47, 0.62], &"pistol": [0.25, 0.36, 0.48, 0.6], &"cyber": [0.27, 0.37, 0.5, 0.62]}
## The laser the `laser` mode fits, and its slot (data/pool.md; the part model's `laser_redLaser`).
const LASER := &"redLaser"
const LASER_SLOT := &"laser"

var _port: SubViewport = null
var _camera: Camera3D = null
var _outside: Camera3D = null
var _fill: OmniLight3D = null
var _only: Array[StringName] = []
## The parts fitted besides the grip (`laser` mode: the Red Laser on the AEG's side rail).
var _extra: Dictionary = {}
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
	if what == "outside" or what == "laser":
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
				for share: float in OUTSIDE_SHARES[id]:
					var path := "%s/outside_%s_reload_%02d.jpg" % [folder, id, roundi(share * 100.0)]
					failed += await _from_outside(id, &"", share, path)
		"laser":
			_extra = {LASER_SLOT: LASER}
			for grip in GRIPS:
				var stem := "%s/laser_aeg_%s" % [folder, grip if grip != &"" else &"none"]
				failed += await _still(&"aeg", grip, false, 0.0, -1.0, stem + "_hip.jpg")
				failed += await _from_outside(&"aeg", grip, -1.0, stem + "_outside.jpg")
			for share: float in OUTSIDE_SHARES[&"aeg"]:
				var path := "%s/laser_aeg_reload_%02d.jpg" % [folder, roundi(share * 100.0)]
				failed += await _from_outside(&"aeg", &"", share, path)
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
	_fill = OmniLight3D.new()
	_fill.light_energy = OUTSIDE_FILL.x
	_fill.omni_range = OUTSIDE_FILL.y
	_fill.visible = false
	_port.add_child(_fill)
	return true


## Your hands holding replica `id` (with grip part `grip` fitted, skin only if `skin`) under the camera, and a
## character carrying it: [view, character]. The caller frees the view once drawn.
func _hands(id: StringName, grip: StringName, skin: bool) -> Array:
	var r := ReplicaStats.load_replica(id)
	var loadout: Array[ReplicaConfig] = [r]
	var fitted := _extra.duplicate()
	if grip != &"":
		fitted[ReplicaParts.GRIP_SLOT] = grip
	var parts: Array[Dictionary] = [fitted]
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
		if reload >= 0.0:
			var mag := hands.find_child(ReplicaParts.MAGAZINE_ATTACHMENT, true, false) as BoneAttachment3D
			if mag != null:
				(mag.get_parent() as Skeleton3D).force_update_all_bone_transforms()
				mag.on_skeleton_update()
				at = at.lerp(mag.global_position, 0.5)
		at += _camera.global_basis.y * OUTSIDE_LIFT
		var way := (OUTSIDE if reload >= 0.0 else GRIP_OUTSIDE).normalized()
		_outside.global_position = at + _camera.global_basis * way * OUTSIDE_FAR
		_outside.look_at(at, Vector3.UP)
		_outside.current = true
		_fill.global_position = _outside.global_position
		_fill.visible = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		failed = _save(path)
		_fill.visible = false
		_camera.current = true
	hands.queue_free()
	return failed


func _save(path: String) -> int:
	print("[render_arms] %s" % path)
	return 1 if _port.get_texture().get_image().save_jpg(path, QUALITY) != OK else 0
