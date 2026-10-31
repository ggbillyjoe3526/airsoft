class_name SiteSurface
extends RefCounted
## The site dress's surface (DD1): one ShaderMaterial on site_surface.gdshader for a map's blocks (MapLevel's site
## mesh) and its details (SiteDress), and the per-vertex data that tells the shader each box and finish. Each vertex
## carries CUSTOM0 = (the box's centre, its finish's slot) and CUSTOM1 = (its half size, flags); COLOR is the baked
## light, white without a bake, or a detail's own paint with FLAG_TINT. Static functions only.

const SHADER := preload("res://game/play/site/site_surface.gdshader")
## The flags (site_surface.gdshader's FLAG_ constants); a container's piece rides above PIECE_SHIFT.
const FLAG_CHEVRON := 1
const FLAG_HAZARD := 2
const FLAG_PALETTE := 4
const FLAG_TINT := 8
const FLAG_NO_BEVEL := 16
const PIECE_SHIFT := 8
## The shader's finish slots and container paints.
const SLOTS := 40
const PAINTS := 8
## The most bay lines the shader draws (SiteDressing.LINES).
const LINES := SiteDressing.LINES
## The marks' colours (SiteLook.marks) in the shader's order (its MARK_ constants).
const MARKS: Array[StringName] = [&"tuft", &"chip", &"rust_foot", &"chevron", &"stripe", &"wire", &"carton", &"slat_gap", &"slat", &"goods_olive", &"goods_tan", &"pallet", &"grass", &"dirt_foot", &"bay_line"]
## The tiling noise textures: their size (px) and features across one (the shader reads one feature a unit, so a
## texture repeats every NOISE_FEATURES units).
const NOISE_SIZE := 256
const NOISE_FEATURES := 8.0
## The surface arrays' format with both custom channels as four floats.
const CUSTOM_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

static var _fbm: ImageTexture = null
static var _cells: ImageTexture = null


## A material for `map` in `look`: the finishes, the noise, the photo sets and the map's puddles.
static func material(look: SiteLook, map: MapData) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var names := look.finish_names()
	assert(names.size() <= SLOTS, "SiteLook has more finishes than the shader's slots")
	var modes := PackedInt32Array()
	var paints := PackedVector3Array()
	var accents := PackedVector3Array()
	var bands := PackedVector2Array()
	var pbr := PackedVector2Array()
	for n in names:
		modes.append(look.canvases[n])
		paints.append(_linear(look.paints.get(n, look.paints[&"default"])))
		accents.append(_linear(look.accents.get(n, Color.BLACK)))
		bands.append(look.bands.get(n, Vector2(1.0, 0.0)))
		pbr.append(look.finishes_pbr.get(n, Vector2(0.8, 0.0)))
	m.set_shader_parameter(&"modes", modes)
	m.set_shader_parameter(&"paints", paints)
	m.set_shader_parameter(&"accents", accents)
	m.set_shader_parameter(&"bands", bands)
	m.set_shader_parameter(&"pbr", pbr)
	var containers := PackedVector3Array()
	for c: Color in look.container_paint.slice(0, PAINTS):
		containers.append(_linear(c))
	m.set_shader_parameter(&"container_paint", containers)
	var marks := PackedVector3Array()
	for k in MARKS:
		marks.append(_linear(look.marks.get(k, Color.MAGENTA)))
	m.set_shader_parameter(&"marks", marks)
	m.set_shader_parameter(&"container_count", containers.size())
	m.set_shader_parameter(&"container_unit", look.container_unit)
	m.set_shader_parameter(&"container_split", look.container_split)
	m.set_shader_parameter(&"container_tier", look.container_tier)
	m.set_shader_parameter(&"fbm_tex", fbm_texture())
	m.set_shader_parameter(&"cells_tex", _cells_texture())
	m.set_shader_parameter(&"joint", look.joint)
	m.set_shader_parameter(&"edge_width", look.edge_width)
	m.set_shader_parameter(&"edge_light", look.edge_light)
	_photo(m, look.slab_colour, look.slab_normal, &"slab_col", &"slab_nrm", &"slab_set",
			Vector4(look.slab_scale, look.slab_mix, look.slab_depth, look.slab_luma))
	_photo(m, look.ply_colour, look.ply_normal, &"ply_col", &"ply_nrm", &"ply_set",
			Vector4(look.ply_scale, look.ply_mix, look.ply_depth, look.ply_luma))
	_wet(m, look, map)
	_lines(m, look, map)
	return m


## The map's bay lines (SiteDressing) and the dock's hazard lip.
static func _lines(m: ShaderMaterial, look: SiteLook, map: MapData) -> void:
	var lines := PackedVector4Array()
	lines.resize(LINES)
	var count := 0
	for r: Rect2 in (map.site.lines if map.site != null else [] as Array[Rect2]).slice(0, LINES):
		lines[count] = Vector4(r.get_center().x, r.get_center().y, r.size.x * 0.5, r.size.y * 0.5)
		count += 1
	m.set_shader_parameter(&"lines", lines)
	m.set_shader_parameter(&"line_count", count)
	m.set_shader_parameter(&"hazard_lip", look.hazard_lip)


## The custom channels for a box round `centre`, half `half` in finish `finish` with `flags`.
static func customs(look: SiteLook, centre: Vector3, half: Vector3, finish: StringName, flags: int) -> Array[Color]:
	return [Color(centre.x, centre.y, centre.z, float(slot_of(look, finish))),
			Color(half.x, half.y, half.z, float(flags))]


## Block `b`'s custom channels on its map.
static func block_customs(look: SiteLook, b: MapData.Block) -> Array[Color]:
	return customs(look, b.center, b.size * 0.5, look.finish_of(b), flags_of(look, b))


## The ground beyond the walls, under `top`.
static func ground_customs(look: SiteLook, top: float) -> Array[Color]:
	return customs(look, Vector3(0.0, top - 50.0, 0.0), Vector3(1e4, 50.0, 1e4), &"ground", FLAG_NO_BEVEL)


## Whether block `b` is drawn as CC0 props (PropDress, DR2) instead of its faces.
static func as_props(look: SiteLook, b: MapData.Block) -> bool:
	return b.rise == MapData.Rise.NONE and look.props != null and look.props.dresses(b)


## Where block `b`'s faces are drawn: where they are, but for a sandbag stack, whose own box is drawn `bag_core` m
## inside its sides and top, under its bags (SiteDress), which fill the block; for a kind drawn as props
## (PropDressConfig.dresses, DR2), which fill it instead, nowhere (folded to its middle), or for tiled props their
## backing, half a row inside each lined face (PropDressConfig.tile_depths).
static func core_of(look: SiteLook, b: MapData.Block) -> Transform3D:
	if as_props(look, b):
		if look.props.backs(b):
			var rows := look.props.tile_depths(b)
			return _inset(b, Vector2(rows.y * 0.5, rows.x * 0.5), look.props.backing_top)
		return Transform3D(Basis.from_scale(Vector3.ZERO), b.center)
	if look.finish_of(b) != &"sandbags" or b.rise != MapData.Rise.NONE:
		return Transform3D.IDENTITY
	return _inset(b, Vector2(look.bag_core, look.bag_core), look.bag_core)


## Whether block `b`'s faces are not drawn at all: a kind drawn as props with no backing (DR2).
static func hidden(look: SiteLook, b: MapData.Block) -> bool:
	return as_props(look, b) and not look.props.backs(b)


## Block `b`'s box drawn `side.x` m inside its sides across x, `side.y` inside those across z and `top` m under its
## top, its foot where it is.
static func _inset(b: MapData.Block, side: Vector2, top: float) -> Transform3D:
	var h := b.size * 0.5
	var scale := Vector3(maxf(h.x - side.x, 0.0) / h.x, maxf(b.size.y - top, 0.0) / b.size.y,
			maxf(h.z - side.y, 0.0) / h.z)
	var basis := Basis.from_scale(scale)
	var foot := b.center - Vector3(0.0, h.y, 0.0)
	return Transform3D(basis, foot - basis * foot)


## The flags block `b` is drawn with: a container's chevron, paint by unit and piece; the dock's and a hoarding's
## hazard stripes; no bevel on gravel.
static func flags_of(look: SiteLook, b: MapData.Block) -> int:
	match look.finish_of(b):
		&"container":
			return FLAG_CHEVRON | FLAG_PALETTE | (b.piece << PIECE_SHIFT)
		&"dock", &"hoarding":
			return FLAG_HAZARD
		&"gravel":
			return FLAG_NO_BEVEL
	return 0


## The slot of finish `finish` (its place in SiteLook.finish_names), `default`'s for one it doesn't know.
static func slot_of(look: SiteLook, finish: StringName) -> int:
	var i := look.finish_names().find(finish)
	return i if i >= 0 else look.finish_names().find(&"default")


## Adds a box round `centre` of `size` (no underside) to `st` (begun, with both custom formats RGBA float), in finish
## `finish` with `flags`, its vertices' colour `colour` (white, or a paint with FLAG_TINT).
static func add_box(st: SurfaceTool, look: SiteLook, centre: Vector3, size: Vector3, finish: StringName, flags: int,
		colour: Color = Color.WHITE) -> void:
	var c := customs(look, centre, size * 0.5, finish, flags)
	st.set_color(colour)
	st.set_custom(0, c[0])
	st.set_custom(1, c[1])
	var lo := centre - size * 0.5
	var hi := centre + size * 0.5
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	for f: Array in [[7, 6, 5, 4], [3, 2, 6, 7], [1, 0, 4, 5], [2, 1, 5, 6], [0, 3, 7, 4]]:
		add_face(st, PackedVector3Array([p[f[0]], p[f[1]], p[f[2]], p[f[3]]]))


## A convex face given anticlockwise as seen from outside (MapLevel's order and winding).
static func add_face(st: SurfaceTool, pts: PackedVector3Array) -> void:
	st.set_normal(GreyboxFaces.face_normal(pts))
	for i in range(1, pts.size() - 1):
		st.add_vertex(pts[0])
		st.add_vertex(pts[i + 1])
		st.add_vertex(pts[i])


## A SurfaceTool begun for site vertices.
static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	return st


## The tiling fbm noise (SiteDress's sky reads it too), made once.
static func fbm_texture() -> ImageTexture:
	if _fbm == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = 4127
		noise.frequency = NOISE_FEATURES / float(NOISE_SIZE)
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 5
		_fbm = _texture(noise)
	return _fbm


## The tiling stones: red each stone's centre to edge, green the stone's own random shade.
static func _cells_texture() -> ImageTexture:
	if _cells == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.seed = 7351
		noise.frequency = NOISE_FEATURES / float(NOISE_SIZE)
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
		var edge := noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE)
		noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
		var shade := noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE)
		var img := Image.create(NOISE_SIZE, NOISE_SIZE, false, Image.FORMAT_RG8)
		for y in NOISE_SIZE:
			for x in NOISE_SIZE:
				img.set_pixel(x, y, Color(edge.get_pixel(x, y).r, shade.get_pixel(x, y).r, 0.0))
		img.generate_mipmaps()
		_cells = ImageTexture.create_from_image(img)
	return _cells


static func _texture(noise: FastNoiseLite) -> ImageTexture:
	var img := noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _photo(m: ShaderMaterial, colour_path: String, normal_path: String, colour_key: StringName,
		normal_key: StringName, set_key: StringName, values: Vector4) -> void:
	var colour := load(colour_path) as Texture2D
	var normal := load(normal_path) as Texture2D
	if colour == null or normal == null:
		push_warning("SiteSurface: %s or %s could not be loaded; drawn without it" % [colour_path, normal_path])
		m.set_shader_parameter(set_key, Vector4(values.x, 0.0, 0.0, 1.0))
		return
	m.set_shader_parameter(colour_key, colour)
	m.set_shader_parameter(normal_key, normal)
	m.set_shader_parameter(set_key, values)


## The map's puddles drawn into a mask over their extent (a dark, glossy patch on the slab; docs/ART.md › Wet ground).
static func _wet(m: ShaderMaterial, look: SiteLook, map: MapData) -> void:
	if map.puddles.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in map.puddles:
		lo = lo.min(p.at - p.size * 0.6)
		hi = hi.max(p.at + p.size * 0.6)
	var px := look.wet_pixels
	var w := maxi(1, ceili((hi.x - lo.x) * px))
	var h := maxi(1, ceili((hi.y - lo.y) * px))
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	var edge := FastNoiseLite.new()
	edge.seed = map.dressing_seed
	edge.frequency = 1.3
	for p in map.puddles:
		var from := ((p.at - p.size * 0.6 - lo) * px).floor()
		var to := ((p.at + p.size * 0.6 - lo) * px).ceil()
		for y in range(maxi(0, int(from.y)), mini(h, int(to.y))):
			for x in range(maxi(0, int(from.x)), mini(w, int(to.x))):
				var world := lo + (Vector2(x, y) + Vector2(0.5, 0.5)) / px
				var r := ((world - p.at) / (p.size * 0.5)).length() + edge.get_noise_2dv(world) * 0.35
				var wet := 1.0 - smoothstep(0.7, 1.0, r)
				if wet > img.get_pixel(x, y).r:
					img.set_pixel(x, y, Color(wet, wet, wet))
	m.set_shader_parameter(&"wet_tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter(&"wet_rect", Vector4(lo.x, lo.y, 1.0 / (w / px), 1.0 / (h / px)))


static func _linear(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)
