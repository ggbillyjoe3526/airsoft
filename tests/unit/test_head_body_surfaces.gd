extends GutTest
## MQ3B: the human figure's head gear, team arm bands and boots drawn as what they are made of (owner, 2026-11-12:
## "Also do this for figure and cloth models. This means the human face, helmets, goggles, plate carriers, etc.").
## The heads' atlas is painted worn (tools/blender/figures/head_textures.py) and the ear cups, their cushions, the
## goggles' frame, the mesh mask's binding and the headset's band draw from tiles of their own where they sampled
## flat swatches; the body's baked maps get the arm
## bands' ribbed elastic and the boots' suede, creases and lugs (tools/blender/figures/body_surfaces.py). No mesh
## changed: the figure keeps its triangles (test_figure_body.gd) and its eight materials.

## The maps' side (head_textures.py ATLAS, body_surfaces.py SIZE).
const MAP := 2048
## The heads' new tiles, px from the atlas's left and bottom: x, y, width, height (head_textures.py paint).
const TILES := {
	"cup_defender": Rect2(0.0, 64.0, 512.0, 64.0),
	"cup_headset": Rect2(0.0, 128.0, 512.0, 64.0),
	"binding": Rect2(0.0, 192.0, 256.0, 64.0),
	"headband": Rect2(256.0, 192.0, 256.0, 64.0),
	"goggle_frame": Rect2(1024.0, 384.0, 512.0, 64.0),
	"cushion": Rect2(1024.0, 448.0, 512.0, 64.0),
	"cup_face_defender": Rect2(1152.0, 896.0, 128.0, 128.0),
	"cup_face_headset": Rect2(1280.0, 896.0, 128.0, 128.0),
	"boonie_top": Rect2(1024.0, 896.0, 128.0, 128.0),
}
## A moulded cup's colour is even (a faint tone turns to squares in the game's compressed map): its side wall's
## strip and its face's tile are painted in their sheen, the roughness spreading at least this far (0-1).
const SHEEN_TILES: Array[String] = ["cup_defender", "cup_headset", "cup_face_defender", "cup_face_headset"]
const SHEEN_SPREAD_AT_LEAST := 0.15
## Which heads wear what: the high cut olive ear defenders and a mesh mask under its glasses, the full cut goggles,
## the cap a headset with its band, goggles and a mesh mask; the boonie its top panel, laid flat.
const WEARS := {
	"Head_HighCut": ["cup_defender", "cup_face_defender", "cushion", "binding"],
	"Head_FullCut": ["goggle_frame"],
	"Head_Cap": ["cup_headset", "cup_face_headset", "cushion", "goggle_frame", "binding", "headband"],
	"Head_Boonie": ["boonie_top"],
}
const HEADS: Array[String] = ["Head_HighCut", "Head_FullCut", "Head_Cap", "Head_Boonie"]
## The flat swatches' rows at the atlas's bottom left (head_textures.py SWATCH_ROWS, headkit.py SWATCH_AREA and
## SWATCH): small hard parts and unseen faces still draw from them. The first is the inside of a helmet's shell.
const SWATCH_ROWS := 64.0
const SWATCH_AREA := 512.0
const SWATCH := 32.0
## The most of a head's drawn area left on flat swatches it can be seen on (the largest, the high cut: 0.15).
const FLAT_AT_MOST := 0.18
## A tile's colours spread at least this far (the darkest to the lightest of its green, as a share of its mean: the
## cushions and the headset are near black): it is painted, not flat.
const TILE_SPREAD_AT_LEAST := 0.15
## A pixel of a normal map this far (of 255) off flat is carrying detail.
const BUMP := 4
## The share of an arm band's or a boot's pixels that carry detail in the normal map, at least.
const BAND_BUMPY_AT_LEAST := 0.5
const BOOT_BUMPY_AT_LEAST := 0.3
## The arm band under the team colour: its mean (0-1) at least, so the team's colour stays the team's own, and the
## spread of its green at least (the ribs' valleys and the grime show).
const BAND_MEAN_AT_LEAST := 0.82
const BAND_SPREAD_AT_LEAST := 0.1
## Boots: no triangle's middle is above this (m); the roughness there spreads at least this far (suede to rubbed).
const BOOT_TOP := 0.2
const BOOT_ROUGH_SPREAD_AT_LEAST := 0.12
const MATERIALS_AT_MOST := 8

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
		if own != null and own.resource_name.begins_with(material):
			return i
	return -1


static func _image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


## A tile's rectangle in UV space (v runs down the image, the tiles' rows up it).
static func _uv_rect(tile: Rect2) -> Rect2:
	return Rect2(tile.position.x / MAP, 1.0 - (tile.position.y + tile.size.y) / MAP, tile.size.x / MAP, tile.size.y / MAP)


## The triangles of a surface whose three corners lie inside `rect` (UV).
static func _triangles_in(mesh: Mesh, surface: int, rect: Rect2) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var count := 0
	for i in range(0, index.size(), 3):
		if rect.has_point(uv[index[i]]) and rect.has_point(uv[index[i + 1]]) and rect.has_point(uv[index[i + 2]]):
			count += 1
	return count


## The pixels under a surface's triangles' middles and corners' thirds: [x, y] pairs in `size` px maps, for the
## triangles `keep` (a Callable of the triangle's middle in space) lets through.
static func _samples(mesh: Mesh, surface: int, size: int, keep: Callable) -> Array[Vector2i]:
	var arrays := mesh.surface_get_arrays(surface)
	var pos := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var out: Array[Vector2i] = []
	for i in range(0, index.size(), 3):
		var a := index[i]
		var b := index[i + 1]
		var c := index[i + 2]
		if not keep.call((pos[a] + pos[b] + pos[c]) / 3.0):
			continue
		for w: Vector3 in [Vector3(1, 1, 1) / 3.0, Vector3(0.6, 0.2, 0.2), Vector3(0.2, 0.6, 0.2), Vector3(0.2, 0.2, 0.6)]:
			var at := uv[a] * w.x + uv[b] * w.y + uv[c] * w.z
			out.append(Vector2i(clampi(int(at.x * size), 0, size - 1), clampi(int(at.y * size), 0, size - 1)))
	return out


static func _bumpy_share(image: Image, at: Array[Vector2i]) -> float:
	var bumpy := 0
	for p in at:
		var n := image.get_pixelv(p)
		if absi(n.r8 - 128) > BUMP or absi(n.g8 - 128) > BUMP:
			bumpy += 1
	return float(bumpy) / maxf(float(at.size()), 1.0)


## Samples laid out on a MAP-sized map, moved onto `image` (the roughness maps are imported smaller).
static func _scaled(at: Array[Vector2i], image: Image) -> Array[Vector2i]:
	var scaled: Array[Vector2i] = []
	for p in at:
		scaled.append(Vector2i(p.x * image.get_width() / MAP, p.y * image.get_height() / MAP))
	return scaled


## The least, the mean and the most of one channel under the samples.
static func _range(image: Image, at: Array[Vector2i], channel: int) -> Vector3:
	var least := 1.0
	var most := 0.0
	var sum := 0.0
	for p in at:
		var v: float = image.get_pixelv(p)[channel]
		least = minf(least, v)
		most = maxf(most, v)
		sum += v
	return Vector3(least, sum / maxf(float(at.size()), 1.0), most)


static func _everywhere(_middle: Vector3) -> bool:
	return true


static func _low(middle: Vector3) -> bool:
	return middle.y < BOOT_TOP


func test_the_ear_cups_cushions_and_goggle_frames_draw_from_their_own_tiles() -> void:
	var root := _human()
	for head: String in WEARS:
		var mesh := _mesh(root, head)
		var at := _surface(mesh, "Headwear")
		assert_gte(at, 0, head)
		if at < 0:
			continue
		for tile: String in WEARS[head]:
			assert_gt(_triangles_in(mesh, at, _uv_rect(TILES[tile])), 0, "%s draws from %s" % [head, tile])


func test_the_new_tiles_are_painted_and_carry_relief() -> void:
	var head := _mesh(_human(), "Head_HighCut")
	var m := head.surface_get_material(_surface(head, "Headwear")) as BaseMaterial3D
	var colour := _image(m.albedo_texture)
	var normal := _image(m.normal_texture)
	var sheen := _image(m.roughness_texture)
	assert_eq(colour.get_size(), Vector2i(MAP, MAP), "the heads' colour map")
	for tile: String in TILES:
		var rect := TILES[tile] as Rect2
		var at: Array[Vector2i] = []
		for y in range(int(MAP - rect.position.y - rect.size.y) + 4, int(MAP - rect.position.y) - 4, 3):
			for x in range(int(rect.position.x) + 4, int(rect.end.x) - 4, 3):
				at.append(Vector2i(x, y))
		if tile in SHEEN_TILES:
			var rough := _range(sheen, _scaled(at, sheen), 1)
			assert_gt(rough.z - rough.x, SHEEN_SPREAD_AT_LEAST, "%s sheen spreads" % tile)
		else:
			var green := _range(colour, at, 1)
			assert_gt((green.z - green.x) / maxf(green.y, 0.001), TILE_SPREAD_AT_LEAST, "%s colours spread" % tile)
		assert_gt(_bumpy_share(normal, at), 0.05, "%s relief" % tile)


func test_little_of_a_head_that_shows_is_left_on_flat_swatches() -> void:
	# With the cups, the binding and the band on tiles, the swatches hold the small hard parts (buckles, screws, the
	# microphone, the rims' rubber trim) and a shell's unseen inside, which is left out of the count.
	var root := _human()
	var rows := Rect2(0.0, 1.0 - SWATCH_ROWS / MAP, SWATCH_AREA / MAP, SWATCH_ROWS / MAP)
	var inside := Rect2(0.0, 1.0 - SWATCH / MAP, SWATCH / MAP, SWATCH / MAP)
	for head in HEADS:
		var mesh := _mesh(root, head)
		var at := _surface(mesh, "Headwear")
		assert_gte(at, 0, head)
		if at < 0:
			continue
		var arrays := mesh.surface_get_arrays(at)
		var pos := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var flat := 0.0
		var total := 0.0
		for i in range(0, index.size(), 3):
			var area := (pos[index[i + 1]] - pos[index[i]]).cross(pos[index[i + 2]] - pos[index[i]]).length() * 0.5
			var middle := (uv[index[i]] + uv[index[i + 1]] + uv[index[i + 2]]) / 3.0
			if inside.has_point(middle):
				continue
			total += area
			if rows.has_point(middle):
				flat += area
		assert_lt(flat / total, FLAT_AT_MOST, "%s: share of its area still on flat swatches" % head)


func test_the_arm_band_draws_the_bodys_colour_map_under_the_team_paint() -> void:
	var body := _mesh(_human(), "Body")
	var cloth := _surface(body, "Clothing")
	var team := _surface(body, "TeamCloth")
	assert_gte(cloth, 0, "Clothing")
	assert_gte(team, 0, "TeamCloth")
	if cloth < 0 or team < 0:
		return
	var source := body.surface_get_material(team) as BaseMaterial3D
	assert_not_null(source.albedo_texture, "the band's colour map")
	assert_eq(source.albedo_texture, (body.surface_get_material(cloth) as BaseMaterial3D).albedo_texture,
			"the band shares the body's colour map (no ninth set of maps)")
	assert_eq(source.albedo_color, Color.WHITE, "white under the team paint")
	# The game's team paint keeps the map and multiplies it.
	var blue := Color(0.23, 0.53, 0.96)
	var painted := models.team_material(0, source, 0, blue, 0.0) as BaseMaterial3D
	assert_eq(painted.albedo_texture, source.albedo_texture)
	assert_eq(painted.albedo_color, blue)


func test_the_arm_band_is_near_white_with_ribs_showing() -> void:
	var body := _mesh(_human(), "Body")
	var team := _surface(body, "TeamCloth")
	if team < 0:
		fail_test("no TeamCloth surface")
		return
	var m := body.surface_get_material(team) as BaseMaterial3D
	var at := _samples(body, team, MAP, _everywhere)
	assert_gt(at.size(), 500, "the band's samples")
	var colour := _image(m.albedo_texture)
	var green := _range(colour, at, 1)
	assert_gt(green.y, BAND_MEAN_AT_LEAST, "the band's mean under the team colour")
	assert_gt(green.z - green.x, BAND_SPREAD_AT_LEAST, "the ribs' valleys and the grime show")
	var red := _range(colour, at, 0)
	var blue := _range(colour, at, 2)
	assert_almost_eq(red.y, blue.y, 0.03, "the band is neutral: it does not tint the team's colour")
	assert_gt(_bumpy_share(_image(m.normal_texture), at), BAND_BUMPY_AT_LEAST, "the band's ribs in the normal map")


func test_the_boots_carry_relief_and_more_than_one_roughness() -> void:
	var body := _mesh(_human(), "Body")
	var cloth := _surface(body, "Clothing")
	if cloth < 0:
		fail_test("no Clothing surface")
		return
	var m := body.surface_get_material(cloth) as BaseMaterial3D
	var at := _samples(body, cloth, MAP, _low)
	assert_gt(at.size(), 2000, "the boots' samples")
	assert_gt(_bumpy_share(_image(m.normal_texture), at), BOOT_BUMPY_AT_LEAST, "the boots' nap, creases and lugs")
	var rough_image := _image(m.roughness_texture)
	var rough := _range(rough_image, _scaled(at, rough_image), 1)
	assert_gt(rough.z - rough.x, BOOT_ROUGH_SPREAD_AT_LEAST, "suede, rubbed patches, rubber and metal eyelets")


func test_the_figure_keeps_its_eight_materials() -> void:
	var names := {}
	for node in _human().find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var own := mesh.surface_get_material(i)
			if own != null:
				names[own.resource_name] = true
	assert_lte(names.size(), MATERIALS_AT_MOST, "materials: %s" % str(names.keys()))
