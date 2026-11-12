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
	assert_eq(view.materials().size(), 4)


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


func test_subway_s_lifts_are_drawn_in_their_models() -> void:
	var cfg := play.lifts
	var car := PropDressConfig.load_mesh(cfg.car_model)
	assert_not_null(car, "the car model is read")
	var landings := view.get_node_or_null(^"Landings") as MultiMeshInstance3D
	assert_not_null(landings, "the landings' doorways drawn")
	var stops := 0
	for i in map.lifts.size():
		stops += map.lifts[i].stop_count()
		var body := view.get_node(NodePath("Car%d/Body" % i)) as MeshInstance3D
		assert_eq(body.mesh.get_aabb(), car.get_aabb(), "car %d is the model" % i)
		# The model's door (-z) turned to face the lift's door.
		var spec := map.lifts[i]
		var facing := body.basis * Vector3.FORWARD
		assert_almost_eq(facing, Vector3(spec.out.x, 0.0, spec.out.y), Vector3.ONE * 0.001, "facing its door")
	if landings != null:
		assert_eq(landings.multimesh.instance_count, stops, "one doorway a stop")
	var buttons := view.get_node(^"Buttons") as MultiMeshInstance3D
	assert_almost_eq(buttons.multimesh.mesh.get_aabb().size, cfg.button_size, Vector3.ONE * 0.001,
			"the button model at the button's size")


func test_a_lift_unlike_the_model_keeps_plain_boxes() -> void:
	var cfg: LiftViewConfig = play.lifts.duplicate()
	cfg.model_well = Vector2(3.0, 3.0)
	var odd := LiftView.build(map, MapStyle.new(), tuning.lifts, cfg)
	add_child(odd)
	var car := PropDressConfig.load_mesh(cfg.car_model)
	var body := odd.get_node(^"Car0/Body") as MeshInstance3D
	assert_ne(body.mesh.get_aabb(), car.get_aabb(), "a box body")
	assert_null(odd.get_node_or_null(^"Landings"), "no doorways")
	odd.free()


func test_lit_arrows_share_the_landings_transforms() -> void:
	var landings := view.get_node(^"Landings") as MultiMeshInstance3D
	var lights := view.get_node_or_null(^"LandingLights") as MultiMeshInstance3D
	assert_not_null(lights, "the lit arrows are drawn")
	if lights == null:
		return
	assert_eq(lights.multimesh.instance_count, landings.multimesh.instance_count, "one set a landing")
	for j in landings.multimesh.instance_count:
		assert_eq(lights.multimesh.get_instance_transform(j), landings.multimesh.get_instance_transform(j),
				"arrows %d sit on their landing" % j)
	var lit := MapStyle.new().colour_of(LiftView.LIT_KIND, 0)
	var g: float = play.lifts.landing_lit_gain
	assert_true(lights.multimesh.use_colors, "instance colours on")
	if DisplayServer.get_name() == "headless":
		pass_test("the dummy renderer keeps no instance data to read back; colours need a display")
		return
	for j in lights.multimesh.instance_count:
		var c := lights.multimesh.get_instance_color(j)
		assert_almost_eq(c.r, lit.r * g, 0.01, "glow red %d" % j)
		assert_almost_eq(c.g, lit.g * g, 0.01, "glow green %d" % j)
		assert_almost_eq(c.b, lit.b * g, 0.01, "glow blue %d" % j)
		assert_eq(c.a, 1.0, "opaque %d" % j)


func test_a_missing_lit_model_still_builds_without_arrows() -> void:
	var cfg: LiftViewConfig = play.lifts.duplicate()
	cfg.landing_lit_model = ""
	var bare := LiftView.build(map, MapStyle.new(), tuning.lifts, cfg)
	add_child(bare)
	assert_not_null(bare.get_node_or_null(^"Landings"), "the landings are still drawn")
	assert_null(bare.get_node_or_null(^"LandingLights"), "no arrows")
	bare.free()


func test_the_lit_arrows_are_freed_with_the_view() -> void:
	var lights := view.get_node(^"LandingLights") as MultiMeshInstance3D
	var ref: WeakRef = weakref(lights)
	view.free()
	view = LiftView.build(map, MapStyle.new(), tuning.lifts, play.lifts)
	add_child(view)
	assert_null(ref.get_ref(), "freed with its view")
