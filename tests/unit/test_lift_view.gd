extends GutTest
## The lifts' view (MT2, game/play/lift_view.gd): built for Subway's two lifts (none for a map without), each car
## drawn where it waits and between ticks where it rides, a landing's leaves apart only at the car's stop while it
## stands open there, the car's leaves inside its front when open, the buttons lit while called, the lamps and probes
## switched.

var tuning: SimTuning = SimTuning.new()
var play: PlayTuning = PlayTuning.new()
var map: MapData = null
var view: LiftView = null


func before_all() -> void:
	map = MapData.load_map("subway", MapStyle.new(), 6)


func before_each() -> void:
	view = LiftView.build(map, MapStyle.new(), tuning.lifts, play.lifts)
	add_child(view)


func after_each() -> void:
	view.free()


func _lifts() -> LiftState:
	var lifts := LiftState.new()
	var n := map.lifts.size()
	lifts.y.resize(n)
	lifts.prev_y.resize(n)
	lifts.stop.resize(n)
	lifts.phase.resize(n)
	lifts.doors.resize(n)
	lifts.calls.resize(n)
	for i in map.lifts.size():
		var spec := map.lifts[i]
		lifts.stop[i] = spec.start
		lifts.y[i] = spec.stops[spec.start]
		lifts.prev_y[i] = lifts.y[i]
		lifts.doors[i] = 1.0
		lifts.phase[i] = LiftState.Phase.OPEN
	return lifts


## The level distance (along the door's face) of leaf `j` from its doorway's middle.
func _apart(spec: LiftSpec, j: int) -> float:
	var at := view.leaf_at(j).origin
	var mid := (spec.door_from + spec.door_to) * 0.5
	return absf((at.x if spec.along_x() else at.z) - mid)


func test_a_map_without_lifts_has_no_view() -> void:
	var depot := MapData.load_map("depot", MapStyle.new(), 6)
	assert_null(LiftView.build(depot, MapStyle.new(), tuning.lifts, play.lifts))


func test_each_car_starts_drawn_at_its_start_stop() -> void:
	for i in map.lifts.size():
		var spec := map.lifts[i]
		assert_almost_eq(view.drawn_y(i), spec.stops[spec.start], 0.001, spec.name)
	assert_eq(view.materials().size(), 3)


func test_a_riding_car_is_drawn_between_its_ticks() -> void:
	var lifts := _lifts()
	lifts.prev_y[0] = 10.0
	lifts.y[0] = 11.0
	lifts.phase[0] = LiftState.Phase.MOVING
	view.refresh(lifts, 0.25)
	assert_almost_eq(view.drawn_y(0), 10.25, 0.001)


func test_landing_leaves_part_only_at_the_open_stop_and_the_car_s_slide_into_its_front() -> void:
	var lifts := _lifts()
	view.refresh(lifts, 1.0)
	var spec := map.lifts[0]
	var w := spec.door_to - spec.door_from
	var stops := spec.stop_count()
	for k in stops:
		var open := k == spec.start
		assert_almost_eq(_apart(spec, k * 2), w * (0.75 if open else 0.25), 0.001, "stop %d's leaf" % k)
	assert_almost_eq(_apart(spec, stops * 2), w * 0.75, 0.001, "the car's leaf open")
	var inside := (view.leaf_at(stops * 2).origin - spec.on_face(0.0, 0.0, 0.0)) * Vector3(spec.out.x, 0.0, spec.out.y)
	assert_lt(inside.x + inside.z, 0.0, "the car's leaves stand inside its front")
	lifts.phase[0] = LiftState.Phase.MOVING
	view.refresh(lifts, 1.0)
	assert_almost_eq(_apart(spec, spec.start * 2), w * 0.25, 0.001, "shut while it rides")
	assert_almost_eq(_apart(spec, stops * 2), w * 0.25, 0.001)


func test_buttons_light_while_their_stop_is_called() -> void:
	var lifts := _lifts()
	lifts.calls[1] = 1 << 1
	view.refresh(lifts, 1.0)
	var style := MapStyle.new()
	var lit := style.colour_of(LiftView.LIT_KIND, 0)
	var unlit := style.colour_of(LiftView.BUTTON_KIND, 0)
	var first := map.lifts[0].stop_count() * 2
	var stops := map.lifts[1].stop_count()
	assert_eq(view.button_colour(first + 1), lit, "the east lift's concourse call")
	assert_eq(view.button_colour(first + stops + 1), lit, "and its panel's concourse button")
	assert_eq(view.button_colour(first), unlit)
	assert_eq(view.button_colour(1), unlit, "the west lift's isn't")
	lifts.calls[1] = 0
	view.refresh(lifts, 1.0)
	assert_eq(view.button_colour(first + 1), unlit, "out once answered")


func test_lamps_and_probes_switch() -> void:
	view.set_lamps(false)
	view.set_probes(false)
	for car in view.find_children("Car*", "Node3D", false, false):
		assert_false((car.get_node("Lamp") as Node3D).visible)
		assert_false((car.get_node("Probe") as Node3D).visible)
	view.set_lamps(true)
	view.set_probes(true)
	for car in view.find_children("Car*", "Node3D", false, false):
		assert_true((car.get_node("Lamp") as Node3D).visible)
		assert_true((car.get_node("Probe") as Node3D).visible)
