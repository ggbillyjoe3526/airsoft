extends GutTest
## The second audit's graphics fixes on Subway and the lamps (AUD2, gfxa): a station's lights are put on by one
## helper (GraphicsApply.apply_station) that the match and the eye pictures both call, so the pictures light the
## running tunnels' lamps and the lift cars as a match does.

var tuning: SimTuning = SimTuning.new()
var play: PlayTuning = PlayTuning.new()
var map: MapData = null


func before_all() -> void:
	map = MapData.load_map("subway", MapStyle.new(), 6)


func _cars(lifts: LiftView) -> Array[Node]:
	return lifts.find_children("Car*", "Node3D", false, false)


func test_apply_station_lights_the_tunnel_lamps_and_the_cars_on_high_and_not_on_low() -> void:
	var lifts := LiftView.build(map, MapStyle.new(), tuning.lifts, play.lifts)
	var fixtures := StationFixtures.build(map, play.station_fixtures)
	add_child_autofree(lifts)
	add_child_autofree(fixtures)
	assert_gt(fixtures.lamps().size(), 0, "Subway's tunnel lamps have lights")
	assert_gt(_cars(lifts).size(), 0, "Subway has lift cars")
	var table := GraphicsTable.shared()
	GraphicsApply.apply_station(table.preset(&"high"), lifts, fixtures)
	for lamp in fixtures.lamps():
		assert_true(lamp.visible, "High: a tunnel lamp lights its arch")
	for car in _cars(lifts):
		assert_true((car.get_node("Lamp") as Node3D).visible, "High: the car's lamp lit")
		assert_true((car.get_node("Probe") as Node3D).visible, "High: the car's probe shown (Reflections: probes)")
	GraphicsApply.apply_station(table.preset(&"low"), lifts, fixtures)
	for lamp in fixtures.lamps():
		assert_false(lamp.visible, "Low: no lamp lights")
	for car in _cars(lifts):
		assert_false((car.get_node("Lamp") as Node3D).visible, "Low: the car's lamp unlit")
		assert_false((car.get_node("Probe") as Node3D).visible, "Low: no reflections")


func test_apply_station_takes_a_map_without_a_station() -> void:
	GraphicsApply.apply_station(GraphicsTable.shared().preset(&"high"), null, null)
	assert_true(true, "nothing to light, nothing done")


func test_the_eye_pictures_light_the_station_as_a_match_does() -> void:
	# The pictures built the tunnel lamps and the lifts but never switched them, so the running tunnels drew without
	# their lamps' light on High and Ultra (AUD2 row 20).
	var tool := FileAccess.get_file_as_string("res://tools/eye_pictures.gd")
	assert_string_contains(tool, "GraphicsApply.apply_station(values, lifts, station_fixtures)")
	var session := FileAccess.get_file_as_string("res://game/play/play_session.gd")
	assert_string_contains(session, "GraphicsApply.apply_station(values, _lifts, _station_fixtures)")


func test_the_eye_pictures_light_an_underground_field_and_dress_a_station_as_a_match_does() -> void:
	# Without set_underground the pictures lit Subway with the sky's ambient light, so its plant room's props, black in
	# a match on High, drew lit (AUD2 row 19); and they stood a model in every box, unpainted.
	var tool := FileAccess.get_file_as_string("res://tools/eye_pictures.gd")
	assert_string_contains(tool, "lighting.set_underground(map.roof_underground)")
	assert_string_contains(tool, "PropDress.build(map, cfg, play.site_look.prop_paint)")
	assert_string_contains(tool, "play.site_look.props.named_only() if station")


func test_no_roof_lamp_hangs_straight_over_a_tall_model_in_a_ceilinged_room() -> void:
	# Subway's plant room hung a lamp straight over each fan housing: every side of the housing turned away from its
	# lamp and lay past the other's reach, so the housings (and a booth stood there) drew near black in a match on
	# High while the walls and floor were lit (AUD2 row 19). tools/subway/build_map.py now hangs a lamp 1 m clear.
	var plant := AABB(Vector3(4.0, 8.8, -4.0), Vector3(14.0, 3.7, 8.0))
	var lamps := 0
	for i in map.roof_lamps.size():
		var spot := Vector3(map.roof_lamps[i].x, map.roof_lamp_heights[i] - 0.05, map.roof_lamps[i].y)
		if not plant.has_point(spot):
			continue
		lamps += 1
		for b in map.blocks:
			if b.dress == &"" or b.size.y < 1.5:
				continue
			var lo := b.center - b.size * 0.5
			var hi := b.center + b.size * 0.5
			var over := spot.x > lo.x - 1.0 + 1e-3 and spot.x < hi.x + 1.0 - 1e-3 and spot.z >= lo.z and spot.z <= hi.z
			assert_false(over and spot.y > hi.y, "the lamp at %s hangs clear of %s" % [spot, b.dress])
	assert_eq(lamps, 2, "the plant room keeps its two lamps")
