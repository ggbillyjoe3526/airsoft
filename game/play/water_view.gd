class_name WaterView
extends MeshInstance3D
## A map's shallow streams (MapData.water, WS1) drawn on every preset: each a flat ribbon along its line at the water's
## level, as wide as the stream (Water's half width either side), cut WoodsConfig.stream_across times across; the banks
## rise through it, so the water shows only over the bed (look_water.gdshader fades its edge by the depth behind it).
## Each vertex carries its downstream way (where the level falls along the line; on level water, as Woodland's is, the
## line's own way) in its colour for the ripples' flow. One
## draw, no shadow. Look only: the simulation reads the same streams through WorldQuery.water, never this node.

const WATER_SHADER := preload("res://game/play/look/look_water.gdshader")
## A turn in the line sharper than this (the cosine between its two legs) keeps its corner's width as the legs' own
## rather than mitred out, so a tight bend can't throw the ribbon's edge far out.
const MITRE_LIMIT := 0.5

var _look: ShaderMaterial = null


## `map`'s streams drawn with `cfg`, or null on a map with none.
static func build(map: MapData, cfg: WoodsConfig) -> WaterView:
	var water := map.water
	if water.is_empty():
		return null
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var index := PackedInt32Array()
	var across := maxi(1, cfg.stream_across)
	for s in water.size():
		_ribbon(water.points_of(s), water.half_width_of(s), across, verts, normals, colours, index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var view := WaterView.new()
	view.name = "Water"
	view._look = look(cfg)
	mesh.surface_set_material(0, view._look)
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return view


## The water's material as `cfg` sets it.
static func look(cfg: WoodsConfig) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	m.set_shader_parameter(&"shallow", cfg.stream_shallow)
	m.set_shader_parameter(&"deep", cfg.stream_deep)
	m.set_shader_parameter(&"deep_at", cfg.stream_deep_at)
	m.set_shader_parameter(&"edge_soft", cfg.stream_edge)
	m.set_shader_parameter(&"roughness", cfg.stream_roughness)
	m.set_shader_parameter(&"specular", cfg.stream_specular)
	m.set_shader_parameter(&"sheen", cfg.stream_sheen)
	m.set_shader_parameter(&"ripple_scale", cfg.stream_ripple)
	m.set_shader_parameter(&"ripple_tilt", cfg.stream_tilt)
	m.set_shader_parameter(&"flow", cfg.stream_flow)
	m.set_shader_parameter(&"ripple_cycle", cfg.stream_cycle)
	return m


## Reduced motion holds the ripples still.
func set_motion(motion: MotionScale) -> void:
	_look.set_shader_parameter(&"motion", 1.0 if motion.dust > 0.0 else 0.0)


## The materials it draws, for ShaderPrewarm.
func materials() -> Array[Material]:
	var out: Array[Material] = [_look]
	return out


## One stream's ribbon appended: a row of `across` + 1 vertices across its line at each point, `half` m either side,
## square to the mean of the legs either side (mitred, up to MITRE_LIMIT), at the point's level.
static func _ribbon(points: PackedVector3Array, half: float, across: int, verts: PackedVector3Array,
		normals: PackedVector3Array, colours: PackedColorArray, index: PackedInt32Array) -> void:
	var n := points.size()
	var first := verts.size()
	for i in n:
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, n - 1)]
		var back := Vector2(points[i].x - a.x, points[i].z - a.z).normalized() if i > 0 else Vector2.ZERO
		var ahead := Vector2(b.x - points[i].x, b.z - points[i].z).normalized() if i < n - 1 else Vector2.ZERO
		var along := (back + ahead).normalized()
		var reach := half
		if i > 0 and i < n - 1 and back.dot(ahead) > MITRE_LIMIT:
			reach = half / maxf(along.dot(ahead), 1e-3)
		var side := Vector2(-along.y, along.x) * reach
		# Downstream: the way along the line the level falls (the line's own way where it is level), packed into 0..1.
		var down := along if b.y <= a.y else -along
		var way := Color(down.x * 0.5 + 0.5, down.y * 0.5 + 0.5, 0.5, 1.0)
		for k in across + 1:
			var f := float(k) / across * 2.0 - 1.0
			verts.append(Vector3(points[i].x + side.x * f, points[i].y, points[i].z + side.y * f))
			normals.append(Vector3.UP)
			colours.append(way)
	var row := across + 1
	for i in n - 1:
		for k in across:
			var v := first + i * row + k
			index.append_array([v, v + row, v + 1, v + 1, v + row, v + row + 1])
