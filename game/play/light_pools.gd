class_name LightPools
extends Node3D
## A night field's pools of light (MapData.lights; the browser game's render/light/lightPools.ts), built only under a
## night preset: each light lights the ground within its radius. Every pool is drawn as one disc following the ground
## under it, all of them one additive mesh (one draw call), and each light glows where it hangs (one billboard each,
## one draw call). The nearest pools to the eye, as many as the graphics give (LightingConfig.real_lights_for: Low 0,
## Medium 2, High 4), get a real light each, casting no shadow, and their drawn disc fades out as the light fades in.
## Fires flicker, on the drawn disc and the real light alike; still under Reduced motion. Look only: nothing the
## simulation reads. Built once; `update` each rendered frame allocates nothing.

## The most lights a map may have drawn (the disc shader's array).
const MAX_POOLS := 32
## The drawn discs: COLOR is the pool's light at that point (linear), UV.x its index, UV.y 1 for a fire.
const POOL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float drawn[32];
uniform float flicker = 0.0;
uniform float rate = 7.0;

void fragment() {
	int i = int(UV.x + 0.5);
	float t = TIME * rate + float(i) * 1.7;
	float f = 1.0 + flicker * UV.y * (0.6 * sin(t) + 0.4 * sin(t * 2.3 + 1.1));
	ALBEDO = COLOR.rgb * drawn[i] * f;
}
"""

var _cfg: LightingConfig = null
var _lights: Array[MapData.Light] = []
var _colours: PackedColorArray = PackedColorArray()
var _ground: MeshInstance3D = null
var _pool_material: ShaderMaterial = null
var _glows: MultiMeshInstance3D = null
## The real lights, the pool each serves (-1 none), the pool it is fading toward, and how far in it is (0 to 1).
var _real: Array[OmniLight3D] = []
var _serving: PackedInt32Array = PackedInt32Array()
var _target: PackedInt32Array = PackedInt32Array()
var _fade: PackedFloat32Array = PackedFloat32Array()
## Each pool's drawn share (1 drawn, 0 under a real light), as last sent to the shader.
var _drawn: PackedFloat32Array = PackedFloat32Array()
var _chosen: PackedInt32Array = PackedInt32Array()
var _scores: PackedFloat32Array = PackedFloat32Array()
var _flicker: float = 1.0
var _time: float = 0.0


## The pools of `map`'s lights under `cfg` (a night preset), or null on a map with none or a day preset.
static func build(map: MapData, cfg: LightingConfig) -> LightPools:
	if not cfg.night or map.lights.is_empty():
		return null
	var pools := LightPools.new()
	pools.name = "LightPools"
	pools._cfg = cfg
	if map.lights.size() > MAX_POOLS:
		push_warning("LightPools: %s has %d lights; the first %d are lit" % [map.id, map.lights.size(), MAX_POOLS])
	for l: MapData.Light in map.lights.slice(0, MAX_POOLS):
		pools._lights.append(l)
		pools._colours.append(cfg.pool_colour(l.kind, l.colour))
	var n := pools._lights.size()
	pools._drawn.resize(MAX_POOLS)
	pools._drawn.fill(1.0)
	pools._scores.resize(n)
	pools._ground = MeshInstance3D.new()
	pools._ground.name = "Pools"
	pools._ground.mesh = ground_mesh(map, pools._lights, pools._colours, cfg)
	pools._ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pools._pool_material = ShaderMaterial.new()
	pools._pool_material.shader = CodeShaders.of(POOL_SHADER)
	pools._pool_material.set_shader_parameter(&"drawn", pools._drawn)
	pools._pool_material.set_shader_parameter(&"rate", cfg.flicker_rate)
	pools._pool_material.set_shader_parameter(&"flicker", cfg.flicker)
	pools._ground.material_override = pools._pool_material
	pools.add_child(pools._ground)
	pools._glows = pools._make_glows()
	pools.add_child(pools._glows)
	return pools


## The height of the ground under (x, z) at or below `below` (m): the highest floor or ramp top there no higher, or
## the sloping ground; `below` when there is none.
static func ground_under(map: MapData, x: float, z: float, below: float) -> float:
	var best := -INF
	if map.terrain != null:
		var h := map.terrain.height_at(x, z)
		if not is_nan(h) and h <= below:
			best = h
	for b in map.blocks:
		if b.kind != &"floor" and b.kind != &"ramp":
			continue
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		if x < lo.x or x > hi.x or z < lo.z or z > hi.z:
			continue
		var top := MapData.ramp_top(b, x, z) if b.rise != MapData.Rise.NONE else hi.y
		if top <= below:
			best = maxf(best, top)
	return best if best > -INF else below


## Every light's drawn disc on the ground under it as one mesh: `pool_rings` rings out to its radius, its colour at
## `pool_strength` in the middle falling to nothing at the edge.
static func ground_mesh(map: MapData, lights: Array[MapData.Light], colours: PackedColorArray,
		cfg: LightingConfig) -> ArrayMesh:
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var rings := maxi(1, cfg.pool_rings)
	var segs := maxi(3, cfg.pool_segments)
	for i in lights.size():
		var l := lights[i]
		var lin := colours[i].srgb_to_linear()
		var tag := Vector2(i, 1.0 if l.kind == &"fire" else 0.0)
		var first := pos.size()
		pos.append(_on_ground(map, l, 0.0, 0.0, cfg))
		col.append(lin * cfg.pool_strength)
		uv.append(tag)
		for r in range(1, rings + 1):
			var t := float(r) / rings
			var share := (1.0 - t) * (1.0 - t)
			for s in segs:
				var a := TAU * s / segs
				pos.append(_on_ground(map, l, cos(a) * l.radius * t, sin(a) * l.radius * t, cfg))
				col.append(lin * cfg.pool_strength * share)
				uv.append(tag)
		for s in segs:
			idx.append_array([first, first + 1 + (s + 1) % segs, first + 1 + s])
		for r in range(1, rings):
			var inner := first + 1 + (r - 1) * segs
			var outer := inner + segs
			for s in segs:
				var s1 := (s + 1) % segs
				idx.append_array([inner + s, outer + s1, outer + s, inner + s, inner + s1, outer + s1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	if not pos.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _on_ground(map: MapData, l: MapData.Light, dx: float, dz: float, cfg: LightingConfig) -> Vector3:
	var x := l.position.x + dx
	var z := l.position.z + dz
	return Vector3(x, ground_under(map, x, z, l.position.y) + cfg.pool_lift, z)


## The pools to light for an eye at `eye`: the `count` nearest by distance to each pool's edge, a pool in `current`
## counted `hysteresis` m nearer so a light moves only for a pool clearly nearer. Into `out` (resized to the count
## lit), using `scores` (one per light) as scratch; allocates nothing once both are sized.
static func nearest(lights: Array[MapData.Light], eye: Vector3, count: int, current: PackedInt32Array,
		hysteresis: float, scores: PackedFloat32Array, out: PackedInt32Array) -> void:
	var n := mini(count, lights.size())
	for i in lights.size():
		var edge := maxf(0.0, eye.distance_to(lights[i].position) - lights[i].radius)
		scores[i] = edge - (hysteresis if current.has(i) else 0.0)
	out.resize(n)
	for k in n:
		var best := -1
		for i in lights.size():
			if scores[i] < INF and (best < 0 or scores[i] < scores[best]):
				best = i
		out[k] = best
		scores[best] = INF


## How many pools get a real light (the graphics': LightingConfig.real_lights_for); lights are made or freed only on a
## change.
func set_real_count(count: int) -> void:
	count = mini(count, _lights.size())
	while _real.size() > count:
		var gone: OmniLight3D = _real.pop_back()
		var pool := _serving[_real.size()]
		if pool >= 0:
			_drawn[pool] = 1.0
		gone.queue_free()
	_serving.resize(count)
	_target.resize(count)
	_fade.resize(count)
	while _real.size() < count:
		var light := OmniLight3D.new()
		light.name = "PoolLight%d" % _real.size()
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_serving[_real.size()] = -1
		_target[_real.size()] = -1
		_fade[_real.size()] = 0.0
		_real.append(light)
	_pool_material.set_shader_parameter(&"drawn", _drawn)


## Reduced motion stills the fires (their light holds steady).
func set_motion(motion: MotionScale) -> void:
	_flicker = 1.0 if motion.dust > 0.0 else 0.0
	_pool_material.set_shader_parameter(&"flicker", _cfg.flicker * _flicker)


## Moves the real lights to the pools nearest `eye`, fading over `delta` s, and flickers the fires'.
func update(eye: Vector3, delta: float) -> void:
	_time += delta
	if _real.is_empty():
		return
	nearest(_lights, eye, _real.size(), _serving, _cfg.real_hysteresis, _scores, _chosen)
	# a light keeps its pool while chosen; a free one takes a chosen pool nobody has
	for k in _real.size():
		_target[k] = _serving[k] if _chosen.has(_serving[k]) else -1
	for pool in _chosen:
		if not _target.has(pool):
			_target[_target.find(-1)] = pool
	var step := delta / maxf(_cfg.real_fade, 1e-3)
	var changed := false
	for k in _real.size():
		var was := _fade[k]
		if _serving[k] == _target[k] and _serving[k] >= 0:
			_fade[k] = minf(1.0, _fade[k] + step)
		else:
			_fade[k] = maxf(0.0, _fade[k] - step)
			if _fade[k] <= 0.0 and _serving[k] != _target[k]:
				# the released pool is drawn whole again before the light moves on
				var released := _serving[k]
				if released >= 0 and _drawn[released] != 1.0:
					_drawn[released] = 1.0
					changed = true
				_serving[k] = _target[k]
				_place(k)
		var pool := _serving[k]
		if pool >= 0 and absf(_drawn[pool] - (1.0 - _fade[k])) > 1e-4:
			_drawn[pool] = 1.0 - _fade[k]
			changed = true
		if was != _fade[k] or pool >= 0:
			_light_up(k)
	if changed:
		_pool_material.set_shader_parameter(&"drawn", _drawn)


## The pools served by a real light now (-1 for a light serving none), one per real light.
func served() -> PackedInt32Array:
	return _serving


## Each pool's drawn share: 1 drawn, 0 lit by a real light.
func drawn_share(pool: int) -> float:
	return _drawn[pool]


## The real lights, for tests and the frame-time record.
func real_lights() -> Array[OmniLight3D]:
	return _real


func pools_mesh() -> ArrayMesh:
	return _ground.mesh as ArrayMesh


## The materials it draws, for ShaderPrewarm.
func materials() -> Array[Material]:
	return [_pool_material, _glows.multimesh.mesh.surface_get_material(0)]


## The fire flicker's factor on pool `pool` at `t` s (the shader's, so the real light and the disc agree).
func flicker_at(pool: int, t: float) -> float:
	if _lights[pool].kind != &"fire":
		return 1.0
	var a := t * _cfg.flicker_rate + pool * 1.7
	return 1.0 + _cfg.flicker * _flicker * (0.6 * sin(a) + 0.4 * sin(a * 2.3 + 1.1))


func _place(k: int) -> void:
	var pool := _serving[k]
	var light := _real[k]
	light.visible = pool >= 0
	if pool < 0:
		return
	light.position = _lights[pool].position
	light.omni_range = _lights[pool].radius * _cfg.real_reach
	light.light_color = _colours[pool]


func _light_up(k: int) -> void:
	var pool := _serving[k]
	if pool < 0:
		return
	_real[k].light_energy = _cfg.real_energy * _fade[k] * flicker_at(pool, _time)


func _make_glows() -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.billboard_keep_scale = true
	look.vertex_color_use_as_albedo = true
	look.disable_fog = true
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	soft.gradient = g
	look.albedo_texture = soft
	quad.material = look
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = _lights.size()
	for i in _lights.size():
		var size := _lights[i].radius * _cfg.glow_size
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), _lights[i].position))
		var c := _colours[i].lerp(Color.WHITE, _cfg.glow_white) * _cfg.glow_strength
		mm.set_instance_color(i, Color(c.r, c.g, c.b, 1.0))
	var inst := MultiMeshInstance3D.new()
	inst.name = "Glows"
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst
