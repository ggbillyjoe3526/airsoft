extends GutTest
## MQ3: the human figure's gear drawn as what it is made of (owner, 2026-11-12: "Also do this for figure and cloth
## models. This means the human face, helmets, goggles, plate carriers, etc."). The full-detail carrier, pouches, belt,
## pack and radio are unwrapped into charts and baked (tools/blender/figure-gear/atlas.py): the TeamGear's in its own
## 2K maps, the Gear's in the knee pads' 2K maps round the pads' own square. The lower levels still draw plain colours
## from each family's swatch strip in the same maps, so the figure keeps its eight materials.

## The maps' side (gear.py ATLAS, pads.py MAP).
const MAP := 2048
## The roughness and metal maps are drawn at half that (their import's size limit, as the body's and the heads').
const ROUGHNESS_MAP := 1024
## The pads' own square at the maps' top left (gear.py PADS_TEX), as a share of the maps' side.
const PADS_SQUARE := 0.5
## Each family's swatch strip in its maps, px: left, top, right, bottom (gear.py PADS_AT, TEAM_AT, TEX_W, TEX_H).
const STRIPS := {"Pads": Rect2(32.0, 928.0, 256.0, 32.0), "TeamGear": Rect2(32.0, 32.0, 256.0, 32.0)}
## The strip's own wrap round it (gear.py PADS_WRAP), which no chart may touch.
const STRIP_WRAP := 32.0
const BAKED: Array[String] = ["Kit", "Kit_Pack", "Kit_Radio"]
const PLAIN: Array[String] = ["Kit_LOD1", "Kit_LOD2", "Kit_Pack_LOD1", "Kit_Pack_LOD2", "Kit_Radio_LOD1"]
const PADS: Array[String] = ["Kit_Pads", "Kit_Pads_LOD1", "Kit_Pads_LOD2"]
const FAMILIES: Array[String] = ["TeamGear", "Pads"]
## The least of its maps a family's charts cover (the TeamGear's own maps; the Gear's three quarters of the pads').
const COVERED_AT_LEAST := {"TeamGear": 0.3, "Pads": 0.2}
## A pixel of a normal map this far (of 255) off flat is carrying detail.
const BUMP := 4
const BUMPY_AT_LEAST := 0.15
## The figure's materials (BP6).
const MATERIALS_AT_MOST := 8
const UV_SLACK := 0.5 / MAP

var config: FigureConfig = null
var models: FigureModels = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func _human() -> Node:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	return root


func _mesh(root: Node, part: String) -> Mesh:
	var mi := root.find_child(part, true, false) as MeshInstance3D
	assert_not_null(mi, part)
	return mi.mesh if mi != null else null


static func _surface(mesh: Mesh, material: String) -> int:
	for i in mesh.get_surface_count():
		var own := mesh.surface_get_material(i)
		if own != null and own.resource_name == material:
			return i
	return -1


static func _uvs(mesh: Mesh, surface: int) -> PackedVector2Array:
	return mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV] as PackedVector2Array


## The share of the maps a surface's triangles cover.
static func _uv_area(mesh: Mesh, surface: int) -> float:
	var arrays := mesh.surface_get_arrays(surface)
	var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var area := 0.0
	for i in range(0, index.size(), 3):
		area += absf((uv[index[i + 1]] - uv[index[i]]).cross(uv[index[i + 2]] - uv[index[i]])) * 0.5
	return area


static func _strip(family: String, grown: float) -> Rect2:
	var px: Rect2 = STRIPS[family]
	return Rect2(px.position / MAP, px.size / MAP).grow(grown / MAP)


static func _image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


func test_both_families_draw_from_2k_maps_with_normals() -> void:
	var kit := _mesh(_human(), "Kit")
	for family in FAMILIES:
		var at := _surface(kit, family)
		assert_gte(at, 0, family)
		if at < 0:
			continue
		var material := kit.surface_get_material(at) as BaseMaterial3D
		assert_not_null(material, family)
		assert_not_null(material.albedo_texture, "%s colour" % family)
		assert_eq(material.albedo_texture.get_size(), Vector2(MAP, MAP), "%s colour" % family)
		assert_true(material.normal_enabled, "%s normal" % family)
		assert_not_null(material.normal_texture, "%s normal" % family)
		assert_eq(material.normal_texture.get_size(), Vector2(MAP, MAP), "%s normal" % family)
		assert_not_null(material.roughness_texture, "%s roughness" % family)
		assert_eq(material.roughness_texture.get_size(), Vector2(ROUGHNESS_MAP, ROUGHNESS_MAP), "%s roughness" % family)


func test_the_full_detail_pieces_are_unwrapped_into_charts() -> void:
	var root := _human()
	var covered := {"TeamGear": 0.0, "Pads": 0.0}
	for part in BAKED:
		var mesh := _mesh(root, part)
		if mesh == null:
			continue
		for family in FAMILIES:
			var at := _surface(mesh, family)
			if at < 0:
				continue
			covered[family] += _uv_area(mesh, at)
			var strip := _strip(family, STRIP_WRAP)
			var off := 0
			for uv in _uvs(mesh, at):
				var in_map := uv.x >= -UV_SLACK and uv.y >= -UV_SLACK and uv.x <= 1.0 + UV_SLACK and uv.y <= 1.0 + UV_SLACK
				var on_pads := family == "Pads" and uv.x < PADS_SQUARE - UV_SLACK and uv.y < PADS_SQUARE - UV_SLACK
				if not in_map or on_pads or (family == "TeamGear" and strip.has_point(uv)):
					off += 1
			assert_eq(off, 0, "%s %s: every corner in the maps, off the pads' square and off the strip" % [part, family])
	for family in FAMILIES:
		assert_gt(covered[family], COVERED_AT_LEAST[family], "%s: the charts' share of the maps" % family)


func test_the_lower_levels_still_draw_from_the_strips() -> void:
	var root := _human()
	for part in PLAIN:
		var mesh := _mesh(root, part)
		if mesh == null:
			continue
		for family in FAMILIES:
			var at := _surface(mesh, family)
			if at < 0:
				continue
			var strip := _strip(family, 0.5)
			var off := 0
			for uv in _uvs(mesh, at):
				if not strip.has_point(uv):
					off += 1
			assert_eq(off, 0, "%s %s: every corner on the strip" % [part, family])


func test_the_pads_keep_to_their_own_square() -> void:
	var root := _human()
	for part in PADS:
		var mesh := _mesh(root, part)
		if mesh == null:
			continue
		var off := 0
		for uv in _uvs(mesh, 0):
			if uv.x > PADS_SQUARE + UV_SLACK or uv.y > PADS_SQUARE + UV_SLACK or uv.x < -UV_SLACK or uv.y < -UV_SLACK:
				off += 1
		assert_eq(off, 0, part)


func test_the_maps_carry_detail_where_the_charts_are() -> void:
	var kit := _mesh(_human(), "Kit")
	for family in FAMILIES:
		var at := _surface(kit, family)
		if at < 0:
			continue
		var normal := _image((kit.surface_get_material(at) as BaseMaterial3D).normal_texture)
		var bumpy := 0
		var seen := 0
		# Every fourth pixel each way, outside the pads' own square (which has its own detail).
		for y in range(0, MAP, 4):
			for x in range(0, MAP, 4):
				if family == "Pads" and x < MAP * PADS_SQUARE and y < MAP * PADS_SQUARE:
					continue
				seen += 1
				var c := normal.get_pixel(x, y)
				if absi(c.r8 - 128) > BUMP or absi(c.g8 - 128) > BUMP:
					bumpy += 1
		assert_gt(float(bumpy) / float(seen), BUMPY_AT_LEAST, "%s: the normal map's share that is not flat" % family)


func test_the_strips_are_still_plain_in_the_maps() -> void:
	var kit := _mesh(_human(), "Kit")
	for family in FAMILIES:
		var at := _surface(kit, family)
		if at < 0:
			continue
		var normal := _image((kit.surface_get_material(at) as BaseMaterial3D).normal_texture)
		var px: Rect2 = STRIPS[family]
		var bumpy := 0
		for y in range(int(px.position.y), int(px.end.y), 2):
			for x in range(int(px.position.x), int(px.end.x), 2):
				var c := normal.get_pixel(x, y)
				if absi(c.r8 - 128) > BUMP * 2 or absi(c.g8 - 128) > BUMP * 2:
					bumpy += 1
		assert_eq(bumpy, 0, "%s: no relief on the strip the lower levels draw from" % family)


func test_the_figure_keeps_its_materials() -> void:
	var root := _human()
	var names := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var own := mi.mesh.surface_get_material(i)
			if own != null:
				names[own.resource_name.get_slice(".", 0)] = true
	assert_lte(names.size(), MATERIALS_AT_MOST, str(names.keys()))
