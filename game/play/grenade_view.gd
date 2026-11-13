class_name GrenadeView
extends Node3D
## The smoke and flash bombs (SF1), drawn from the state: each slot of GameState.grenades as its bomb's model (BL9:
## the smoke's canister, the flash's pull-ring tube), its stripe or band green for smoke and violet for flash (off
## both team hues), spinning while it flies and drawn between ticks, its pin pulled once thrown (BP7); each smoke's
## cloud as up to PUFFS soft camera-facing puffs filling its ellipsoid (Grenades.cloud_middle, cloud_scale,
## cloud_density; as many as the Mesh detail's EffectsConfig.smoke_puffs, the fewer the larger: `set_puffs`), lighter
## at the top, turning slowly, dimmed by night; a flash's bang as a burst of light and a flare where it went off.
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
## Each cloud's puffs: how many at most, each one's size as a share of the cloud's width (at most; each its own share),
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
## A frame runs the bang's light down by at most this (s), so a long frame hitch at the bang still shows its flare for
## FLASH_TIME / FLASH_STEP frames or more.
const FLASH_STEP := 1.0 / 30.0
## The wash: the dazzle's white fades out over its last DAZZLE_FADE s (at most SOFT_WASH with Reduced motion); inside
## a cloud the smoke's colour, up to SMOKE_WASH as the eyes near its middle.
const DAZZLE_FADE := 1.2
const SOFT_WASH := 0.6
const SMOKE_WASH := 0.94
## The wash's canvas layer: over the field, under the HUD's (1).
const WASH_LAYER := 0
## Through the thrower's own eyes, the bomb in hand: this far right, down and ahead of the eyes (m). Your arms' model
## holds it there (tools/blender/arms/arms.py HELD_AT), and throws it from there (GT3, ArmsThrow).
const HELD_AT := Vector3(0.12, -0.12, -0.32)
## Tipped in the hand (rad, about the view's forward and right axes), as a fist holds it (arms.py HELD_TIP).
const HELD_TIP := Vector2(-0.45, 0.35)
## Each kind's hold in your arms' model (ArmsView: `<id>_Hold`, `Hold_<id>`), by Grenade.Kind.
const HOLDS: Array[StringName] = [&"", &"smoke", &"flash"]
## Each kind's pin (the smoke's pin and ring, the flash's split ring and hook) by its model's material, by
## Grenade.Kind: in your arms the left hand pulls it out (GT3), so the bomb in hand draws it apart.
const PIN_MATERIALS: Array[String] = ["", "Wire", "Steel"]

## Reduced motion on: the dazzle's wash is softer.
var soft_flash: bool = false

var _cfg: GrenadeConfig = null
var _canisters: Array[MeshInstance3D] = []
## Each kind's mesh, its Kind material painted (BODY_COLOURS), by Grenade.Kind, and how far it reaches below its
## middle lying on its side (m).
var _meshes: Array[Mesh] = []
var _lie_reach := PackedFloat32Array()
## Each kind's mesh as it flies and lies once thrown: its pin pulled (PIN_MATERIALS' surfaces left out; the whole mesh
## for a model with none), by Grenade.Kind.
var _thrown_meshes: Array[Mesh] = []
var _puffs: MultiMeshInstance3D = null
## Each puff's place in the unit ball and its size share, the same for every cloud.
var _layout := PackedVector3Array()
var _sizes := PackedFloat32Array()
## Whether each slot's puffs are shown now (hidden ones are scaled away once).
var _clouded := PackedByteArray()
## How many of each cloud's PUFFS are drawn (the first ones of the layout), and how much larger each is drawn for it.
var _shown: int = PUFFS
var _grow: float = 1.0
var _shade: float = 1.0
var _light: OmniLight3D = null
var _flare: MeshInstance3D = null
var _flare_paint: StandardMaterial3D = null
var _flash_left: float = 0.0
var _wash: ColorRect = null
## The bomb in hand: `_held_root` square to the view at the bomb's middle (your arms ride it), `_held` tipped in it
## (HELD_TIP: `_held_rest`) and moved with the hand throwing it, and its pin `_pin` (with your arms) with it until the
## left hand takes it.
var _held_root: Node3D = null
## The life the hands have this frame (HA1: ReplicaView's HandsMotion, stepped before this draws), which the bomb in
## hand takes too; null: none.
var hands_life: HandsMotion = null
var _held: MeshInstance3D = null
var _pin: MeshInstance3D = null
var _held_rest := Transform3D.IDENTITY
var _held_kind: int = Grenade.Kind.NONE
## How far up into view the hand is (0 below, 1 in place), and how far through the throw it is (ArmsThrow's share).
var _raise: float = 0.0
var _share: float = 0.0
## Whether the empty hand is following through after a throw.
var _following := false
## How much of the arms' ease back from a throw cut off in its windup is left (1 at the cut, 0 none: ArmsView's
## `unwind_throw`, over ViewModelConfig.bomb_unwind_time).
var _unwind: float = 0.0
## Your arms holding it (none until `setup_arms`), and by Grenade.Kind: the bomb in hand without its pin and the pin
## alone (null: none), each surface's material with the depth pressed as theirs, and the pin's middle (the bomb's
## frame).
var _arms: ArmsView = null
var _view_cfg: ViewModelConfig = null
var _held_meshes: Array[Mesh] = []
var _pin_meshes: Array[Mesh] = []
var _held_paint: Array[Array] = []
var _pin_paint: Array[Array] = []
var _pin_middle := PackedVector3Array()
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
		paint.resource_name = KIND_MATERIAL
		var mesh := _kind_mesh(kind, paint)
		_meshes.append(mesh)
		_lie_reach.append(-(_lying() * mesh.get_aabb()).position.y)
		_thrown_meshes.append(_split(mesh, PIN_MATERIALS[kind] if kind < PIN_MATERIALS.size() else "")[0])
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
	_held_rest = Transform3D(Basis(Vector3.FORWARD, HELD_TIP.x) * Basis(Vector3.RIGHT, HELD_TIP.y), Vector3.ZERO)
	_held.transform = _held_rest
	_held_root.add_child(_held)
	_pin = MeshInstance3D.new()
	_pin.name = "Pin"
	_pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pin.visible = false
	_held_root.add_child(_pin)
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
	_flash_left = maxf(0.0, _flash_left - minf(delta, FLASH_STEP))
	var lit := _flash_left / FLASH_TIME
	if _light.visible:
		_light.light_energy = FLASH_ENERGY * lit * lit
		_flare_paint.albedo_color.a = lit
		if lit <= 0.0:
			_light.visible = false
			_flare.visible = false
	_draw_wash(state, eyes, eye)
	_draw_held(eyes, eye, delta, fraction / float(Engine.physics_ticks_per_second))


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
	_pin.layers = OpticGlass.HANDS_LAYER
	var pressed: Dictionary[Material, Material] = {}
	for k in _meshes.size():
		var parts := _split(_meshes[k], PIN_MATERIALS[k] if k < PIN_MATERIALS.size() else "")
		_held_meshes.append(parts[0])
		_pin_meshes.append(parts[1])
		# In your hand a bomb is made of what its model says (MQ2B: card, polymer, steel); thrown, it stays plain.
		var named := ReplicaSurfaces.named(_meshes[k])
		_held_paint.append(_paint(parts[0], named, pressed, cfg.depth_scale))
		_pin_paint.append(_paint(parts[1], named, pressed, cfg.depth_scale))
		_pin_middle.append(parts[1].get_aabb().get_center() if parts[1] != null else Vector3.ZERO)
	_held.mesh = null
	_held_kind = Grenade.Kind.NONE


## Dresses your arms as `kind` (FigureMix.HUMAN or FigureMix.ROBOT).
func set_arms_kind(kind: int) -> void:
	if _arms != null:
		_arms.set_kind(kind)


## Shows your arms skin only (`on`; Dev › Skin-only arms, BP8) or gloved.
func set_arms_skin(on: bool) -> void:
	if _arms != null:
		_arms.set_skin(on)


## Each cloud drawn as `count` of its PUFFS (at least 1), each sqrt(PUFFS / count) times as wide, so the cloud covers
## as much and looks as thick: set by the graphics' Mesh detail (EffectsConfig.smoke_puffs_at), on a change only. The
## puffs left out are scaled away at once; a cloud in the air is drawn again on the next frame.
func set_puffs(count: int) -> void:
	var n := clampi(count, 1, PUFFS)
	if n == _shown:
		return
	_shown = n
	_grow = sqrt(float(PUFFS) / n)
	if _puffs == null:
		return
	var mm := _puffs.multimesh
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_clouded.fill(0)


## How many puffs each cloud draws now, for tests.
func puffs_shown() -> int:
	return _shown


## Puff `k`'s width (m) in a cloud `rx` m wide across its radius: none for one not drawn (`set_puffs`).
func puff_width(k: int, rx: float) -> float:
	if k < 0 or k >= _shown:
		return 0.0
	return rx * 2.0 * PUFF_SIZE * _sizes[k] * _grow


## The puffs' and the bombs' materials, and your arms' and the bomb in hand's (depth pressed), for ShaderPrewarm.
func materials() -> Array[Material]:
	var out: Array[Material] = [(_puffs.multimesh.mesh as PrimitiveMesh).material, _flare_paint]
	for mesh in _meshes:
		for i in mesh.get_surface_count():
			var own := mesh.surface_get_material(i)
			if own != null and not out.has(own):
				out.append(own)
	for paint: Array in _held_paint + _pin_paint:
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


## Kind `kind`'s mesh once thrown (its pin pulled), for tests.
func thrown_mesh_of(kind: int) -> Mesh:
	return _thrown_meshes[clampi(kind, 0, _thrown_meshes.size() - 1)]


## Kind `kind`'s mesh in your arms' hand (its pin drawn apart: `pin_mesh_of`), for tests.
func held_mesh_of(kind: int) -> Mesh:
	return _held_meshes[clampi(kind, 0, _held_meshes.size() - 1)] if not _held_meshes.is_empty() else mesh_of(kind)


func pin_mesh_of(kind: int) -> Mesh:
	return _pin_meshes[clampi(kind, 0, _pin_meshes.size() - 1)] if not _pin_meshes.is_empty() else null


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
	if m.mesh != _thrown_meshes[kind]:
		m.mesh = _thrown_meshes[kind]
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
	for k in _shown:
		var u := turn * _layout[k]
		var width := puff_width(k, rx)
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


## The bomb in `eyes`' hand while it waits for a trigger pull (MC1) or is thrown, before their eyes at `eye`, the tick
## `ahead` s on (s) from its last step. With your arms (`setup_arms`) the hand comes up into view with it from
## ViewModelConfig.bomb_raise_drop below over bomb_raise_time, eased as a draw, and throws it (ArmsThrow): the left
## hand pulls the pin and the right arm swings over and lets it go, then follows through out of view, where it is
## gone; a bomb put back goes down with the hand the way it came, and a throw cut off in its windup (a hit, the round's
## end, other eyes) eases the arms back to its start as the hand goes (bomb_unwind_time) instead of snapping them to
## the hold. Without them the bomb shows and goes at once.
func _draw_held(eyes: Character, eye: Vector3, delta: float, ahead: float) -> void:
	var kind := Grenades.held(eyes)
	var through := _arms != null and eyes != null and _held_root.visible and _held_kind != Grenade.Kind.NONE \
			and eyes.grenades.throwing != Grenade.Kind.NONE and eyes.grenades.released
	if kind != Grenade.Kind.NONE:
		if _following:
			# A new bomb straight after a throw's follow-through: it comes up from below too.
			_raise = 0.0
		_following = false
		_raise = 1.0 if _view_cfg == null else move_toward(_raise, 1.0, delta / _view_cfg.bomb_raise_time)
		if kind != _held_kind:
			_end_unwind()
			_hold(kind)
		_share = throw_share(eyes, _cfg, ahead)
	elif through:
		_share = throw_share(eyes, _cfg, ahead)
		_following = true
	elif _following:
		# The follow-through has taken the empty hand out of view.
		_following = false
		_raise = 0.0
	elif eyes != null and _view_cfg != null and _held_root.visible and _raise > 0.0:
		# Put back, or a throw cut off (hit, round over, other eyes): down the way it came, the arms easing back from
		# where the throw left them.
		if _share > 0.0 and _arms != null:
			_arms.cut_throw(_share)
			_unwind = 1.0
		_share = 0.0
		_raise = move_toward(_raise, 0.0, delta / _view_cfg.bomb_raise_time)
	else:
		_raise = 0.0
	if _share > 0.0:
		_unwind = 0.0
	elif _unwind > 0.0 and _view_cfg != null:
		# Never longer than the hand takes to go down, or it is gone before the arms are back.
		_unwind = move_toward(_unwind, 0.0,
				delta / minf(_view_cfg.bomb_unwind_time, _view_cfg.bomb_raise_time))
	if _raise <= 0.0:
		_share = 0.0
		_unwind = 0.0
		_following = false
		if _held_root.visible:
			_held_root.visible = false
		return
	var low := 1.0 - _raise
	var drop := _view_cfg.bomb_raise_drop * low * low if _view_cfg != null else 0.0
	var view := Basis.from_euler(Vector3(eyes.pitch, eyes.yaw, 0.0))
	var at := HELD_AT + Vector3(0.0, -drop, 0.0)
	if hands_life != null:
		# The bob, the breathing and the lean your hands have with a replica (HA1), about the bomb's own middle.
		_held_root.transform = Transform3D(view * Basis.from_euler(hands_life.turn), eye + view * (at + hands_life.shift))
	else:
		_held_root.transform = Transform3D(view, eye + view * at)
	_held.visible = kind != Grenade.Kind.NONE
	if _arms != null:
		if _unwind > 0.0:
			_arms.unwind_throw(1.0 - _unwind)
		else:
			_arms.throw_pose(_share)
		var model := _arms.model_transform()
		var back := model.affine_inverse()
		_held.transform = model * _arms.bomb_moved() * back * _held_rest
		_pin.visible = _pin.mesh != null and _held.visible and _share < _view_cfg.bomb_pin_out
		if _pin.visible:
			_pin.transform = model * _arms.pin_moved(_share) * back * _held_rest
	_held_root.visible = true


## The arms put back on the hold if they were easing back from a cut-off throw (before another hold goes on).
func _end_unwind() -> void:
	if _unwind > 0.0 and _arms != null:
		_arms.throw_pose(0.0)
	_unwind = 0.0


## How far `c` is through a throw `ahead` s past its last step (ArmsThrow's share: 0..1 over the windup, 1..2 over the
## recovery; 0 with none).
static func throw_share(c: Character, cfg: GrenadeConfig, ahead: float) -> float:
	var hand := c.grenades
	if hand.throwing == Grenade.Kind.NONE:
		return 0.0
	if not hand.released:
		return clampf(1.0 - (hand.windup_left - ahead) / maxf(cfg.windup, 0.001), 0.0, 1.0)
	return 1.0 + clampf(1.0 - (hand.recover_left - ahead) / maxf(cfg.recover, 0.001), 0.0, 1.0)


## The bomb in hand becomes kind `kind`'s, in your arms when they're set up (its pin apart, for the left hand).
func _hold(kind: int) -> void:
	_held_kind = kind
	var k := clampi(kind, 0, _meshes.size() - 1)
	if _arms == null:
		_held.mesh = _meshes[k]
		return
	_held.mesh = _held_meshes[k]
	_pin.mesh = _pin_meshes[k]
	_dress(_held, _held_paint[k])
	_dress(_pin, _pin_paint[k])
	_arms.hold(HOLDS[k] if k < HOLDS.size() else &"", _held_root)
	_arms.ready_throw(_arms.model_transform().affine_inverse() * (_held_rest * _pin_middle[k]))


static func _dress(node: MeshInstance3D, paint: Array) -> void:
	for i in paint.size():
		node.set_surface_override_material(i, paint[i])


## `mesh` drawn apart: [it without the surfaces whose material is named `pin`, those alone (null: none)]; `mesh` and
## null when it has none or can't be.
static func _split(mesh: Mesh, pin: String) -> Array[Mesh]:
	var own := mesh as ArrayMesh
	var out: Array[Mesh] = [mesh, null]
	if own == null or pin.is_empty():
		return out
	var body := ArrayMesh.new()
	var parts := ArrayMesh.new()
	for i in own.get_surface_count():
		var material := own.surface_get_material(i)
		var into := parts if material != null and material.resource_name == pin else body
		into.add_surface_from_arrays(own.surface_get_primitive_type(i), own.surface_get_arrays(i))
		into.surface_set_material(into.get_surface_count() - 1, material)
	if parts.get_surface_count() > 0 and body.get_surface_count() > 0:
		out[0] = body
		out[1] = parts
	return out


## `mesh`'s surfaces' materials with the depth pressed to `scale` (one copy for each of the model's materials, kept in
## `pressed`), each one `named` gives a kind (ReplicaSurfaces.named) drawn on that surface in its own colour (MQ2B).
static func _paint(mesh: Mesh, named: Dictionary[StringName, int], pressed: Dictionary[Material, Material],
		scale: float) -> Array[Material]:
	var out: Array[Material] = []
	if mesh == null:
		return out
	for i in mesh.get_surface_count():
		var own := mesh.surface_get_material(i)
		if own == null:
			out.append(null)
			continue
		if not pressed.has(own):
			var material_name := StringName(own.resource_name)
			var shown: Material = ReplicaPaint.own_surface(own, named[material_name]) if named.has(material_name) else own
			pressed[own] = _pressed(shown, scale)
		out.append(pressed[own])
	return out


## Whether the bomb in hand is drawn, for tests.
func held_shown() -> bool:
	return _held_root.visible and _held.visible


## Your arms holding the bomb (null until `setup_arms`), for tests.
func arms() -> ArmsView:
	return _arms


## `shown` with its depth pressed towards the eye to `scale` (ViewModelConfig.depth_scale, as your arms' and the
## replica's) and no shadow falling on it: a copy of a model's material, or this view's own surface of one
## (ReplicaPaint.own_surface) pressed as it stands, as the replica in your hands is; `shown` itself when it can't be
## pressed.
static func _pressed(shown: Material, scale: float) -> Material:
	if ReplicaPaint.is_surface(shown):
		(shown as ShaderMaterial).set_shader_parameter(&"z_clip_scale", minf(scale, 1.0))
		return shown
	var base := shown as BaseMaterial3D
	if base == null:
		return shown
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
