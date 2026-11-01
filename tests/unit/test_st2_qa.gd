extends GutTest
## ST2 QA: The Street's CC0 dress. Hunts props that are single-surface only by luck, that float, shrink inside their
## box or leave a box's footprint bare (what you see must be what stops a BB).

const MAX_TRIANGLES: int = 3000

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _street() -> MapData:
	var m := MapData.load_map("street", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "street loads: %s" % [m.problems])
	return m


func _dress(m: MapData) -> PropDress:
	var dress := PropDress.build(m, play.site_look.props)
	if dress != null:
		add_child_autofree(dress)
	return dress


func test_every_street_model_is_one_mesh_one_surface_with_vertex_colours_under_budget() -> void:
	var cfg := play.site_look.props
	var m := _street()
	var used: Dictionary[StringName, bool] = {}
	for b in m.blocks:
		if b.dress != &"":
			used[b.dress] = true
	for model: StringName in used:
		var path: String = cfg.models.get(model, "")
		assert_ne(path, "", "%s has a path" % model)
		var scene := load(path) as PackedScene
		assert_not_null(scene, "%s loads" % model)
		if scene == null:
			continue
		var root := scene.instantiate()
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		root.free()
		assert_eq(meshes.size(), 1, "%s: PropDressConfig.load_mesh reads only the first mesh node" % model)
		var mesh := cfg.mesh_of(model)
		assert_eq(mesh.get_surface_count(), 1, "%s: the layout and colour tests read only surface 0" % model)
		var arrays := mesh.surface_get_arrays(0)
		assert_gt((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size(), 0, "%s has vertex colours" % model)
		var tris := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_lt(tris, MAX_TRIANGLES, "%s triangles" % model)


func test_a_fitted_prop_rests_on_the_ground_and_fills_its_blocks_footprint_and_height() -> void:
	var m := _street()
	var cfg := play.site_look.props
	var dress := _dress(m)
	assert_not_null(dress)
	if dress == null:
		return
	var placed := dress.placed()
	var bad: Array[String] = []
	var checked := 0
	for b in m.blocks:
		if b.dress == &"" or cfg.lay_of(b) != PropDressConfig.Lay.FIT or not placed.has(b.dress):
			continue
		var mesh := dress.mesh_of(b.dress)
		var box := AABB(b.center - b.size * 0.5, b.size)
		var hit := false
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for t in placed[b.dress].transforms:
			var world := t * mesh.get_aabb()
			if not box.grow(1e-3).intersects(world) or not box.grow(1e-3).has_point(world.get_center()):
				continue
			hit = true
			# the transformed vertex bounds, not the AABB of a rotated box
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			for v in verts:
				lo = lo.min(t * v)
				hi = hi.max(t * v)
			checked += 1
			if absf(lo.y - box.position.y) > 0.02:
				bad.append("%s at %s floats/sinks by %.2f" % [b.dress, b.center, lo.y - box.position.y])
			if hi.y < box.end.y * 0.97 and b.dress != &"lamp":
				bad.append("%s at %s tops out %.2f under its box" % [b.dress, b.center, box.end.y - hi.y])
			if (hi.x - lo.x) < b.size.x * 0.95 or (hi.z - lo.z) < b.size.z * 0.95:
				bad.append("%s at %s leaves its footprint bare: %s of %s" % [b.dress, b.center,
						Vector2(hi.x - lo.x, hi.z - lo.z), Vector2(b.size.x, b.size.z)])
			break
		assert_true(hit, "%s at %s has a placed prop" % [b.dress, b.center])
	assert_gt(checked, 80, "most of the street's dressed blocks were measured")
	assert_eq(bad, [] as Array[String], "every fitted prop fills its block")


func test_a_grid_of_bins_or_units_fills_its_block_end_to_end() -> void:
	var m := _street()
	var cfg := play.site_look.props
	var dress := _dress(m)
	if dress == null:
		fail_test("no dress")
		return
	var placed := dress.placed()
	for model: StringName in [&"bin_green", &"bin_steel", &"bin_teal", &"units"]:
		var mesh := dress.mesh_of(model)
		var blocks := 0
		var long_total := 0.0
		for b in m.blocks:
			if b.dress == model:
				blocks += 1
				long_total += maxf(b.size.x, b.size.z)
				assert_eq(cfg.lay_of(b), PropDressConfig.Lay.GRID)
		var per_block := float(placed[model].transforms.size()) / maxf(blocks, 1)
		assert_gt(per_block, 1.0, "%s: more than one a block (%d blocks)" % [model, blocks])
		assert_not_null(mesh)
		assert_gt(long_total, 0.0)
