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
