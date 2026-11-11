class_name LightFixtures
extends Node3D
## What a field's lights stand on or hang from (WG4, LightFixturesConfig): a campfire on the ground under each fire,
## a lantern at each lantern's light, hung on a chain from a roof or beam just over it, on a nail on the post it is in,
## or else from the hook of a pole stood beside it where nothing stands. One MultiMesh a model, in the props' vertex
## colours; by night a campfire's coals and a lantern's globe glow and their flames show, flickering and swaying (by
## day the coals are dark, the globe is glass and there are no flames), as LightPools lights them. Look only: no
## collider, nothing the simulation reads. Built once; the flicker is the flame shader's, so nothing runs a frame.

## The render layer the fixtures draw on as well as the first, so the light pools' real lights, which sit inside a
## lantern's globe or among a campfire's logs, leave them out of their shadows (LightPools, Graphics › Lamp light).
const LAYER := 1 << 17
const PROP_SURFACE := &"Prop"
const EMBER_SURFACE := &"Ember"
const GLOW_SURFACE := &"Glow"
const FLAME_SURFACE := &"Flame"

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

uniform float energy = 2.0;

void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
"""

const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 2.5;
uniform float rate = 7.0;
uniform float sway = 0.05;

varying float seed;

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	seed = at.x * 1.3 + at.z * 0.7;
	float t = TIME * rate + seed;
	float h = max(VERTEX.y, 0.0);
	VERTEX.x += sin(t + VERTEX.y * 9.0) * sway * h;
	VERTEX.z += cos(t * 1.3 + VERTEX.y * 7.0) * sway * 0.7 * h;
}

void fragment() {
	float t = TIME * rate + seed;
	float f = 0.82 + 0.12 * sin(t * 1.7) + 0.06 * sin(t * 4.3 + 1.1);
	ALBEDO = COLOR.rgb * energy * f;
}
"""

## Each model's instances, by model path.
var _placed: Dictionary[String, Array] = {}
var _views: Array[MultiMeshInstance3D] = []
var _materials: Array[Material] = []
var _flame: ShaderMaterial = null
var _cfg: LightFixturesConfig = null


## The fixtures of `map`'s lights under `cfg`, lit for `light` (its night), or null on a map without any.
static func build(map: MapData, cfg: LightFixturesConfig, light: LightingConfig) -> LightFixtures:
	if map == null or cfg == null or map.lights.is_empty() or not cfg.map_ids.has(String(map.id)):
		return null
	var placed := placings(map, cfg)
	if placed.is_empty():
		return null
	var fixtures := LightFixtures.new()
	fixtures.name = "LightFixtures"
	fixtures._cfg = cfg
	fixtures._placed = placed
	var night := light != null and light.night
	var prop := LookMaterials.vertex_colour(cfg.roughness, cfg.metallic)
	# by day the globe is glass (the props' own) and the coals are cold: dimmed to charcoal in the props' light
	var glow: Material = null
	var coals: Material = LookMaterials.vertex_colour(cfg.roughness, cfg.metallic, cfg.cold_tint)
	if night:
		var g := ShaderMaterial.new()
		g.shader = CodeShaders.of(GLOW_SHADER)
		g.set_shader_parameter(&"energy", cfg.glow_energy)
		glow = g
		coals = g
		fixtures._flame = ShaderMaterial.new()
		fixtures._flame.shader = CodeShaders.of(FLAME_SHADER)
		fixtures._flame.set_shader_parameter(&"energy", cfg.flame_energy)
		fixtures._flame.set_shader_parameter(&"rate", cfg.flicker_rate)
		fixtures._flame.set_shader_parameter(&"sway", cfg.flame_sway)
	fixtures._materials.append(prop)
	fixtures._materials.append(coals)
	if fixtures._flame != null:
		fixtures._materials.append(fixtures._flame)
	for path: String in placed:
		var src := PropDressConfig.load_mesh(path)
		if src == null:
			push_warning("LightFixtures: \"%s\" won't load; its fixtures are left out" % path)
			continue
		var mesh := _surfaces(src, prop, glow if glow != null else prop, coals, fixtures._flame)
		fixtures._add(path, mesh, placed[path])
	return fixtures


## Where each fixture of `map`'s lights stands: its model's path to its transforms. Pure and seeded (the map's
## dressing seed turns each fixture about its upright).
static func placings(map: MapData, cfg: LightFixturesConfig) -> Dictionary[String, Array]:
	var out: Dictionary[String, Array] = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = map.dressing_seed
	for l: MapData.Light in map.lights:
		var model: String = cfg.kind_models.get(l.kind, "")
		var turn := rng.randf_range(0.0, TAU)
		if model.is_empty():
			continue
		if l.kind == &"fire":
			var ground := LightPools.ground_under(map, l.position.x, l.position.z, l.position.y)
			if is_nan(ground):
				continue
			_put(out, model, Transform3D(Basis(Vector3.UP, turn), Vector3(l.position.x, ground, l.position.z)))
			continue
		_lantern(out, map, cfg, l.position, model, turn)
	return out


## A lantern at `at` (its globe's middle): on a nail on the block it is in, on a chain from the block just over it,
## or on a pole's hook beside it.
static func _lantern(out: Dictionary[String, Array], map: MapData, cfg: LightFixturesConfig, at: Vector3, model: String,
		turn: float) -> void:
	var inside := _block_at(map, cfg, at, 0.0)
	if inside != null:
		var lamp := _off_face(inside, at, cfg.lamp_radius)
		_put(out, model, Transform3D(Basis(Vector3.UP, turn), lamp))
		_chain(out, cfg, lamp + Vector3(0.0, cfg.bail, 0.0), cfg.nail_drop)
		return
	_put(out, model, Transform3D(Basis(Vector3.UP, turn), at))
	var bail := at + Vector3(0.0, cfg.bail, 0.0)
	var over := _underside_over(map, cfg, bail)
	if over - bail.y <= cfg.hang_reach:
		_chain(out, cfg, bail, over - bail.y)
		return
	# a pole beside it, its hook over the bail: the first way round (from its turn) with nothing standing there
	var dir := Vector3.ZERO
	for k in cfg.pole_tries:
		var a := turn + k * TAU / cfg.pole_tries
		var d := Vector3(cos(a), 0.0, sin(a))
		if _block_at(map, cfg, bail - d * cfg.hook_reach, cfg.post_clear) == null:
			dir = d
			break
	if dir == Vector3.ZERO:
		dir = Vector3(cos(turn), 0.0, sin(turn))
	var foot_at := bail - dir * cfg.hook_reach
	var ground := LightPools.ground_under(map, foot_at.x, foot_at.z, at.y)
	if is_nan(ground):
		ground = bail.y - cfg.hook_height
	var stretch := clampf((bail.y - ground) / cfg.hook_height, cfg.post_stretch.x, cfg.post_stretch.y)
	# the pole's +x (its hook) toward the lantern
	var basis := Basis(Vector3.UP, atan2(-dir.z, dir.x)) * Basis.from_scale(Vector3(1.0, stretch, 1.0))
	_put(out, cfg.post_model, Transform3D(basis, Vector3(foot_at.x, bail.y - cfg.hook_height * stretch, foot_at.z)))


## A chain `length` m long hanging from `bail` up (its top `length` m over the bail).
static func _chain(out: Dictionary[String, Array], cfg: LightFixturesConfig, bail: Vector3, length: float) -> void:
	if length <= cfg.chain_min:
		return
	_put(out, cfg.chain_model, Transform3D(Basis.from_scale(Vector3(1.0, length, 1.0)), bail + Vector3(0.0, length,
			0.0)))


## The lowest block underside over `p` (a footprint grown by hang_margin holding it), INF for none.
static func _underside_over(map: MapData, cfg: LightFixturesConfig, p: Vector3) -> float:
	var best := INF
	for b in map.blocks:
		if cfg.ignore_kinds.has(String(b.kind)):
			continue
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		var m := cfg.hang_margin
		if p.x < lo.x - m or p.x > hi.x + m or p.z < lo.z - m or p.z > hi.z + m or lo.y < p.y:
			continue
		best = minf(best, lo.y)
	return best


## A block (not of ignore_kinds) whose footprint, grown by `grow` m, holds `p` and whose height spans it; null for none.
static func _block_at(map: MapData, cfg: LightFixturesConfig, p: Vector3, grow: float) -> MapData.Block:
	for b in map.blocks:
		if cfg.ignore_kinds.has(String(b.kind)):
			continue
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		if p.x >= lo.x - grow and p.x <= hi.x + grow and p.z >= lo.z - grow and p.z <= hi.z + grow \
				and p.y >= lo.y and p.y <= hi.y:
			return b
	return null


## `p` moved out of block `b` through its nearest side, `clear` m past the face.
static func _off_face(b: MapData.Block, p: Vector3, clear: float) -> Vector3:
	var d := p - b.center
	var half := b.size * 0.5
	if half.x - absf(d.x) <= half.z - absf(d.z):
		var sx := 1.0 if d.x >= 0.0 else -1.0
		return Vector3(b.center.x + sx * (half.x + clear), p.y, p.z)
	var sz := 1.0 if d.z >= 0.0 else -1.0
	return Vector3(p.x, p.y, b.center.z + sz * (half.z + clear))


static func _put(out: Dictionary[String, Array], model: String, t: Transform3D) -> void:
	if not out.has(model):
		out[model] = []
	out[model].append(t)


## `src`'s surfaces drawn with these materials, by each surface's material name: the props' for its own, `glow` for
## the globe, `coals` for the coals, `flame` for the flames (left out with none: by day).
static func _surfaces(src: Mesh, prop: Material, glow: Material, coals: Material, flame: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in src.get_surface_count():
		var m := src.surface_get_material(s)
		var surface_name := StringName(m.resource_name) if m != null else PROP_SURFACE
		var look: Material = prop
		if surface_name == FLAME_SURFACE:
			if flame == null:
				continue
			look = flame
		elif surface_name == EMBER_SURFACE:
			look = coals
		elif surface_name == GLOW_SURFACE:
			look = glow
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		mesh.surface_set_material(mesh.get_surface_count() - 1, look)
	return mesh


func _add(path: String, mesh: ArrayMesh, transforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, Color.WHITE)
	var view := MultiMeshInstance3D.new()
	view.name = path.get_file().get_basename().capitalize()
	view.multimesh = mm
	view.layers = 1 | LAYER
	add_child(view)
	_views.append(view)


## Each model's instances, by path: what the views draw.
func placed() -> Dictionary[String, Array]:
	return _placed


func views() -> Array[MultiMeshInstance3D]:
	return _views


## The materials drawn, to warm their shaders before play.
func materials() -> Array[Material]:
	return _materials


## Still flames under Reduced motion (as LightPools' flicker): no sway, no flicker.
func set_motion(motion: MotionScale) -> void:
	if _flame == null:
		return
	var on := motion.dust > 0.0
	_flame.set_shader_parameter(&"rate", _cfg.flicker_rate if on else 0.0)
	_flame.set_shader_parameter(&"sway", _cfg.flame_sway if on else 0.0)
