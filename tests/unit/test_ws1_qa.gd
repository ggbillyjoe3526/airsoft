extends GutTest
## QA for WS1 (the stream in Woodland's dry bed): the stream's edges and ends, maps with no water, a splash in a bush,
## a BB that passes over or lands beside the water, the treeline with variants missing, and the spruce scatter.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style


func _line(level: float = 0.5, half: float = 2.0) -> Water:
	var w := Water.new()
	w.add(PackedVector3Array([Vector3(0.0, level, 0.0), Vector3(10.0, level, 0.0)]), half)
	return w


func test_water_reaches_exactly_its_half_width_and_rounds_off_at_its_ends() -> void:
	var w := _line()
	assert_false(is_nan(w.level_at(5.0, 2.0)), "exactly the half width is in")
	assert_true(is_nan(w.level_at(5.0, 2.001)), "past it is out")
	assert_false(is_nan(w.level_at(-2.0, 0.0)), "the end reaches its half width along the line")
	assert_true(is_nan(w.level_at(-1.5, 1.5)), "but the corner of its box is dry: the end is round")
	assert_false(is_nan(w.level_at(11.9, 0.0)))


func test_a_stream_with_a_repeated_point_has_no_nan_and_the_nearest_stream_wins() -> void:
	var w := Water.new()
	assert_true(w.add(PackedVector3Array([Vector3(0.0, 0.4, 0.0), Vector3(0.0, 0.4, 0.0), Vector3(4.0, 0.4, 0.0)]), 1.0))
	assert_almost_eq(w.level_at(0.0, 0.5), 0.4, 1e-5, "a zero length segment divides by nothing")
	assert_true(w.add(PackedVector3Array([Vector3(0.0, 0.9, 1.2), Vector3(4.0, 0.9, 1.2)]), 1.0))
	assert_almost_eq(w.level_at(2.0, 0.3), 0.4, 1e-5, "nearer the first stream")
	assert_almost_eq(w.level_at(2.0, 0.9), 0.9, 1e-5, "nearer the second")
	assert_false(is_nan(w.depth_at(Vector3(2.0, 0.0, 0.5))))


func test_depth_is_never_negative_or_nan_far_off_or_far_below() -> void:
	var w := _line()
	for p: Vector3 in [Vector3(1e6, 0.0, 1e6), Vector3(5.0, -1e4, 0.0), Vector3(5.0, 1e4, 0.0), Vector3(5.0, 0.0, 0.0)]:
		var d := w.depth_at(p)
		assert_false(is_nan(d))
		assert_gte(d, 0.0)


func test_maps_without_water_have_none_and_their_routes_are_priced_as_before() -> void:
	for id: String in ["depot", "subway", "range"]:
		var m := MapData.load_map(id, style, 6)
		assert_true(m.water.is_empty(), "%s has no stream" % id)
		var nav := NavGrid.build(m, tuning.nav, tuning.body)
		var dear := tuning.nav.duplicate() as NavConfig
		dear.wade_cost = 50.0
		dear.splash_cost = 20.0
		var other := NavGrid.build(m, dear, tuning.body)
		assert_eq(nav.floor_y, other.floor_y, "%s: the water prices change nothing" % id)
		var a := m.ends[0].spawns[0].position
		var b := m.ends[1].spawns[0].position
		var r1 := PackedVector3Array()
		var r2 := PackedVector3Array()
		assert_eq(nav.find_route(a, b, r1), other.find_route(a, b, r2))
		assert_eq(r1, r2, "%s: the same route whatever wading costs" % id)


func test_a_splash_in_a_bush_is_a_splash_not_leaves() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(80.0, 0.5, 80.0), RayHit.Surface.EARTH)
	w.add_stream(PackedVector3Array([Vector3(0.0, 0.3, -40.0), Vector3(0.0, 0.3, 40.0)]), 4.0)
	var events := SimEvents.new()
	var c := Character.new(0, 0, Vector3(0.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.in_bush = true
	c.in_water = true
	c.prev_position = Vector3(0.0, 0.0, 0.5)
	c.step_distance = 100.0
	Footsteps.step(c, tuning.footsteps, events, w, tuning.noise)
	assert_gt(events.count, 0)
	assert_eq(events.items[0].value2, RayHit.Surface.WATER, "water, not leaves")
	assert_gte(events.items[0].carry, tuning.noise.carry(RayHit.Surface.WATER), "heard as far as a splash")


func test_a_grazing_bb_lands_as_water_in_the_stream_and_as_earth_short_of_it() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(80.0, 0.5, 80.0), RayHit.Surface.EARTH)
	w.add_stream(PackedVector3Array([Vector3(0.0, 0.3, -40.0), Vector3(0.0, 0.3, 40.0)]), 4.0)
	var pool := BBPool.new(4)
	# Grazing: 1 m above the bank, 20 m from the stream, nearly level.
	pool.spawn(0, Vector3(20.0, 0.5, 0.0), Vector3(-1.0, -0.02, 0.0).normalized(), 40.0, 0.0, 0.25e-3, 0.0)
	pool.spawn(0, Vector3(9.5, 0.5, 5.0), Vector3(-1.0, -0.02, 0.0).normalized(), 40.0, 0.0, 0.25e-3, 0.0)
	var events := SimEvents.new()
	var ends: Array[MapEnd] = []
	var people: Array[Character] = []
	var seen_water := false
	var seen_bank := false
	var impacts := 0
	for i in 120:
		BBStep.step(pool, people, w, tuning, -10.0, false, ends, events, DT)
		for j in events.count:
			if events.items[j].kind == GameEvent.Kind.BB_IMPACT:
				impacts += 1
				if events.items[j].value2 == RayHit.Surface.WATER:
					seen_water = true
					assert_between(events.items[j].position.x, -2.0, 2.0, "a splash only inside the stream")
				else:
					seen_bank = true
					assert_gt(events.items[j].position.x, 2.0, "short of the stream it is the bank's")
		events.clear()
	assert_gt(impacts, 0, "it came down somewhere")
	assert_true(seen_water, "it came down in the stream and splashed")
	assert_true(seen_bank, "and the other landed on the bank")


func test_a_bb_landing_on_a_deck_over_the_water_is_the_decks_not_a_splash() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(80.0, 0.5, 80.0), RayHit.Surface.EARTH)
	w.add_box(Vector3(0.0, 0.9, 0.0), Vector3(6.0, 0.2, 6.0), RayHit.Surface.WOOD)
	w.add_stream(PackedVector3Array([Vector3(0.0, 0.3, -40.0), Vector3(0.0, 0.3, 40.0)]), 4.0)
	var pool := BBPool.new(4)
	var bb := pool.spawn(0, Vector3(0.5, 2.0, 0.0), Vector3.DOWN, 40.0, 0.0, 0.25e-3, 0.0)
	var events := SimEvents.new()
	var ends: Array[MapEnd] = []
	var people: Array[Character] = []
	var surface := -1
	for i in 30:
		BBStep.step(pool, people, w, tuning, -10.0, false, ends, events, DT)
		for j in events.count:
			if events.items[j].kind == GameEvent.Kind.BB_IMPACT and surface < 0:
				surface = events.items[j].value2
		events.clear()
	assert_ne(surface, -1, "it landed")
	assert_ne(surface, RayHit.Surface.WATER, "on the deck's wood, not the stream under it")
	assert_not_null(bb)


func test_footsteps_on_a_world_with_no_water_object_still_work() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(80.0, 0.5, 80.0), RayHit.Surface.GRAVEL)
	w.water = null
	var events := SimEvents.new()
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.prev_position = Vector3(0.0, 0.0, 0.5)
	c.step_distance = 100.0
	Footsteps.step(c, tuning.footsteps, events, w, tuning.noise)
	assert_gt(events.count, 0)
	assert_eq(events.items[0].value2, RayHit.Surface.GRAVEL)


func test_the_band_stands_without_its_variants_and_keeps_the_main_model() -> void:
	var play := PlayTuning.load_default()
	var cfg := play.skyline.duplicate() as SkylineConfig
	var full := cfg.treeline_meshes()
	assert_gt(full.size(), 1, "the main model and the variants that load")
	var none := play.skyline.duplicate() as SkylineConfig
	none.treeline_variants = PackedStringArray(["res://assets/models/skyline/nope.glb", ""])
	var only := none.treeline_meshes()
	assert_eq(only.size(), 1, "variants that won't load are left out")
	var empty := play.skyline.duplicate() as SkylineConfig
	empty.treeline_variants = PackedStringArray()
	assert_eq(empty.treeline_meshes().size(), 1)
	var map := MapData.load_map("woodland", play.map_style, 1)
	var middle := SkylineView.middle_of(map)
	for p in map.skyline:
		if p.kind == &"treeline":
			assert_gt(SkylineModels.placed_of(p, none, middle).size(), 0, "a band without variants still stands")
			assert_gt(SkylineModels.placed_of(p, empty, middle).size(), 0)
	var gone := play.skyline.duplicate() as SkylineConfig
	gone.treeline_model = ""
	assert_eq(gone.treeline_meshes().size(), 0, "no main model, no sections: the cones stand")


func test_the_band_is_the_same_every_build_and_uses_more_than_one_section() -> void:
	var play := PlayTuning.load_default()
	var map := MapData.load_map("woodland", play.map_style, 1)
	var middle := SkylineView.middle_of(map)
	for p in map.skyline:
		if p.kind != &"treeline":
			continue
		var a := SkylineModels.placed_of(p, play.skyline, middle)
		var b := SkylineModels.placed_of(p, play.skyline, middle)
		assert_eq(a.size(), b.size())
		var kinds := {}
		for i in a.size():
			assert_eq(a[i].at, b[i].at, "seeded: the same every build")
			kinds[a[i].mesh] = true
		if a.size() >= 6:
			assert_gt(kinds.size(), 1, "a long band is not one section repeated")


func test_zero_treeline_rise_and_shift_do_not_flatten_or_break_a_band() -> void:
	var play := PlayTuning.load_default()
	var cfg := play.skyline.duplicate() as SkylineConfig
	cfg.treeline_rise = Vector2(1.0, 1.0)
	cfg.treeline_shift = 0.0
	var map := MapData.load_map("woodland", play.map_style, 1)
	var middle := SkylineView.middle_of(map)
	for p in map.skyline:
		if p.kind == &"treeline":
			for one in SkylineModels.placed_of(p, cfg, middle):
				assert_false(is_nan(one.at.origin.x + one.at.origin.z))
				assert_gt(one.at.basis.y.length(), 0.0)
