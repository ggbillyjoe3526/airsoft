extends GutTest
## DH1 (Dev 3, Depot's hall shell, tools/blender/maps/): the hall's 8 m walls are drawn as bays whose columns stand
## under the roof's trusses, a roller shutter or a fire exit in some bays (two at most a wall, never side by side,
## only where nothing stands in front, each kind at least once), every bay facing the field; the Range's lower walls
## keep their boxes; the roof draws one truss bay a truss line and cell, all of it up under the
## roof, and its lamps' lenses glow; the floor draws its own slab set on the clean look, at the brightness its file
## has; every model keeps to its triangle budget.

const BUDGETS := {
	&"hall_wall": 2000, &"hall_shutter": 4000, &"hall_exit": 4000, &"pillar": 1200, &"camo_net": 1500,
}
const ROOF_BUDGETS := {
	"res://assets/models/props/roof_truss.glb": 4000, "res://assets/models/props/roof_lamp.glb": 400,
}
const HALL_WALL := 6.0
const FEATURES: Array[StringName] = [&"hall_shutter", &"hall_exit"]

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var cfg: PropDressConfig = null
var depot: MapData = null


func before_all() -> void:
	cfg = play.site_look.props
	depot = MapData.load_map("depot", play.map_style, tuning.rounds.team_size)


func _walls(m: MapData) -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	for b in m.blocks:
		if b.kind == &"wall" and b.rise == MapData.Rise.NONE and b.size.y >= HALL_WALL:
			out.append(b)
	return out


func _box(b: MapData.Block, grow: float) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size).grow(grow)


func _dress(m: MapData) -> PropDress:
	var dress := PropDress.build(m, cfg)
	if dress != null:
		add_child_autofree(dress)
	return dress


## The hall wall whose box holds `at`, or null.
func _wall_at(at: Vector3) -> MapData.Block:
	for b in _walls(depot):
		if _box(b, 1e-3).has_point(at + Vector3(0.0, 0.01, 0.0)):
			return b
	return null


func _triangles(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		n += (index.size() if not index.is_empty() else verts.size()) / 3
	return n


func test_every_hall_wall_is_drawn_as_bays_with_its_columns_under_the_trusses() -> void:
	assert_true(depot.ok(), "Depot loads: %s" % [depot.problems])
	var walls := _walls(depot)
	assert_gt(walls.size(), 3, "the hall has its walls")
	var area := depot.footprint().grow(play.roof.ceiling_overhang)
	var trusses := RoofView.truss_lines(area, play.roof.truss_step)
	var pitch: float = cfg.bay_pitch[&"hall_wall"]
	assert_eq(pitch, play.roof.truss_step, "a bay a truss step")
	for b in walls:
		assert_true(cfg.dresses(b), "the wall at %s is bays" % b.center)
		assert_eq(cfg.lay_of(b), PropDressConfig.Lay.BAY)
		var edges := PropLayout.bay_cells(b, pitch, cfg.bay_anchor[&"hall_wall"])
		assert_gt(edges.size(), 1)
		for i in edges.size() - 1:
			assert_gt(edges[i + 1] - edges[i], pitch * 0.5 - 1e-3, "no sliver of a bay")
			assert_lt(edges[i + 1] - edges[i], pitch * 1.5 + 1e-3)
		if b.size.x < b.size.z:
			continue
		for i in range(1, edges.size() - 1):
			assert_true(Array(trusses).any(func(x: float) -> bool: return absf(x - edges[i]) < 1e-3),
					"a column at x %.2f stands under a truss" % edges[i])


func test_the_ranges_lower_walls_keep_their_boxes() -> void:
	for id: String in ["range"]:
		var m := MapData.load_map(id, play.map_style, 1)
		assert_true(m.ok(), "%s loads" % id)
		for b in m.blocks:
			if b.kind == &"wall" and b.size.y < HALL_WALL:
				assert_false(cfg.dresses(b), "%s's wall at %s keeps its box" % [id, b.center])


func test_the_feature_bays_are_few_apart_open_and_each_kind_is_there() -> void:
	var placed := _dress(depot).placed()
	var pitch: float = cfg.bay_pitch[&"hall_wall"]
	var on_wall: Dictionary[Vector3, Array] = {}
	for kind in FEATURES:
		assert_true(placed.has(kind), "Depot has a %s" % kind)
		if not placed.has(kind):
			continue
		for t: Transform3D in placed[kind].transforms:
			var wall := _wall_at(t.origin)
			assert_not_null(wall, "the %s at %s is in a hall wall" % [kind, t.origin])
			if wall == null:
				continue
			if not on_wall.has(wall.center):
				on_wall[wall.center] = []
			on_wall[wall.center].append(t.origin)
			# nothing stands in the 2 m in front of it, below the door's head
			var front := (t.basis * Vector3.BACK).normalized()
			var half := (wall.size.z if wall.size.x >= wall.size.z else wall.size.x) * 0.5
			for d: float in [0.5, 1.0, cfg.bay_clear - 0.1]:
				var at := Vector3(t.origin.x, 1.0, t.origin.z) + front * (half + d)
				for other in depot.blocks:
					assert_false(_box(other, 0.0).has_point(at), "%s's front at %s is open" % [kind, at])
	for centre: Vector3 in on_wall:
		var at: Array = on_wall[centre]
		assert_lte(at.size(), cfg.bay_feature_most, "at most two on the wall at %s" % centre)
		for i in at.size():
			for j in range(i + 1, at.size()):
				assert_gt((at[i] as Vector3).distance_to(at[j]), pitch + 0.01, "never side by side")


func test_every_bay_faces_the_field() -> void:
	var placed := _dress(depot).placed()
	var middle := PropLayout.field_middle(depot)
	var n := 0
	for kind: StringName in [&"hall_wall", &"hall_shutter", &"hall_exit"]:
		if not placed.has(kind):
			continue
		for t: Transform3D in placed[kind].transforms:
			var front := (t.basis * Vector3.BACK).normalized()
			var to := middle - t.origin
			assert_gt(front.dot(Vector3(to.x, 0.0, to.z).normalized()), 0.0, "%s at %s faces in" % [kind, t.origin])
			assert_almost_eq(absf(front.y), 0.0, 1e-4, "upright")
			n += 1
	assert_gt(n, _walls(depot).size(), "every wall has its bays")


func test_the_roof_draws_a_bay_a_truss_line_and_cell_all_up_under_the_roof() -> void:
	var roof := RoofView.build(depot, play.roof)
	add_child_autofree(roof)
	var area := depot.footprint().grow(play.roof.ceiling_overhang)
	var lines := RoofView.bay_lines(area, play.roof)
	assert_lte(lines[0] - play.roof.truss_step * 0.5, area.position.x, "the bays reach the hall's west end")
	assert_gte(lines[lines.size() - 1] + play.roof.truss_step * 0.5, area.end.x, "and its east end")
	var cells := RoofView.bay_cells(area, play.roof)
	assert_gt(cells, 0)
	assert_eq(roof.bay_count(), lines.size() * cells)
	assert_eq(roof.bay_views().size(), ceili(float(lines.size()) / play.roof.bay_chunk))
	var box := roof.bay_views()[0].multimesh.mesh.get_aabb()
	var placings := RoofView.bay_placings(box, area, depot.roof_height, play.roof)
	assert_eq(placings.size(), roof.bay_count())
	for t in placings:
		var at := t * box
		assert_gt(at.position.y, depot.roof_height - 2.0, "a bay keeps up under the roof, far over the 3 m racks")
		assert_almost_eq(at.end.y, depot.roof_height, 1e-3, "its top at the roof's underside")
		assert_almost_eq(at.size.x, play.roof.truss_step, 1e-3, "a truss step along")
	var lamps := roof.get_node("Lamps") as MultiMeshInstance3D
	var glows := 0
	for s in lamps.multimesh.mesh.get_surface_count():
		var m := lamps.multimesh.mesh.surface_get_material(s) as StandardMaterial3D
		if m != null and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			glows += 1
	assert_eq(glows, 1, "the lens glows, the body is painted")
	var low_lamp := depot.roof_height - lamps.multimesh.mesh.get_aabb().size.y
	assert_gt(low_lamp, HALL_WALL - 0.5, "the lamps hang well over a head and a thrown grenade's arc")
	for at in depot.roof_lamps:
		var spot := RoofView.lamp_spot(at, play.roof)
		var line := roundf(spot.x / play.roof.truss_step) * play.roof.truss_step
		assert_gte(absf(spot.x - line), play.roof.lamp_clear - 1e-4, "the lamp at %s hangs clear of the truss" % at)
		assert_lte(spot.distance_to(at), play.roof.lamp_clear + 1e-3, "and near where the map hangs it")


func test_the_floor_draws_its_slab_set_on_the_clean_look_at_its_brightness() -> void:
	var look := play.site_look
	assert_eq(look.grit, 0.0, "the look is clean")
	assert_gt(look.slab_grain, 0.0)
	var m := SiteSurface.material(look, depot)
	assert_not_null(m.get_shader_parameter(&"slab_col"), "the slab's photo is loaded")
	assert_null(m.get_shader_parameter(&"ply_col"), "the plywood's is not")
	var image := (load(look.slab_colour) as Texture2D).get_image()
	image.decompress()
	image.resize(128, 128)
	var sum := 0.0
	for y in image.get_height():
		for x in image.get_width():
			sum += image.get_pixel(x, y).srgb_to_linear().get_luminance()
	var mean := sum / (image.get_width() * image.get_height())
	assert_almost_eq(mean, look.slab_luma, 0.02, "slab_luma is the file's mean brightness")


func test_every_model_keeps_to_its_budget() -> void:
	for model: StringName in BUDGETS:
		var mesh := cfg.mesh_of(model)
		assert_not_null(mesh, "%s loads" % model)
		if mesh != null:
			assert_between(_triangles(mesh), int(BUDGETS[model] * 0.5), int(BUDGETS[model]), "%s's triangles" % model)
	for path: String in ROOF_BUDGETS:
		var mesh := PropDressConfig.load_mesh(path)
		assert_not_null(mesh, "%s loads" % path)
		if mesh != null:
			assert_between(_triangles(mesh), int(ROOF_BUDGETS[path] * 0.5), int(ROOF_BUDGETS[path]), path)


func test_a_net_wall_s_sections_all_face_one_way_so_their_edges_meet() -> void:
	var placed := _dress(depot).placed()
	assert_true(placed.has(&"camo_net"))
	var by_wall: Dictionary[Vector3, Basis] = {}
	for t: Transform3D in placed[&"camo_net"].transforms:
		var wall: MapData.Block = null
		for b in depot.blocks:
			if b.kind == &"net" and _box(b, 1e-3).has_point(t.origin + Vector3(0.0, 0.01, 0.0)):
				wall = b
		assert_not_null(wall, "the section at %s is in a net block" % t.origin)
		if wall == null:
			continue
		if not by_wall.has(wall.center):
			by_wall[wall.center] = t.basis
		assert_true(t.basis.is_equal_approx(by_wall[wall.center]), "the section at %s turns as its wall's others" % t.origin)


func test_the_pillar_the_net_and_the_lamp_are_solid_from_outside() -> void:
	# FS1's check (test_model_faces): rays from all round and above first meet a face turned toward them. The wall
	# bays and the roof bay are seen from the hall only, and their test is that they fill their boxes.
	var faces: GDScript = load("res://tests/unit/test_model_faces.gd")
	for path: String in ["res://assets/models/props/pillar.glb", "res://assets/models/props/camo_net.glb",
			"res://assets/models/props/roof_lamp.glb"]:
		var mesh := PropDressConfig.load_mesh(path)
		assert_not_null(mesh, "%s loads" % path)
		if mesh != null:
			var share: float = faces.call("back_share", mesh)
			assert_lt(share, 0.02, "%s: %.1f%% of rays meet a face turned away" % [path.get_file(), share * 100.0])
