class_name GrenadeView
extends Node3D
## The smoke and flash bombs (SF1), drawn from the state: each slot of GameState.grenades as its bomb's model (BL9:
## the smoke's canister, the flash's pull-ring tube), its stripe or band green for smoke and violet for flash (off
## both team hues), spinning while it flies and drawn between ticks; each smoke's
## cloud as PUFFS soft camera-facing puffs filling its ellipsoid (Grenades.cloud_middle, cloud_scale, cloud_density),
## lighter at the top, turning slowly, dimmed by night; a flash's bang as a burst of light and a flare where it went off.
## Through the eyes the view is through, a wash over the screen: white while a flash dazzles them (fading over its last
## DAZZLE_FADE s; softer with Reduced motion on), and the smoke's colour while the eyes are inside a cloud. Reads the
## state and the tick's events; owns no rule. Made once; a frame allocates nothing.

## Each bomb's model by Grenade.Kind (NONE: none), its long axis up through its middle (tools/blender/grenades/), and
## the material in it painted in the kind's colour; a model that won't load draws a plain canister CANISTER_RADIUS
## by CANISTER_HEIGHT (m) in that colour instead.
const MODELS: Array[String] = ["", "res://assets/models/grenades/smoke.glb", "res://assets/models/grenades/flash.glb"]
const KIND_MATERIAL := "Kind"
const CANISTER_RADIUS := 0.032
const CANISTER_HEIGHT := 0.12
## A bomb at rest lies on its side, turned this way about the view's forward axis: the smoke's lever (the model's +X)
## points up, so the canister rests on its body; it is lifted by the model's own lowest reach that way.
const LIE := -PI * 0.5
## Each kind's colour (NONE unused); its spin while flying (turns a second).
const BODY_COLOURS: Array[Color] = [Color("2b2d31"), Color("4f9d6a"), Color("7d5bc4")]
const BODY_ROUGHNESS := 0.6
const SPIN := 2.0
## Each cloud's puffs: how many, each one's size as a share of the cloud's width (at most; each its own share of it),
## its colour from the bottom of the cloud to the top, its alpha at full density, and how fast the cloud turns (rad/s).
## The puffs' places come from their own seeded stream: every cloud alike.
const PUFFS := 28
const PUFF_SIZE := 1.1
const PUFF_SIZE_MIN := 0.6
const SMOKE_LOW := Color("bdb7ac")
const SMOKE_HIGH := Color("f6f2ea")
const PUFF_ALPHA := 0.9
const TURN := 0.12
const PUFF_SEED := 9113
## A puff fades out this close (m) to the ground or a wall it passes into, so a cloud has no hard edge there, and keeps
## its middle at least this share of its width over the canister's ground.
const PUFF_SOFT := 1.2
const PUFF_FLOOR := 0.3
## By night the smoke is drawn this much darker (it is unlit).
const NIGHT_SHADE := 0.32
## The bang: a light this bright, reaching this far (m), gone over FLASH_TIME s, and a flare this big (m) fading with it.
const FLASH_ENERGY := 14.0
const FLASH_RANGE := 16.0
const FLASH_TIME := 0.3
const FLASH_COLOUR := Color(1.0, 0.97, 0.9)
const FLARE_SIZE := 2.4
## The wash: the dazzle's white fades out over its last DAZZLE_FADE s (at most SOFT_WASH with Reduced motion); inside
## a cloud the smoke's colour, up to SMOKE_WASH as the eyes near its middle.
const DAZZLE_FADE := 1.2
const SOFT_WASH := 0.6
const SMOKE_WASH := 0.94
## The wash's canvas layer: over the field, under the HUD's (1).
const WASH_LAYER := 0
## Through the thrower's own eyes, the bomb in hand while the pin comes out: this far right, down and ahead of the eyes
## (m), lifted HELD_LIFT as the windup runs out. Your arms' model holds it there (tools/blender/arms/arms.py HELD_AT).
const HELD_AT := Vector3(0.12, -0.12, -0.32)
const HELD_LIFT := 0.03
## Tipped in the hand (rad, about the view's forward and right axes), as a fist holds it (arms.py HELD_TIP).
const HELD_TIP := Vector2(-0.45, 0.35)
## Each kind's hold in your arms' model (ArmsView: `<id>_Hold`, `Hold_<id>`), by Grenade.Kind.
const HOLDS: Array[StringName] = [&"", &"smoke", &"flash"]

## Reduced motion on: the dazzle's wash is softer.
var soft_flash: bool = false

var _cfg: GrenadeConfig = null
var _canisters: Array[MeshInstance3D] = []
## Each kind's mesh, its Kind material painted (BODY_COLOURS), by Grenade.Kind, and how far it reaches below its
## middle lying on its side (m).
var _meshes: Array[Mesh] = []
var _lie_reach := PackedFloat32Array()
var _puffs: MultiMeshInstance3D = null
## Each puff's place in the unit ball and its size share, the same for every cloud.
var _layout := PackedVector3Array()
var _sizes := PackedFloat32Array()
## Whether each slot's puffs are shown now (hidden ones are scaled away once).
var _clouded := PackedByteArray()
var _shade: float = 1.0
var _light: OmniLight3D = null
var _flare: MeshInstance3D = null
var _flare_paint: StandardMaterial3D = null
var _flash_left: float = 0.0
var _wash: ColorRect = null
## The bomb in hand: `_held_root` square to the view at the bomb's middle (your arms ride it), `_held` tipped in it.
var _held_root: Node3D = null
var _held: MeshInstance3D = null
var _held_kind: int = Grenade.Kind.NONE
## How far up into view the hand is (0 below, 1 in place) and its lift through the windup (m), kept as it goes down.
var _raise: float = 0.0
var _lift: float = 0.0
## Your arms holding it (none until `setup_arms`), and each kind's materials with the depth pressed as theirs, by
## Grenade.Kind and surface.
var _arms: ArmsView = null
var _view_cfg: ViewModelConfig = null
var _held_paint: Array[Array] = []
var _wash_layer: CanvasLayer = null


## A canister and PUFFS puffs for each of `count` slots, drawn for `cfg`'s bombs; `night` dims the smoke.
func setup(count: int, cfg: GrenadeConfig, night: bool) -> void:
	name = "Grenades"
	top_level = true
	_cfg = cfg
	_shade = NIGHT_SHADE if night else 1.0
	for kind in BODY_COLOURS.size():
		var paint := StandardMaterial3D.new()
		paint.albedo_color = BODY_COLOURS[kind]
		paint.roughness = BODY_ROUGHNESS
		var mesh := _kind_mesh(kind, paint)
		_meshes.append(mesh)
		_lie_reach.append(-(_lying() * mesh.get_aabb()).position.y)
	for i in maxi(0, count):
		var m := MeshInstance3D.new()
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_canisters.append(m)
	_puffs = MultiMeshInstance3D.new()
	_puffs.name = "Smoke"
	var smoke := PuffView.flat_material()
	smoke.proximity_fade_enabled = true
	smoke.proximity_fade_distance = PUFF_SOFT
	PuffView.pool_of(_puffs, maxi(1, count * PUFFS), smoke)
	add_child(_puffs)
	for i in _puffs.multimesh.instance_count:
		_puffs.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_clouded.resize(maxi(0, count))
	_lay_out()
	_held_root = Node3D.new()
	_held_root.name = "Held"
	_held_root.visible = false
	add_child(_held_root)
	_held = MeshInstance3D.new()
	_held.name = "Bomb"
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.basis = Basis(Vector3.FORWARD, HELD_TIP.x) * Basis(Vector3.RIGHT, HELD_TIP.y)
	_held_root.add_child(_held)
	_light = OmniLight3D.new()
	_light.light_color = FLASH_COLOUR
	_light.omni_range = FLASH_RANGE
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_flare_paint = PuffView.flat_material()
	_flare_paint.vertex_color_use_as_albedo = false
	_flare_paint.albedo_color = FLASH_COLOUR
	var quad := QuadMesh.new()
	quad.size = Vector2(FLARE_SIZE, FLARE_SIZE)
	quad.material = _flare_paint
	_flare = MeshInstance3D.new()
	_flare.mesh = quad
	_flare.visible = false
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flare)
	_wash_layer = CanvasLayer.new()
	_wash_layer.layer = WASH_LAYER
	add_child(_wash_layer)
	_wash = ColorRect.new()
	_wash.name = "Wash"
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.visible = false
	_wash_layer.add_child(_wash)


## The tick's events: a flash's bang lights up where it went off.
func on_tick(state: GameState) -> void:
	var bang := state.events.first(GameEvent.Kind.FLASH_BANG)
	if bang == null:
		return
	_flash_left = FLASH_TIME
	_light.position = bang.position
	_flare.position = bang.position
	_light.visible = true
	_flare.visible = true


## Every frame: the canisters `fraction` of a tick past their last step, the clouds, the bang's light, and the wash for
## `eyes` (the character the view is through; null: none) seen from `eye`.
func update(state: GameState, fraction: float, delta: float, eyes: Character, eye: Vector3) -> void:
	var pool := state.grenades
	for i in _canisters.size():
		var g: Grenade = pool[i] if i < pool.size() else null
		_draw_canister(_canisters[i], g, fraction)
		_draw_cloud(i, g)
	_flash_left = maxf(0.0, _flash_left - delta)
	var lit := _flash_left / FLASH_TIME
	if _light.visible:
		_light.light_energy = FLASH_ENERGY * lit * lit
		_flare_paint.albedo_color.a = lit
		if lit <= 0.0:
			_light.visible = false
			_flare.visible = false
	_draw_wash(state, eyes, eye)
	_draw_held(eyes, eye, delta)


## Your arms holding the bomb in hand (BL4's model, `cfg`'s look) and the bomb drawn with them: its depth pressed as
## theirs and out of an optic's view. Without this the bomb is drawn alone at its true depth.
func setup_arms(cfg: ViewModelConfig, kind: int) -> void:
	if _arms != null:
		return
	_view_cfg = cfg
	_arms = ArmsView.new()
	add_child(_arms)
	_arms.setup(cfg)
	_arms.set_kind(kind)
	_held.layers = OpticGlass.HANDS_LAYER
	for mesh in _meshes:
		var paint: Array[Material] = []
		for i in mesh.get_surface_count():
			paint.append(_pressed(mesh.surface_get_material(i), cfg.depth_scale))
		_held_paint.append(paint)
	_held.mesh = null
	_held_kind = Grenade.Kind.NONE


## Dresses your arms as `kind` (FigureMix.HUMAN or FigureMix.ROBOT).
func set_arms_kind(kind: int) -> void:
	if _arms != null:
		_arms.set_kind(kind)


## The puffs' and the bombs' materials, and your arms' and the bomb in hand's (depth pressed), for ShaderPrewarm.
func materials() -> Array[Material]:
	var out: Array[Material] = [(_puffs.multimesh.mesh as PrimitiveMesh).material, _flare_paint]
	for mesh in _meshes:
		for i in mesh.get_surface_count():
			var own := mesh.surface_get_material(i)
			if own != null and not out.has(own):
				out.append(own)
	for paint: Array in _held_paint:
		for m: Material in paint:
			if m != null and not out.has(m):
				out.append(m)
	if _arms != null:
		out.append_array(_arms.materials())
	return out


## Every kind's mesh by Grenade.Kind (NONE's unused), each made once and shared: the figures hold them in the hand
## while they throw (FigureView.set_bombs; never changed there).
func meshes() -> Array[Mesh]:
	return _meshes


## Kind `kind`'s mesh, for tests.
func mesh_of(kind: int) -> Mesh:
	return _meshes[clampi(kind, 0, _meshes.size() - 1)]


## How far kind `kind`'s model reaches below its middle lying on its side (m), for tests.
func lie_reach(kind: int) -> float:
	return _lie_reach[clampi(kind, 0, _lie_reach.size() - 1)]


## A bomb lying on its side.
static func _lying() -> Transform3D:
	return Transform3D(Basis(Vector3.FORWARD, LIE), Vector3.ZERO)


## The model of `kind` (MODELS) with its Kind material swapped for `paint`, made once; a plain canister drawn in
## `paint` when it has none or won't load.
static func _kind_mesh(kind: int, paint: StandardMaterial3D) -> Mesh:
	var own := PropDressConfig.load_mesh(MODELS[kind]) as ArrayMesh if kind < MODELS.size() else null
	if own == null:
		var can := CylinderMesh.new()
		can.top_radius = CANISTER_RADIUS
		can.bottom_radius = CANISTER_RADIUS
		can.height = CANISTER_HEIGHT
		can.material = paint
		return can
	var mesh := own.duplicate() as ArrayMesh
	for i in mesh.get_surface_count():
		var material := mesh.surface_get_material(i)
		if material != null and material.resource_name == KIND_MATERIAL:
			mesh.surface_set_material(i, paint)
	return mesh


## The wash's colour now (alpha 0: none), for tests.
func wash() -> Color:
	return _wash.color if _wash.visible else Color(0.0, 0.0, 0.0, 0.0)


## Whether slot `i`'s canister is drawn, and its puffs, for tests.
func canister_shown(i: int) -> bool:
	return i < _canisters.size() and _canisters[i].visible


func cloud_shown(i: int) -> bool:
	return i < _clouded.size() and _clouded[i] == 1


## How bright the bang's light is now, for tests.
func flash_energy() -> float:
	return _light.light_energy if _light.visible else 0.0


## How much the screen is washed out for eyes dazzled `left` of `total` s (0..1): whole until the last DAZZLE_FADE s,
## then fading; at most SOFT_WASH when `soft`.
static func dazzle_wash(left: float, total: float, soft: bool) -> float:
	if left <= 0.0 or total <= 0.0:
		return 0.0
	var amount := clampf(left / DAZZLE_FADE, 0.0, 1.0)
	return amount * (SOFT_WASH if soft else 1.0)


## How deep in smoke the eyes at `eye` are (0 outside every cloud .. 1 at a middle), each cloud by its density.
static func smoke_inside(pool: Array[Grenade], cfg: GrenadeConfig, eye: Vector3) -> float:
	var most := 0.0
	for g in pool:
		if not g.active or not g.popped or g.kind != Grenade.Kind.SMOKE:
			continue
		var size := Grenades.cloud_scale(g, cfg)
		var rx := cfg.smoke_radius * size
		var ry := cfg.smoke_height * size
		if rx <= 0.0 or ry <= 0.0:
			continue
		var p := eye - Grenades.cloud_middle(g, cfg)
		var q := Vector3(p.x / rx, p.y / ry, p.z / rx).length()
		if q < 1.0:
			most = maxf(most, (1.0 - q) * Grenades.cloud_density(g, cfg))
	return most


## Slot's canister `m` for bomb `g` (null or inactive: hidden): spinning about its side while it flies, lying on its side
## once it rests.
func _draw_canister(m: MeshInstance3D, g: Grenade, fraction: float) -> void:
	if g == null or not g.active:
		if m.visible:
			m.visible = false
		return
	var at := g.prev_position.lerp(g.position, fraction)
	var basis := Basis.IDENTITY
	if g.resting:
		basis = _lying().basis
	else:
		basis = Basis(Vector3.RIGHT, SPIN * TAU * g.age)
	var kind := clampi(g.kind, 0, _meshes.size() - 1)
	m.transform = Transform3D(basis, at + Vector3(0.0, _lie_reach[kind] - _cfg.radius, 0.0) if g.resting else at)
	if m.mesh != _meshes[kind]:
		m.mesh = _meshes[kind]
	m.visible = true


## Slot `i`'s cloud: its puffs placed in its ellipsoid, or scaled away once when it has none.
func _draw_cloud(i: int, g: Grenade) -> void:
	var mm := _puffs.multimesh
	var first := i * PUFFS
	var size := Grenades.cloud_scale(g, _cfg) if g != null and g.active else 0.0
	if size <= 0.0:
		if _clouded[i] == 1:
			_clouded[i] = 0
			for k in PUFFS:
				mm.set_instance_transform(first + k, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		return
	_clouded[i] = 1
	var density := Grenades.cloud_density(g, _cfg)
	var middle := Grenades.cloud_middle(g, _cfg)
	var rx := _cfg.smoke_radius * size
	var ry := _cfg.smoke_height * size
	# The cloud's own time turns it: every cloud turns as its smoke ages.
	var turn := Basis(Vector3.UP, TURN * g.smoking)
	for k in PUFFS:
		var u := turn * _layout[k]
		var width := rx * 2.0 * PUFF_SIZE * _sizes[k]
		var at := middle + Vector3(u.x * rx, u.y * ry, u.z * rx)
		at.y = maxf(at.y, g.position.y + width * PUFF_FLOOR)
		mm.set_instance_transform(first + k, Transform3D(Basis.from_scale(Vector3.ONE * width), at))
		var colour := SMOKE_LOW.lerp(SMOKE_HIGH, clampf(u.y * 0.5 + 0.5, 0.0, 1.0)) * _shade
		colour.a = PUFF_ALPHA * density
		mm.set_instance_color(first + k, colour)


func _draw_wash(state: GameState, eyes: Character, eye: Vector3) -> void:
	var white := 0.0
	var smoke := 0.0
	if eyes != null:
		white = dazzle_wash(eyes.dazzle_left, eyes.dazzle_total, soft_flash)
		smoke = minf(SMOKE_WASH, smoke_inside(state.grenades, _cfg, eye) * 2.0)
	if white <= 0.0 and smoke <= 0.0:
		if _wash.visible:
			_wash.visible = false
		return
	var colour := SMOKE_HIGH * _shade
	colour.a = smoke
	if white > 0.0:
		colour = colour.blend(Color(1.0, 1.0, 1.0, white))
	_wash.color = colour
	_wash.visible = true


## The bomb in `eyes`' hand while its pin comes out, or while it waits in hand for a trigger pull (MC1), before their
## eyes at `eye`.
## With your arms (`setup_arms`) the hand comes up into view with it from ViewModelConfig.bomb_raise_drop below over
## bomb_raise_time, eased as a draw, and once it has left the hand the empty hand goes back down the same way; without
## them the bomb shows and goes at once.
func _draw_held(eyes: Character, eye: Vector3, delta: float) -> void:
	var kind := Grenades.held(eyes)
	if kind != Grenade.Kind.NONE:
		var ready := 0.0
		if eyes.grenades.throwing == kind:
			ready = 1.0 - clampf(eyes.grenades.windup_left / maxf(_cfg.windup, 0.001), 0.0, 1.0)
		_lift = HELD_LIFT * ready
		_raise = 1.0 if _view_cfg == null else move_toward(_raise, 1.0, delta / _view_cfg.bomb_raise_time)
		if kind != _held_kind:
			_hold(kind)
	elif eyes != null and _view_cfg != null and _held_root.visible and _raise > 0.0:
		_raise = move_toward(_raise, 0.0, delta / _view_cfg.bomb_raise_time)
	else:
		_raise = 0.0
	if _raise <= 0.0:
		if _held_root.visible:
			_held_root.visible = false
		return
	var low := 1.0 - _raise
	var drop := _view_cfg.bomb_raise_drop * low * low if _view_cfg != null else 0.0
	var view := Basis.from_euler(Vector3(eyes.pitch, eyes.yaw, 0.0))
	_held_root.transform = Transform3D(view, eye + view * (HELD_AT + Vector3(0.0, _lift - drop, 0.0)))
	_held.visible = kind != Grenade.Kind.NONE
	_held_root.visible = true


## The bomb in hand becomes kind `kind`'s, in your arms when they're set up.
func _hold(kind: int) -> void:
	_held_kind = kind
	var k := clampi(kind, 0, _meshes.size() - 1)
	_held.mesh = _meshes[k]
	if k < _held_paint.size():
		var paint: Array = _held_paint[k]
		for i in paint.size():
			_held.set_surface_override_material(i, paint[i])
	if _arms != null:
		_arms.hold(HOLDS[k] if k < HOLDS.size() else &"", _held_root)


## Whether the bomb in hand is drawn, for tests.
func held_shown() -> bool:
	return _held_root.visible and _held.visible


## Your arms holding the bomb (null until `setup_arms`), for tests.
func arms() -> ArmsView:
	return _arms


## A copy of `own` with its depth pressed towards the eye to `scale` (ViewModelConfig.depth_scale, as your arms' and the
## replica's) and no shadow falling on it; `own` itself when it can't be pressed.
static func _pressed(own: Material, scale: float) -> Material:
	var base := own as BaseMaterial3D
	if base == null:
		return own
	var copy := base.duplicate() as BaseMaterial3D
	copy.disable_receive_shadows = true
	if scale < 1.0:
		copy.use_z_clip_scale = true
		copy.z_clip_scale = scale
	return copy


## Each puff's place in the unit ball (more of them low and in the middle) and its size share, from PUFF_SEED.
func _lay_out() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PUFF_SEED
	_layout.resize(PUFFS)
	_sizes.resize(PUFFS)
	for k in PUFFS:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 0.6), rng.randf_range(-1.0, 1.0))
		_layout[k] = dir.normalized() * sqrt(rng.randf()) * 0.75 if dir.length_squared() > 0.0 else Vector3.ZERO
		_sizes[k] = rng.randf_range(PUFF_SIZE_MIN, 1.0)
