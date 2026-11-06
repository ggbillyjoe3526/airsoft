class_name FigureView
extends Node3D
## Another player on the field, drawn as its rigged figure (FigureBody, step 23; every bot on every preset, DECISIONS
## BD1), placed and posed from its Character between the last two ticks: its legs by `animate` (FigurePose: moving,
## crouching, jumping, vaulting, the hit call, the walk-off and the lean) and its upper body (the aim, the holster, a
## switch, a trigger press per SHOT event, `on_shot`), its replicas handed to it (FigureHands: in the hand, stowed,
## hanging from the hand), the models' cut-down figure versions in its team's paint (ReplicaPaint) with its parts'
## figure versions fitted (ReplicaParts). Calling a hit, "HIT!" shows above the head; it stays up on the walk off; a
## figure leaving the field fades out, its replicas put away. The hit flinch (`hit`, FigureFlinch): the upper body
## jolts the way the BB flew, through FigureBend. In a reload (FI4) the left hand carries a copy of the replica model's
## magazine, made here once a slot in the replica's paint, and throws the old one into `thrown`. A bomb thrown (GT1,
## `set_bombs`): its model in the right hand until it leaves, the arms throwing it. A kind the session
## couldn't load draws no body, only the sign (the tests catch a missing model, FigureModels warns). Where the sun casts
## no shadows, a soft dark disc lies on the floor under it (`set_contact_shadow`: the contact shadow, one shared mesh).

## Where the sign floats and how it is drawn.
const SIGN_HEIGHT := 2.25
const SIGN_FONT_SIZE := 96
const SIGN_PIXEL := 0.004
const SIGN_OUTLINE_DARKEN := 0.5
const MODEL_DIR := "res://assets/models/replicas/"

var character_id: int = -1
var _sign: Label3D = null
var _hits: HitConfig = null
## The replicas the character carries, as the models' figure versions (kept hidden on the figure between bodies).
var _replicas: Array[MeshInstance3D] = []
var _classes: Array[StringName] = []
## Each replica's magazine copy (the full model's magazine mesh, painted as the replica; null without one); where the
## figure throws its old magazines (null: none thrown).
var _magazines: Array[MeshInstance3D] = []
## Each replica's far version beyond the far line (HeldMerge.far_version; null: none) and the magazine in its well that
## it stands in for there (null: none), BP5.
var _fars: Array[MeshInstance3D] = []
var _wells: Array[MeshInstance3D] = []
var _lod_margin: float = 0.0
var thrown: ThrownMagazines = null
## Seen this much (1 solid, 0 gone), as `update` last drew it; a shot since the last pose (the trigger pressed).
var _fade: float = 1.0
var _fired: bool = false
## The figure drawn (null when its kind couldn't load); the team and its colour and glow, for a body made later.
var _body: FigureBody = null
var _team: int = 0
var _team_colour: Color = Color.WHITE
var _glow: float = 0.0
## The legs: their pose (reused every frame), the lines its levels change at, whether the next pose snaps (the
## first, or the first after the legs were left still), and the frames and time gathered beyond the far line.
var _pose: FigurePose = null
var _lines: Vector2 = Vector2.ZERO
## The camera's view cone (view_corner) and the camera settings it was worked out for (fov, the view's size, its kept
## aspect), so it is worked out again only when they change.
var _corner: Vector2 = Vector2.ZERO
var _corner_for: Vector4 = Vector4.INF
## Frames until the view is looked at again (FigureConfig.hold_view_stride).
var _view_frames: int = 0
var _snap: bool = true
var _far_frames: int = 0
var _far_delta: float = 0.0
## The hit flinch, eased on every frame's time in `update` (hidden or far all the same).
var _flinch: FigureFlinch = null
## Each replica's muzzle in its figure version's space (where a gas replica's breath comes from, GasPuffs).
var _muzzles: PackedVector3Array = PackedVector3Array()
## How far forward each replica's support hand may hold its handguard, in its figure version's space (HG1;
## Vector3.INF: no handguard), and each replica's id.
var _supports: PackedVector3Array = PackedVector3Array()
var _ids: Array[StringName] = []
## The contact shadow (null until given one), its numbers, and the floor the feet last stood on (y).
var _contact: MeshInstance3D = null
var _effects: EffectsConfig = null
var _floor_y: float = 0.0
## The disc's radius as last placed (m: narrower crouched).
var _contact_radius: float = 0.0
## Muzzle up at a wall (FB5): the level the ray asks (null: never raised), the body's eye heights, the ray's scratch,
## poses left until the next ray, and the time since the last shot (s; a shot holds the replica level).
var _world: WorldQuery = null
var _body_config: BodyConfig = null
var _wall: RayHit = null
var _raise_wait: int = 0
var _raise_stride: int = 1
var _since_shot: float = INF
## The bombs' meshes by Grenade.Kind (GrenadeView's, shared) and their timing, for a throw in the hand (GT1; empty:
## none drawn).
var _bomb_meshes: Array[Mesh] = []
var _grenade_config: GrenadeConfig = null


## Draws `c` in `team_colour` (the body's Team* paint, set_body, and the sign's outline), glowing with `glow` of it
## (High contrast by day, TeamColours), holding its replicas in its team's paints (`realistic`: each bold scheme as its
## plain colour) with `parts[i]` on replica `i` (Kit.parts; bots carry theirs as they come); `figures` gives the hit
## flinch's numbers (the built-in ones when null).
func setup(c: Character, team_colour: Color, hits: HitConfig, font: Font,
		realistic: bool = false, parts: Array[Dictionary] = [], glow: float = 0.0, figures: FigureConfig = null) -> void:
	character_id = c.id
	_floor_y = c.position.y
	var cfg := figures if figures != null else FigureConfig.new()
	_flinch = FigureFlinch.new(cfg)
	_raise_stride = maxi(cfg.raise_stride, 1)
	_lod_margin = cfg.lod_margin
	# Staggered, so the figures look at the view on different frames.
	_view_frames = posmod(c.id, maxi(cfg.hold_view_stride, 1))
	_hits = hits
	_team = c.team
	_team_colour = team_colour
	_glow = glow
	name = "Figure_%d" % c.id
	top_level = true
	for i in c.armament.replicas.size():
		var held := _held_replica(c.armament.replicas[i], c.team, realistic, parts[i] if i < parts.size() else {},
				_magazines, _muzzles, _supports, cfg, _fars, _wells)
		_replicas.append(held)
		_classes.append(c.armament.replicas[i].site_class)
		_ids.append(c.armament.replicas[i].id)
		if held != null:
			add_child(held)
		if _magazines[i] != null:
			add_child(_magazines[i])
	_sign = make_sign(font, team_colour)
	_sign.position = Vector3(0.0, SIGN_HEIGHT, 0.0)
	add_child(_sign)


## Draws figure kind `kind` of `models`, its levels changing at `lines` (m); with `models` null, or a kind it couldn't
## load, no body (the old one freed, its replicas kept).
func set_body(models: FigureModels, kind: int, lines: Vector2) -> void:
	if _body != null:
		# The replicas back on the figure first, hidden: they outlive the body.
		_body.hands.release(self)
		# Out of the tree at once, so the old body never draws beside a new one this frame.
		remove_child(_body)
		_body.queue_free()
		_body = null
	_lines = lines
	_snap = true
	_set_replica_lines(lines)
	if models != null and models.has_kind(kind):
		_pose = FigurePose.new(models.config) if _pose == null else _pose
		_body = FigureBody.new()
		if _body.setup(models, kind, character_id, _team, _team_colour, _glow, lines):
			add_child(_body)
			_body.hands.hold(_replicas, _classes, _magazines, _supports, _ids)
			_body.hands.thrown = thrown
			if not _bomb_meshes.is_empty():
				_body.hands.set_bomb_meshes(_bomb_meshes)
			_pose.grenades = _grenade_config
			_body.set_fade(_fade)
		else:
			_body.free()
			_body = null


## Throws drawn with `meshes` (GrenadeView.meshes, by Grenade.Kind, shared) in the hand, timed by `cfg` (GT1): the
## bomb in the right hand from the pin to the release, the arms throwing it.
func set_bombs(meshes: Array[Mesh], cfg: GrenadeConfig) -> void:
	_bomb_meshes = meshes
	_grenade_config = cfg
	if _pose != null:
		_pose.grenades = cfg
	if _body != null:
		_body.hands.set_bomb_meshes(meshes)


## Raises the replica, muzzle up, at level geometry `query` finds within its reach along the aim (FB5), the eyes at
## `body`'s heights; the rays are spread over the figures by id.
func set_world(query: WorldQuery, body_config: BodyConfig) -> void:
	_world = query
	_body_config = body_config
	if _wall == null:
		_wall = RayHit.new()
	_raise_wait = absi(character_id) % _raise_stride


## The figure drawn, or null.
func body() -> FigureBody:
	return _body


## The figure's levels change at `lines` (m) from now on (the graphics' Mesh detail).
func set_lod_lines(lines: Vector2) -> void:
	_lines = lines
	if _body != null:
		_body.set_lod_lines(lines)
	_set_replica_lines(lines)


## Each replica drawn whole up to the far line, its far version beyond it (BP5: from 8 or 9 draws to 2 or 3, the
## magazine in its well one more at every distance), each crossed lod_margin past it as the body's levels are.
func _set_replica_lines(lines: Vector2) -> void:
	for i in _fars.size():
		var far := _fars[i]
		if far == null:
			continue
		# no far line yet (no body): the whole replica only
		far.visible = lines.y > 0.0
		far.visibility_range_begin = lines.y
		far.visibility_range_begin_margin = _lod_margin
		# the magazine in its well draws at every distance (one draw), so a reload far off still empties the well
		_replicas[i].visibility_range_end = lines.y
		_replicas[i].visibility_range_end_margin = _lod_margin


## The models' figure version of `r` (its `Figure` mesh, cut down from the model) with `parts`' figure copies fitted
## (ReplicaParts.fit_figure: a part takes the place of the magazine or flash hider it replaces, an optic hides the iron
## sights), hidden, painted for `team` (null without a model). A copy of the magazine it carries (its figure magazine or
## the magazine part's copy, both drawn in the model's space) for the reloads, in the same paint (null without one),
## goes on the end of `magazines`, its muzzle point in the model's space (where the figure version is drawn) on the
## end of `muzzles`, and where the support hand holds it (`support_mark`) on the end of `supports`.
func _held_replica(r: ReplicaConfig, team: int, realistic: bool, parts: Dictionary,
		magazines: Array[MeshInstance3D], muzzles: PackedVector3Array, supports: PackedVector3Array,
		cfg: FigureConfig, fars: Array[MeshInstance3D], wells: Array[MeshInstance3D]) -> MeshInstance3D:
	var scene := load(MODEL_DIR + r.id + ".glb") as PackedScene
	fars.append(null)
	wells.append(null)
	if scene == null:
		magazines.append(null)
		muzzles.append(Vector3.ZERO)
		supports.append(Vector3.INF)
		return null
	var model := scene.instantiate()
	var muzzle := _in_model(model.find_child(ReplicaParts.MUZZLE_NODE, true, false) as Node3D, model)
	var barrel_end := _in_model(model.find_child(ReplicaParts.BARREL_END_NODE, true, false) as Node3D, model)
	var mount := model.find_child(cfg.support_mount, true, false) as Node3D
	var support := _in_model(mount, model) if mount != null else Vector3.INF
	var paint := ReplicaPaint.bot_paint(team, r)
	var held := model.find_child(ReplicaParts.FIGURE_NODE, true, false) as MeshInstance3D
	var copy: MeshInstance3D = null
	if held != null:
		held.get_parent().remove_child(held)
		held.owner = null
		for child in held.find_children("*", "", true, false):
			child.owner = null
		held.transform = Transform3D.IDENTITY
		held.visible = false
		held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for piece: Node in held.find_children("*", "GeometryInstance3D", true, false):
			(piece as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fit := ReplicaParts.fit_figure(held, r.id, parts, barrel_end, muzzle)
		muzzle = fit.muzzle
		support = support_mark(support, fit.grip, cfg)
		ReplicaPaint.apply(held, paint, realistic)
		var key := _merge_key(r.id, paint, realistic, parts)
		var made := HeldMerge.merge(held, fit.magazine, key)
		var far_mesh := HeldMerge.far_version(held, (made if made != "" else key) + "/far")
		if far_mesh != null:
			var far := MeshInstance3D.new()
			far.name = "Far"
			far.mesh = far_mesh
			far.visible = false
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			held.add_child(far)
			fars[-1] = far
			if fit.magazine != null and fit.magazine.get_parent() == held:
				wells[-1] = fit.magazine
		if fit.magazine != null and fit.magazine.mesh != null:
			copy = MeshInstance3D.new()
			copy.name = "Magazine_%s" % r.id
			copy.mesh = fit.magazine.mesh
			copy.visible = false
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ReplicaPaint.apply(copy, paint, realistic)
	magazines.append(copy)
	muzzles.append(muzzle)
	supports.append(support)
	model.free()
	return held


## What a held replica is fitted and painted with, naming its merged mesh (HeldMerge): its id, paint, Realistic colours
## and parts (slot=key, in slot order).
static func _merge_key(id: StringName, paint: StringName, realistic: bool, parts: Dictionary) -> String:
	var slots := parts.keys()
	slots.sort()
	var key := "%s/%s/%s" % [id, paint, realistic]
	for slot: Variant in slots:
		key += "/%s=%s" % [slot, parts[slot]]
	return key


## How far forward the support hand may hold a handguard whose mount is at `mount` (the model's space; Vector3.INF:
## none): there, or with `grip` (a grip part's copy, in the same space) fitted, FigureConfig.support_behind_grip behind
## its back end.
static func support_mark(mount: Vector3, grip: MeshInstance3D, cfg: FigureConfig) -> Vector3:
	if not mount.is_finite() or grip == null or grip.mesh == null:
		return mount
	var back := (grip.transform * grip.get_aabb()).end.z
	return Vector3(mount.x, mount.y, back + cfg.support_behind_grip)


## Where `node` sits in `model`'s space (the model's origin when null).
static func _in_model(node: Node3D, model: Node) -> Vector3:
	var at := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != model:
		if n is Node3D:
			at = (n as Node3D).transform * at
		n = n.get_parent()
	return at.origin if node != null else Vector3.ZERO


## A shot from this figure (its SHOT event): one trigger press at its next pose.
func on_shot() -> void:
	if _body != null:
		_fired = true


## Whether replica `slot` is in the figure's hand and drawn (so its muzzle can be found).
func muzzle_shown(slot: int) -> bool:
	return slot >= 0 and slot < _replicas.size() and _replicas[slot] != null and _replicas[slot].is_visible_in_tree()


## The muzzle of replica `slot` in the world as last drawn (`muzzle_shown` first).
func muzzle_position(slot: int) -> Vector3:
	return _replicas[slot].global_transform * _muzzles[slot]


## The soft disc of `cfg`'s contact shadow, flat on the floor at radius 1 (a figure scales it), its material shared:
## made once a match and given to every figure (`add_contact_shadow`).
static func contact_mesh(cfg: EffectsConfig) -> PlaneMesh:
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, cfg.contact_darkness))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	g.add_point(cfg.contact_middle, Color(0.0, 0.0, 0.0, cfg.contact_darkness * cfg.contact_middle_shade))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = PuffView.DISC_PIXELS
	tex.height = PuffView.DISC_PIXELS
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * 2.0
	disc.material = mat
	return disc


## Gives the figure its contact shadow, `disc` (`contact_mesh`, shared), sized and placed by `cfg`; hidden until
## `set_contact_shadow`.
func add_contact_shadow(disc: Mesh, cfg: EffectsConfig) -> void:
	_effects = cfg
	_contact_radius = cfg.contact_radius
	_contact = MeshInstance3D.new()
	_contact.name = "ContactShadow"
	_contact.mesh = disc
	_contact.top_level = true
	_contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contact.visible = false
	add_child(_contact)


## Draws the contact shadow (where the sun casts none) or not.
func set_contact_shadow(on: bool) -> void:
	if _contact == null:
		return
	# Placed at once: switched on from the pause menu, the tree paused, no update comes before it is drawn.
	if on and not _contact.visible:
		_place_disc()
	_contact.visible = on


## The contact shadow drawn, or null.
func contact_shadow() -> MeshInstance3D:
	return _contact


## The "HIT!" sign, hidden until the hit is called.
static func make_sign(font: Font, team_colour: Color) -> Label3D:
	var s := Label3D.new()
	s.text = TranslationServer.translate(&"HUD_HIT_SIGN")
	s.font = font
	s.font_size = SIGN_FONT_SIZE
	s.pixel_size = SIGN_PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.outline_size = SIGN_FONT_SIZE / 6
	s.modulate = Color.WHITE
	s.outline_modulate = team_colour.darkened(SIGN_OUTLINE_DARKEN)
	s.visible = false
	return s


## Poses the figure's legs from `c` at `fraction` between its ticks, `delta` seconds on, seen from `eye`. A
## hidden figure's legs are left still (and snap to the pose when it shows again); beyond the far line they move every
## FigureConfig.far_stride-th frame, but a figure's first pose is always taken (never the rig's rest pose). After
## `update` and after the figure is hidden from its own eyes.
func animate(c: Character, fraction: float, delta: float, eye: Vector3) -> void:
	if _body == null:
		return
	if not visible:
		_snap = true
		_fired = false
		return
	var cfg := _pose.config()
	var far := _lines.y + cfg.lod_margin
	var near := _lines.x + cfg.lod_margin
	_body.near = global_position.distance_squared_to(eye) <= near * near
	_view_frames -= 1
	if _view_frames <= 0 or _snap:
		_view_frames = cfg.hold_view_stride
		_body.seen = _seen(get_viewport().get_camera_3d(), cfg)
	if not _snap and global_position.distance_squared_to(eye) > far * far:
		if cfg.far_stride <= 0:
			# Held still out there: a press kept now would play stale when the figure comes near.
			_far_frames = 0
			_far_delta = 0.0
			_fired = false
			return
		_far_delta += delta
		_far_frames += 1
		if _far_frames < cfg.far_stride:
			return
		delta = _far_delta
	_far_frames = 0
	_far_delta = 0.0
	_pose.read(c, fraction, _hits)
	_since_shot = 0.0 if _fired else _since_shot + delta
	if _snap:
		# Shown again (or first posed): the pose snaps to this target, so one from before it was hidden is dropped (level
		# until the figure's next ray, which keeps its turn among the others).
		_pose.raise_target = 0.0
	_pose.raise_target = _raise_target(c)
	if _snap:
		_snap = false
		_pose.snap()
	else:
		_pose.settle(delta)
	_body.animate(_pose, _hits, delta, _fired)
	_body.set_flinch(_flinch.tilt())
	_fired = false
	if _fade < 1.0:
		_body.hands.show_hands(-1, -1, false)
		_body.hands.show_reload(-1, 0.0, true)
		_body.hands.show_bomb(Grenade.Kind.NONE)


## How far (0..1) the replica is raised at the level ahead of `c`'s aim, as `_pose` read it (FB5): by how close the
## level comes within the replica's reach (ahead of the figure's speed by raise_lead), eased out, one ray every
## raise_stride poses; none for a replica held level after a shot, holstered, out of the hand or out of play.
func _raise_target(c: Character) -> float:
	var cfg := _pose.config()
	if _world == null or c.status != Character.Status.ALIVE or _pose.in_hand < 0 or _pose.holster > 0.0 \
			or _since_shot < cfg.raise_fire_hold:
		return 0.0
	if _raise_wait > 0:
		_raise_wait -= 1
		return _pose.raise_target
	_raise_wait = _raise_stride - 1
	var yaw := rotation.y
	var h := Character.eye_height(_pose.crouch, _body_config)
	var from := _pose.feet + Vector3(0.0, h - cfg.raise_drop, 0.0) \
			+ Lean.offset(h, _pose.lean, _pose.crouch, yaw, _hits)
	var cp := cos(_pose.pitch)
	var way := Vector3(-sin(yaw) * cp, sin(_pose.pitch), -cos(yaw) * cp)
	var reach := lerpf(cfg.raise_reach_rifle, cfg.raise_reach_pistol, _pose.pistol)
	var lead := maxf(0.0, _pose.velocity.dot(way)) * cfg.raise_lead
	if not _world.ray(from, from + way * (reach + lead), _wall):
		return 0.0
	var near := _wall.fraction * (reach + lead) - lead
	# Eased out: the box round the replica tilts out ahead before it rises clear, so most of the raise comes early.
	var share := 1.0 - clampf((reach - near) / maxf(reach - cfg.raise_full, 0.001), 0.0, 1.0)
	return 1.0 - share * share


## The flinch dropped at once (a round reset or a rematch), the figure's bend too.
func reset_flinch() -> void:
	_flinch.reset()
	if _body != null:
		_body.set_flinch(Vector3.ZERO)


## A BB flying along `way` (the world's) hit the character, facing `yaw`: the upper body jolts that way (flattened).
func hit(way: Vector3, yaw: float) -> void:
	_flinch.hit(Basis(Vector3.UP, -yaw) * way)


## Places and poses the figure for `c` at `fraction` between its ticks, the hit flinch `delta` seconds on.
func update(c: Character, fraction: float, delta: float = 0.0) -> void:
	_flinch.advance(delta)
	global_position = c.prev_position.lerp(c.position, fraction)
	rotation = Vector3(0.0, lerp_angle(c.prev_yaw, c.yaw, fraction), 0.0)
	_sign.visible = c.status == Character.Status.CALLING or c.status == Character.Status.WALKING_OFF
	var fade := 1.0
	if c.status == Character.Status.LEAVING:
		fade = clampf(1.0 - c.status_time / maxf(_hits.vanish_time, 0.001), 0.0, 1.0)
	visible = fade > 0.0
	_fade = fade
	if c.grounded:
		_floor_y = global_position.y
	if _contact != null and _contact.visible:
		_place_contact(c, fraction)
	if _body != null:
		# The hands show the replicas as animate poses them; put away as it fades (the paint is shared).
		_body.set_fade(fade)
		if fade < 1.0:
			_body.hands.show_hands(-1, -1, false)
			_body.hands.show_reload(-1, 0.0, true)
			_body.hands.show_bomb(Grenade.Kind.NONE)


## The contact shadow under `c`'s feet at `fraction`: narrower crouched (`_place_disc`).
func _place_contact(c: Character, fraction: float) -> void:
	var crouch := lerpf(c.prev_crouch_amount, c.crouch_amount, fraction)
	_contact_radius = lerpf(_effects.contact_radius, _effects.contact_crouched_radius, crouch)
	_place_disc()


## The contact shadow under the figure as last placed: on the floor its feet last stood on, fading with the figure and
## as the feet rise off that floor, and gone once they drop below it (off a crate or a ledge, until they land).
func _place_disc() -> void:
	var feet := global_position
	var height := feet.y - _floor_y
	var up := clampf(1.0 - height / maxf(_effects.contact_fade_height, 0.001), 0.0, 1.0) if height >= 0.0 else 0.0
	_contact.global_transform = Transform3D(Basis.from_scale(Vector3(_contact_radius, 1.0, _contact_radius)),
			Vector3(feet.x, _floor_y + _effects.contact_lift, feet.z))
	_contact.transparency = 1.0 - _fade * up


## Whether the figure's hands and replica may show in `camera`'s view (FigureConfig.hold_view_height and _radius; true
## without a camera).
func _seen(camera: Camera3D, cfg: FigureConfig) -> bool:
	if camera == null:
		return true
	var size := camera.get_viewport().get_visible_rect().size
	var key := Vector4(camera.fov, size.x, size.y, camera.keep_aspect)
	if key != _corner_for:
		_corner_for = key
		_corner = view_corner(camera)
	return in_cone(camera.global_transform, _corner, global_position + Vector3.UP * cfg.hold_view_height,
			cfg.hold_view_radius)


## Whether a ball `radius` round `point` may show in `camera`'s view (true without a camera): in_cone with its
## view_corner.
static func in_view(camera: Camera3D, point: Vector3, radius: float) -> bool:
	return camera == null or in_cone(camera.global_transform, view_corner(camera), point, radius)


## The cosine and sine of the angle from `camera`'s view axis to its view's corners (a cone round the view).
static func view_corner(camera: Camera3D) -> Vector2:
	var size := camera.get_viewport().get_visible_rect().size
	var tall := tan(deg_to_rad(camera.fov) * 0.5)
	var wide := tall * (size.x / size.y if size.y > 0.0 else 1.0)
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		wide = tall
		tall = wide * (size.y / size.x if size.x > 0.0 else 1.0)
	var corner := atan(sqrt(tall * tall + wide * wide))
	return Vector2(cos(corner), sin(corner))


## Whether a ball `radius` round `point` reaches into the cone `corner` (view_corner) round the view axis of a camera
## at `at` (true for a ball round the camera). The ball widens the cone by the angle it fills, asin(radius / distance),
## added through the cosines so no angle is worked out.
static func in_cone(at: Transform3D, corner: Vector2, point: Vector3, radius: float) -> bool:
	var to := point - at.origin
	var far := to.length()
	if far <= radius:
		return true
	var fills := radius / far
	var widest := corner.x * sqrt(1.0 - fills * fills) - corner.y * fills
	return -at.basis.z.normalized().dot(to) >= widest * far
