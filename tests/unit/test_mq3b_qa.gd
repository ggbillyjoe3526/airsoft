extends GutTest
## MQ3B QA: what the surfaces-only pass must not disturb. The arm band's new colour map must stay near white and
## neutral on every detail level and for both teams, no head's UVs may wander off their tiles at any level, the
## heads' triangles stay as on main, and tools/blender/figures/body_surfaces.py refuses a file it has painted.

const MAP := 2048
const HEADS: Array[String] = ["Head_HighCut", "Head_FullCut", "Head_Cap", "Head_Boonie"]
const LEVELS: Array[String] = ["", "_LOD1", "_LOD2"]
## The Headwear surface's triangles on main (and now: no mesh changed), by mesh.
const HEADWEAR_TRIANGLES := {
	"Head_HighCut": 7714, "Head_HighCut_LOD1": 2544, "Head_HighCut_LOD2": 810,
	"Head_FullCut": 7290, "Head_FullCut_LOD1": 2342, "Head_FullCut_LOD2": 726,
	"Head_Cap": 7578, "Head_Cap_LOD1": 2512, "Head_Cap_LOD2": 808,
	"Head_Boonie": 7276, "Head_Boonie_LOD1": 2412, "Head_Boonie_LOD2": 780,
}
## The strip and block tiles (px from the atlas's left and bottom), as in head_textures.py.
## The boonie crown tile in image pixels (x from the left, y from the top).
const CROWN_TILE := Rect2(1024, 1024, 512, 256)
const TILES: Array[Rect2] = [
	Rect2(0, 64, 512, 64), Rect2(0, 128, 512, 64), Rect2(0, 192, 256, 64), Rect2(256, 192, 256, 64),
	Rect2(1024, 384, 512, 64), Rect2(1024, 448, 512, 64),
]
## The arm band under the team colour: no sampled pixel is darker than this, the mean at least the other.
const BAND_FLOOR := 0.3
const BAND_MEAN := 0.8
## What Python prints when the build tools' numpy or Pillow are not installed (CI's test runner has neither).
const NO_MODULE := "No module named"
const TEAM_COLOURS: Array[Color] = [Color(0.23, 0.53, 0.96), Color(0.96, 0.55, 0.15)]

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
	assert_not_null(mi, part)
	return mi.mesh if mi != null else null


static func _surface(mesh: Mesh, material: String) -> int:
	for i in mesh.get_surface_count():
		var own := mesh.surface_get_material(i)
		if own != null and own.resource_name.begins_with(material):
			return i
	return -1


static func _tile_of(px: Vector2) -> int:
	for i in TILES.size():
		var r := TILES[i]
		var y := MAP - px.y
		if px.x >= r.position.x and px.x <= r.end.x and y >= r.position.y and y <= r.end.y:
			return i
	return -1


func test_every_level_of_the_body_draws_the_arm_band_near_white_from_the_colour_map() -> void:
	var root := _human()
	for level in LEVELS:
		var mesh := _mesh(root, "Body" + level)
		var team := _surface(mesh, "TeamCloth")
		assert_gte(team, 0, "Body%s has a TeamCloth surface" % level)
		if team < 0:
			continue
		var m := mesh.surface_get_material(team) as BaseMaterial3D
		assert_not_null(m.albedo_texture, "Body%s band's colour map" % level)
		assert_eq(m.albedo_color, Color.WHITE, "Body%s band's albedo is white under the team paint" % level)
		var image := m.albedo_texture.get_image()
		if image.is_compressed():
			image.decompress()
		var arrays := mesh.surface_get_arrays(team)
		var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var sum := 0.0
		var least := 1.0
		var n := 0
		for i in range(0, index.size(), 3):
			var at := (uv[index[i]] + uv[index[i + 1]] + uv[index[i + 2]]) / 3.0
			var c := image.get_pixel(clampi(int(at.x * MAP), 0, MAP - 1), clampi(int(at.y * MAP), 0, MAP - 1))
			var grey := (c.r + c.g + c.b) / 3.0
			assert_almost_eq(c.r, c.b, 0.12, "Body%s band pixel is neutral" % level)
			sum += grey
			least = minf(least, grey)
			n += 1
		assert_gt(n, 100, "Body%s band triangles" % level)
		assert_gt(sum / maxf(float(n), 1.0), BAND_MEAN, "Body%s band mean under its triangles" % level)
		assert_gt(least, BAND_FLOOR, "Body%s: no band triangle samples camouflage or empty atlas" % level)


func test_both_teams_bands_keep_the_map_and_stay_opaque() -> void:
	var team_surface := _mesh(_human(), "Body")
	var source := team_surface.surface_get_material(_surface(team_surface, "TeamCloth")) as BaseMaterial3D
	assert_eq(source.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "the band is opaque (the fade path sets alpha itself)")
	for team in TEAM_COLOURS.size():
		var made := models.team_material(0, source, team, TEAM_COLOURS[team], 0.0) as BaseMaterial3D
		assert_eq(made.albedo_texture, source.albedo_texture, "team %d keeps the colour map" % team)
		assert_eq(made.albedo_color.to_html(false), TEAM_COLOURS[team].to_html(false), "team %d colour" % team)
		assert_ne(made, source, "a copy, so the source stays white")
	assert_eq(source.albedo_color, Color.WHITE, "the shared source is untouched")
	var glowing := models.team_material(0, source, 0, TEAM_COLOURS[0], 0.6) as BaseMaterial3D
	assert_eq(glowing.albedo_texture, source.albedo_texture, "the glow twin keeps the map")
	assert_true(glowing.emission_enabled)


func test_no_head_triangle_leaves_the_atlas_or_straddles_two_tiles_at_any_level() -> void:
	var root := _human()
	for head in HEADS:
		for level in LEVELS:
			var name := head + level
			var mesh := _mesh(root, name)
			var at := _surface(mesh, "Headwear")
			assert_gte(at, 0, name)
			if at < 0:
				continue
			var arrays := mesh.surface_get_arrays(at)
			var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			assert_eq(index.size() / 3, HEADWEAR_TRIANGLES[name], "%s keeps main's triangles" % name)
			var outside := 0
			var straddle := 0
			for i in range(0, index.size(), 3):
				var tiles := {}
				for k in 3:
					var p := uv[index[i + k]]
					if p.x < -0.0001 or p.x > 1.0001 or p.y < -0.0001 or p.y > 1.0001:
						outside += 1
					tiles[_tile_of(p * MAP)] = true
				if tiles.size() > 1:
					straddle += 1
			assert_eq(outside, 0, "%s: corners outside 0..1" % name)
			assert_eq(straddle, 0, "%s: triangles with corners in different tiles or half in one" % name)


func test_the_face_surfaces_keep_their_uvs_inside_the_face_cells() -> void:
	var root := _human()
	for head in HEADS:
		var mesh := _mesh(root, head)
		for i in mesh.get_surface_count():
			var own := mesh.surface_get_material(i)
			if own == null or not own.resource_name.begins_with("Face"):
				continue
			var uv := mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			for p in uv:
				assert_true(p.x >= 0.0 and p.x <= 1.0 and p.y >= 0.0 and p.y <= 1.0, "%s face uv in range" % head)


func test_body_surfaces_refuses_a_file_it_has_painted_and_leaves_it_alone() -> void:
	var copy := "user://mq3b_qa_human.glb"
	var source := ProjectSettings.globalize_path("res://assets/models/characters/human.glb")
	var script := ProjectSettings.globalize_path("res://tools/blender/figures/body_surfaces.py")
	var before := FileAccess.get_md5("res://assets/models/characters/human.glb")
	assert_eq(DirAccess.copy_absolute(source, ProjectSettings.globalize_path(copy)), OK)
	var output: Array = []
	var code := OS.execute("python3", ["-I", script, ProjectSettings.globalize_path(copy)], output, true)
	if code == -1 or str(output).contains(NO_MODULE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))
		pending("python3 with numpy and Pillow is not available here")
		return
	assert_ne(code, 0, "a second run stops")
	assert_true(str(output).contains("painted already"), "and says why")
	assert_eq(FileAccess.get_md5(copy), before, "the file is untouched")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))


func test_the_boonie_crown_climbs_its_tile_ring_by_ring_as_the_cloth_rises() -> void:
	var root := _human()
	for level in LEVELS:
		var mesh := _mesh(root, "Head_Boonie" + level)
		var at := _surface(mesh, "Headwear")
		var arrays := mesh.surface_get_arrays(at)
		var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var vertex := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var heights := {}
		for i in uv.size():
			var px := uv[i] * float(MAP)
			if px.x < CROWN_TILE.position.x or px.x > CROWN_TILE.end.x or px.y < CROWN_TILE.position.y or px.y > CROWN_TILE.end.y:
				continue
			var t := snappedf((CROWN_TILE.end.y - px.y) / CROWN_TILE.size.y, 0.0005)
			if not heights.has(t):
				heights[t] = []
			(heights[t] as Array).append(vertex[i].y)
		var rows: Array = heights.keys()
		rows.sort()
		assert_gte(rows.size(), 6, "Body%s: the crown's rings" % level)
		var last := -INF
		for t: float in rows:
			var mean := 0.0
			for y: float in heights[t]:
				mean += y
			mean /= float((heights[t] as Array).size())
			assert_gte(mean, last - 0.0005, "%s: t %.3f sits no lower than the ring below" % [level, t])
			last = mean
		assert_gt(rows[rows.size() - 1], 0.95, "%s: the top fan reaches the tile's top" % level)
