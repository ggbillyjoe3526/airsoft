class_name SkylineView
extends Node3D
## The map's skyline (`MapData.skyline`; DP3): every piece some player can see over the walls (SkylineSight) built in
## greybox by SkylineShapes as one vertex-coloured mesh in the shared light (one draw call, casting no shadow), each
## vertex faded toward the sky's horizon colour by its distance from the field's middle, and the smoke of the chimneys marked
## `smoke` as one particle system, drawn from Medium (`set_smoke`) and frozen under Reduced motion. Under a night preset
## the masts' lamps are a second surface, self-lit (SkylineConfig.mast_lamp_glow) through the haze, with no real light;
## by day they are part of the one mesh. Scenery out of reach: no collider, no nav cell, nothing the simulation reads.

## The pieces built, and those no player can see (left out).
var kept: Array[SkylinePiece] = []
var left_out: Array[SkylinePiece] = []
var _cfg: SkylineConfig = null
var _mesh: MeshInstance3D = null
var _smoke: GPUParticles3D = null
var _smoke_motion: ParticleProcessMaterial = null
var _since: float = INF


## The skyline of `map` seen from an eye `eye_height` m over its stand points, faded toward `lighting`'s horizon (the
## playing preset's), its lamps lit when that is a night; null when the map has none or no player could see any of it
## (the map then draws as before).
static func build(map: MapData, cfg: SkylineConfig, lighting: LightingConfig, eye_height: float) -> SkylineView:
	if map.skyline.is_empty():
		return null
	var middle := middle_of(map)
	var sight := SkylineSight.of(map, eye_height, cfg.raised_from, cfg.floor_inset)
	var view := SkylineView.new()
	view.name = "Skyline"
	view._cfg = cfg
	var parts: Array[SkylineShapes.Part] = []
	var placed: Array[SkylineModels.Placed] = []
	var chimneys := PackedVector3Array()
	var each: Array[Array] = []
	for p in map.skyline:
		each.append(SkylineShapes.parts_of(p, cfg, middle))
	var seen := seen_of(map.skyline, each, sight, cfg, middle)
	for i in map.skyline.size():
		var p := map.skyline[i]
		if not seen[i]:
			view.left_out.append(p)
			continue
		view.kept.append(p)
		var models := SkylineModels.placed_of(p, cfg, middle)
		for part: SkylineShapes.Part in each[i]:
			if models.is_empty() or part.with_model:
				parts.append(part)
		placed.append_array(models)
		if p.smoke and p.kind == &"chimney":
			chimneys.append(SkylineShapes.smoke_from(p))
	if view.kept.is_empty():
		view.free()
		return null
	view._mesh = MeshInstance3D.new()
	view._mesh.name = "Pieces"
	view._mesh.mesh = mesh_of(parts, cfg, lighting.sky_horizon, middle, lighting.night, placed)
	view._mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# In the shared light (BP7), as the field's own blocks are: its sRGB vertex colours, already faded.
	view._mesh.mesh.surface_set_material(0, LookMaterials.vertex_colour(cfg.roughness, 0.0, Color.WHITE, true))
	if view._mesh.mesh.get_surface_count() > 1:
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color.BLACK
		glow.metallic_specular = 0.0
		glow.emission_enabled = true
		glow.emission = cfg.mast_lamp_glow
		glow.emission_energy_multiplier = cfg.mast_lamp_energy
		glow.disable_fog = true
		view._mesh.mesh.surface_set_material(1, glow)
	view.add_child(view._mesh)
	if not chimneys.is_empty():
		view._make_smoke(chimneys, lighting)
	return view


## Whether some player sees each of `pieces` (their parts `parts`, in order) through `sight`: tried nearest the field's
## `middle` first, each one seen hiding what stands beyond it (SkylineShapes.hides_of) from the pieces tried after it,
## so a piece seen only past a nearer one is left out (DP3's row). Only pieces built hide, so nothing left out ever
## stands in front of one.
static func seen_of(pieces: Array[SkylinePiece], parts: Array[Array], sight: SkylineSight, cfg: SkylineConfig,
		middle: Vector2) -> Array[bool]:
	var order: Array[int] = []
	var near: Array[float] = []
	for i in pieces.size():
		order.append(i)
		near.append(nearest_to(pieces[i], middle))
	order.sort_custom(func(a: int, b: int) -> bool: return near[a] < near[b] or (near[a] == near[b] and a < b))
	var seen: Array[bool] = []
	seen.resize(pieces.size())
	seen.fill(false)
	for i in order:
		var mine: Array[SkylineShapes.Part] = []
		mine.assign(parts[i])
		if not sight.sees(SkylineShapes.samples_of(mine)):
			continue
		seen[i] = true
		var boxes := SkylineShapes.hides_of(pieces[i], cfg)
		for k in range(0, boxes.size() - 1, 2):
			sight.add_box(boxes[k], boxes[k + 1])
	return seen


## How near `p` stands to `middle` (x, z, m): its spot's distance, or a line's nearest point's.
static func nearest_to(p: SkylinePiece, middle: Vector2) -> float:
	if p.points.is_empty():
		return p.at.distance_to(middle)
	var best := INF
	for q in p.points:
		best = minf(best, q.distance_to(middle))
	return best


## The middle of the map's blocks (x, z), where the skyline faces and fades from.
static func middle_of(map: MapData) -> Vector2:
	return map.middle()


## `parts` and the models `placed` as one mesh, each part's faces flat and turned outward from its middle, each
## vertex's colour faded toward `horizon` by its distance from `middle`; with `lamps_apart`, the lamps (parts' and
## models') as a second surface (none without lamps).
static func mesh_of(parts: Array[SkylineShapes.Part], cfg: SkylineConfig, horizon: Color, middle: Vector2,
		lamps_apart: bool = false, placed: Array[SkylineModels.Placed] = []) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var far := horizon.srgb_to_linear()
	var lamps: Array[SkylineShapes.Part] = []
	var rest: Array[SkylineShapes.Part] = []
	for part in parts:
		(lamps if lamps_apart and part.lamp else rest).append(part)
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var lamp_pos := PackedVector3Array()
	var lamp_nor := PackedVector3Array()
	var lamp_col := PackedColorArray()
	_add_parts(rest, cfg, far, middle, pos, nor, col)
	_add_parts(lamps, cfg, far, middle, lamp_pos, lamp_nor, lamp_col)
	for model: SkylineModels.Placed in placed:
		SkylineModels.add(model, cfg, far, middle, lamps_apart, pos, nor, col, lamp_pos, lamp_nor, lamp_col)
	_add_surface(mesh, pos, nor, col)
	_add_surface(mesh, lamp_pos, lamp_nor, lamp_col)
	return mesh


static func _add_parts(parts: Array[SkylineShapes.Part], cfg: SkylineConfig, far: Color, middle: Vector2,
		pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray) -> void:
	for part in parts:
		var centre := Vector3.ZERO
		for q in part.a:
			centre += q
		for q in part.b:
			centre += q
		centre /= part.a.size() + part.b.size()
		var own := part.colour.srgb_to_linear()
		var n := part.a.size()
		for i in n:
			var j := (i + 1) % n
			_tri(part.a[i], part.a[j], part.b[j], centre, own, far, middle, cfg, pos, nor, col)
			_tri(part.a[i], part.b[j], part.b[i], centre, own, far, middle, cfg, pos, nor, col)
		for ring: PackedVector3Array in ([part.a] if part.cap_a else []) + ([part.b] if part.cap_b else []):
			for i in range(1, n - 1):
				_tri(ring[0], ring[i], ring[i + 1], centre, own, far, middle, cfg, pos, nor, col)


static func _add_surface(mesh: ArrayMesh, pos: PackedVector3Array, nor: PackedVector3Array,
		col: PackedColorArray) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_COLOR] = col
	if not pos.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## The triangles drawn, every surface's (0 with nothing built).
func triangle_count() -> int:
	var mesh := _mesh.mesh as ArrayMesh if _mesh != null else null
	if mesh == null:
		return 0
	var n := 0
	for i in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## The pieces' mesh.
func mesh() -> ArrayMesh:
	return _mesh.mesh as ArrayMesh


## The materials it draws, for ShaderPrewarm: the pieces' and, with chimneys seen, the smoke's (drawn only from
## Medium, so its first draw would otherwise come mid-match).
func materials() -> Array[Material]:
	var out: Array[Material] = []
	for i in _mesh.mesh.get_surface_count():
		out.append(_mesh.mesh.surface_get_material(i))
	if _smoke != null:
		out.append((_smoke.draw_pass_1 as PrimitiveMesh).material)
	return out


## The chimneys' smoke, or null on a skyline with none seen.
func smoke() -> GPUParticles3D:
	return _smoke


## Whether the graphics `values` draw the chimneys' smoke: from Medium, read off the mesh detail row (Low's is low).
static func smokes(values: GraphicsQuality) -> bool:
	return values.mesh_detail >= GraphicsQuality.MeshDetail.MEDIUM


## Draws the smoke (the graphics settings: `smokes`) or hides it, so it does no work.
func set_smoke(on: bool) -> void:
	if _smoke == null or _smoke.visible == on:
		return
	_smoke.visible = on
	_smoke.emitting = on
	if on:
		_smoke.restart() # the plumes stand full from the first frame (preprocess)


## Reduced motion freezes the smoke where it hangs.
func set_motion(motion: MotionScale) -> void:
	if _smoke != null:
		_smoke.speed_scale = 1.0 if motion.dust > 0.0 else 0.0


## Bends the smoke with `wind` (m/s), `delta` seconds since the last frame; followed every `smoke_refresh` s.
func update(wind: Vector3, delta: float) -> void:
	if _smoke == null or not _smoke.visible:
		return
	_since += delta
	if _since < _cfg.smoke_refresh:
		return
	_since = 0.0
	var drift := Vector3(wind.x, 0.0, wind.z) * _cfg.smoke_wind_share
	if drift.length() < _cfg.smoke_breeze:
		drift = Vector3(_cfg.smoke_breeze, 0.0, 0.0)
	var v := drift + Vector3.UP * (_cfg.smoke_rise / _cfg.smoke_life)
	_smoke_motion.direction = v.normalized()
	_smoke_motion.initial_velocity_min = v.length()
	_smoke_motion.initial_velocity_max = v.length()


static func _tri(p0: Vector3, p1: Vector3, p2: Vector3, centre: Vector3, own: Color, far: Color, middle: Vector2,
		cfg: SkylineConfig, pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray) -> void:
	var n := (p1 - p0).cross(p2 - p0)
	if n.length_squared() < 1e-10:
		return
	if n.dot((p0 + p1 + p2) / 3.0 - centre) < 0.0:
		var swap := p1
		p1 = p2
		p2 = swap
		n = -n
	n = n.normalized()
	# Godot's front faces wind clockwise seen from outside
	for q: Vector3 in [p0, p2, p1]:
		pos.append(q)
		nor.append(n)
		var d := Vector2(q.x, q.z).distance_to(middle)
		var fade := clampf((d - cfg.fade_from) / cfg.fade_span, 0.0, 1.0) * cfg.fade_most
		col.append(own.lerp(far, fade).linear_to_srgb())


func _make_smoke(from: PackedVector3Array, lighting: LightingConfig) -> void:
	var cfg := _cfg
	var points := Image.create(from.size(), 1, false, Image.FORMAT_RGBF)
	var lo := from[0]
	var hi := from[0]
	for i in from.size():
		points.set_pixel(i, 0, Color(from[i].x, from[i].y, from[i].z))
		lo = lo.min(from[i])
		hi = hi.max(from[i])
	_smoke_motion = ParticleProcessMaterial.new()
	_smoke_motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	_smoke_motion.emission_point_texture = ImageTexture.create_from_image(points)
	_smoke_motion.emission_point_count = from.size()
	_smoke_motion.gravity = Vector3.ZERO
	_smoke_motion.spread = cfg.smoke_spread
	_smoke_motion.direction = Vector3.UP
	_smoke_motion.initial_velocity_min = cfg.smoke_rise / cfg.smoke_life
	_smoke_motion.initial_velocity_max = cfg.smoke_rise / cfg.smoke_life
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, cfg.smoke_size_from / cfg.smoke_size_to))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	_smoke_motion.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, cfg.smoke_fade_in, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, cfg.smoke_opacity), Color(1, 1, 1, 0)])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	_smoke_motion.color_ramp = fade_tex
	_smoke = GPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.amount = cfg.smoke_puffs * from.size()
	_smoke.lifetime = cfg.smoke_life
	_smoke.preprocess = cfg.smoke_life
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke.process_material = _smoke_motion
	var reach := cfg.smoke_rise + cfg.smoke_size_to + cfg.smoke_life * maxf(cfg.smoke_breeze, 1.0) * 4.0
	_smoke.visibility_aabb = AABB(lo - Vector3.ONE * reach, hi - lo + Vector3.ONE * reach * 2.0)
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(0.5, 0.0)
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	puff.gradient = soft
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.albedo_texture = puff
	var tint := cfg.smoke_colour * (cfg.smoke_night if lighting.night else 1.0)
	look.albedo_color = Color(tint.r, tint.g, tint.b, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * cfg.smoke_size_to
	quad.material = look
	_smoke.draw_pass_1 = quad
	_smoke.visible = false
	_smoke.emitting = false
	add_child(_smoke)
