extends GutTest
## FT1 (QA): Woodland's treelines fade only treeline_fade as far as other pieces (cones and model band), the skyline
## draws no specular while LookMaterials keeps Godot's 0.5, GRID models drawn wider than their cell stay in the box
## with the end ones flush and neighbours overlapping (spread 1 is the old layout), a thicket's core is a fifth tall.

var play: PlayTuning = PlayTuning.load_default()
var look: SiteLook = null


func before_each() -> void:
	look = play.site_look


func _tree_piece(x0: float) -> SkylinePiece:
	var warnings: Array[String] = []
	return SkylinePiece.read({"skyline": [{"kind": "treeline", "height": 15, "depth": 5,
			"points": [{"x": x0, "z": 300}, {"x": x0 + 20, "z": 300}]}]}, warnings)[0]


func _fade_of(part: SkylineShapes.Part, cfg: SkylineConfig) -> float:
	# How far toward the horizon the first vertex of `part` went (0 its undimmed colour, 1 the horizon), in linear light.
	var horizon := Color(1, 0, 1)
	var parts: Array[SkylineShapes.Part] = [part]
	var flat: SkylineConfig = cfg.duplicate()
	flat.fade_most = 0.0
	var base: Color = (SkylineView.mesh_of(parts, flat, horizon, Vector2.ZERO).surface_get_arrays(0)[
			Mesh.ARRAY_COLOR] as PackedColorArray)[0].srgb_to_linear()
	var got: Color = (SkylineView.mesh_of(parts, cfg, horizon, Vector2.ZERO).surface_get_arrays(0)[
			Mesh.ARRAY_COLOR] as PackedColorArray)[0].srgb_to_linear()
	return (got.r - base.r) / (horizon.r - base.r)


func test_treeline_cones_carry_the_treeline_fade_and_other_pieces_the_full_one() -> void:
	var cfg := play.skyline
	var parts := SkylineShapes.parts_of(_tree_piece(0.0), cfg, Vector2.ZERO)
	assert_gt(parts.size(), 0)
	for p in parts:
		assert_almost_eq(p.haze, cfg.treeline_fade, 1e-6, "a cone fades treeline_fade")
	var warnings: Array[String] = []
	var hill := SkylinePiece.read({"skyline": [{"kind": "hill", "x": 0, "z": 300, "width": 20, "depth": 20,
			"height": 10}]}, warnings)
	for p in SkylineShapes.parts_of(hill[0], cfg, Vector2.ZERO):
		assert_almost_eq(p.haze, 1.0, 1e-6, "a hill piece fades fully")


func test_a_far_treeline_vertex_fades_treeline_fade_as_far_as_the_same_distance_of_a_hill() -> void:
	var cfg := play.skyline
	var colour := Color(0.1, 0.4, 0.2)
	var a := SkylineShapes.box(Vector3(299, 0, -1), Vector3(301, 2, 1), colour)
	var b := SkylineShapes.box(Vector3(299, 0, -1), Vector3(301, 2, 1), colour)
	b.haze = cfg.treeline_fade
	var full := _fade_of(a, cfg)
	var tree := _fade_of(b, cfg)
	assert_gt(full, 0.3, "far pieces do fade (%f)" % full)
	assert_almost_eq(tree, full * cfg.treeline_fade, 0.02, "the treeline fades treeline_fade of that")
	assert_lt(tree, full)


func test_a_treeline_with_zero_fade_keeps_its_own_colour_at_any_distance() -> void:
	var cfg: SkylineConfig = play.skyline.duplicate()
	cfg.treeline_fade = 0.0
	var p := SkylineShapes.box(Vector3(499, 0, -1), Vector3(501, 2, 1), Color(0.1, 0.4, 0.2))
	p.haze = cfg.treeline_fade
	assert_almost_eq(_fade_of(p, cfg), 0.0, 0.01)


func test_the_model_band_carries_the_treeline_fade() -> void:
	var cfg := play.skyline
	if cfg.treeline_mesh() == null:
		pending("the treeline model does not load here")
		return
	var placed := SkylineModels.placed_of(_tree_piece(0.0), cfg, Vector2.ZERO)
	assert_gt(placed.size(), 0)
	for one in placed:
		assert_almost_eq(one.haze, cfg.treeline_fade, 1e-6)


func test_the_treeline_greens_are_the_far_woods() -> void:
	var cfg := play.skyline
	for c in cfg.treeline_colours:
		assert_true(c.g > c.r and c.g > c.b, "a green: %s" % c)
		assert_gt(c.g, 0.3, "not the near-black greens that read grey")


func test_the_skyline_material_has_no_specular_and_the_default_stays_half() -> void:
	assert_eq(play.skyline.specular, 0.0)
	var def := LookMaterials.vertex_colour(0.8, 0.0)
	assert_eq(def.get_shader_parameter(&"specular"), null, "untouched: the shader's own default")
	var shader_default: Variant = RenderingServer.shader_get_parameter_default(def.shader.get_rid(), &"specular")
	if shader_default == null:
		pending("no renderer here to read the shader's default (needs a display)")
		return
	assert_almost_eq(shader_default as float, 0.5, 1e-6, "Godot's 0.5 for every other user")


func test_a_built_skyline_view_sets_the_specular_from_the_config() -> void:
	var m := MapData.load_map("woodland", play.map_style, 1)
	var body := BodyConfig.new()
	var cfg: SkylineConfig = play.skyline.duplicate()
	cfg.specular = 0.0
	var v := SkylineView.build(m, cfg, play.lighting, body.stand_eye_height)
	if v == null:
		pending("woodland shows no skyline")
		return
	autofree(v)
	var mat := v._mesh.mesh.surface_get_material(0) as ShaderMaterial
	assert_almost_eq(float(mat.get_shader_parameter(&"specular")), 0.0, 1e-6)


# --- GRID spread -----------------------------------------------------------------------------------------------

func _grid(size: Vector3, cell: Vector3, spread: Vector2, model: AABB = AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE),
		rng_seed: int = 1) -> Array[Transform3D]:
	var cfg: PropDressConfig = look.props.duplicate()
	cfg.grid_spread = {&"m": spread}
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var out: Dictionary[StringName, PropLayout.Placed] = {}
	var boxes: Dictionary[StringName, AABB] = {&"m": model}
	var picks: Array[StringName] = [&"m"]
	PropLayout._grid(out, picks, boxes, Vector3(10, 0, 20), size, cell, cfg, rng, &"m")
	return out[&"m"].transforms


func _world(t: Transform3D, model: AABB) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in 8:
		var c := t * (model.position + model.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
		lo = lo.min(c)
		hi = hi.max(c)
	return AABB(lo, hi - lo)


func test_a_spread_of_one_is_the_old_even_cell_layout() -> void:
	for along_x: bool in [true, false]:
		var size := Vector3(6.0, 3.0, 3.0) if along_x else Vector3(3.0, 3.0, 6.0)
		var cell := Vector3(1.5, 1.5, 1.5)
		var got := _grid(size, cell, Vector2.ONE)
		var model := AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
		var long := 6.0
		var n := Vector3i(4, 2, 2)
		var step := Vector3(long / n.x, size.y / n.y, 3.0 / n.z)
		var want: Array[AABB] = []
		for i in n.x:
			for k in n.z:
				for j in n.y:
					var u := (i + 0.5) * step.x - long * 0.5
					var v := (k + 0.5) * step.z - 1.5
					var at := Vector3(10, 0, 20) + (Vector3(u, j * step.y, v) if along_x else Vector3(v, j * step.y, u))
					var half := Vector3(step.x if along_x else step.z, 0, step.z if along_x else step.x) * 0.5
					want.append(AABB(at - Vector3(half.x, 0, half.z), Vector3(half.x * 2, step.y, half.z * 2)))
		assert_eq(got.size(), want.size())
		for t in got:
			var w := _world(t, model)
			var found := false
			for e in want:
				if w.position.distance_to(e.position) < 1e-3 and w.size.distance_to(e.size) < 1e-3:
					found = true
			assert_true(found, "a cell as before (along_x %s): %s" % [along_x, w])


func test_a_spread_keeps_every_model_in_its_box_the_ends_flush_and_neighbours_overlapping() -> void:
	var model := AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	for along_x: bool in [true, false]:
		var size := Vector3(9.0, 4.0, 3.0) if along_x else Vector3(3.0, 4.0, 9.0)
		var box := AABB(Vector3(10, 0, 20) - Vector3(size.x, 0, size.z) * 0.5, size)
		var ts := _grid(size, Vector3(1.5, 0, 1.5), Vector2(1.8, 1.5))
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		var worlds: Array[AABB] = []
		for t in ts:
			var w := _world(t, model)
			worlds.append(w)
			lo = lo.min(w.position)
			hi = hi.max(w.end)
			assert_true(box.grow(0.001).encloses(AABB(w.position, Vector3(w.size.x, 0.01, w.size.z))), "inside: %s" % w)
		assert_almost_eq(lo.x, box.position.x, 1e-3, "flush low x")
		assert_almost_eq(lo.z, box.position.z, 1e-3, "flush low z")
		assert_almost_eq(hi.x, box.end.x, 1e-3, "flush high x")
		assert_almost_eq(hi.z, box.end.z, 1e-3, "flush high z")
		var overlaps := 0
		for i in worlds.size():
			for j in range(i + 1, worlds.size()):
				if worlds[i].intersection(worlds[j]).get_volume() > 1e-4 and worlds[i].position.y == worlds[j].position.y:
					overlaps += 1
		assert_gt(overlaps, 0, "neighbours overlap")


func test_a_single_model_across_or_along_stays_in_its_box_at_any_spread() -> void:
	# n.x == 1 and n.z == 1: pitch has no division by zero and the model is the box's, never wider.
	var model := AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	for spread: Vector2 in [Vector2(1.8, 1.5), Vector2(10, 10), Vector2(0.5, 0.5)]:
		var ts := _grid(Vector3(1.0, 2.0, 1.0), Vector3(1.5, 0, 1.5), spread)
		assert_eq(ts.size(), 1)
		var w := _world(ts[0], model)
		assert_true(is_finite(w.position.x) and is_finite(w.size.x))
		assert_lte(w.size.x, 1.0 + 1e-3, "never past the box")
		assert_lte(w.size.z, 1.0 + 1e-3)


func test_a_huge_spread_never_leaves_the_box() -> void:
	var model := AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	var size := Vector3(8.0, 3.0, 2.0)
	var box := AABB(Vector3(10, 0, 20) - Vector3(size.x, 0, size.z) * 0.5, size)
	for t in _grid(size, Vector3(1.5, 0, 1.5), Vector2(50, 50)):
		var w := _world(t, model)
		assert_true(box.grow(0.001).encloses(AABB(w.position, Vector3(w.size.x, 0.01, w.size.z))), "%s" % w)


func test_only_spruce_is_spread_and_other_grids_keep_their_cells() -> void:
	var cfg := look.props
	assert_eq(cfg.grid_spread.keys(), [&"spruce"] as Array)
	assert_gt(cfg.grid_spread[&"spruce"].x, 1.0)
	for model: StringName in [&"crate", &"camo_net", &"cordwood"]:
		assert_false(cfg.grid_spread.has(model), "%s is not spread" % model)


# --- the core --------------------------------------------------------------------------------------------------

func test_a_spruce_core_is_a_fifth_of_the_thicket_s_height_in_the_shade_colour() -> void:
	assert_almost_eq(look.props.model_cores[&"spruce"].y, 0.2, 1e-6)
	assert_eq(MapLevel.CORE_SHARE, 0.3)
	var under := play.map_style.colours[&"thicket"]
	var forest := Color8(0x2b, 0x5c, 0x48)
	for ch in 3:
		assert_almost_eq(under[ch], forest[ch] * 0.55, 1.5 / 255.0, "spruce.py's UNDER: the forest green at 0.55")


func test_core_box_is_a_fifth_tall_and_inset_at_most_the_core_share() -> void:
	var b := MapData.Block.new()
	b.center = Vector3(0, 2, 0)
	b.size = Vector3(1.0, 4.0, 10.0)
	var cored: Array[MapData.Block] = [b]
	var t := MapLevel.core_box(b, Vector2(0.7, 0.2), cored)
	var lo := b.center - b.size * 0.5
	var box := AABB(lo, b.size)
	var core := t * box.position
	var core_end := t * box.end
	assert_almost_eq(core_end.y - core.y, 0.8, 1e-4, "a fifth of 4 m")
	assert_almost_eq(core.x - lo.x, 0.3, 1e-4, "inset capped at 0.3 of the 1 m width")
	assert_almost_eq(core.z - lo.z, 0.7, 1e-4, "the full inset along the long side")


func test_two_touching_thickets_cores_still_meet() -> void:
	var a := MapData.Block.new()
	a.center = Vector3(0, 2, 0)
	a.size = Vector3(4, 4, 4)
	var b := MapData.Block.new()
	b.center = Vector3(4, 2, 0)
	b.size = Vector3(4, 4, 4)
	var cored: Array[MapData.Block] = [a, b]
	var ta := MapLevel.core_box(a, Vector2(0.7, 0.2), cored)
	assert_almost_eq((ta * Vector3(2, 0, 0)).x, 2.0, 1e-4, "a's core runs to the shared face")
