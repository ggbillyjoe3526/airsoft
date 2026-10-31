extends GutTest
## Sloping ground (WL1; the browser game's map/terrain.test.ts, the terrain half of nav/navGrid.test.ts, M33c and M33i):
## TerrainGrid's heights on its two triangles a cell, its mesh, slope and range; MapData reading `terrain` and `ground`;
## MapLevel drawing the same triangles and handing Jolt them as a trimesh per ground surface (rays, what is underfoot,
## a body walking the Knoll's steepest face); the nav grid's floors from the ground; and the two new surfaces' sound,
## puffs and ricochets.

const DT := 1.0 / 60.0
## Five seconds of standing still.
const STILL_TICKS := 300
## A height over every floor of the one-storey terrain maps: queries take the cell's only floor.
const ABOVE := 50.0
## Half the sloped yard's width (m): its terrain covers [-15, 15] in x and z.
const YARD_HALF := 15.0

var tuning: SimTuning = SimTuning.new()
var style: MapStyle = MapStyle.new()
var hit: RayHit = RayHit.new()


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A 3 x 2 cell terrain with a different bumpy height at every vertex, so a wrong diagonal shows.
static func _bumpy() -> TerrainGrid:
	var rng := _rng(3)
	return TerrainGrid.create(-3.0, 2.0, 2.0, 3, 2, func(_x: float, _z: float) -> float: return rng.randf() * 4.0 - 1.0)


## The browser's slope yard's ground: rising 0.15 a metre along +x with a rounded hill 1.6 m high at (6, -6).
static func _slope_yard_terrain() -> TerrainGrid:
	return TerrainGrid.create(-YARD_HALF, -YARD_HALF, 1.0, 30, 30, func(x: float, z: float) -> float:
		var r2 := (x - 6.0) * (x - 6.0) + (z + 6.0) * (z + 6.0)
		return 0.15 * x + 1.6 * exp(-r2 / 8.0))


## A plane rising `slope` a metre along +x over [-size / 2, size / 2] squared.
static func _plane(slope: float, cell: float = 1.0, size: float = 2.0 * YARD_HALF) -> TerrainGrid:
	var n := roundi(size / cell)
	return TerrainGrid.create(-size * 0.5, -size * 0.5, cell, n, n, func(x: float, _z: float) -> float: return slope * x)


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## A map of just `t` and `blocks`.
static func _terrain_map(t: TerrainGrid, blocks: Array[MapData.Block] = []) -> MapData:
	var m := MapData.new()
	m.id = "terrain"
	m.terrain = t
	m.blocks = blocks
	return m


## The browser's slope yard: a crate on the slope, a wall across the low end and a low wall on the hill's flank.
static func _slope_yard() -> MapData:
	var blocks: Array[MapData.Block] = [
		_block(&"crate", Vector3(-5.0, -0.75 + 0.6, 3.0), Vector3(1.2, 1.2, 1.2)),
		_block(&"wall", Vector3(-14.8, 0.0, 0.0), Vector3(0.4, 5.0, 12.0)),
		_block(&"wall", Vector3(3.0, 1.2, -6.0), Vector3(0.3, 1.2, 3.0)),
	]
	return _terrain_map(_slope_yard_terrain(), blocks)


## A small map file on sloping ground: `terrain` and `ground` as JSON, three trees round (2, 2), one spawn and dead
## zone an end.
static func _file(terrain: String, ground: String) -> String:
	var tree := "{\"kind\": \"tree\", \"center\": {\"x\": %s, \"y\": 3, \"z\": %s}, \"size\": {\"x\": 0.5, \"y\": 6, \"z\": 0.5}}"
	var trees := ", ".join([tree % [1, 2], tree % [3, 2], tree % [2, 3.5]])
	var spot := "{\"position\": {\"x\": %s, \"y\": 0, \"z\": 0}}"
	return ("{\"name\": \"Slope\", \"blocks\": [%s], \"terrain\": %s, \"ground\": %s, \"spawns\": [[%s], [%s]], "
			+ "\"deadZones\": [[%s], [%s]]}") % [trees, terrain, ground, spot % -4, spot % 4, spot % -4.5, spot % 4.5]


## A flat 10 x 10 m terrain at height 0 with 1 m cells, as JSON.
static func _flat_terrain() -> String:
	var heights := PackedStringArray()
	for k in 121:
		heights.append("0")
	return "{\"minX\": -5, \"minZ\": -5, \"cell\": 1, \"cols\": 10, \"rows\": 10, \"heights\": [%s]}" % ",".join(heights)


## The flat terrain's ground: grass, leaves under the trees round (2, 2), an earth path along z = -3 and a gravel box.
const GROUND := "{\"base\": \"grass\", \"underTrees\": \"leaves\", \"patches\": [{\"surface\": \"earth\", \"path\": " \
		+ "[{\"x\": -5, \"z\": -3}, {\"x\": 5, \"z\": -3}], \"width\": 2}, {\"surface\": \"gravel\", \"box\": [-4, -2, 1, 3]}]}"


func _level(m: MapData) -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, style, tuning.body)
	return level


# --- heights on the triangles ---

func test_reads_each_vertex_height_back_and_builds_heights_row_by_row() -> void:
	var t := TerrainGrid.create(10.0, -4.0, 0.5, 4, 3, func(x: float, z: float) -> float: return 2.0 * x + 3.0 * z)
	assert_eq(t.heights.size(), 5 * 4)
	for j in 4:
		for i in 5:
			var x := 10.0 + i * 0.5
			var z := -4.0 + j * 0.5
			assert_almost_eq(t.height_at(x, z), 2.0 * x + 3.0 * z, 1e-5)
	var b := _bumpy()
	for j in b.rows + 1:
		for i in b.cols + 1:
			assert_almost_eq(b.height_at(b.min_x + i * b.cell, b.min_z + j * b.cell), b.vertex_height(i, j), 1e-6)


func test_interpolates_the_two_triangles_split_along_the_x0_z0_to_x1_z1_diagonal() -> void:
	# One cell with corner heights h00 = 0, h10 = 1, h01 = 2, h11 = 4 (not a plane).
	var t := TerrainGrid.new()
	t.cols = 1
	t.rows = 1
	t.heights = PackedFloat64Array([0.0, 1.0, 2.0, 4.0])
	# Lower triangle (00, 10, 11), where x >= z: 0 + u * 1 + v * (4 - 1).
	assert_almost_eq(t.height_at(0.5, 0.25), 0.5 + 0.25 * 3.0, 1e-6)
	# Upper triangle (00, 01, 11), where z > x: 0 + v * 2 + u * (4 - 2).
	assert_almost_eq(t.height_at(0.25, 0.5), 0.5 * 2.0 + 0.25 * 2.0, 1e-6)
	# On the diagonal both agree: on the way from h00 to h11.
	assert_almost_eq(t.height_at(0.5, 0.5), 2.0, 1e-6)
	assert_almost_eq(t.height_at(0.3, 0.3), 1.2, 1e-6)
	# The other diagonal's midpoint (1.5) is not the centre's height.
	assert_gt(absf(t.height_at(0.5, 0.5) - 1.5), 1e-3)


func test_is_continuous_across_cell_borders() -> void:
	var t := _bumpy()
	var rng := _rng(11)
	for n in 200:
		var z := t.min_z + rng.randf() * t.rows * t.cell
		var x := t.min_x + (1 + rng.randi_range(0, t.cols - 2)) * t.cell
		assert_almost_eq(t.height_at(x - 1e-6, z), t.height_at(x + 1e-6, z), 1e-4)
		var x2 := t.min_x + rng.randf() * t.cols * t.cell
		var z2 := t.min_z + (1 + rng.randi_range(0, t.rows - 2)) * t.cell
		assert_almost_eq(t.height_at(x2, z2 - 1e-6), t.height_at(x2, z2 + 1e-6), 1e-4)


func test_counts_the_outer_edges_as_inside_and_is_nan_beyond_them() -> void:
	var t := _bumpy()
	assert_eq(t.max_x(), 3.0)
	assert_eq(t.max_z(), 6.0)
	assert_almost_eq(t.height_at(t.min_x, t.min_z), t.vertex_height(0, 0), 1e-6)
	assert_almost_eq(t.height_at(t.max_x(), t.max_z()), t.vertex_height(3, 2), 1e-6)
	assert_false(is_nan(t.height_at(t.max_x(), 3.0)))
	assert_false(is_nan(t.height_at(0.0, t.max_z())))
	assert_true(is_nan(t.height_at(t.min_x - 0.001, 3.0)))
	assert_true(is_nan(t.height_at(t.max_x() + 0.001, 3.0)))
	assert_true(is_nan(t.height_at(0.0, t.min_z - 0.001)))
	assert_true(is_nan(t.height_at(0.0, t.max_z() + 0.001)))
	assert_true(is_nan(t.height_at(1e6, -1e6)))


# --- the mesh ---

func test_the_mesh_has_two_triangles_a_cell_all_facing_up() -> void:
	for t: TerrainGrid in [_bumpy(), _slope_yard_terrain(), _plane(0.4, 2.0, 10.0)]:
		var p := t.mesh_positions()
		var idx := t.mesh_indices()
		assert_eq(p.size(), (t.cols + 1) * (t.rows + 1))
		assert_eq(idx.size(), t.cols * t.rows * 6)
		var down := 0
		for k in range(0, idx.size(), 3):
			# Clockwise seen from above (Godot's front face): (c - a) x (b - a) points up.
			if (p[idx[k + 2]] - p[idx[k]]).cross(p[idx[k + 1]] - p[idx[k]]).y <= 0.0:
				down += 1
		assert_eq(down, 0, "every triangle faces up")


func test_a_point_on_the_ground_is_on_the_mesh() -> void:
	for t: TerrainGrid in [_bumpy(), _slope_yard_terrain()]:
		var p := t.mesh_positions()
		var idx := t.mesh_indices()
		var rng := _rng(29)
		for n in 300:
			var x := t.min_x + rng.randf() * t.cols * t.cell
			var z := t.min_z + rng.randf() * t.rows * t.cell
			var found := NAN
			for k in range(0, idx.size(), 3):
				var a := p[idx[k]]
				var b := p[idx[k + 1]]
				var c := p[idx[k + 2]]
				var w := _barycentric(Vector2(x, z), a, b, c)
				if w.x >= -1e-6 and w.y >= -1e-6 and w.z >= -1e-6:
					found = w.x * a.y + w.y * b.y + w.z * c.y
					break
			assert_false(is_nan(found), "(%s, %s) is over a triangle" % [x, z])
			assert_almost_eq(found, t.height_at(x, z), 1e-4, "(%s, %s)" % [x, z])


static func _barycentric(q: Vector2, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var det := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	var l0 := ((b.z - c.z) * (q.x - c.x) + (c.x - b.x) * (q.y - c.z)) / det
	var l1 := ((c.z - a.z) * (q.x - c.x) + (a.x - c.x) * (q.y - c.z)) / det
	return Vector3(l0, l1, 1.0 - l0 - l1)


func test_the_ground_squares_are_the_mesh_s_triangles_cut_smaller() -> void:
	var t := _slope_yard_terrain()
	t._plain_ground(2)
	var faces := t.surface_faces(RayHit.Surface.size())
	assert_eq(faces[RayHit.Surface.EARTH].size(), t.cols * t.rows * 4 * 6, "four squares a cell, two triangles each")
	var rng := _rng(5)
	var tris := faces[RayHit.Surface.EARTH]
	for n in 200:
		var k := rng.randi_range(0, tris.size() / 3 - 1) * 3
		var a := tris[k]
		var b := tris[k + 1]
		var c := tris[k + 2]
		assert_gt((c - a).cross(b - a).y, 0.0, "faces up")
		# Any point inside the small triangle is on the terrain's own.
		var q := a * 0.2 + b * 0.3 + c * 0.5
		assert_almost_eq(q.y, t.height_at(q.x, q.z), 1e-4)


# --- slope and range ---

func test_reads_the_slope_of_a_plane_whichever_way_it_tilts() -> void:
	assert_almost_eq(_plane(0.3).steepest_slope(), 0.3, 1e-5)
	assert_eq(_plane(0.0).steepest_slope(), 0.0)
	var tilted := TerrainGrid.create(0.0, 0.0, 0.5, 6, 6, func(x: float, z: float) -> float: return 0.3 * x + 0.4 * z)
	assert_almost_eq(tilted.steepest_slope(), 0.5, 1e-5)
	assert_almost_eq(_plane(0.25, 2.5, 15.0).steepest_slope(), 0.25, 1e-5)


func test_finds_the_steepest_triangle_not_the_average() -> void:
	var t := TerrainGrid.create(0.0, 0.0, 1.0, 4, 4, func(x: float, z: float) -> float:
		return 1.0 if x == 3.0 and z == 3.0 else 0.0)
	assert_gte(t.steepest_slope(), 1.0)
	assert_gt(_slope_yard_terrain().steepest_slope(), 0.15)


func test_gives_the_lowest_and_highest_vertex_heights() -> void:
	var t := TerrainGrid.create(0.0, 0.0, 1.0, 2, 2, func(x: float, z: float) -> float: return x - 2.0 * z)
	assert_eq(t.height_range(), Vector2(-4.0, 2.0))


# --- MapData ---

func test_a_map_whose_ground_is_terrain_alone_loads_and_one_with_neither_is_refused() -> void:
	var m := MapData.parse(_file(_flat_terrain(), GROUND), style, 1)
	assert_true(m.ok(), str(m.problems))
	assert_not_null(m.terrain)
	assert_eq(m.terrain.cols, 10)
	assert_eq(m.floor_top(0.0, 0.0), 0.0, "the terrain is the floor")
	var bare := MapData.parse(_file(_flat_terrain(), GROUND).replace("\"terrain\":", "\"notTerrain\":"), style, 1)
	assert_true(bare.problems.has("no floor"), str(bare.problems))


func test_malformed_terrain_is_refused_with_its_reason() -> void:
	var short := _flat_terrain().replace("\"heights\": [0,", "\"heights\": [")
	var m := MapData.parse(_file(short, GROUND), style, 1)
	assert_false(m.ok())
	assert_string_contains(" ".join(m.problems), "terrain's heights are not a list of its 121 vertices")
	var no_cell := MapData.parse(_file(_flat_terrain().replace("\"cell\": 1", "\"cell\": 0"), GROUND), style, 1)
	assert_string_contains(" ".join(no_cell.problems), "terrain has no cells")


func test_the_ground_is_its_base_then_leaves_under_the_trees_then_each_patch() -> void:
	var m := MapData.parse(_file(_flat_terrain(), GROUND), style, 1)
	var t := m.terrain
	assert_eq(t.ground_cell, 0.5)
	assert_eq(t.ground_cols, 20)
	assert_eq(t.surface_at(-4.2, 4.2), RayHit.Surface.GRASS, "the base")
	assert_eq(t.surface_at(2.2, 2.6), RayHit.Surface.LEAVES, "three trunks within 4 m overhead")
	assert_eq(t.surface_at(0.2, -3.2), RayHit.Surface.EARTH, "on the path")
	assert_eq(t.surface_at(0.2, -1.6), RayHit.Surface.GRASS, "just off the path's 1 m half width")
	assert_eq(t.surface_at(-3.0, 2.0), RayHit.Surface.GRAVEL, "the box, over the leaves")
	assert_eq(t.surface_at(99.0, 99.0), t.surface_at(4.9, 4.9), "past the edge, the edge's")


func test_an_unknown_ground_surface_is_left_out_with_a_warning() -> void:
	var m := MapData.parse(_file(_flat_terrain(), GROUND.replace("\"base\": \"grass\"", "\"base\": \"lava\"")), style,
			1)
	assert_true(m.ok())
	assert_string_contains(" ".join(m.warnings), "ground's base lava")
	assert_eq(m.terrain.surface_at(-4.2, 4.2), RayHit.Surface.EARTH, "left as earth")


# --- MapLevel: the mesh, rays, what is underfoot ---

func test_the_level_draws_the_ground_squares_in_their_surfaces_colours_in_its_tiles() -> void:
	var m := MapData.parse(_file(_flat_terrain(), GROUND), style, 1)
	var level := _level(m)
	var greybox := (level.get_node("Greybox") as MeshInstance3D).mesh as ArrayMesh
	assert_eq(greybox.get_surface_count(), 1, "the blocks: one draw call")
	var tiles := level.ground_tiles()
	assert_eq(tiles.size(), 1, "a 10 m slope is one tile")
	var seen: Dictionary[int, bool] = {}
	var wrong := 0
	var squares := 0
	for tile in tiles:
		assert_eq(tile.material_override, level.get_node("Greybox").material_override, "the greybox's material")
		var arrays := (tile.mesh as ArrayMesh).surface_get_arrays(0)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for v in range(0, positions.size(), 4):
			var corner := positions[v]
			var s := m.terrain.surface_at(corner.x + 0.25, corner.z + 0.25)
			var want := style.terrain_colour(s)
			var got := colours[v]
			# A mesh keeps its colours in bytes.
			if maxf(maxf(absf(got.r - want.r), absf(got.g - want.g)), absf(got.b - want.b)) > 1.0 / 255.0:
				wrong += 1
			seen[s] = true
			squares += 1
	assert_eq(squares, m.terrain.ground_cols * m.terrain.ground_rows, "every square drawn once")
	assert_eq(wrong, 0, "every square in its surface's colour")
	assert_eq(seen.size(), 4, "grass, leaves, earth and gravel drawn")


func test_woodland_s_ground_is_tiles_that_cull_drawing_the_very_squares_of_the_whole() -> void:
	var m := MapData.load_map("woodland", style, 1)
	var level := _level(m)
	var tiles := level.ground_tiles()
	assert_eq(tiles.size(), 24, "176 x 120 m in tiles of 32 m: 6 x 4")
	# the whole ground as one mesh, as it was drawn before WL4
	var whole := []
	whole.resize(Mesh.ARRAY_MAX)
	whole[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	whole[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	whole[Mesh.ARRAY_COLOR] = PackedColorArray()
	whole[Mesh.ARRAY_INDEX] = PackedInt32Array()
	GreyboxFaces.add_terrain(whole, m.terrain, style)
	# read back through a mesh, as the tiles are (it keeps colours in bytes and packs normals)
	var whole_mesh := ArrayMesh.new()
	whole_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, whole)
	whole = whole_mesh.surface_get_arrays(0)
	var wp: PackedVector3Array = whole[Mesh.ARRAY_VERTEX]
	var wn: PackedVector3Array = whole[Mesh.ARRAY_NORMAL]
	var wc: PackedColorArray = whole[Mesh.ARRAY_COLOR]
	var wi: PackedInt32Array = whole[Mesh.ARRAY_INDEX]
	var gc := m.terrain.ground_cell
	var drawn := PackedByteArray()
	drawn.resize(m.terrain.ground_cols * m.terrain.ground_rows)
	var differ := 0
	var triangles := 0
	for tile in tiles:
		var box := tile.get_aabb()
		assert_lte(maxf(box.size.x, box.size.z), MapLevel.TERRAIN_TILE + 0.001, "%s is at most a tile" % tile.name)
		assert_eq(tile.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "it casts as the ground did")
		var a := (tile.mesh as ArrayMesh).surface_get_arrays(0)
		var p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		triangles += idx.size() / 3
		for v in range(0, p.size(), 4):
			var q := roundi((p[v].z - m.terrain.min_z) / gc) * m.terrain.ground_cols + roundi((p[v].x - m.terrain.min_x) / gc)
			drawn[q] += 1
			var u := q * 4
			for k in 4:
				if p[v + k] != wp[u + k] or n[v + k] != wn[u + k] or c[v + k] != wc[u + k]:
					differ += 1
			# the same two triangles, split the same way
			var t0 := (v / 4) * 6
			for k in 6:
				if idx[t0 + k] - v != wi[q * 6 + k] - u:
					differ += 1
	assert_eq(differ, 0, "each square's corners, normals, colours and split as the whole ground's")
	assert_eq(triangles, wi.size() / 3, "no square more or less")
	assert_eq(Array(drawn).count(1), drawn.size(), "every square in exactly one tile")


func test_rays_and_feet_meet_each_ground_surface() -> void:
	var m := MapData.parse(_file(_flat_terrain(), GROUND), style, 1)
	var q := _level(m).query()
	var spots: Dictionary[int, Vector2] = {
		RayHit.Surface.GRASS: Vector2(-4.2, 4.2), RayHit.Surface.LEAVES: Vector2(2.2, 2.6),
		RayHit.Surface.EARTH: Vector2(0.2, -3.2), RayHit.Surface.GRAVEL: Vector2(-3.0, 2.0),
	}
	for s: int in spots:
		var at := spots[s]
		assert_true(q.ray(Vector3(at.x, 2.0, at.y), Vector3(at.x, -2.0, at.y), hit), "a ray meets the ground")
		assert_eq(hit.surface, s, str(at))
		assert_almost_eq(hit.position.y, 0.0, 1e-3)
		assert_eq(q.surface_under(Vector3(at.x, tuning.body.rest_gap, at.y)), s, "underfoot at %s" % at)


func test_a_ray_straight_down_meets_woodland_s_ground_within_a_centimetre_at_1000_points() -> void:
	var m := MapData.load_map("woodland", style, 1)
	assert_true(m.ok(), str(m.problems))
	m.blocks.clear()
	var q := _level(m).query()
	var t := m.terrain
	var rng := _rng(1000)
	var worst := 0.0
	var missed := 0
	for n in 1000:
		var x := rng.randf_range(t.min_x, t.max_x())
		var z := rng.randf_range(t.min_z, t.max_z())
		if not q.ray(Vector3(x, 20.0, z), Vector3(x, -20.0, z), hit):
			missed += 1
			continue
		worst = maxf(worst, absf(hit.position.y - t.height_at(x, z)))
		assert_eq(hit.surface, t.surface_at(x, z) as RayHit.Surface, "(%s, %s)'s surface" % [x, z])
	assert_eq(missed, 0)
	assert_lt(worst, 0.01, "worst %s m" % worst)
	gut.p("worst of 1000 rays down: %.5f m" % worst)


## The steepest triangle in the Knoll's area, its cell's middle on the ground, and the way down it (x, z).
static func _knoll_face(m: MapData) -> Array[Vector3]:
	var t := m.terrain
	var knoll: MapAreas.Area = null
	for a in m.areas:
		if a.name == "Knoll":
			knoll = a
	var worst := -1.0
	var at := Vector3.ZERO
	for j in t.rows:
		for i in t.cols:
			var x := t.min_x + (i + 0.5) * t.cell
			var z := t.min_z + (j + 0.5) * t.cell
			if x < knoll.x0 + 3.0 or x > knoll.x1 - 3.0 or z < knoll.z0 + 3.0 or z > knoll.z1 - 3.0:
				continue
			var h00 := t.vertex_height(i, j)
			var h10 := t.vertex_height(i + 1, j)
			var h01 := t.vertex_height(i, j + 1)
			var h11 := t.vertex_height(i + 1, j + 1)
			var s := maxf(Vector2(h10 - h00, h11 - h10).length(), Vector2(h11 - h01, h01 - h00).length())
			if s > worst:
				worst = s
				at = Vector3(x, t.height_at(x, z), z)
	var e := 0.5
	var down := Vector3(t.height_at(at.x - e, at.z) - t.height_at(at.x + e, at.z), 0.0,
			t.height_at(at.x, at.z - e) - t.height_at(at.x, at.z + e)).normalized()
	return [at, down, Vector3(worst / t.cell, 0.0, 0.0)]


## Runs `ticks` of movement for `c` under `cmd` on `level`; the most the feet were ever off the ground at the body's
## middle (m). A flat-bottomed body rests on its uphill rim, so on a slope its middle stands radius x slope clear.
func _walk(level: MapLevel, t: TerrainGrid, c: Character, cmd: PlayerCommand, ticks: int) -> float:
	var mover := level.mover(tuning.body)
	var worst := 0.0
	for i in ticks:
		Movement.step(c, cmd, tuning.movement, tuning.accuracy, DT, mover)
		worst = maxf(worst, absf(c.position.y - tuning.body.rest_gap - t.height_at(c.position.x, c.position.z)))
	return worst


static func _yaw_to(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func test_a_body_walks_up_down_and_across_the_knoll_s_steepest_face_and_stands_still_on_it() -> void:
	var m := OldWoodland.load_map(style, 1) # the first Woodland's Knoll
	var face := _knoll_face(m)
	m.blocks.clear()
	var level := _level(m)
	var t := m.terrain
	var at := face[0]
	var down := face[1]
	gut.p("Knoll's steepest face: slope %.3f at %s, down %s" % [face[2].x, at, down])
	assert_gt(face[2].x, 0.4, "a real slope")
	# Feet stay on the ground: within the rim's lift on a 1:2 slope and a centimetre.
	var lift := tuning.body.radius * FieldStandard.MAX_RAMP_SLOPE + 0.01
	var start := at + down * 4.0
	var c := Character.new(0, 0, Vector3(start.x, t.height_at(start.x, start.z) + tuning.body.rest_gap, start.z), 0.0,
			ReplicaStats.default_loadout())
	var cmd := PlayerCommand.new()
	cmd.forward = 1.0
	# Up 8 m: about two seconds at a run.
	cmd.yaw = _yaw_to(-down)
	var off := _walk(level, t, c, cmd, 120)
	var climbed := (c.position - start).dot(-down)
	assert_gt(climbed, 6.0, "walked up the face (%.2f m)" % climbed)
	assert_lt(off, lift, "feet on the ground all the way up")
	assert_true(c.grounded)
	# Back down.
	var top := c.position
	cmd.yaw = _yaw_to(down)
	off = _walk(level, t, c, cmd, 120)
	assert_gt((c.position - top).dot(down), 6.0, "walked down the face")
	assert_lt(off, lift, "kept to the ground walking down")
	assert_true(c.grounded)
	# Across, from the middle of the face, set down still: along the slope, not down it.
	c.position = Vector3(at.x, at.y + tuning.body.rest_gap, at.z)
	c.velocity = Vector3.ZERO
	cmd.forward = 0.0
	_walk(level, t, c, cmd, 1)
	var set_down := c.position
	var across := Vector3(-down.z, 0.0, down.x)
	cmd.forward = 1.0
	cmd.yaw = _yaw_to(across)
	off = _walk(level, t, c, cmd, 60)
	var gone := (c.position - set_down).dot(across)
	var slid := (c.position - set_down).dot(down)
	gut.p("across the face: %.3f m, %.4f m down it" % [gone, slid])
	assert_gt(gone, 3.0, "walked across the face")
	assert_lt(absf(slid), 0.01, "kept across the face, not down it")
	assert_lt(off, lift)
	# Still, standing and crouched, from where it stopped and from being set down.
	cmd.forward = 0.0
	for crouch: bool in [false, true]:
		cmd.crouch = crouch
		_walk(level, t, c, cmd, 60)
		var rest := c.position
		_walk(level, t, c, cmd, STILL_TICKS)
		assert_lt(c.position.distance_to(rest), 0.01, "stands still on the face for 5 s (crouched %s)" % crouch)
		assert_true(c.grounded)
	# A body spawned on the face, its rim in the slope: Jolt pops it out downhill once, and it stays there.
	var spawned := Character.new(1, 0, Vector3(at.x, at.y + tuning.body.rest_gap, at.z), 0.0,
			ReplicaStats.default_loadout())
	_walk(level, t, spawned, cmd, 1)
	assert_eq(Vector2(spawned.velocity.x, spawned.velocity.z), Vector2.ZERO, "popped out with no speed")
	var rest := spawned.position
	_walk(level, t, spawned, cmd, STILL_TICKS)
	assert_lt(spawned.position.distance_to(rest), 0.01, "spawned on the face, it stays")


# --- the nav grid ---

func test_the_nav_grid_takes_its_bounds_and_floors_from_the_terrain() -> void:
	var m := _slope_yard()
	var g := NavGrid.build(m, tuning.nav, tuning.body)
	assert_eq(g.min_x, -YARD_HALF)
	assert_eq(g.min_z, -YARD_HALF)
	assert_gte(g.min_x + g.cols * g.cell, YARD_HALF)
	var rng := _rng(2)
	var checked := 0
	for n in 400:
		var x := -14.0 + rng.randf() * 28.0
		var z := -14.0 + rng.randf() * 28.0
		var c := g.cell_index(x, z)
		var cx := g.cell_x(c % g.cols)
		@warning_ignore("integer_division")
		var cz := g.cell_z(c / g.cols)
		var near := false
		for b in m.blocks:
			near = near or (absf(cx - b.center.x) < b.size.x * 0.5 + 0.5 and absf(cz - b.center.z) < b.size.z * 0.5 + 0.5)
		if near:
			continue
		assert_almost_eq(g.floor_at(Vector3(x, ABOVE, z)), m.terrain.height_at(cx, cz), 1e-4)
		checked += 1
	assert_gt(checked, 300)
	assert_almost_eq(g.floor_at(Vector3(4, ABOVE, 10)) - g.floor_at(Vector3(-4, ABOVE, 10)), 1.2, 0.05)


func test_blocks_stand_in_the_way_on_the_slope_and_beyond_the_terrain_is_nowhere() -> void:
	var g := NavGrid.build(_slope_yard(), tuning.nav, tuning.body)
	assert_false(g.is_walkable_at(Vector3(-5, ABOVE, 3)), "the crate")
	assert_true(g.is_walkable_at(Vector3(-5, ABOVE, 5)))
	assert_false(g.is_walkable_at(Vector3(-14.5, ABOVE, 0)), "against the end wall")
	assert_true(g.is_walkable_at(Vector3(0, ABOVE, 10)))
	assert_false(g.is_walkable_at(Vector3(16, ABOVE, 0)))
	assert_true(is_nan(g.floor_at(Vector3(16, ABOVE, 0))))


func test_a_floor_block_over_the_ground_is_a_floor_and_one_sunk_under_it_is_not() -> void:
	var blocks: Array[MapData.Block] = [
		_block(&"floor", Vector3(3, 0.5, 5), Vector3(2, 1, 4)),
		_block(&"floor", Vector3(-5, -3.25, -5), Vector3(4, 0.5, 4)),
	]
	var g := NavGrid.build(_terrain_map(_plane(0.1), blocks), tuning.nav, tuning.body)
	assert_almost_eq(g.floor_at(Vector3(3, ABOVE, 5)), 1.0, 1e-4)
	assert_almost_eq(g.floor_at(Vector3(0, ABOVE, 5)), 0.0, 0.05)
	assert_almost_eq(g.floor_at(Vector3(-5, ABOVE, -5)), -0.5, 0.05)
	assert_true(g.is_walkable_at(Vector3(-5, ABOVE, -5)))


func test_routes_run_up_and_down_a_slope_as_steep_as_a_ramp_on_the_ground() -> void:
	assert_gte(tuning.body.max_step, FieldStandard.MAX_RAMP_SLOPE * tuning.nav.cell * sqrt(2.0) - 1e-3,
			"a diagonal nav step up a 1:2 slope is a step")
	var route := PackedVector3Array()
	for slope: float in [FieldStandard.MAX_RAMP_SLOPE * 0.6, FieldStandard.MAX_RAMP_SLOPE]:
		var t := _plane(slope)
		var g := NavGrid.build(_terrain_map(t), tuning.nav, tuning.body)
		for pair: Array in [[Vector3(-10, slope * -10, 2), Vector3(10, slope * 10, -3)],
				[Vector3(11, slope * 11, 6), Vector3(-11, slope * -11, 6)]]:
			var from: Vector3 = pair[0]
			var to: Vector3 = pair[1]
			assert_true(g.find_route(from, to, route), "slope %s" % slope)
			var p := from
			for leg in route:
				assert_true(g.clear_line(p, leg), "leg %s -> %s walkable" % [p, leg])
				assert_lte(absf(g.floor_at(Vector3(leg.x, ABOVE, leg.z)) - t.height_at(leg.x, leg.z)),
						slope * tuning.nav.cell)
				p = leg
			assert_lt(Vector2(p.x - to.x, p.z - to.z).length(), tuning.nav.cell)


func test_no_route_climbs_a_cliff_but_each_side_stays_connected() -> void:
	var cliff := TerrainGrid.create(-15.0, -15.0, 1.0, 30, 30, func(x: float, _z: float) -> float:
		return 1.0 if x >= 0.0 else 0.0)
	assert_gt(cliff.steepest_slope(), FieldStandard.MAX_RAMP_SLOPE)
	var g := NavGrid.build(_terrain_map(cliff), tuning.nav, tuning.body)
	var route := PackedVector3Array()
	assert_false(g.find_route(Vector3(-10, 0, 0), Vector3(10, 1, 0), route))
	assert_true(g.find_route(Vector3(-10, 0, 0), Vector3(-4, 0, 6), route))
	assert_true(g.find_route(Vector3(4, 1, -6), Vector3(10, 1, 0), route))


func test_a_platform_no_step_reaches_is_its_own_region_and_a_route_to_it_is_refused_at_once() -> void:
	var blocks: Array[MapData.Block] = [_block(&"floor", Vector3(5, 2.5, 5), Vector3(4, 1, 4))]
	var g := NavGrid.build(_terrain_map(_plane(0.0), blocks), tuning.nav, tuning.body)
	var ground := g.node_at(Vector3(-5, 0.5, -5))
	var top := g.node_at(Vector3(5, ABOVE, 5))
	assert_eq(g.walkable[top], 1, "the platform's middle is walkable")
	assert_false(g.linked(ground, top), "no step up 3 m")
	assert_false(g.linked(ground, top, true), "no vault either")
	assert_true(g.linked(ground, g.node_at(Vector3(10, 0.5, -10))), "the ground is one region")
	var route := PackedVector3Array([Vector3.ONE])
	var t0 := Time.get_ticks_usec()
	assert_false(g.find_route(Vector3(-5, 0, -5), Vector3(5, 3, 5), route))
	gut.p("refused in %d us" % (Time.get_ticks_usec() - t0))
	assert_true(route.is_empty())
	assert_eq(g.region[g.node_at(Vector3(5, ABOVE, 5))], g.region[g.node_at(Vector3(6, ABOVE, 6))])
	# Every walkable node has a region no higher than itself; every blocked one has none.
	for k in g.node_count():
		assert_true(g.region[k] <= k and (g.region[k] >= 0) == (g.walkable[k] == 1), "node %d" % k)
		if g.region[k] > k or (g.region[k] >= 0) != (g.walkable[k] == 1):
			break


func test_a_terrain_whose_cols_or_rows_are_not_whole_is_refused() -> void:
	for key: String in ["cols", "rows"]:
		var problems: Array[String] = []
		var raw := {"minX": 0, "minZ": 0, "cell": 1, "cols": 2, "rows": 2, "heights": [0, 0, 0, 0, 0, 0, 0, 0, 0]}
		raw[key] = 2.5
		assert_null(TerrainGrid.read(raw, problems))
		assert_eq(problems, ["terrain's %s is not a whole number" % key] as Array[String])


# --- the new surfaces and timber ---

func test_grass_and_leaves_are_appended_and_sound_puff_and_stop_bbs_as_earth() -> void:
	assert_eq(RayHit.Surface.GRASS, 6)
	assert_eq(RayHit.Surface.LEAVES, 7)
	var play := PlayTuning.load_default()
	for s: int in [RayHit.Surface.GRASS, RayHit.Surface.LEAVES]:
		var name: String = String(RayHit.Surface.find_key(s)).to_lower()
		assert_eq(SimAudio.SURFACE_NAMES[s], name, "a step on it plays step_%s_*" % name)
		assert_true(ResourceLoader.exists("%sstep_%s_run_1.wav" % [SoundConfig.CUE_DIR, name]), name)
		assert_eq(SimAudio.IMPACT_NAMES[s], "earth", "a BB on it sounds as earth")
		assert_eq(play.effects.puff_colours[s], play.effects.puff_colours[RayHit.Surface.EARTH], "puffs as earth")
		assert_eq(RicochetConfig.new().restitution(s as RayHit.Surface), 0.0, "no ricochet")
		assert_eq(MapData.SURFACES[name], s, "a map file names it")


func test_trees_logs_and_fences_are_dull_wood() -> void:
	for kind: StringName in [&"tree", &"log", &"fence"]:
		assert_eq(style.surface_of(kind), RayHit.Surface.WOOD, kind)
		var c: Color = style.colours[kind]
		assert_lt(FieldChecks.hue_saturation(c).y, 0.3, "%s's saturation on linear RGB" % kind)


func test_no_ground_colour_reads_as_a_team() -> void:
	var teams := AccessibilityTable.read_file().colours
	for s: int in style.terrain_colours:
		assert_false(FieldChecks.reads_as_team(style.terrain_colour(s), teams), str(RayHit.Surface.find_key(s)))


func test_a_diagonal_line_up_smooth_ground_steeper_than_0_53_walks_but_one_across_a_kerb_s_corner_is_a_drop() -> void:
	# Ground rising 0.4 a metre along both x and z: a straight step climbs 0.08 m a 0.2 m cell and a diagonal one 0.16,
	# over max_step (0.15) but a straight step at a time (WR1: a Woodland bot stalled on such a bank, its line judged a
	# drop).
	var t := TerrainGrid.create(-10.0, -10.0, 1.0, 20, 20, func(x: float, z: float) -> float: return 0.4 * (x + z))
	var nav := NavGrid.build(_terrain_map(t), tuning.nav, tuning.body)
	var from := Vector3(-3.0, t.height_at(-3.0, -3.0), -3.0)
	var to := Vector3(3.0, t.height_at(3.0, 3.0), 3.0)
	assert_false(nav.drop_on_line(from, to), "no drop up the slope's fall line")
	assert_true(nav.clear_line(from, to), "a clear line")
	var route := PackedVector3Array()
	assert_true(nav.find_route(from, to, route))
	assert_eq(route.size(), 1, "one straight leg: %s" % route)
	# A 0.2 m kerb (a floor block) on flat ground: crossing its corner diagonally is as much a step up as crossing its side.
	var flat := TerrainGrid.create(-10.0, -10.0, 1.0, 20, 20, func(_x: float, _z: float) -> float: return 0.0)
	var kerb: Array[MapData.Block] = [_block(&"floor", Vector3(3.0, 0.1, 3.0), Vector3(6.0, 0.2, 6.0))]
	var kerbed := NavGrid.build(_terrain_map(flat, kerb), tuning.nav, tuning.body)
	assert_true(kerbed.drop_on_line(Vector3(-2.0, 0.0, -2.0), Vector3(2.0, 0.2, 2.0)), "over a kerb's corner")
