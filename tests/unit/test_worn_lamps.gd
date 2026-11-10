extends GutTest
## DW1: Depot's worn roof lamps (owner, 2026-11-10: "some lamps aren't as bright or they flicker or one that doesn't
## work", Depot only): the map names them, a dim one glows and lights less in a warmer colour, a dead one neither glows
## nor lights, a flickering one stutters now and then, the same every run; a map naming none is untouched.

var cfg: RoofConfig = RoofConfig.new()
var depot: MapData = null


func before_all() -> void:
	depot = MapData.load_map("depot", MapStyle.new(), 6)


func _roof(map: MapData) -> RoofView:
	var roof := RoofView.build(map, cfg)
	add_child_autofree(roof)
	return roof


func _first(state: int) -> int:
	return Array(depot.roof_lamp_states).find(state)


func test_depot_names_its_worn_lamps_and_only_depot() -> void:
	assert_eq(depot.roof_lamp_states.size(), depot.roof_lamps.size(), "a state for every lamp")
	assert_eq(depot.roof_lamp_states.count(MapData.LAMP_DIM), 12)
	assert_eq(depot.roof_lamp_states.count(MapData.LAMP_FLICKER), 3)
	assert_eq(depot.roof_lamp_states.count(MapData.LAMP_DEAD), 2)
	for id: String in ["woodland", "range"]:
		var other := MapData.load_map(id, MapStyle.new(), 6)
		if other != null:
			assert_eq(other.roof_lamp_states.count(MapData.LAMP_WORKING), other.roof_lamp_states.size(), id)


func test_a_dead_lamp_hangs_among_four_working_neighbours() -> void:
	var spacing := 7.0
	for i in depot.roof_lamps.size():
		if depot.roof_lamp_states[i] != MapData.LAMP_DEAD:
			continue
		var neighbours := 0
		for j in depot.roof_lamps.size():
			if j != i and depot.roof_lamps[i].distance_to(depot.roof_lamps[j]) <= spacing + 0.01:
				neighbours += 1
				assert_eq(depot.roof_lamp_states[j], MapData.LAMP_WORKING,
						"lamp %d next to dead lamp %d works, so the patch under it is filled" % [j, i])
		assert_eq(neighbours, 4, "dead lamp %d is not in an edge row" % i)


func test_an_unknown_state_is_a_working_lamp_with_a_warning() -> void:
	var text := FileAccess.get_file_as_string(MapData.DIR + "depot.json")
	var json: Dictionary = JSON.parse_string(text)
	(json["roof"]["lamps"] as Array)[0]["state"] = "sparkly"
	var map := MapData.parse(JSON.stringify(json), MapStyle.new(), 6)
	assert_eq(map.roof_lamp_states[0], MapData.LAMP_WORKING)
	assert_true(map.warnings.any(func(w: String) -> bool: return w.contains("sparkly")))


func test_a_dead_lamp_has_no_light_and_a_dark_lens() -> void:
	var roof := _roof(depot)
	var dead := _first(MapData.LAMP_DEAD)
	assert_null(roof.lamp_lights().light_of(dead))
	assert_eq(RoofView.lens_tint(MapData.LAMP_DEAD, cfg), Color(0, 0, 0))
	assert_eq(RoofView.lens_tint(MapData.LAMP_WORKING, cfg), Color.WHITE)
	assert_eq(RoofView.lens_tint(MapData.LAMP_FLICKER, cfg), Color.WHITE, "a flickering lens steps from full")
	# Headless, a MultiMesh reads back no instance data (the dummy renderer), so the lens tints are checked above.
	assert_true((roof.get_node("Lamps") as MultiMeshInstance3D).multimesh.use_custom_data)


func test_a_dim_lamp_glows_and_lights_less_in_a_warmer_colour() -> void:
	var lamps := _roof(depot).lamp_lights()
	var dim := lamps.light_of(_first(MapData.LAMP_DIM))
	var working := lamps.light_of(_first(MapData.LAMP_WORKING))
	assert_almost_eq(dim.light_energy, working.light_energy * cfg.lamp_dim_share, 0.001)
	assert_eq(dim.light_color, cfg.lamp_dim_colour)
	var tint := RoofView.lens_tint(MapData.LAMP_DIM, cfg)
	assert_lt(tint.get_luminance(), 0.75, "the lens glows less")
	assert_lt(tint.b, tint.r, "and warmer")


func test_a_flickering_lamp_is_dynamic_and_follows_its_steps() -> void:
	var roof := _roof(depot)
	var lamp := _first(MapData.LAMP_FLICKER)
	var spot := roof.lamp_lights().light_of(lamp)
	assert_eq(spot.light_bake_mode, Light3D.BAKE_DYNAMIC, "out of the baked bounce light, as it changes")
	roof.lamp_lights().set_flicker(lamp, cfg.lamp_flicker_low)
	assert_almost_eq(spot.light_energy, cfg.lamp_light_energy * cfg.lamp_flicker_low, 0.001)
	roof.lamp_lights().set_flicker(lamp, 1.0)
	assert_almost_eq(spot.light_energy, cfg.lamp_light_energy, 0.001)
	assert_true(roof.is_processing(), "the roof steps its flickering lamps")


func test_the_flicker_is_mostly_on_now_and_then_off_and_the_same_every_run() -> void:
	var on := 0
	var off := 0
	var differs := false
	for i in 6000:
		var t := i * 0.01
		var level := RoofView.flicker_level(t, 5, cfg)
		assert_true(is_equal_approx(level, 1.0) or is_equal_approx(level, cfg.lamp_flicker_low))
		assert_eq(level, RoofView.flicker_level(t, 5, cfg), "the same every call")
		if level == 1.0:
			on += 1
		else:
			off += 1
		if level != RoofView.flicker_level(t, 41, cfg):
			differs = true
	assert_gt(off, 0, "it stutters in a minute")
	assert_gt(on, off * 6, "but shines most of the time")
	assert_true(differs, "each lamp in its own rhythm")


func test_a_roof_without_worn_lamps_never_processes() -> void:
	var plain := MapData.load_map("depot", MapStyle.new(), 6)
	plain.roof_lamp_states.fill(MapData.LAMP_WORKING)
	var roof := _roof(plain)
	assert_false(roof.is_processing())
	assert_eq(roof.lamp_lights().light_count(), roof.lamp_count())
