extends GutTest
## RM2: the Range's rebuilt props. Sandbags are drawn matte in their own material (warmed with the rest), the
## three Range models stay within 5,000 triangles, and a cordwood section's pieces never pass its box.

const RANGE_MODELS: Array[StringName] = [&"sandbags", &"site_toilet", &"water_tote"]
const CORDWOOD: Array[StringName] = [&"cordwood", &"cordwood_b", &"cordwood_c", &"cordwood_start", &"cordwood_end",
		&"cordwood_single"]

var play: PlayTuning = PlayTuning.load_default()


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		var count: int = (idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		n += count / 3
	return n


func _range_dress() -> PropDress:
	var m := MapData.load_map("range", play.map_style, 1)
	var dress := PropDress.build(m, play.site_look.props)
	add_child_autofree(dress)
	return dress


func test_sandbags_are_drawn_matte_in_their_own_warmed_material() -> void:
	var cfg := play.site_look.props
	assert_almost_eq(cfg.model_roughness.get(&"sandbags", -1.0) as float, 0.97, 0.0001)
	var dress := _range_dress()
	var views := dress.views_of(&"sandbags")
	assert_gt(views.size(), 0, "the range has sandbags")
	var mat := views[0].material_override as ShaderMaterial
	assert_almost_eq(mat.get_shader_parameter(&"roughness") as float, 0.97, 0.0001, "drawn at 0.97")
	for v in dress.views_of(&"water_tote"):
		assert_ne(v.material_override, mat, "not the shared material")
	assert_true(dress.materials().has(mat), "in the prewarm list")


func test_the_range_models_stay_within_their_triangle_budget() -> void:
	var dress := _range_dress()
	for model in RANGE_MODELS:
		assert_gt(dress.views_of(model).size(), 0, "%s is placed" % model)
		var t := _tris(dress.mesh_of(model))
		assert_lt(t, 5000, "%s within 5,000 triangles (%d)" % [model, t])
		assert_gt(t, 500, "%s is a real model" % model)


func test_the_baked_colours_keep_the_team_rule_when_stored_8_bit() -> void:
	var dress := _range_dress()
	for model in RANGE_MODELS:
		var mesh := dress.mesh_of(model)
		for s in mesh.get_surface_count():
			var cols: Variant = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			assert_not_null(cols, "%s keeps its vertex colours" % model)
			if cols == null:
				continue
			for c: Color in (cols as PackedColorArray):
				var hi := maxf(c.r, maxf(c.g, c.b))
				var lo := minf(c.r, minf(c.g, c.b))
				var is_team := hi > 0.35 and (hi - lo) > 0.6 * hi and (c.b > c.r * 1.5 or c.r > c.b * 1.5) \
						and c.g < maxf(c.r, c.b) * 0.5
				assert_false(is_team, "%s has no strongly red or blue vertex (%s)" % [model, c])
				if is_team:
					return


func test_cordwood_sections_stay_inside_their_box_and_budget() -> void:
	for model in CORDWOOD:
		var mesh := load("res://assets/models/props/%s.glb" % model) as PackedScene
		assert_not_null(mesh, "%s loads" % model)
		var root := mesh.instantiate()
		add_child_autofree(root)
		var tris := 0
		var box := AABB()
		var first := true
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			tris += _tris(mi.mesh)
			var b := mi.global_transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		assert_lte(tris, 3200, "%s within its 3,200 budget (%d)" % [model, tris])
		assert_gt(box.size.x, 0.5, "%s has a body" % model)
		assert_almost_eq(box.position.y, 0.0, 0.05, "%s stands on its floor" % model)


# ---- attempt 2: sandbag lines closed by end models ----

const BAG := AABB(Vector3(-0.6, 0.0, -0.3), Vector3(1.2, 0.9, 0.6))


func _boxes() -> Dictionary[StringName, AABB]:
	var b: Dictionary[StringName, AABB] = {}
	for n: StringName in [&"sandbags", &"sandbags_start", &"sandbags_end", &"sandbags_single", &"cordwood", &"crate"]:
		b[n] = BAG
	return b


## Lays `model` in a box of `size` at `foot` with the config's own rules; returns what _grid placed.
func _line(model: StringName, size: Vector3, rng_seed: int = 7) -> Dictionary[StringName, PropLayout.Placed]:
	var out: Dictionary[StringName, PropLayout.Placed] = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var picks: Array[StringName] = [model]
	PropLayout._grid(out, picks, _boxes(), Vector3(10.0, 0.0, -4.0), size, Vector3(1.2, 0.9, 0.6),
			play.site_look.props, rng, model)
	return out


func _model_at(out: Dictionary[StringName, PropLayout.Placed], axis: int) -> Array:
	## [name, ...] ordered by the cell's position on `axis` (0 = x, 2 = z)
	var rows: Array = []
	for name: StringName in out:
		var p: PropLayout.Placed = out[name]
		for t: Transform3D in p.transforms:
			rows.append([t.origin[axis], name])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as float) < (b[0] as float))
	var names: Array = []
	for r: Array in rows:
		names.append(r[1])
	return names


func test_a_sandbag_line_along_x_starts_and_ends_with_its_end_models() -> void:
	var names := _model_at(_line(&"sandbags", Vector3(4.8, 0.9, 0.6)), 0)
	assert_eq(names, [&"sandbags_start", &"sandbags", &"sandbags", &"sandbags_end"] as Array)


func test_a_sandbag_line_along_z_swaps_the_ends() -> void:
	var names := _model_at(_line(&"sandbags", Vector3(0.6, 0.9, 3.6)), 2)
	assert_eq(names, [&"sandbags_end", &"sandbags", &"sandbags_start"] as Array, "+x turns to world -z")


func test_a_one_cell_sandbag_line_takes_the_model_closed_at_both_ends() -> void:
	var out := _line(&"sandbags", Vector3(1.2, 0.9, 0.6))
	assert_eq(out.keys(), [&"sandbags_single"] as Array)
	assert_eq((out[&"sandbags_single"] as PropLayout.Placed).transforms.size(), 1)


func test_a_one_cell_sandbag_line_without_its_model_takes_the_start_model() -> void:
	var out: Dictionary[StringName, PropLayout.Placed] = {}
	var boxes := _boxes()
	boxes.erase(&"sandbags_single")
	var picks: Array[StringName] = [&"sandbags"]
	PropLayout._grid(out, picks, boxes, Vector3.ZERO, Vector3(1.2, 0.9, 0.6), Vector3(1.2, 0.9, 0.6),
			play.site_look.props, RandomNumberGenerator.new(), &"sandbags")
	assert_eq(out.keys(), [&"sandbags_start"] as Array)


func test_a_two_cell_line_has_no_middle_cell() -> void:
	var names := _model_at(_line(&"sandbags", Vector3(2.4, 0.9, 0.6)), 0)
	assert_eq(names, [&"sandbags_start", &"sandbags_end"] as Array)


func test_sandbags_are_never_turned_and_a_closed_line_has_shade_one() -> void:
	for size: Vector3 in [Vector3(7.2, 0.9, 0.6), Vector3(0.6, 0.9, 7.2)]:
		var out := _line(&"sandbags", size)
		var along_x := size.x >= size.z
		for name: StringName in out:
			var p: PropLayout.Placed = out[name]
			for s: float in p.shades:
				assert_eq(s, 1.0, "closed line keeps one shade")
			for t: Transform3D in p.transforms:
				# the model's x runs along the box's long side whatever the seed: never flipped end for end
				var x_axis := t.basis.x.normalized()
				assert_almost_eq(absf(x_axis.x if along_x else x_axis.z), 1.0, 0.001)
				assert_gt(x_axis.x if along_x else -x_axis.z, 0.0, "not turned a half")


func test_two_rows_across_a_sandbag_box_each_get_their_ends() -> void:
	var out := _line(&"sandbags", Vector3(3.6, 0.9, 1.2))
	assert_eq((out[&"sandbags_start"] as PropLayout.Placed).transforms.size(), 2)
	assert_eq((out[&"sandbags_end"] as PropLayout.Placed).transforms.size(), 2)
	assert_eq((out[&"sandbags"] as PropLayout.Placed).transforms.size(), 2)


func test_a_sandbag_line_without_its_end_bounds_falls_back_to_the_base_model() -> void:
	var out: Dictionary[StringName, PropLayout.Placed] = {}
	var rng := RandomNumberGenerator.new()
	var boxes := _boxes()
	boxes.erase(&"sandbags_end")
	var picks: Array[StringName] = [&"sandbags"]
	PropLayout._grid(out, picks, boxes, Vector3.ZERO, Vector3(3.6, 0.9, 0.6), Vector3(1.2, 0.9, 0.6),
			play.site_look.props, rng, &"sandbags")
	assert_eq(out.keys(), [&"sandbags"] as Array, "an unloaded end model never leaves a hole")


func test_other_grid_models_lay_out_as_they_did_and_keep_their_stream() -> void:
	# a model with no ends: shade drawn from the stream as before; and the stream after a sandbag line is the
	# same as after any other same-sized line (the closed line still draws its shades and turns)
	var cfg := play.site_look.props
	for model: StringName in [&"crate", &"camo_net"]:
		assert_false(cfg.grid_ends.has(model), "%s has no end models" % model)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 3
	b.seed = 3
	var o1: Dictionary[StringName, PropLayout.Placed] = {}
	var o2: Dictionary[StringName, PropLayout.Placed] = {}
	var picks: Array[StringName] = [&"sandbags"]
	PropLayout._grid(o1, picks, _boxes(), Vector3.ZERO, Vector3(4.8, 0.9, 0.6), Vector3(1.2, 0.9, 0.6), cfg, a, &"sandbags")
	var picks2: Array[StringName] = [&"crate"]
	PropLayout._grid(o2, picks2, _boxes(), Vector3.ZERO, Vector3(4.8, 0.9, 0.6), Vector3(1.2, 0.9, 0.6), cfg, b, &"crate")
	assert_eq(a.randi(), b.randi(), "a sandbag line spends the same draws as an unclosed one, as unturned models do")


func test_a_woodpile_line_is_closed_by_its_end_models_and_its_middle_sections_vary() -> void:
	# twelfth woodpile pass: the middle sections are cut flush and run on into each other; the line's first and last
	# sections close it, a one-section line takes the model closed at both ends, and nothing is turned
	var cfg := play.site_look.props
	var boxes := _boxes()
	for n: StringName in [&"cordwood_b", &"cordwood_c", &"cordwood_start", &"cordwood_end", &"cordwood_single"]:
		boxes[n] = BAG
	var picks: Array[StringName] = [&"cordwood", &"cordwood_b", &"cordwood_c"]
	for cells: int in [1, 2, 5]:
		var out: Dictionary[StringName, PropLayout.Placed] = {}
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		PropLayout._grid(out, picks, boxes, Vector3.ZERO, Vector3(1.2 * cells, 0.9, 0.6), Vector3(1.2, 0.9, 0.6), cfg,
				rng, &"cordwood")
		var count := 0
		for k: StringName in out:
			count += out[k].transforms.size()
			for t: Transform3D in out[k].transforms:
				assert_almost_eq(t.basis.get_euler().y, 0.0, 0.001, "%s is never turned" % k)
		assert_eq(count, cells, "%d cells laid" % cells)
		if cells == 1:
			assert_eq(out.keys(), [&"cordwood_single"] as Array, "one section closes at both ends")
		else:
			assert_true(out.has(&"cordwood_start") and out.has(&"cordwood_end"), "%d cells: both ends closed" % cells)
			assert_eq(out[&"cordwood_start"].transforms.size(), 1, "one start section")
			assert_false(out.has(&"cordwood_single"), "no single section in a longer line")


func test_the_end_models_share_the_sandbag_box_and_load_with_the_range_and_stockade() -> void:
	for map_id: String in ["range", "stockade"]:
		var m := MapData.load_map(map_id, play.map_style, 1)
		var used := PropDress._models_used(m, play.site_look.props)
		assert_true(used.has(&"sandbags_start") and used.has(&"sandbags_end") and used.has(&"sandbags_single"),
				"%s loads the end models" % map_id)
		var dress := PropDress.build(m, play.site_look.props)
		add_child_autofree(dress)
		var base := dress.mesh_of(&"sandbags").get_aabb()
		for e: StringName in [&"sandbags_start", &"sandbags_end"]:
			assert_gt(dress.views_of(e).size(), 0, "%s draws %s" % [map_id, e])
			var box := dress.mesh_of(e).get_aabb()
			assert_true(box.size.is_equal_approx(base.size) or box.size.distance_to(base.size) < 0.05,
					"%s box matches sandbags' (%s vs %s)" % [e, box.size, base.size])
			assert_true(box.position.distance_to(base.position) < 0.05, "%s sits as sandbags does" % e)
			assert_lt(_tris(dress.mesh_of(e)), 5000, "%s within budget" % e)


func test_end_models_stay_inside_their_blocks_on_range_and_stockade() -> void:
	for map_id: String in ["range", "stockade"]:
		var m := MapData.load_map(map_id, play.map_style, 1)
		var dress := PropDress.build(m, play.site_look.props)
		add_child_autofree(dress)
		var boxes: Array[AABB] = []
		for b in m.blocks:
			if b.dress == &"sandbags":
				boxes.append(AABB(b.center - b.size * 0.5, b.size))
		assert_gt(boxes.size(), 0, "%s has sandbag blocks" % map_id)
		for e: StringName in [&"sandbags_start", &"sandbags_end", &"sandbags"]:
			var mesh := dress.mesh_of(e).get_aabb()
			var placed: PropLayout.Placed = dress.placed().get(e, null)
			assert_not_null(placed, "%s is laid on %s" % [e, map_id])
			if placed == null:
				continue
			for i in placed.transforms.size():
				var w := placed.transforms[i] * mesh
				var ok := false
				for bx: AABB in boxes:
					ok = ok or bx.grow(0.05).encloses(w)
				assert_true(ok, "%s #%d on %s stays in a block" % [e, i, map_id])


# ---- attempt 3: three main sections that take turns along a wall ----

const SANDBAG_SECTIONS: Array[StringName] = [&"sandbags", &"sandbags_b", &"sandbags_c"]


func test_sandbag_sections_take_turns_and_share_one_box() -> void:
	var cfg := play.site_look.props
	assert_eq(cfg.variants_of(&"sandbags"), SANDBAG_SECTIONS, "two more sections take turns with sandbags")
	for v: StringName in SANDBAG_SECTIONS:
		assert_almost_eq(cfg.model_roughness.get(v, -1.0) as float, 0.97, 0.0001, "%s drawn matt" % v)
	var dress := _range_dress()
	var base := dress.mesh_of(&"sandbags").get_aabb()
	var laid := 0
	for v: StringName in SANDBAG_SECTIONS:
		var mesh := dress.mesh_of(v)
		assert_not_null(mesh, "%s loads on the range" % v)
		if mesh == null:
			continue
		assert_lt(base.size.distance_to(mesh.get_aabb().size), 0.01, "%s is the sandbags' size" % v)
		var t := _tris(mesh)
		assert_lt(t, 5000, "%s within 5,000 triangles (%d)" % [v, t])
		laid += dress.views_of(v).size()
	assert_gt(laid, 0, "the range lays its sections")


func test_a_long_line_mixes_the_sections_between_its_ends() -> void:
	var out: Dictionary[StringName, PropLayout.Placed] = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var boxes := _boxes()
	boxes[&"sandbags_b"] = BAG
	boxes[&"sandbags_c"] = BAG
	PropLayout._grid(out, SANDBAG_SECTIONS.duplicate(), boxes, Vector3.ZERO, Vector3(24.0, 0.9, 0.6),
			Vector3(1.2, 0.9, 0.6), play.site_look.props, rng, &"sandbags")
	var names := _model_at(out, 0)
	assert_eq(names.size(), 20)
	assert_eq(names[0], &"sandbags_start")
	assert_eq(names[-1], &"sandbags_end")
	var kinds := {}
	for n: StringName in names.slice(1, -1):
		assert_true(SANDBAG_SECTIONS.has(n), "%s is a main section" % n)
		kinds[n] = true
	assert_eq(kinds.size(), 3, "all three sections laid along 24 m")
	for name: StringName in out:
		for s: float in (out[name] as PropLayout.Placed).shades:
			assert_eq(s, 1.0, "one shade along the line")


func test_section_variants_load_and_stay_in_their_blocks_on_range_and_stockade() -> void:
	for map_id: String in ["range", "stockade"]:
		var m := MapData.load_map(map_id, play.map_style, 1)
		var used := PropDress._models_used(m, play.site_look.props)
		var dress := PropDress.build(m, play.site_look.props)
		add_child_autofree(dress)
		var boxes: Array[AABB] = []
		for b in m.blocks:
			if b.dress == &"sandbags":
				boxes.append(AABB(b.center - b.size * 0.5, b.size))
		for v: StringName in [&"sandbags_b", &"sandbags_c"]:
			assert_true(used.has(v), "%s loads %s" % [map_id, v])
			var mesh := dress.mesh_of(v)
			assert_not_null(mesh, "%s has a mesh for %s" % [map_id, v])
			var placed: PropLayout.Placed = dress.placed().get(v, null)
			if mesh == null or placed == null:
				continue
			for t: Transform3D in placed.transforms:
				var w := t * mesh.get_aabb()
				var ok := false
				for bx: AABB in boxes:
					ok = ok or bx.grow(0.05).encloses(w)
				assert_true(ok, "%s %s stays in a block" % [map_id, v])


func test_short_lines_with_variants_keep_their_ends_and_use_no_variant() -> void:
	var boxes := _boxes()
	boxes[&"sandbags_b"] = BAG
	boxes[&"sandbags_c"] = BAG
	for cells: int in [1, 2, 3]:
		var out: Dictionary[StringName, PropLayout.Placed] = {}
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		PropLayout._grid(out, SANDBAG_SECTIONS.duplicate(), boxes, Vector3.ZERO, Vector3(1.2 * cells, 0.9, 0.6),
				Vector3(1.2, 0.9, 0.6), play.site_look.props, rng, &"sandbags")
		var names := _model_at(out, 0)
		assert_eq(names.size(), cells)
		assert_eq(names[0], &"sandbags_single" if cells == 1 else &"sandbags_start")
		if cells > 1:
			assert_eq(names[-1], &"sandbags_end")
		if cells == 3:
			assert_true(SANDBAG_SECTIONS.has(names[1]), "the middle cell is a main section")


func _line_cfg(cfg: PropDressConfig, size: Vector3, boxes: Dictionary[StringName, AABB]) -> Dictionary[StringName, PropLayout.Placed]:
	var out: Dictionary[StringName, PropLayout.Placed] = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var picks: Array[StringName] = [&"sandbags"]
	PropLayout._grid(out, picks, boxes, Vector3.ZERO, size, Vector3(1.2, 0.9, 0.6), cfg, rng, &"sandbags")
	return out


func test_a_two_name_grid_ends_entry_still_closes_a_one_cell_line_with_the_start_model() -> void:
	var cfg := play.site_look.props.duplicate() as PropDressConfig
	cfg.grid_ends = {&"sandbags": PackedStringArray(["sandbags_start", "sandbags_end"])}
	var out := _line_cfg(cfg, Vector3(1.2, 0.9, 0.6), _boxes())
	assert_eq(out.keys(), [&"sandbags_start"] as Array)
	var many := _line_cfg(cfg, Vector3(3.6, 0.9, 0.6), _boxes())
	assert_true(many.has(&"sandbags_end") and not many.has(&"sandbags_single"))


func test_a_one_cell_line_along_z_and_a_multi_row_one_cell_line_take_the_single_model() -> void:
	var cfg := play.site_look.props
	var z_line := _line_cfg(cfg, Vector3(0.6, 0.9, 1.2), _boxes())
	assert_eq(z_line.keys(), [&"sandbags_single"] as Array)
	var rows := _line_cfg(cfg, Vector3(1.2, 0.9, 1.8), _boxes())
	for name: StringName in rows:
		assert_eq(name, &"sandbags_single", "every row of a one-cell line is closed at both ends")
