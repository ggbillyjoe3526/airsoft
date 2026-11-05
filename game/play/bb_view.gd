class_name BBView
extends MultiMeshInstance3D
## Every BB in the air, drawn between the last two ticks as one MultiMesh (one draw call, nothing allocated a frame):
## the Blender BB (EffectsConfig.bb_model, BM1), small bright balls with a darker rim (bb_ball.gdshader), a little
## larger than life and never under
## EffectsConfig.bb_min_angle on screen, each with a faint
## short trail fading back along its flight (one more instanced draw), so they read at range. Your own BBs leave from
## the muzzle's side of the view and join their true path from the eye over EffectsConfig.muzzle_join_time, so a shot
## never starts in front of your face; only the muzzle's offset across the flight is drawn, never ahead along it, so a
## drawn BB never passes the wall its true one stops on.
## Glowing BBs (WL8, Loadout.Glow) are drawn apart: a green ball never smaller on screen than EffectsConfig.glow_min_angle
## and a green streak back along its flight, two more instanced draws, hidden while none flies. Which BBs glow is set
## once a match (`set_glowing`): presentation only, as the BBs fly the same.

## The stand-in ball's coarseness, drawn only when EffectsConfig.bb_model can't be read.
const RADIAL_SEGMENTS := 8
const RINGS := 4
## A streak seen this nearly end-on (the sine of its angle off the line of sight) is not drawn: it would be a dot.
const END_ON := 0.001
## A white BB's look: its colour with a darker rim.
const BALL_SHADER := preload("res://game/play/bb_ball.gdshader")
## Steps in a trail's fade from the BB to its tail.
const FADE_STEPS := 16

var _cfg: EffectsConfig = null
var _glow_balls: MultiMeshInstance3D = null
var _streaks: MultiMeshInstance3D = null
## The white BBs' trails (null: EffectsConfig.bb_trail_opacity is 0).
var _trails: MultiMeshInstance3D = null
## Each character's loadout slots whose BBs glow this match, by its id: bit `slot` set.
var _glowing: PackedByteArray = PackedByteArray()
## Whether any character's BBs glow this match: without, a white BB costs no more than before glowing BBs.
var _any: bool = false


func setup(cfg: EffectsConfig, pool_size: int) -> void:
	_cfg = cfg
	name = "BBs"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var white := ShaderMaterial.new()
	white.shader = BALL_SHADER
	white.set_shader_parameter(&"colour", cfg.bb_colour)
	white.set_shader_parameter(&"rim", cfg.bb_rim_colour)
	white.set_shader_parameter(&"rim_from", cfg.bb_rim_from)
	var ball_mesh := bb_mesh(cfg.bb_model)
	multimesh = _instances(ball_mesh, pool_size)
	material_override = white
	_glow_balls = _child("GlowBBs", ball_mesh, pool_size)
	_glow_balls.material_override = _unshaded(cfg.glow_colour)
	var streak := _unshaded(Color(cfg.glow_streak_colour, cfg.glow_streak_opacity))
	streak.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.material = streak
	_streaks = _child("GlowStreaks", quad, pool_size)
	if cfg.bb_trail_opacity > 0.0:
		var trail := _unshaded(Color(cfg.bb_colour, cfg.bb_trail_opacity))
		trail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		trail.cull_mode = BaseMaterial3D.CULL_DISABLED
		trail.albedo_texture = _fade()
		var strip := QuadMesh.new()
		strip.material = trail
		_trails = _child("Trails", strip, pool_size)


## Which BBs glow this match: `bits[id]` holds bit `slot` for each loadout slot of character `id` whose BBs glow
## (glow_bits). A character past its end glows none.
func set_glowing(bits: PackedByteArray) -> void:
	_glowing = bits
	_any = false
	for b in bits:
		_any = _any or b != 0


## The bits `set_glowing` takes for one character whose slots load `choices`, on a field lit by a preset with `night` as
## its flag.
static func glow_bits(choices: Array[Loadout.Glow], night: bool) -> int:
	var bits := 0
	for slot in choices.size():
		if Loadout.glows(choices[slot], night):
			bits |= 1 << slot
	return bits


## The material the field draws with (ShaderPrewarm draws it before the first one).
func drawn_material() -> Material:
	return material_override


## The glowing BBs' materials, for ShaderPrewarm too: the first one fired mustn't stall a frame.
func glow_materials() -> Array[Material]:
	return [_glow_balls.material_override, (_streaks.multimesh.mesh as PrimitiveMesh).material]


## The ball every BB is drawn as: the first mesh of the model at `path` (1 m across, centred), shared by the white and
## the glowing BBs, each drawing it in its own material. A model that can't be read warns and leaves a code-made ball
## of the same size, so BBs still show.
static func bb_mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene != null:
		var root := scene.instantiate()
		var found := root.find_children("*", "MeshInstance3D", true, false)
		var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
		root.free()
		if mesh != null:
			return mesh
	push_warning("BBView: no BB model at %s; drawing a code-made ball" % path)
	return _sphere()


## The white BBs' trail material, for ShaderPrewarm (null: no trails drawn).
func trail_material() -> Material:
	return null if _trails == null else (_trails.multimesh.mesh as PrimitiveMesh).material


## The draws: white BBs, glowing balls and their streaks, and the white BBs' trails when drawn.
func draws() -> Array[MultiMeshInstance3D]:
	if _trails == null:
		return [self, _glow_balls, _streaks]
	return [self, _glow_balls, _streaks, _trails]


## Draws `pool`'s BBs at `fraction` between ticks, seen from `eye`; `player_id`'s own are drawn from `muzzle_offset`
## (the muzzle less the eye) at first.
func update(pool: BBPool, player_id: int, muzzle_offset: Vector3, fraction: float, tick: float, eye: Vector3) -> void:
	var n := 0
	var g := 0
	var s := 0
	var t := 0
	for bb in pool.bbs:
		if not bb.active:
			continue
		var at := drawn_at(_cfg, bb, player_id, muzzle_offset, fraction, tick)
		var age := bb.age + fraction * tick
		if not (_any and _glows(bb)):
			multimesh.set_instance_transform(n, ball(_cfg, at, eye, _cfg.bb_min_angle))
			n += 1
			if _trails != null:
				var trail := streak_of(_cfg, at, bb.velocity, age, eye, _cfg.bb_trail_time, _cfg.bb_trail_angle)
				if trail.basis.x != Vector3.ZERO:
					_trails.multimesh.set_instance_transform(t, trail)
					t += 1
			continue
		_glow_balls.multimesh.set_instance_transform(g, ball(_cfg, at, eye))
		g += 1
		var streak := streak_of(_cfg, at, bb.velocity, age, eye)
		if streak.basis.x != Vector3.ZERO:
			_streaks.multimesh.set_instance_transform(s, streak)
			s += 1
	multimesh.visible_instance_count = n
	_glow_balls.multimesh.visible_instance_count = g
	_streaks.multimesh.visible_instance_count = s
	_glow_balls.visible = g > 0
	_streaks.visible = s > 0
	if _trails != null:
		_trails.multimesh.visible_instance_count = t
		_trails.visible = t > 0


## Where `bb` is drawn at `fraction` between ticks `tick` s apart: `player_id`'s own from `muzzle_offset` (the muzzle
## less the eye) at first, joining its true path from the side (across_flight) over `cfg.muzzle_join_time`.
static func drawn_at(cfg: EffectsConfig, bb: BB, player_id: int, muzzle_offset: Vector3, fraction: float,
		tick: float) -> Vector3:
	var at := bb.prev_position.lerp(bb.position, fraction)
	var age := bb.age + fraction * tick
	if bb.owner_id == player_id and age < cfg.muzzle_join_time:
		at += across_flight(muzzle_offset, bb.velocity) * (1.0 - age / cfg.muzzle_join_time)
	return at


## The part of `offset` square to `velocity`'s line (all of it with no velocity): a BB drawn from the muzzle joins its
## path from the side, never ahead of where it truly is.
static func across_flight(offset: Vector3, velocity: Vector3) -> Vector3:
	var speed := velocity.length()
	if not (speed > 0.0):
		return offset
	var along := velocity / speed
	return offset - along * offset.dot(along)


## A BB at `at` seen from `eye`: a BB's size, never under `least` radians across its radius (a glowing BB's
## `cfg.glow_min_angle` unless given).
static func ball(cfg: EffectsConfig, at: Vector3, eye: Vector3, least: float = -1.0) -> Transform3D:
	var angle := cfg.glow_min_angle if least < 0.0 else least
	var size := maxf(cfg.bb_size, 2.0 * angle * at.distance_to(eye))
	return Transform3D(Basis.from_scale(Vector3.ONE * size), at)


## A BB's streak or trail (the unit quad's place): back from `at` along `velocity` for `time` s of its flight (a glowing
## BB's `cfg.glow_streak_time` unless given), never longer than the `age` s it has flown, `width` radians wide
## (`cfg.glow_streak_angle` unless given) as seen from `eye` and turned to face it; the quad's top edge at the BB. One
## seen end-on (or of no length) comes back with a zero x column: not drawn.
static func streak_of(cfg: EffectsConfig, at: Vector3, velocity: Vector3, age: float, eye: Vector3,
		time: float = -1.0, width: float = -1.0) -> Transform3D:
	var along := velocity * minf(cfg.glow_streak_time if time < 0.0 else time, age)
	var mid := at - along * 0.5
	var to_eye := eye - mid
	var side := along.cross(to_eye)
	var length := along.length()
	var dist := to_eye.length()
	var side_length := side.length()
	if length * dist <= 0.0 or side_length < END_ON * length * dist:
		return Transform3D(Basis(Vector3.ZERO, along, Vector3.ZERO), mid)
	var across := side / side_length
	# across is square to along, so their cross product is `length` long
	var wide := cfg.glow_streak_angle if width < 0.0 else width
	return Transform3D(Basis(across * wide * dist, along, across.cross(along) / length), mid)


func _glows(bb: BB) -> bool:
	return bb.slot >= 0 and bb.owner_id >= 0 and bb.owner_id < _glowing.size() \
			and (_glowing[bb.owner_id] >> bb.slot) & 1 == 1


## Opaque at the quad's top edge (the BB), clear at its bottom (the trail's tail).
static func _fade() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(Color.WHITE, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.width = 1
	tex.height = FADE_STEPS
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat


static func _sphere() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = RADIAL_SEGMENTS
	sphere.rings = RINGS
	return sphere


static func _instances(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	return mm


func _child(child_name: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = child_name
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.multimesh = _instances(mesh, count)
	mmi.visible = false
	add_child(mmi)
	return mmi
