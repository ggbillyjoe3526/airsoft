extends GutTest
## QA for MM3's field drawing: the edges the feature's own tests leave alone. The storey_cut, storey_pick and
## storey_of boundaries to the exact value, pixel alignment (no off-by-one, north up), the size cap on a thin field, the
## painter's order against the file's order, the dock's rim beside an equal floor and over a gap, a map with only
## ramps drawing nothing, malformed maps, and every layer freed with its field. Small maps are built from JSON text.

const TOLERANCE := 1.5 / 255.0

var cfg: MinimapConfig = null


func before_each() -> void:
	cfg = PlayTuning.load_default().minimap.duplicate() as MinimapConfig


func after_each() -> void:
	cfg = null


func test_a_map_with_only_ramps_draws_nothing_and_one_on_terrain_its_ground() -> void:
	var woodland := OldWoodland.load_map(MapStyle.new(), 1)
	assert_true(MinimapField.drawn(woodland), "its terrain is its ground")
	var drawn := MinimapField.build(woodland, cfg)
	assert_eq(drawn.layers.size(), 1)
	# Sloping ground is its own picture under the layer (FM2), the layer clear over it.
	assert_eq(drawn.layers[0].get_pixelv(Vector2i(drawn.pixel_of(-20.0, 5.0))).a, 0.0)
	var share := (drawn.pixel_of(-20.0, 5.0) - drawn.ground_rect.position) / drawn.ground_rect.size
	var meadow := drawn.ground.get_pixelv(Vector2i(share * Vector2(drawn.ground.get_size())))
	var want := cfg.ground_colour
	# The ground is tinted by its surface and shaded by its slope and height (FM2), so near the plain ground, its alpha
	# kept (an image keeps a colour in bytes), and nothing like a wall's.
	var near := cfg.ground_tint_share + cfg.relief_shade + cfg.relief_height
	assert_lt(Vector3(meadow.r - want.r, meadow.g - want.g, meadow.b - want.b).length(), near,
			"open meadow draws as ground: %s" % meadow)
	assert_almost_eq(meadow.a, want.a, 0.01)
	assert_lt(meadow.get_luminance(), cfg.low_colour.get_luminance(), "darker than cover")
	woodland.terrain = null
	assert_false(MinimapField.drawn(woodland), "its roof ramps alone are no field")
	assert_true(MinimapField.build(woodland, cfg).layers.is_empty())
	var ramp := _field([_blk("ramp", 0, 0.5, 0, 4, 1, 4, "+x")])
	assert_true(ramp.layers.is_empty(), "a ramp alone is not a floor")


func test_a_block_starting_exactly_at_storey_cut_is_kept() -> void:
	cfg.storey_cut = 2.0
	var f := _field([_blk("floor", 0, -0.25, 0, 20, 0.5, 20), _blk("wall", -5, 2.5, 0, 1, 1, 1),
			_blk("wall", 5, 3.75, 0, 1, 3, 1)], [0, 3])
	assert_colour(f, 0, -5.0, 0.0, cfg.tall_colour, "starts at 2.0 m, not more than the cut: drawn")
	assert_colour(f, 0, 5.0, 0.0, cfg.ground_colour, "starts at 2.25 m, over the cut: left out")
	assert_colour(f, 1, 5.0, 0.0, cfg.tall_colour, "it is on the 3 m storey's own drawing")


func test_a_map_without_storeys_cuts_what_starts_high() -> void:
	var f := _field([_blk("floor", 0, -0.25, 0, 20, 0.5, 20), _blk("wall", -5, 2.25, 0, 1, 1.5, 1),
			_blk("wall", 5, 2.5, 0, 1, 1, 1)])
	assert_colour(f, 0, -5.0, 0.0, cfg.tall_colour, "a wall from 1.5 m up is drawn")
	assert_colour(f, 0, 5.0, 0.0, cfg.ground_colour, "a lintel from 2.0 m up is left out of the one image")


func test_storey_of_flips_exactly_at_storey_pick_below_the_floor() -> void:
	var f := _field([_blk("floor", 0, -0.25, 0, 20, 0.5, 20)], [0, 3, 6])
	assert_eq(f.storey_of(2.5), 1, "pick below the 3 m floor is on it")
	assert_eq(f.storey_of(2.4999), 0)
	assert_eq(f.storey_of(5.5), 2)
	assert_eq(f.storey_of(5.4999), 1)
	assert_eq(f.storey_of(-100.0), 0)
	assert_eq(f.storey_of(100.0), 2)


func test_a_wall_top_at_the_pick_band_is_ground_and_one_below_it_is_washed() -> void:
	# Storey 1 (floor 3 m, pick 0.5): tops 3.5 and 2.5 are in the band; 3.75 is cover; 2.25 is below.
	var f := _field([_blk("floor", 0, -0.25, 0, 20, 0.5, 20), _blk("wall", -6, 1.75, 0, 1, 3.5, 1),
			_blk("wall", -3, 1.875, 0, 1, 3.75, 1), _blk("wall", 0, 1.25, 0, 1, 2.5, 1),
			_blk("wall", 3, 1.125, 0, 1, 2.25, 1)], [0, 3])
	var washed_tall := cfg.tall_colour.blend(cfg.below_storey_colour)
	assert_colour(f, 1, -6.0, 0.0, cfg.ground_colour, "top at floor + pick: ground there")
	assert_colour(f, 1, -3.0, 0.0, cfg.low_colour, "a hair over it: 0.75 m of cover from the floor")
	assert_colour(f, 1, 0.0, 0.0, cfg.ground_colour, "top at floor - pick is not below: drawn as ground, unwashed")
	assert_colour(f, 1, 3.0, 0.0, washed_tall, "a hair under it is below: its own look, washed")


func test_pixels_line_up_with_the_block_and_north_is_up() -> void:
	# Floor -5..5 on both axes at 10 px/m; a wall x -3..-2, z -4..-3: columns 20..29, rows 10..19.
	var f := _field([_blk("floor", 0, -0.25, 0, 10, 0.5, 10), _blk("wall", -2.5, 1.5, -3.5, 1, 3, 1),
			_blk("wall", 2.5, 1.5, 0, 0.92, 3, 1)])
	var img := f.layers[0]
	assert_eq(img.get_size(), Vector2i(100, 100))
	for row: int in [9, 10, 19, 20]:
		for col: int in [19, 20, 29, 30]:
			var inside := row in [10, 19] and col in [20, 29]
			var want := cfg.tall_colour if inside else cfg.ground_colour
			var got := img.get_pixel(col, row)
			assert_true(_near(got, want), "pixel (%d, %d) %s, want %s" % [col, row, got, want])
	# x 2.04..2.96 is 70.4..79.6 px: the pixels whose middle it holds, 70 to 79.
	assert_true(_near(img.get_pixel(70, 50), cfg.tall_colour) and _near(img.get_pixel(79, 50), cfg.tall_colour))
	assert_true(_near(img.get_pixel(69, 50), cfg.ground_colour) and _near(img.get_pixel(80, 50), cfg.ground_colour))
	assert_eq(f.pixel_of(-3.0, -4.0), Vector2(20, 10), "the wall's north west corner")
	assert_eq(f.pixel_of(5.0, 5.0), Vector2(100, 100), "the far corner is the image's size")


func test_a_long_thin_field_is_capped_on_its_long_side_and_drawn_to_its_end() -> void:
	var f := _field([_blk("floor", 0, -0.25, 0, 1, 0.5, 3000), _blk("wall", 0, 1.5, 1499.5, 1, 3, 1)])
	var img := f.layers[0]
	assert_eq(img.get_height(), cfg.max_layer_side, "z is the long side")
	assert_gte(img.get_width(), 1)
	assert_lt(f.scale, cfg.layer_scale)
	assert_true(_near(img.get_pixel(0, img.get_height() - 1), cfg.tall_colour), "the far end's wall reaches the edge")
	assert_true(_near(img.get_pixel(0, 0), cfg.ground_colour), "the near end is ground")


func test_the_painter_goes_by_top_then_floors_first_not_by_the_files_order() -> void:
	var tall := _blk("wall", 0, 1.5, 0, 2, 3, 2)
	var low := _blk("barrier", 0, 0.5, 0, 2, 1, 2)
	var ground := _blk("floor", 0, -0.25, 0, 10, 0.5, 10)
	assert_colour(_field([ground, tall, low]), 0, 0.0, 0.0, cfg.tall_colour, "the taller wins listed first")
	assert_colour(_field([ground, low, tall]), 0, 0.0, 0.0, cfg.tall_colour, "and listed last")
	# A crate (top 1.0) over the edge of a raised floor whose top is also 1.0: the floor is drawn first either way.
	var dock := _blk("floor", 2, 0.75, 0, 4, 0.5, 4)
	var crate := _blk("crate", 2, 0.5, 0, 2, 1, 2)
	assert_colour(_field([ground, crate, dock]), 0, 2.0, 0.0, cfg.low_colour, "a crate listed before its floor")
	assert_colour(_field([ground, dock, crate]), 0, 2.0, 0.0, cfg.low_colour, "and after it")


func test_the_rim_is_missing_beside_an_equal_floor_and_there_over_a_gap() -> void:
	# Docks A (x -10..-2) and B (x -2..6) of one height, listed B first so A's rim is drawn over B if it were wrong; and
	# C (x 8..12) with an empty gap between B and C.
	var f := _field([_blk("floor", 2, 0.25, 0, 8, 0.5, 6), _blk("floor", -6, 0.25, 0, 8, 0.5, 6),
			_blk("floor", 10, 0.25, 0, 4, 0.5, 6)])
	assert_colour(f, 0, -1.85, 0.0, cfg.raised_colour, "no rim where an equal floor meets A's edge")
	assert_colour(f, 0, 6.15, 0.0, cfg.drop_colour, "the rim over the gap beside B")
	assert_colour(f, 0, 7.0, 0.0, Color(0, 0, 0, 0), "past the rim the gap is empty")


func test_a_ramp_flush_with_a_dock_leaves_the_docks_edge_unrimmed() -> void:
	var f := _field([_blk("floor", 0, -0.25, 0, 20, 0.5, 20), _blk("floor", 5, 0.25, 0, 10, 0.5, 4),
			_blk("ramp", -1.2, 0.25, 0, 2.4, 0.5, 4, "+x")])
	assert_colour(f, 0, -0.1, 0.0, cfg.ramp_colour, "the ramp's top end beside the dock")
	assert_colour(f, 0, 3.0, 2.1, cfg.drop_colour, "the dock's long side drops to the ground")
	assert_colour(f, 0, 3.0, 1.8, cfg.raised_colour, "the dock inside its rim")


func test_the_rim_marks_only_a_drop_of_more_than_raised_floor() -> void:
	var low_step := _field([_blk("floor", 0, 0.125, 0, 20, 0.25, 20), _blk("floor", 5, 0.25, 0, 4, 0.5, 4)])
	assert_colour(low_step, 0, 5.0, 2.15, cfg.ground_colour, "a 0.25 m step down: no rim")
	var high_step := _field([_blk("floor", 0, 0.0625, 0, 20, 0.125, 20), _blk("floor", 5, 0.25, 0, 4, 0.5, 4)])
	assert_colour(high_step, 0, 5.0, 2.15, cfg.drop_colour, "a 0.375 m step down: rim")


func test_malformed_maps_build_nothing_and_do_not_crash() -> void:
	var texts: Array[String] = ["[]", "{}", "not json", '{"blocks": 3}', '{"blocks": [4, {"kind": "floor"}]}',
			JSON.stringify({"blocks": [_blk("wall", 0, 1.5, 0, 2, 3, 2)]}),
			JSON.stringify({"blocks": [_blk("floor", 0, 0, 0, 0, 0.5, 0)]})]
	for text: String in texts:
		var map := MapData.parse(text, MapStyle.new(), 1)
		var f := MinimapField.build(map, cfg)
		assert_true(f.layers.is_empty(), "no layers for " + text.left(40))
		assert_eq(f.storey_of(1.0), 0)
		assert_eq(f.byte_size(), 0)


func test_a_bad_storey_list_still_gives_a_drawing() -> void:
	var f := _field([_blk("floor", 0, -0.25, 0, 10, 0.5, 10)], [0, 0, -1, "high", 3])
	assert_eq(f.layers.size(), 2, "only 0 and 3 are heights")
	assert_eq(f.floors, PackedFloat64Array([0.0, 3.0]))
	assert_eq(_field([_blk("floor", 0, -0.25, 0, 10, 0.5, 10)], [0]).layers.size(), 1, "a list of one is one image")


func test_every_layer_is_freed_with_its_field() -> void:
	var map := TowerBlock.load_map(MapStyle.new(), 1)
	var f := MinimapField.build(map, cfg)
	var held: Array[WeakRef] = []
	for img: Image in f.layers:
		held.append(weakref(img))
	assert_eq(held.size(), 3)
	f = null
	for w: WeakRef in held:
		assert_null(w.get_ref(), "a layer outlived its field")


func _blk(kind: String, x: float, y: float, z: float, sx: float, sy: float, sz: float, rise: String = "") -> Dictionary:
	var d := {"kind": kind, "center": {"x": x, "y": y, "z": z}, "size": {"x": sx, "y": sy, "z": sz}}
	if not rise.is_empty():
		d["rise"] = rise
	return d


func _field(blocks: Array, storeys: Array = []) -> MinimapField:
	var map := MapData.parse(JSON.stringify({"blocks": blocks, "storeys": storeys}), MapStyle.new(), 1)
	return MinimapField.build(map, cfg)


func _near(got: Color, want: Color) -> bool:
	return maxf(maxf(absf(got.r - want.r), absf(got.g - want.g)), maxf(absf(got.b - want.b), absf(got.a - want.a))) \
			<= TOLERANCE


func assert_colour(f: MinimapField, layer: int, x: float, z: float, want: Color, what: String) -> void:
	var got := f.layers[layer].get_pixelv(Vector2i(f.pixel_of(x, z).floor()))
	assert_true(_near(got, want), "%s (at %.2f, %.2f storey %d: %s, want %s)" % [what, x, z, layer, got, want])
