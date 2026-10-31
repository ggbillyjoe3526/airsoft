class_name BushView
extends MultiMeshInstance3D
## A map's bushes (MapData.foliage, WL5) as placeholder ellipsoids, all in one instanced draw on every preset: a low
## sphere stretched to each bush's radius and height, standing on its foot, in a seeded pick of WoodsConfig's bush
## greens. Look only: the simulation reads the same bushes through WorldQuery.foliage, never this node.

## The stream the bushes' colours are drawn from, salted with the map's dressing seed.
const COLOUR_SALT := 5


## `map`'s bushes drawn with `cfg`, or null on a map with none.
static func build(map: MapData, cfg: WoodsConfig) -> BushView:
	var f := map.foliage
	if f.is_empty() or cfg.bush_colours.is_empty():
		return null
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
	view.multimesh = mm
	view.material_override = LookMaterials.vertex_colour(cfg.bush_roughness, 0.0, Color.WHITE, true)
	return view


## Where bush `i` of `f` is drawn: the unit sphere stretched to its radius and half its height, its middle half its height
## over its foot.
static func placed(f: Foliage, i: int) -> Transform3D:
	var half := f.heights[i] * 0.5
	var r := f.radii[i]
	return Transform3D(Basis.from_scale(Vector3(r, half, r)), f.feet[i] + Vector3.UP * half)


## Each of `map`'s bushes' colour (sRGB): a seeded pick of cfg.bush_colours, up to bush_jitter lighter or darker.
static func colours_of(map: MapData, cfg: WoodsConfig) -> PackedColorArray:
	var out := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(map.dressing_seed, COLOUR_SALT))
	for i in map.foliage.size():
		var c := cfg.bush_colours[rng.randi() % cfg.bush_colours.size()]
		var shade := 1.0 + rng.randf_range(-cfg.bush_jitter, cfg.bush_jitter)
		out.append(Color(c.r * shade, c.g * shade, c.b * shade))
	return out


## The material it draws with, for ShaderPrewarm.
func materials() -> Array[Material]:
	return [material_override]
