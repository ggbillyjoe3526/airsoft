extends GutTest
## DX1 QA: a map's own `dressing.fixtures` (Depot, no station) read tolerantly, drawn without a station or lamps,
## and handled by GraphicsApply.apply_station.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _depot_with(fixtures: Variant) -> MapData:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/depot.json"))
	(d["dressing"] as Dictionary)["fixtures"] = fixtures
	return MapData.parse(JSON.stringify(d), play.map_style, tuning.rounds.team_size)


func test_a_malformed_dressing_fixtures_is_warned_about_and_left_out() -> void:
	for bad: Variant in ["nope", 7, null, {}]:
		var m := _depot_with(bad)
		assert_not_null(m, "depot still loads")
		assert_eq(m.fixtures.size(), 0, "%s gives no fixtures" % str(bad))
		assert_null(StationFixtures.build(m, play.station_fixtures))
	var m2 := _depot_with([
		{"model": "fire_point", "x": 1, "y": 1, "z": 1, "yaw": 0}, {"model": "fire_point"}, 3])
	assert_eq(m2.fixtures.size(), 1)
	var bad_count := 0
	for w in m2.warnings:
		if w.begins_with("dressing.fixtures "):
			bad_count += 1
	assert_eq(bad_count, 2, "each bad entry warned under dressing.fixtures")


func test_depot_fixtures_draw_with_no_station_and_no_lamps_and_apply_station_copes() -> void:
	var m := _depot_with([{"model": "fire_point", "x": 1, "y": 1, "z": 1, "yaw": 0, "scale": 1.0}])
	assert_null(m.station, "depot has no station")
	var view := StationFixtures.build(m, play.station_fixtures)
	assert_not_null(view)
	if view == null:
		return
	add_child_autofree(view)
	assert_eq(view.lamps().size(), 0, "no lit model, no lamp")
	var values := GraphicsQuality.new()
	GraphicsApply.apply_station(values, null, view)
	GraphicsApply.apply_station(values, null, null)
	assert_gt(view.materials().size(), 1)


func test_only_unknown_models_build_nothing() -> void:
	var m := _depot_with([{"model": "no_such", "x": 0, "y": 0, "z": 0, "yaw": 0}])
	assert_null(StationFixtures.build(m, play.station_fixtures))


func _depot() -> MapData:
	return MapData.load_map("depot", play.map_style, tuning.rounds.team_size)


func test_every_bay_variant_of_each_new_model_is_laid_on_depot() -> void:
	var cfg: PropDressConfig = play.site_look.props
	var depot := _depot()
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in cfg.models:
		var mesh := cfg.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	var all := PropLayout.layout(depot, cfg, boxes)
	for base: StringName in [&"wrapped_racking", &"drum_ibc_stack", &"parts_cage"]:
		for bay in cfg.variants_of(base):
			assert_true(all.has(bay), "%s is laid on Depot" % bay)
			if all.has(bay):
				assert_gt((all[bay] as PropLayout.Placed).transforms.size(), 0, "%s has bays" % bay)


func test_the_third_pipe_length_is_placed_and_drawn_in_its_own_chunks() -> void:
	var depot := _depot()
	var n := 0
	for f in depot.fixtures:
		if f.model == &"pipe_run_b":
			n += 1
	assert_gt(n, 0, "Depot has a fitted length")
	assert_eq(play.station_fixtures.chunks.get(&"pipe_run_b", 0.0), 40.0)
	var view := StationFixtures.build(depot, play.station_fixtures)
	assert_not_null(view)
	if view == null:
		return
	add_child_autofree(view)
	var drawn := 0
	var names: Dictionary = {}
	for v in view.views():
		assert_false(names.has(v.name), "node name %s is unique" % v.name)
		names[v.name] = true
		if String(v.name).begins_with("PipeRunBChunk"):
			drawn += v.multimesh.instance_count
			assert_lte(v.multimesh.get_aabb().size.x, 44.5, "a chunk, not the hall")
	assert_eq(drawn, n, "every fitted length drawn once, in chunks")


func test_signs_hang_at_eye_height_and_stand_clear_in_front() -> void:
	var depot := _depot()
	var seen := 0
	for f in depot.fixtures:
		if not String(f.model).begins_with("depot_sign_"):
			continue
		seen += 1
		assert_between(f.position.y, 1.2, 2.0, "%s at %s is at eye height" % [f.model, f.position])
		# a sign faces +z in its own frame; 0.6 m out from it nothing solid stands
		var front := f.position + Vector3(0, 0, 0.6).rotated(Vector3.UP, f.yaw)
		var probe := AABB(front - Vector3(0.1, 0.1, 0.1), Vector3(0.2, 0.2, 0.2))
		for b in depot.blocks:
			if b.kind == &"pillar" or b.kind == &"floor":
				continue
			assert_false(AABB(b.center - b.size * 0.5, b.size).intersects(probe), "%s at %s is blocked in front" % [f.model, f.position])
	assert_gt(seen, 5, "Depot has its signs")


func test_nothing_still_names_the_removed_cable_reel() -> void:
	var depot := _depot()
	for f in depot.fixtures:
		assert_ne(f.model, &"cable_reel")
	assert_false(play.station_fixtures.models.has("cable_reel"))
	assert_false(FileAccess.get_file_as_string("res://data/maps/depot.json").contains("cable_reel"))
