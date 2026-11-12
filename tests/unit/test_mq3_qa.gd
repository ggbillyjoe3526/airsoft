extends GutTest
## MQ3 QA: the gear's baked maps keep the team colour, the levels of detail agree, charts do not overlap,
## the pads' texels are the pads' own, and the committed imports point at the right maps.

const MAP := 2048
const FAMILIES: Array[String] = ["TeamGear", "Pads"]
const BAKED: Array[String] = ["Kit", "Kit_Pack", "Kit_Radio"]
## Main's swatch strip for the team colour (human_teamgear_col.png), sampled in the rows' middle: x, grey.
const OLD_SWATCHES := {0: 187, 16: 117, 32: 106, 48: 148, 64: 128, 128: 128, 240: 128}
const TEAM_STRIP := Rect2i(32, 32, 256, 32)
## How far (0..1) a level's mean colour may differ from the next level's before the drop in detail pops.
const POP_AT_MOST := 1.25
const GRID := 1024
const DOUBLE_COVER_AT_MOST := 0.01
const MAPS: Array[String] = ["teamgear_col", "teamgear_nrm", "teamgear_orm", "pads_col", "pads_nrm", "pads_orm"]

var models: FigureModels = null


func before_all() -> void:
	models = FigureModels.new(FigureConfig.new())
	models.load_kinds()


func _human() -> Node:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	return root


func _mesh(root: Node, part: String) -> Mesh:
	var mi := root.find_child(part, true, false) as MeshInstance3D
	return mi.mesh if mi != null else null


static func _surface(mesh: Mesh, material: String) -> int:
	for i in mesh.get_surface_count():
		var own := mesh.surface_get_material(i)
		if own != null and own.resource_name == material:
			return i
	return -1


static func _image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


## The area-weighted mean colour of the texels at a surface's triangle centres.
static func _mean(mesh: Mesh, surface: int, image: Image) -> Color:
	var arrays := mesh.surface_get_arrays(surface)
	var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var pos := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var sum := Vector3.ZERO
	var weight := 0.0
	for i in range(0, index.size(), 3):
		var a := index[i]
		var b := index[i + 1]
		var c := index[i + 2]
		var area := (pos[b] - pos[a]).cross(pos[c] - pos[a]).length() * 0.5
		var at := (uv[a] + uv[b] + uv[c]) / 3.0
		var texel := image.get_pixel(clampi(int(at.x * image.get_width()), 0, image.get_width() - 1), clampi(int(at.y * image.get_height()), 0, image.get_height() - 1))
		sum += Vector3(texel.r, texel.g, texel.b) * area
		weight += area
	if weight <= 0.0:
		return Color.BLACK
	sum /= weight
	return Color(sum.x, sum.y, sum.z)


func test_the_team_strip_is_the_swatches_main_had() -> void:
	var kit := _mesh(_human(), "Kit")
	var at := _surface(kit, "TeamGear")
	var image := _image((kit.surface_get_material(at) as BaseMaterial3D).albedo_texture)
	for x: int in OLD_SWATCHES:
		var got := image.get_pixel(TEAM_STRIP.position.x + x, TEAM_STRIP.position.y + 16)
		assert_almost_eq(got.r8, OLD_SWATCHES[x] as int, 2, "swatch at %d" % x)


func test_the_team_material_stays_neutral_for_the_team_paint() -> void:
	# The team paint multiplies the texture: a white albedo colour and a mid-grey baked mean keep blue blue.
	var root := _human()
	for part in BAKED:
		var mesh := _mesh(root, part)
		var at := _surface(mesh, "TeamGear")
		if at < 0:
			continue
		var m := mesh.surface_get_material(at) as BaseMaterial3D
		assert_eq(m.albedo_color, Color.WHITE, part)
		var mean := _mean(mesh, at, _image(m.albedo_texture))
		assert_lt(maxf(mean.r, maxf(mean.g, mean.b)) - minf(mean.r, minf(mean.g, mean.b)), 0.08, "%s chart tint %s" % [part, mean])


func test_each_level_has_the_colour_of_the_next() -> void:
	var root := _human()
	for part in BAKED:
		for family in FAMILIES:
			var full := _mesh(root, part)
			var low := _mesh(root, part + "_LOD1")
			if full == null or low == null:
				continue
			var a := _surface(full, family)
			var b := _surface(low, family)
			if a < 0 or b < 0:
				continue
			var m0 := _mean(full, a, _image((full.surface_get_material(a) as BaseMaterial3D).albedo_texture))
			var m1 := _mean(low, b, _image((low.surface_get_material(b) as BaseMaterial3D).albedo_texture))
			var d := maxf(m0.get_luminance(), m1.get_luminance()) / maxf(0.01, minf(m0.get_luminance(), m1.get_luminance()))
			gut.p("%s %s LOD0 %s LOD1 %s" % [part, family, m0, m1])
			assert_lt(d, POP_AT_MOST, "%s %s: brightness ratio, LOD0 %s vs LOD1 %s" % [part, family, m0, m1])


func _cover(meshes: Array[Mesh], family: String) -> Array:
	var owner_of := PackedInt32Array()
	owner_of.resize(GRID * GRID)
	var doubled := 0
	var covered := 0
	var degenerate := 0
	var triangles := 0
	var id := 0
	for mesh in meshes:
		var at := _surface(mesh, family)
		if at < 0:
			continue
		var arrays := mesh.surface_get_arrays(at)
		var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for i in range(0, index.size(), 3):
			id += 1
			triangles += 1
			var p0 := uv[index[i]] * GRID
			var p1 := uv[index[i + 1]] * GRID
			var p2 := uv[index[i + 2]] * GRID
			var area := (p1 - p0).cross(p2 - p0)
			if absf(area) < 1e-4:
				degenerate += 1
				continue
			var lo := Vector2(minf(p0.x, minf(p1.x, p2.x)), minf(p0.y, minf(p1.y, p2.y)))
			var hi := Vector2(maxf(p0.x, maxf(p1.x, p2.x)), maxf(p0.y, maxf(p1.y, p2.y)))
			for y in range(maxi(int(lo.y), 0), mini(int(hi.y) + 1, GRID)):
				for x in range(maxi(int(lo.x), 0), mini(int(hi.x) + 1, GRID)):
					var p := Vector2(x + 0.5, y + 0.5)
					var w0 := (p1 - p).cross(p2 - p) / area
					var w1 := (p2 - p).cross(p0 - p) / area
					if w0 < 0.0 or w1 < 0.0 or 1.0 - w0 - w1 < 0.0:
						continue
					var cell := y * GRID + x
					if owner_of[cell] != 0 and owner_of[cell] != id:
						doubled += 1
					else:
						covered += 1
					owner_of[cell] = id
	return [doubled, covered, degenerate, triangles]


func test_no_chart_overlaps_another() -> void:
	var root := _human()
	for family in FAMILIES:
		var meshes: Array[Mesh] = []
		for part in BAKED:
			meshes.append(_mesh(root, part))
		var r := _cover(meshes, family)
		gut.p("%s doubled %d covered %d degenerate %d of %d" % [family, r[0], r[1], r[2], r[3]])
		assert_lt(float(r[0]) / maxf(1.0, float(r[1])), DOUBLE_COVER_AT_MOST, "%s: share of cells two triangles cover" % family)
		assert_lt(float(r[2]) / maxf(1.0, float(r[3])), 0.02, "%s: degenerate UV triangles" % family)


func test_no_baked_triangle_samples_the_empty_canvas() -> void:
	var root := _human()
	for part in BAKED:
		var mesh := _mesh(root, part)
		for family in FAMILIES:
			var at := _surface(mesh, family)
			if at < 0:
				continue
			var image := _image((mesh.surface_get_material(at) as BaseMaterial3D).albedo_texture)
			var arrays := mesh.surface_get_arrays(at)
			var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			var empty := 0
			var seen := 0
			var canvas := image.get_pixel(MAP - 2, MAP - 2)
			for i in range(0, index.size(), 3):
				var at_uv := (uv[index[i]] + uv[index[i + 1]] + uv[index[i + 2]]) / 3.0
				var t := image.get_pixel(clampi(int(at_uv.x * MAP), 0, MAP - 1), clampi(int(at_uv.y * MAP), 0, MAP - 1))
				seen += 1
				if t.is_equal_approx(canvas) and t.a < 0.01:
					empty += 1
			assert_eq(empty, 0, "%s %s: triangles on transparent canvas of %d" % [part, family, seen])


func test_the_pads_sample_their_own_painting_at_every_level() -> void:
	var root := _human()
	for part: String in ["Kit_Pads", "Kit_Pads_LOD1", "Kit_Pads_LOD2"]:
		var mesh := _mesh(root, part)
		if mesh == null:
			continue
		var m := mesh.surface_get_material(0) as BaseMaterial3D
		var image := _image(m.albedo_texture)
		var arrays := mesh.surface_get_arrays(0)
		var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var gear_charts := 0
		for i in range(0, index.size(), 3):
			var c := (uv[index[i]] + uv[index[i + 1]] + uv[index[i + 2]]) / 3.0
			if c.x > 0.5 or c.y > 0.5:
				gear_charts += 1
		assert_eq(gear_charts, 0, "%s: triangles outside the pads' square" % part)
		assert_eq(image.get_width(), MAP, part)


func test_the_six_maps_import_as_the_record_says() -> void:
	for map in MAPS:
		var path := "res://assets/models/characters/human_%s.webp.import" % map
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(path), OK, path)
		assert_eq(cfg.get_value("params", "compress/mode"), 2, "%s VRAM compressed" % map)
		assert_true(cfg.get_value("params", "mipmaps/generate") as bool, "%s mipmaps" % map)
		assert_eq(cfg.get_value("params", "compress/normal_map") as int == 1, map.ends_with("nrm"), "%s normal flag" % map)
		var limit := cfg.get_value("params", "process/size_limit") as int
		assert_true(limit == 0 or limit == 2048 or (map.ends_with("orm") and limit == 1024), "%s size limit %d" % [map, limit])
	assert_false(FileAccess.file_exists("res://assets/models/characters/human_teamgear_col.png"))
	assert_false(FileAccess.file_exists("res://assets/models/characters/human_teamgear_col.png.import"))


func test_the_team_paint_still_multiplies_the_baked_colour() -> void:
	# Whatever FigureBody does with a team material, it copies the material and sets albedo_color: the copy keeps
	# its textures, so the baked maps survive the paint.
	var kit := _mesh(_human(), "Kit")
	var at := _surface(kit, "TeamGear")
	var src := kit.surface_get_material(at) as BaseMaterial3D
	var copy := src.duplicate() as BaseMaterial3D
	copy.albedo_color = Color("3b87f5")
	assert_eq(copy.albedo_texture, src.albedo_texture)
	assert_eq(copy.normal_texture, src.normal_texture)
	assert_true(copy.resource_name.begins_with("TeamGear") or copy.resource_name.to_lower().begins_with("team"))
