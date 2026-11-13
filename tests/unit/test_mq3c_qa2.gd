extends GutTest
## MQ3C QA, attempt 2: eyeball triangles sample only their patch, skin triangles never do; the per-look face material
## keeps the occlusion and the metal channel; every lens is alpha blended.

const HEADS: Array[String] = ["Head_HighCut", "Head_FullCut", "Head_Cap", "Head_Boonie"]
const LEVELS: Array[String] = ["", "_LOD1", "_LOD2"]
const MAP := Vector2(2048.0, 1024.0)
## face.py: the patch's s range per eye (|s| from 0.0045 to 0.0455) and z range as fractions of the cell (TILE_S 0.072).
const U_RANGES: Array[Vector2] = [Vector2(0.184, 0.469), Vector2(0.531, 0.816)]
const T_RANGE := Vector2(0.0083, 0.2447)
const SLACK := 0.004

var config: FigureConfig = null
var models: FigureModels = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


## (fraction across the cell, fraction down the cell from the image's top, look 0 cell = lower half of the map)
static func _cell(p: Vector2) -> Vector2:
	return Vector2(p.x * 2.0, p.y * 2.0 - 1.0)


static func _in_patch(c: Vector2, flip: bool, slack: float) -> bool:
	var t := 1.0 - c.y if flip else c.y
	if t < T_RANGE.x - slack or t > T_RANGE.y + slack:
		return false
	for r in U_RANGES:
		if c.x >= r.x - slack and c.x <= r.y + slack:
			return true
	return false


func test_no_triangle_straddles_the_eyeball_patch_boundary() -> void:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	for head in HEADS:
		for level in LEVELS:
			var mi := root.find_child(head + level, true, false) as MeshInstance3D
			if mi == null:
				continue
			var mesh := mi.mesh
			for s in mesh.get_surface_count():
				var m := mesh.surface_get_material(s)
				if m == null or not m.resource_name.begins_with("Face"):
					continue
				var arrays := mesh.surface_get_arrays(s)
				var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
				var idx := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
				for flip: bool in [true]:
					var straddle := 0
					var inside := 0
					for t in idx.size() / 3:
						var n := 0
						for k in 3:
							if _in_patch(_cell(uv[idx[t * 3 + k]]), flip, -SLACK):
								n += 1
						inside += 1 if n == 3 else 0
						straddle += 1 if (n > 0 and n < 3) else 0
					gut.p("%s%s flip=%s inside=%d straddle=%d of %d" % [head, level, flip, inside, straddle, idx.size() / 3])
					assert_eq(straddle, 0, "%s%s" % [head, level])
					if level != "_LOD2":
						assert_gt(inside, 0, head + level + " has eyeball patch triangles")


func test_every_look_keeps_the_occlusion_and_the_metal_channel() -> void:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	var mi := root.find_child("Head_HighCut", true, false) as MeshInstance3D
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var src := mesh.surface_get_material(s) as BaseMaterial3D
		if src == null or not src.resource_name.begins_with("Face"):
			continue
		for look in config.face_offsets.size() + 1:
			var m := models.face_material(0, src, look) as BaseMaterial3D
			assert_true(m.ao_enabled, "look %d ao" % look)
			assert_eq(m.ao_texture, src.ao_texture, "look %d ao texture" % look)
			assert_eq(m.roughness_texture, src.roughness_texture, "look %d orm" % look)
			assert_eq(m.metallic_texture, src.metallic_texture, "look %d metal texture" % look)
			assert_eq(m.metallic_texture_channel, src.metallic_texture_channel)
			assert_eq(m.ao_texture_channel, src.ao_texture_channel)
			assert_eq(m.roughness_texture_channel, src.roughness_texture_channel)
		gut.p("metal tex %s ch %d rough ch %d ao ch %d" % [src.metallic_texture, src.metallic_texture_channel, src.roughness_texture_channel, src.ao_texture_channel])


func test_every_lens_is_alpha_blended() -> void:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	for head in HEADS:
		for level in LEVELS:
			var mi := root.find_child(head + level, true, false) as MeshInstance3D
			if mi == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if m == null or not m.resource_name.begins_with("Lens"):
					continue
				var blended := m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
					or m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				assert_true(blended, head + level + ": blended (the glTF importer's prepass skips alpha under 0.99)")
