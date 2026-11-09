class_name BushView
extends Node3D
## A map's bushes (MapData.foliage, WL5) drawn on every preset: the low ones (up to WoodsConfig.fern_tallest m) as the
## fern clump model, the rest as the bush model (WG2, tools/blender/maps/), each kind an instanced draw a square of the
## field (WoodsConfig.bush_chunk), every plant
## stretched to its foliage's radius and height on its foot, turned at random and a seeded shade lighter or darker.
## Without the models (a missing file) they fall back to placeholder ellipsoids in a seeded pick of WoodsConfig's
## bush greens. Look only: the simulation reads the same bushes through WorldQuery.foliage, never this node.

## The stream the bushes' colours and turns are drawn from, salted with the map's dressing seed.
const COLOUR_SALT := 5

var _materials: Array[Material] = []


## `map`'s bushes drawn with `cfg`, or null on a map with none.
static func build(map: MapData, cfg: WoodsConfig) -> BushView:
	var f := map.foliage
	if f.is_empty():
		return null
	var fern := PropDressConfig.load_mesh(cfg.fern_model)
	var bush := PropDressConfig.load_mesh(cfg.bush_model)
	if fern == null or bush == null:
		if cfg.bush_colours.is_empty():
			return null
		push_warning("BushView: the fern or bush model won't load; the bushes are drawn as ellipsoids")
		return _ellipsoids(map, cfg)
	var view := BushView.new()
	view.name = "Bushes"
	var material := LookMaterials.vertex_colour(cfg.bush_roughness, 0.0)
	view._materials.append(material)
	var turns := turns_of(map)
	var shades := shades_of(map, cfg)
	var chunk := maxf(cfg.bush_chunk, 1.0)
	for kind in 2:
		var mesh := fern if kind == 0 else bush
		# the kind's plants by the field's square they stand in, so each square is a draw of its own, culled out of view
		var cells: Dictionary[Vector2i, PackedInt32Array] = {}
		for i in f.size():
			if (f.heights[i] <= cfg.fern_tallest) != (kind == 0):
				continue
			var cell := Vector2i(floori(f.feet[i].x / chunk), floori(f.feet[i].z / chunk))
			if not cells.has(cell):
				cells[cell] = PackedInt32Array()
			cells[cell].append(i)
		var box := mesh.get_aabb()
		for cell: Vector2i in cells:
			var picks: PackedInt32Array = cells[cell]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = picks.size()
			for k in picks.size():
				var i := picks[k]
				mm.set_instance_transform(k, fitted(f, i, box, turns[i]))
				mm.set_instance_color(k, Color(shades[i], shades[i], shades[i]))
			var part := MultiMeshInstance3D.new()
			part.name = "%s %d %d" % ["Ferns" if kind == 0 else "Shrubs", cell.x, cell.y]
			part.multimesh = mm
			part.material_override = material
			if kind == 0 and not cfg.fern_shadow:
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.add_child(part)
	return view


## Each part's draw (a MultiMeshInstance3D: ferns, then shrubs, a square of the field each, or the ellipsoids).
func parts() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for c in get_children():
		if c is MultiMeshInstance3D:
			out.append(c as MultiMeshInstance3D)
	return out


## How many bushes it draws, every part together.
func drawn() -> int:
	var n := 0
	for p in parts():
		n += p.multimesh.instance_count
	return n


## Where bush `i` of `f` is drawn as a model of bounds `box` (its ground line y = 0): stretched to the bush's radius
## across and its height up, turned `turn` about up, standing on its foot.
static func fitted(f: Foliage, i: int, box: AABB, turn: float) -> Transform3D:
	var r := f.radii[i]
	var scale := Vector3(2.0 * r / maxf(box.size.x, 1e-6), f.heights[i] / maxf(box.end.y, 1e-6),
			2.0 * r / maxf(box.size.z, 1e-6))
	var basis := Basis(Vector3.UP, turn) * Basis.from_scale(scale)
	var middle := Vector3(box.position.x + box.size.x * 0.5, 0.0, box.position.z + box.size.z * 0.5)
	return Transform3D(basis, f.feet[i] - basis * middle)


## Where bush `i` of `f` is drawn as a placeholder ellipsoid: the unit sphere stretched to its radius and half its
## height, its middle half its height over its foot.
static func placed(f: Foliage, i: int) -> Transform3D:
	var half := f.heights[i] * 0.5
	var r := f.radii[i]
	return Transform3D(Basis.from_scale(Vector3(r, half, r)), f.feet[i] + Vector3.UP * half)


## Each of `map`'s bushes' turn about up (radians), seeded by the map's dressing seed.
static func turns_of(map: MapData) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(map.dressing_seed, COLOUR_SALT + 1))
	for i in map.foliage.size():
		out.append(rng.randf() * TAU)
	return out


## Each of `map`'s bushes' shade (a linear multiplier of the model's colours), up to bush_jitter lighter or darker.
static func shades_of(map: MapData, cfg: WoodsConfig) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(map.dressing_seed, COLOUR_SALT))
	for i in map.foliage.size():
		out.append(1.0 + rng.randf_range(-cfg.bush_jitter, cfg.bush_jitter))
	return out


## Each of `map`'s bushes' placeholder colour (sRGB): a seeded pick of cfg.bush_colours, up to bush_jitter lighter or
## darker.
static func colours_of(map: MapData, cfg: WoodsConfig) -> PackedColorArray:
	var out := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(map.dressing_seed, COLOUR_SALT))
	for i in map.foliage.size():
		var c := cfg.bush_colours[rng.randi() % cfg.bush_colours.size()]
		var shade := 1.0 + rng.randf_range(-cfg.bush_jitter, cfg.bush_jitter)
		out.append(Color(c.r * shade, c.g * shade, c.b * shade))
	return out


## The materials it draws with, for ShaderPrewarm.
func materials() -> Array[Material]:
	return _materials.duplicate()


## The placeholder: every bush a sphere of bush_sides sides and bush_rings rings in one instanced draw.
static func _ellipsoids(map: MapData, cfg: WoodsConfig) -> BushView:
	var f := map.foliage
	var view := BushView.new()
	view.name = "Bushes"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = cfg.bush_sides
	sphere.rings = cfg.bush_rings
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = f.size()
	var colours := colours_of(map, cfg)
	for i in f.size():
		mm.set_instance_transform(i, placed(f, i))
		mm.set_instance_color(i, colours[i])
	var part := MultiMeshInstance3D.new()
	part.name = "Ellipsoids"
	part.multimesh = mm
	part.material_override = LookMaterials.vertex_colour(cfg.bush_roughness, 0.0, Color.WHITE, true)
	view._materials.append(part.material_override)
	view.add_child(part)
	return view
