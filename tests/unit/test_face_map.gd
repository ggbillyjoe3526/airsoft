extends GutTest
## MQ3C: the figure's face drawn as a real one (owner, 2026-11-13: "Has the players face been improved? If not then
## add that to the list of models to work on"). The face in the balaclava's eye opening has a map of its own
## (tools/blender/figures/face.py FACE_MAP, painted by face_paint.py): four looks, each with skin that carries pores,
## brows of single hairs, a coloured iris round a dark pupil, whites and lashes. Each eyeball draws from a patch of
## its own under the skin's part of the cell (face.py EYE_PATCH), where the pupil gives no light back and a small
## facet beside it mirrors the light (the glint). The goggles' lens is a thin dark tint, so the pupils stay black.
## The heads keep their triangle budgets (test_figure_body.gd) and the figure its eight materials
## (test_head_body_surfaces.gd).

const HEADS: Array[String] = ["Head_HighCut", "Head_FullCut", "Head_Cap", "Head_Boonie"]
const LEVELS: Array[String] = ["", "_LOD1", "_LOD2"]
## The face's map (px) and one look's cell in it (face.py FACE_MAP, FACE_CELLS).
const MAP := Vector2i(2048, 1024)
const CELL := Vector2i(1024, 512)
## The largest side a texture may have (the owner's 2K rule).
const SIDE_AT_MOST := 2048
## Each look's cell's top left corner in the map's picture (the mesh's own look first, then FigureConfig.face_offsets').
const CELLS: Array[Vector2i] = [Vector2i(0, 512), Vector2i(1024, 512), Vector2i(0, 0), Vector2i(1024, 0)]
## Places in a cell (px from its top left; a pixel is about 0.14 mm): the pupils' middles, and from a pupil how far
## out the iris's body and the white lie, how far down the cheek and out the temple (beside the outer corner: the
## skin under the eye is drawn dry and nearly smooth, so no lamp sparks on it), and each brow's middle.
const PUPILS: Array[Vector2i] = [Vector2i(292, 218), Vector2i(731, 218)]
const IRIS_OUT := 27
const WHITE_OUT := 62
const CHEEK_DOWN := 78
const TEMPLE_OUT := 150
const BROWS: Array[Vector2i] = [Vector2i(286, 122), Vector2i(737, 122)]
## Each eyeball's own patch: its pupil's middle, the glint beside it, and how far toward the ear (away from the cell's
## middle) its white lies.
const PATCH_PUPILS: Array[Vector2i] = [Vector2i(334, 446), Vector2i(689, 446)]
const GLINTS: Array[Vector2i] = [Vector2i(317, 431), Vector2i(672, 431)]
const PATCH_WHITE_OUT := 69
## Half the side of the box a colour is read over (px), and of the boxes the cheek's and the brow's grain is read over.
const SPOT := 3
const PATCH := 20
const BROW_BOX := Vector2i(48, 10)
## A pupil is this dark at most, a white this light at least, and lighter than its iris by this much (0-1).
const PUPIL_AT_MOST := 0.14
const WHITE_AT_LEAST := 0.40
const WHITE_OVER_IRIS := 0.08
## A brow is this share of its cheek's lightness at most, and its hairs spread its lightness at least this far.
const BROW_OF_CHEEK_AT_MOST := 0.86
const BROW_SPREAD_AT_LEAST := 0.08
## Each look's skin is at least this much darker than the look before it.
const TONE_STEP_AT_LEAST := 0.05
## A pixel of the normal map this far (of 255) off flat carries detail; the share of the skin's that do, at least,
## and of the eye's, at most (the eye is smooth and wet).
const BUMP := 3
const SKIN_BUMPY_AT_LEAST := 0.3
const EYE_BUMPY_AT_MOST := 0.1
const EYE_ROUGH_AT_MOST := 0.47
const SKIN_ROUGH_AT_LEAST := 0.35
## How open to the light round it (the map's occlusion, 0-1) a pupil is at most and the cheek at least; how far a
## glint is bare mirror (the map's metal) and how light, at least.
const PUPIL_OPEN_AT_MOST := 0.3
const CHEEK_OPEN_AT_LEAST := 0.9
const GLINT_METAL_AT_LEAST := 0.5
const GLINT_LIGHT_AT_LEAST := 0.6
## The lens's tint: its alpha over Godot's 0.1 (under it a lens stops shading the face behind it) and thin, its
## colour dark (a pale thick one laid a grey haze over the eyes). The colour is read as Godot shows it (sRGB): the
## dark tint reads about 0.52, the pale one it replaced 0.88.
const LENS_ALPHA_OVER := 0.1
const LENS_ALPHA_AT_MOST := 0.15
const LENS_LIGHT_AT_MOST := 0.6

var config: FigureConfig = null
var models: FigureModels = null
var _maps: Dictionary[String, Image] = {}


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	var face := _face_material(_mesh(_human(), HEADS[0]))
	if face == null:
		return
	_maps["colour"] = _image(face.albedo_texture)
	_maps["normal"] = _image(face.normal_texture)
	_maps["rough"] = _image(face.roughness_texture)


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


static func _face_material(mesh: Mesh) -> BaseMaterial3D:
	var at := _surface(mesh, "Face")
	return mesh.surface_get_material(at) as BaseMaterial3D if at >= 0 else null


static func _image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


## The mean colour of the box `half` px round `at` (a place in look `look`'s cell) of map `which`, whatever size the
## map was packed at.
func _mean(which: String, look: int, at: Vector2i, half: Vector2i) -> Color:
	var image := _maps[which]
	var scale := Vector2(image.get_size()) / Vector2(MAP)
	var sum := Vector3.ZERO
	var count := 0
	for y in range(at.y - half.y, at.y + half.y + 1):
		for x in range(at.x - half.x, at.x + half.x + 1):
			var p := Vector2i((Vector2(CELLS[look] + Vector2i(x, y)) * scale).floor())
			var c := image.get_pixelv(p)
			sum += Vector3(c.r, c.g, c.b)
			count += 1
	sum /= float(count)
	return Color(sum.x, sum.y, sum.z)


## The darkest and the lightest pixel of that box: [least, most] lightness.
func _spread(which: String, look: int, at: Vector2i, half: Vector2i) -> Vector2:
	var image := _maps[which]
	var out := Vector2(1.0, 0.0)
	for y in range(at.y - half.y, at.y + half.y + 1):
		for x in range(at.x - half.x, at.x + half.x + 1):
			var light := image.get_pixelv(CELLS[look] + Vector2i(x, y)).get_luminance()
			out = Vector2(minf(out.x, light), maxf(out.y, light))
	return out


## The share of that box's normal-map pixels that are off flat.
func _bumpy(look: int, at: Vector2i, half: Vector2i) -> float:
	var image := _maps["normal"]
	var bumpy := 0
	var count := 0
	for y in range(at.y - half.y, at.y + half.y + 1):
		for x in range(at.x - half.x, at.x + half.x + 1):
			var c := image.get_pixelv(CELLS[look] + Vector2i(x, y))
			count += 1
			if absi(c.r8 - 128) >= BUMP or absi(c.g8 - 128) >= BUMP:
				bumpy += 1
	return float(bumpy) / float(count)


func test_the_face_draws_from_a_map_of_its_own_within_the_texture_rule() -> void:
	var root := _human()
	for head in HEADS:
		for level in LEVELS:
			var mesh := _mesh(root, head + level)
			var face := _face_material(mesh)
			assert_not_null(face, "%s%s has a Face surface" % [head, level])
			if face == null:
				continue
			var gear := mesh.surface_get_material(_surface(mesh, "Headwear")) as BaseMaterial3D
			assert_ne(face.albedo_texture, gear.albedo_texture, "%s%s: not the heads' atlas" % [head, level])
			assert_eq(Vector2i(face.albedo_texture.get_size()), MAP, "%s%s: the face's map" % [head, level])
			assert_true(face.normal_enabled and face.normal_texture != null, "%s%s: a normal map" % [head, level])
			assert_not_null(face.roughness_texture, "%s%s: a roughness map" % [head, level])
			assert_true(face.ao_enabled and face.ao_texture != null, "%s%s: an occlusion map" % [head, level])
			for texture: Texture2D in [face.albedo_texture, face.normal_texture, face.roughness_texture]:
				assert_lte(maxi(texture.get_width(), texture.get_height()), SIDE_AT_MOST)


func test_every_face_uv_lies_in_the_first_looks_cell_and_each_look_lands_in_its_own() -> void:
	assert_eq(config.face_offsets.size(), CELLS.size(), "an offset a look")
	var first := Rect2(Vector2(CELLS[0]) / Vector2(MAP), Vector2(CELL) / Vector2(MAP))
	var root := _human()
	for head in HEADS:
		for level in LEVELS:
			var mesh := _mesh(root, head + level)
			var at := _surface(mesh, "Face")
			if at < 0:
				fail_test("%s%s has no Face surface" % [head, level])
				continue
			var uv := mesh.surface_get_arrays(at)[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			var outside := 0
			for p in uv:
				if not first.has_point(p):
					outside += 1
			assert_eq(outside, 0, "%s%s: corners outside the first look's cell" % [head, level])
	for look in CELLS.size():
		var cell := Rect2(first.position + config.face_offsets[look], first.size)
		var own := Rect2(Vector2(CELLS[look]) / Vector2(MAP), Vector2(CELL) / Vector2(MAP))
		assert_almost_eq(cell.position, own.position, Vector2.ONE * 1e-6, "look %d's offset reaches its cell" % look)


func test_each_look_has_dark_pupils_in_a_coloured_iris_between_whites() -> void:
	if _maps.is_empty():
		fail_test("no face map")
		return
	var spot := Vector2i(SPOT, SPOT)
	for look in CELLS.size():
		for eye in PUPILS.size():
			var name := "look %d eye %d" % [look, eye]
			var pupil := _mean("colour", look, PUPILS[eye], spot).get_luminance()
			assert_lt(pupil, PUPIL_AT_MOST, "%s: the pupil is dark" % name)
			for way: int in [-1, 1]:
				var iris := _mean("colour", look, PUPILS[eye] + Vector2i(way * IRIS_OUT, 0), spot)
				var white := _mean("colour", look, PUPILS[eye] + Vector2i(way * WHITE_OUT, 0), spot)
				assert_gt(iris.get_luminance(), pupil, "%s: the iris is lighter than the pupil" % name)
				assert_gt(white.get_luminance(), WHITE_AT_LEAST, "%s: the white is light" % name)
				assert_gt(white.get_luminance(), iris.get_luminance() + WHITE_OVER_IRIS, "%s: and lighter than the iris" % name)
				match look:
					0:
						assert_gt(iris.b, iris.r, "%s: a blue iris" % name)
					1:
						assert_true(iris.g > iris.r and iris.g > iris.b, "%s: a green iris" % name)
					_:
						assert_gt(iris.r, iris.b, "%s: a brown iris" % name)


func test_the_looks_differ_in_skin_tone_and_each_brow_is_darker_hairs() -> void:
	if _maps.is_empty():
		fail_test("no face map")
		return
	var before := 1.0
	for look in CELLS.size():
		var tone := 0.0
		for eye in PUPILS.size():
			var cheek := _mean("colour", look, PUPILS[eye] + Vector2i(0, CHEEK_DOWN), Vector2i(PATCH, PATCH)).get_luminance()
			tone += cheek / float(PUPILS.size())
			var brow := _mean("colour", look, BROWS[eye], BROW_BOX).get_luminance()
			assert_lt(brow, cheek * BROW_OF_CHEEK_AT_MOST, "look %d eye %d: the brow is darker than the skin" % [look, eye])
			var spread := _spread("colour", look, BROWS[eye], BROW_BOX)
			assert_gt(spread.y - spread.x, BROW_SPREAD_AT_LEAST, "look %d eye %d: hairs, not a flat block" % [look, eye])
		assert_lt(tone, before - TONE_STEP_AT_LEAST, "look %d's skin is darker than the look before" % look)
		before = tone


func test_the_skin_carries_pores_and_each_eyeballs_patch_is_smooth_with_a_dark_pupil_and_a_glint() -> void:
	if _maps.is_empty():
		fail_test("no face map")
		return
	var spot := Vector2i(SPOT, SPOT)
	var dot := Vector2i.ONE
	var patch := Vector2i(PATCH, PATCH)
	for look in CELLS.size():
		for eye in PUPILS.size():
			var name := "look %d eye %d" % [look, eye]
			var cheek := PUPILS[eye] + Vector2i(0, CHEEK_DOWN)
			var out := 1 if eye == 1 else -1
			var temple := PUPILS[eye] + Vector2i(TEMPLE_OUT * out, 0)
			var pupil := PATCH_PUPILS[eye]
			var white := pupil + Vector2i(PATCH_WHITE_OUT * out, 0)
			assert_gt(_bumpy(look, temple, patch), SKIN_BUMPY_AT_LEAST, "%s: the skin's pores" % name)
			assert_lt(_bumpy(look, white, spot), EYE_BUMPY_AT_MOST, "%s: the eye's white is smooth" % name)
			assert_lt(_mean("colour", look, pupil, spot).get_luminance(), PUPIL_AT_MOST, "%s: the patch's pupil is dark" % name)
			assert_gt(_mean("colour", look, white, spot).get_luminance(), WHITE_AT_LEAST, "%s: its white is light" % name)
			var eye_rough := _mean("rough", look, white, spot).g
			var skin_rough := _mean("rough", look, cheek, patch).g
			assert_lt(eye_rough, EYE_ROUGH_AT_MOST, "%s: the eye is moist" % name)
			assert_gt(skin_rough, SKIN_ROUGH_AT_LEAST, "%s: the skin is not" % name)
			assert_gt(skin_rough, eye_rough, "%s: the skin is duller than the eye" % name)
			assert_lt(_mean("rough", look, pupil, spot).r, PUPIL_OPEN_AT_MOST, "%s: the pupil gives no light back" % name)
			assert_gt(_mean("rough", look, cheek, patch).r, CHEEK_OPEN_AT_LEAST, "%s: the cheek is open to the light" % name)
			assert_gt(_mean("rough", look, GLINTS[eye], dot).b, GLINT_METAL_AT_LEAST, "%s: the glint mirrors the light" % name)
			assert_gt(_mean("colour", look, GLINTS[eye], dot).get_luminance(), GLINT_LIGHT_AT_LEAST, "%s: and is light" % name)
			assert_lt(_mean("rough", look, white, spot).b, GLINT_METAL_AT_LEAST, "%s: the white is no mirror" % name)


func test_the_lens_is_a_thin_dark_tint_that_still_shades_the_face() -> void:
	var root := _human()
	var lenses := 0
	for head in HEADS:
		var mesh := _mesh(root, head)
		var at := _surface(mesh, "Lens")
		if at < 0:
			continue
		lenses += 1
		var lens := mesh.surface_get_material(at) as BaseMaterial3D
		assert_gt(lens.albedo_color.a, LENS_ALPHA_OVER, "%s: the lens still shades the face" % head)
		assert_lte(lens.albedo_color.a, LENS_ALPHA_AT_MOST, "%s: the lens is thin" % head)
		assert_lt(lens.albedo_color.get_luminance(), LENS_LIGHT_AT_MOST, "%s: the lens's tint is dark" % head)
	assert_gt(lenses, 0, "a head wears a lens")
