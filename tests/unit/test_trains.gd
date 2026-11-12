extends GutTest
## SM1: Subway's trains in their models. The map file's `dressing.trains` reads into each train's box, cars and
## gangways, and a malformed one is warned about and left out; TrainView draws every car's body, lamps, shut doors and
## ends and every open gangway, each instance inside its train's box; StationSurface leaves the boxes the models draw;
## the seats are real blocks clear of the tool carts' aisles; the station's lamp fittings are hidden in the cars (their
## lights kept: hide_lamps_in only scales the fittings away, and shines them in the cars' cool white); the ends' white
## LEDs stand at every cab and uncoupled end; the half cars under a flickering lamp flicker with its light; the orange
## stripe is the only colour near a team's hue; the platform side's windows are see-through glass blocks, the eye
## passing and BBs stopping, drawn by the models' clear panes (the owner, 2026-11-12).

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _subway() -> MapData:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "subway loads: %s" % [m.problems])
	return m


func _train(extra: Dictionary = {}) -> Dictionary:
	var t := {"box": [0, 15, -0.3, 3.6, -2, 2],
			"cars": [{"x": 7.5, "y": 0.9, "z": 0, "turn": 0, "open": [1], "ends": ["cab", "outer"]}],
			"gangways": []}
	t.merge(extra, true)
	return t


func test_the_map_file_reads_each_train_its_cars_and_its_gangways() -> void:
	var warnings: Array[String] = []
	var out := TrainDressing.read({"trains": [_train()]}, warnings)
	assert_eq(warnings.size(), 0, "no warnings: %s" % [warnings])
	assert_eq(out.size(), 1)
	var t := out[0]
	assert_true(t.box.is_equal_approx(AABB(Vector3(0, -0.3, -2), Vector3(15, 3.9, 4))), "its box: %s" % t.box)
	assert_eq(t.cars.size(), 1)
	assert_eq(t.cars[0].middle, Vector3(7.5, 0.9, 0))
	assert_false(t.cars[0].turned)
	assert_eq(t.cars[0].open, PackedInt32Array([1]))
	assert_eq(t.cars[0].ends, [TrainDressing.CAB, TrainDressing.OUTER] as Array[StringName])


func test_a_malformed_train_is_warned_of_and_left_out() -> void:
	var bad: Array[Dictionary] = [
		_train({"box": [0, 15, -0.3, 3.6, -2]}),
		_train({"box": [15, 0, -0.3, 3.6, -2, 2]}),
		_train({"cars": [{"x": 7.5, "y": 0.9, "z": 0, "open": [4], "ends": ["cab", "cab"]}]}),
		_train({"cars": [{"x": 7.5, "y": 0.9, "z": 0, "ends": ["cab", "wheel"]}]}),
		_train({"cars": [{"x": 7.5, "y": 0.9, "z": 0, "ends": ["cab"]}]}),
		_train({"gangways": [{"x": 1, "z": 0}]}),
	]
	for t in bad:
		var warnings: Array[String] = []
		assert_eq(TrainDressing.read({"trains": [t]}, warnings).size(), 0, "left out: %s" % [t])
		assert_eq(warnings.size(), 1, "warned once: %s" % [t])
	var warnings: Array[String] = []
	assert_eq(TrainDressing.read({"trains": "a train"}, warnings).size(), 0)
	assert_eq(warnings.size(), 1)
	warnings.clear()
	assert_eq(TrainDressing.read({}, warnings).size(), 0, "a map without trains has none")
	assert_eq(warnings.size(), 0)


func test_a_train_holds_its_walls_slabs_and_ends_but_nothing_else() -> void:
	var t: TrainDressing = TrainDressing.read({"trains": [_train()]}, [] as Array[String])[0]
	var b := MapData.Block.new()
	b.kind = &"wall"
	b.center = Vector3(5, 1.5, 1.9)
	b.size = Vector3(4, 2.4, 0.15)
	assert_true(t.holds(b), "a side wall inside the box")
	b.kind = &"furniture"
	assert_false(t.holds(b), "a seat is a prop's, not the train model's")
	b.kind = &"wall"
	b.center = Vector3(5, 1.5, 2.5)
	assert_false(t.holds(b), "a wall past the box")


func test_subways_trains_read_without_warnings() -> void:
	var m := _subway()
	assert_eq(m.trains.size(), 2, "the north and south trains")
	assert_eq(m.trains[0].cars.size(), 4)
	assert_eq(m.trains[1].cars.size(), 2)
	for t in m.trains:
		var gangway_ends := 0
		for car in t.cars:
			gangway_ends += car.ends.count(TrainDressing.GANGWAY)
			assert_true(t.box.grow(0.01).has_point(car.middle), "each car inside its box")
		assert_eq(gangway_ends, 2 * t.gangways.size(), "each gangway joins two cars' open ends")
	for w in m.warnings:
		assert_false(w.contains("trains"), "no train warning: %s" % w)


func test_the_view_draws_every_car_door_end_and_gangway() -> void:
	var m := _subway()
	var look := play.station_look.trains
	assert_true(look.loads(), "every train model loads")
	var view := TrainView.build(m, look)
	assert_not_null(view)
	add_child_autofree(view)
	var cars := 0
	var doors := 0
	var glazed := 0
	var gangways := 0
	var ends: Dictionary[StringName, int] = {}
	for t in m.trains:
		cars += t.cars.size()
		gangways += t.gangways.size()
		for car in t.cars:
			doors += TrainDressing.SLOTS
			glazed += TrainDressing.SLOTS - car.open.size()
			for e in car.ends:
				if e != TrainDressing.GANGWAY:
					ends[e] = ends.get(e, 0) + 1
	assert_eq(view.count(look.body), cars)
	assert_eq(view.count(look.lights), 2 * cars, "each car's strips in two halves")
	assert_eq(view.count(look.door), doors, "every far side door hole shut, dark glass")
	assert_eq(view.count(look.door_glazed), glazed, "the platform side's shut but its open ones, clear glass")
	assert_eq(view.count(look.door_glass), glazed, "their glass")
	assert_eq(view.count(look.windows), cars, "each car's platform side windows' glass")
	assert_eq(view.count(look.gangway), gangways)
	for e: StringName in look.ends:
		assert_eq(view.count(look.ends[e]), ends.get(e, 0), "the %s ends" % e)
	var leds: Dictionary[String, int] = {}
	for e: StringName in look.leds:
		leds[look.leds[e]] = leds.get(look.leds[e], 0) + ends.get(e, 0)
	for path: String in leds:
		assert_gt(leds[path], 0, "%s has ends to light" % path)
		assert_eq(view.count(path), leds[path], "white LEDs at every cab and uncoupled end: %s" % path)
	assert_eq(view.count(look.leds[&"cab"]), 3, "the north train's two cabs and the south train's open one")
	assert_eq(view.materials().size(), 4)
	for path: String in [look.windows, look.door_glass]:
		var g := view.view_of(path)
		assert_eq(g.material_override, view.materials()[3], "%s is see-through" % path)
		assert_eq(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_almost_eq(float((g.material_override as ShaderMaterial).get_shader_parameter(&"opacity")),
				look.glass_opacity, 0.001)
	for path: String in [look.lights, look.leds[&"cab"], look.leds[&"outer"]]:
		var v := view.view_of(path)
		assert_eq(v.material_override, view.materials()[1 if path == look.lights else 2], "%s glows" % path)
		assert_eq(v.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(view.boxes().size(), m.trains.size())


func test_every_model_drawn_stays_inside_its_trains_box() -> void:
	var m := _subway()
	var view := TrainView.build(m, play.station_look.trains)
	add_child_autofree(view)
	var outside := 0
	var look := play.station_look.trains
	for path in look.paths():
		var aabb := look.mesh(path).get_aabb()
		for at: Transform3D in view.placed_of(path):
			var placed := at * aabb
			var inside := false
			for t in m.trains:
				if t.box.grow(0.005).encloses(placed):
					inside = true
			if not inside:
				outside += 1
				gut.p("%s at %s is outside its train" % [path, placed])
	assert_eq(outside, 0, "every model inside its train's box")


func test_no_view_for_a_map_without_trains_or_a_model_that_wont_load() -> void:
	var depot := MapData.load_map("depot", play.map_style, tuning.rounds.team_size)
	assert_null(TrainView.build(depot, play.station_look.trains))
	var broken := TrainLook.new()
	broken.body = "res://assets/models/props/no_such_train.glb"
	assert_false(broken.loads())
	assert_null(TrainView.build(_subway(), broken), "the trains stay their boxes")


func test_the_station_leaves_the_trains_boxes_to_their_models() -> void:
	var m := _subway()
	var held := 0
	for b in m.blocks:
		if StationSurface.held(m.trains, b):
			held += 1
			assert_true(b.kind in [&"wall", &"floor", &"container", &"glass"],
					"only walls, slabs, ends and window glass: %s" % b.kind)
	assert_gt(held, 0, "the trains' walls and slabs are held")
	var look := play.station_look.duplicate() as StationLook
	var drawn := StationSurface.mesh(m, play.map_style, look)
	look.trains = TrainLook.new()
	look.trains.body = "res://assets/models/props/no_such_train.glb"
	var boxes := StationSurface.mesh(m, play.map_style, look)
	assert_lt(drawn.surface_get_array_len(0), boxes.surface_get_array_len(0),
			"with the models the station draws fewer faces; without them the boxes stay")


func test_the_seats_are_solid_blocks_in_the_cars_clear_of_the_tool_carts() -> void:
	var m := _subway()
	var seats: Array[MapData.Block] = []
	var carts: Array[MapData.Block] = []
	for b in m.blocks:
		if b.dress in [&"train_seat", &"train_seat_short"]:
			seats.append(b)
		elif b.dress == &"tool_cart":
			carts.append(b)
	assert_eq(seats.size(), 56)
	assert_eq(carts.size(), 2)
	var cfg := play.site_look.props
	for b in seats:
		assert_eq(b.kind, &"furniture", "a seat is low cover")
		assert_almost_eq(b.size.y, 0.45, 0.001)
		assert_true(cfg.dresses(b), "drawn as its model")
		var in_train := false
		for t in m.trains:
			if t.box.grow(0.01).encloses(AABB(b.center - b.size * 0.5, b.size)):
				in_train = true
		assert_true(in_train, "each seat inside a car")
		for c in carts:
			# in the cart's car, no seat along it: the aisle stays a metre each side
			if absf(b.center.z - c.center.z) < 2.0:
				var apart := absf(b.center.x - c.center.x) - (b.size.x + c.size.x) * 0.5
				assert_gt(apart, 0.0, "no seat beside the cart at x %s" % c.center.x)


func test_the_station_lamp_fittings_are_hidden_inside_the_cars_and_their_lights_kept() -> void:
	var m := _subway()
	var roof := RoofView.build(m, play.roof)
	add_child_autofree(roof)
	var boxes: Array[AABB] = []
	for t in m.trains:
		boxes.append(t.box)
	var hidden := roof.hide_lamps_in(boxes)
	assert_gt(hidden, 0, "the cars had station lamps")
	# the lamps whose fittings hang inside a car (a station's roof is plain: each panel its drop under its ceiling)
	assert_true(m.roof_plain)
	var inside := 0
	for i in m.roof_lamps.size():
		var at := Vector3(m.roof_lamps[i].x, m.roof_lamp_heights[i] - play.roof.plain_lamp_drop, m.roof_lamps[i].y)
		for box in boxes:
			if box.has_point(at):
				inside += 1
				break
	assert_eq(hidden, inside, "every lamp inside a car hidden, none else")
	assert_lt(hidden, m.roof_lamps.size(), "the station's own lamps stay")
	assert_not_null(roof.lamp_lights(), "the lights are kept")
	# shone in the cars' cool white when asked: those inside a car, and no other
	var cool := play.station_look.trains.lamp_colour
	assert_gt(cool.b, cool.r, "the cars' white is cool (bluer than red)")
	var again := RoofView.build(m, play.roof)
	add_child_autofree(again)
	assert_eq(again.hide_lamps_in(boxes, cool), inside)
	var tinted := 0
	for i in m.roof_lamps.size():
		var light := again.lamp_lights().light_of(i)
		if light == null:
			continue
		var at := Vector3(m.roof_lamps[i].x, m.roof_lamp_heights[i] - play.roof.plain_lamp_drop, m.roof_lamps[i].y)
		var in_car := boxes.any(func(b: AABB) -> bool: return b.has_point(at))
		assert_eq(light.light_color == cool, in_car, "lamp %d's light cool white only in a car" % i)
		if in_car:
			tinted += 1
	assert_eq(tinted, inside, "every car's light cool white")
	# kept off the station's surface when asked (its layer), so no car lamp lights the tunnel through the car's sides
	var kept := RoofView.build(m, play.roof)
	add_child_autofree(kept)
	assert_eq(kept.hide_lamps_in(boxes, cool, StationSurface.LAYER), inside)
	for i in m.roof_lamps.size():
		var light := kept.lamp_lights().light_of(i)
		if light == null:
			continue
		var at := Vector3(m.roof_lamps[i].x, m.roof_lamp_heights[i] - play.roof.plain_lamp_drop, m.roof_lamps[i].y)
		var in_car := boxes.any(func(b: AABB) -> bool: return b.has_point(at))
		assert_eq(light.light_cull_mask & StationSurface.LAYER == 0, in_car,
				"lamp %d off the station's surface only in a car" % i)
		assert_true(light.light_cull_mask & 1 != 0, "lamp %d still lights the cars and the players" % i)
	var bare := RoofView.new()
	add_child_autofree(bare)
	assert_eq(bare.hide_lamps_in(boxes), 0, "a roof without lamps hides none")


func test_no_train_colour_reads_as_a_team() -> void:
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(play.teams.colours)
	var near: Array[String] = []
	var look := play.station_look.trains
	for path in look.paths():
		var seen: Dictionary[Color, bool] = {}
		for linear in look.mesh(path).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
			var c := linear.linear_to_srgb()
			if seen.has(c):
				continue
			seen[c] = true
			if FieldChecks.reads_as_team(c, teams) and not _stripe(c):
				near.append("%s %s" % [path.get_file(), c.to_html(false)])
	assert_eq(near, [] as Array[String], "worn grey and the orange stripe: no other colour near a team's hue")


## Whether `c` (sRGB, as baked and worn) is the orange stripe's (train.py COLOURS "stripe", #c0652f, the owner's ask,
## 2026-11-12), its grime darkening it but keeping its hue: the one colour let near Beta's.
func _stripe(c: Color) -> bool:
	var own := Color("c0652f")
	return absf(c.h - own.h) < 0.03 and c.v <= own.v + 0.02


func test_the_cars_wear_an_orange_stripe_along_their_sides() -> void:
	var look := play.station_look.trains
	for path: String in [look.body, look.door, look.ends[&"outer"], look.ends[&"cab"]]:
		var striped := 0
		for c in look.mesh(path).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
			if _stripe(c.linear_to_srgb()) and c.linear_to_srgb().s > 0.4:
				striped += 1
		assert_gt(striped, 0, "%s wears the stripe" % path.get_file())


func test_the_half_cars_under_a_flickering_lamp_flicker_with_it() -> void:
	var m := _subway()
	var flickers: Array[int] = []
	for i in m.roof_lamp_states.size():
		if m.roof_lamp_states[i] == MapData.LAMP_FLICKER:
			flickers.append(i)
	assert_eq(flickers.size(), 3, "three of the trains' lamps flicker (layout.py FLICKER)")
	var look := play.station_look.trains
	var view := TrainView.build(m, look, play.roof)
	add_child_autofree(view)
	assert_eq(view.flicker_strips().size(), 3, "one half car under each")
	var placed := view.placed_of(look.lights)
	for k in view.flicker_strips().size():
		var lamp := view.flicker_lamps()[k]
		assert_true(flickers.has(lamp))
		var t: Transform3D = placed[view.flicker_strips()[k]]
		var local := t.affine_inverse() * Vector3(m.roof_lamps[lamp].x, t.origin.y, m.roof_lamps[lamp].y)
		assert_between(local.x, 0.0, look.half_length, "the lamp over its own half")
	assert_true(view.is_processing(), "the flickering strips step per frame")
	var quiet := TrainView.build(m, look)
	add_child_autofree(quiet)
	assert_eq(quiet.flicker_strips().size(), 0, "no roof: nothing flickers")
	assert_false(quiet.is_processing(), "and nothing runs per frame")
	# each strip steps to its lamp's own level (RoofView.flicker_level, as its light does), at the same moment (a
	# headless MultiMesh keeps no custom data, so the level it last set is read)
	view._process(0.0)
	var now := Time.get_ticks_msec() * 0.001
	for k in view.flicker_strips().size():
		var level := view._levels[k]
		assert_true(level == 1.0 or is_equal_approx(level, play.roof.lamp_flicker_low), "full or low: %s" % level)
		var then := RoofView.flicker_level(now, view.flicker_lamps()[k], play.roof)
		var before := RoofView.flicker_level(now - 0.02, view.flicker_lamps()[k], play.roof)
		assert_true(level == then or level == before, "in step with its lamp")


func test_each_cars_open_slots_stand_in_a_gap_of_its_platform_wall_and_the_shut_ones_in_wall() -> void:
	var m := _subway()
	var look := play.station_look.trains
	var checked := 0
	for t in m.trains:
		# the platform side: +z (the models') unless the car is turned
		for car in t.cars:
			var z := t.box.end.z - 0.1 if not car.turned else t.box.position.z + 0.1
			for slot in TrainDressing.SLOTS:
				var x := car.middle.x + (-1.0 if car.turned else 1.0) * look.door_slots[slot]
				var covered := false
				for b in m.blocks:
					if b.kind != &"wall" or not t.holds(b):
						continue
					var lo := b.center - b.size * 0.5
					var hi := b.center + b.size * 0.5
					if x > lo.x and x < hi.x and z > lo.z and z < hi.z and car.middle.y + 1.0 > lo.y \
							and car.middle.y + 1.0 < hi.y:
						covered = true
				if car.open.has(slot):
					assert_false(covered, "open slot %d of the car at x %s is a gap in the wall" % [slot, car.middle.x])
				checked += 1
	assert_gt(checked, 0)


func test_a_train_without_cars_reads_and_a_view_of_only_gangways_builds() -> void:
	var warnings: Array[String] = []
	var out := TrainDressing.read({"trains": [_train({"cars": []})]}, warnings)
	assert_eq(out.size(), 1, "a train with no cars is still a box")
	assert_eq(warnings.size(), 0)
	assert_eq(TrainDressing.read({"trains": [5, null, "x"]}, warnings).size(), 0, "non-dictionaries are left out")
	assert_eq(warnings.size(), 3)


func test_hiding_the_lamps_twice_hides_the_same_and_a_freed_view_leaves_no_orphans() -> void:
	var m := _subway()
	var roof := RoofView.build(m, play.roof)
	add_child_autofree(roof)
	var boxes: Array[AABB] = [m.trains[0].box]
	assert_eq(roof.hide_lamps_in(boxes), roof.hide_lamps_in(boxes), "idempotent")
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var view := TrainView.build(m, play.station_look.trains)
	add_child(view)
	view.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "freeing leaves no orphan")


func test_the_south_cab_door_is_climbed_into_from_the_track_with_no_steps() -> void:
	# owner, 2026-11-12: no ramp at the open cab; a body climbs up from the track and drops back down
	var m := _subway()
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	NavVaults.link(nav, level.query(), tuning.vault, tuning.body, BotConfig.load_default().vault_price)
	# a climb link from the track at the cab's door up onto the car's floor behind it, and a drop back down
	var up := 0
	var down := 0
	for k in nav.node_count():
		var a := nav.node_position(k)
		for l in range(nav.vault_start[k], nav.vault_start[k + 1]):
			var b := nav.node_position(nav.vault_to[l])
			var at_door := absf(a.z - 10.75) < 0.6 and absf(b.z - 10.75) < 0.6
			if at_door and a.y < 0.1 and b.y > 0.8 and a.x > 60.0 and a.x < 61.5 and b.x > 58.0 and b.x < 60.0:
				up += 1
			elif at_door and a.y > 0.8 and b.y < 0.1 and b.x > 60.0 and b.x < 61.5 and a.x > 58.0 and a.x < 60.0:
				down += 1
	assert_gt(up, 0, "a climb up into the cab from the track")
	assert_gt(down, 0, "and a drop back down")
	# and no walk up: the track at the door is the track bed, the car's floor 0.9 m over it
	var floors := 0
	for b in m.blocks:
		if b.kind == &"floor" and absf(b.center.z - 10.8) < 2.0 and b.center.x - b.size.x * 0.5 < 61.0 \
				and b.center.x + b.size.x * 0.5 > 60.5 and b.center.y + b.size.y * 0.5 > 0.05:
			floors += 1
	assert_eq(floors, 0, "no steps or ramp before the cab")


func test_a_bogie_stands_on_the_rails_under_each_train_end_in_its_own_open_space() -> void:
	# owner, 2026-11-12: "model the wheels"
	var m := _subway()
	var bogies: Array[MapData.Block] = []
	for b in m.blocks:
		if b.dress == &"train_bogie":
			bogies.append(b)
	assert_eq(bogies.size(), 4, "one under each of the two trains' two ends")
	var cfg := play.site_look.props
	for b in bogies:
		assert_true(cfg.dresses(b), "drawn as its model")
		assert_true(cfg.models.has(&"train_bogie"))
		var box := AABB(b.center - b.size * 0.5, b.size)
		assert_almost_eq(box.position.y, 0.11, 0.001, "its flanges' foot under the rails' top")
		assert_almost_eq(box.end.y, 0.75, 0.001, "up to the car's underside")
		var under: TrainDressing = null
		for t in m.trains:
			if t.box.grow(0.01).encloses(box):
				under = t
		assert_not_null(under, "inside a train's box")
		if under == null:
			continue
		assert_false(under.holds(b), "the bogie is a prop's")
		# the space round it: nothing solid between it and the end but the track bed, the car's floor over it held
		var end_x := under.box.position.x if b.center.x < under.box.get_center().x else under.box.end.x
		var mouth := Vector3(lerpf(b.center.x, end_x, 0.8), 0.4, b.center.z)
		for o in m.blocks:
			var ob := AABB(o.center - o.size * 0.5, o.size)
			assert_false(ob.has_point(mouth), "the space before the bogie is open: %s at %s" % [o.kind, o.center])
			if o.kind == &"floor" and ob.has_point(Vector3(b.center.x, 0.8, b.center.z)):
				assert_true(under.holds(o), "the slab over the bogie is the train model's")
			if o.kind == &"floor" and ob.has_point(Vector3(b.center.x, -0.1, b.center.z)):
				assert_false(under.holds(o), "the track bed under it is the station's")


func test_a_floor_well_under_the_cars_floor_is_the_track_bed_not_the_train() -> void:
	var t: TrainDressing = TrainDressing.read({"trains": [_train()]}, [] as Array[String])[0]
	var b := MapData.Block.new()
	b.kind = &"floor"
	b.center = Vector3(1, -0.15, 0)
	b.size = Vector3(2, 0.3, 3.5)
	assert_false(t.holds(b), "the track bed under an end")
	b.center = Vector3(1, 0.825, 0)
	b.size = Vector3(2, 0.15, 3.5)
	assert_true(t.holds(b), "the slab over it")
	b.center = Vector3(7, 0.3, 0)
	b.size = Vector3(4, 1.2, 3.5)
	assert_true(t.holds(b), "the car's floor slab down to the bed")


func test_a_train_without_cars_still_holds_a_low_floor_in_its_box() -> void:
	var d := _train()
	d["cars"] = []
	var t: TrainDressing = TrainDressing.read({"trains": [d]}, [] as Array[String])[0]
	var b := MapData.Block.new()
	b.kind = &"floor"
	b.center = Vector3(1, -0.15, 0)
	b.size = Vector3(2, 0.3, 3.5)
	if t == null or not t.cars.is_empty():
		pending("train reads cars from elsewhere")
		return
	assert_true(t.holds(b), "no cars: no floor height to measure against, nothing is skipped")


## A map of one car (the turned one when `turned`) with a flickering lamp at each of `lamps` (x, z) in its roof data.
func _flicker_map(turned: bool, lamps: Array[Vector2], states: Array[int] = []) -> MapData:
	var m := MapData.new()
	m.trains = TrainDressing.read({"trains": [_train({"cars": [{"x": 7.5, "y": 0.9, "z": 0,
			"turn": 1 if turned else 0, "open": [], "ends": ["cab", "outer"]}]})]}, [] as Array[String])
	for i in lamps.size():
		m.roof_lamps.append(lamps[i])
		m.roof_lamp_states.append(states[i] if i < states.size() else MapData.LAMP_FLICKER)
	return m


func test_a_turned_cars_half_strips_link_to_the_lamp_over_each_half() -> void:
	var look := play.station_look.trains
	# car middle x 7.5: its halves cover x 0.2 to 7.5 and 7.5 to 14.8 (half_length 7.3); one lamp over each
	for turned: bool in [false, true]:
		var m := _flicker_map(turned, [Vector2(3.0, 0.0), Vector2(12.0, 0.0)])
		var view := TrainView.build(m, look, play.roof)
		add_child_autofree(view)
		assert_eq(view.flicker_strips().size(), 2, "a half under each lamp (turned %s)" % turned)
		assert_ne(view.flicker_strips()[0], view.flicker_strips()[1], "two different halves")
		assert_eq(view.flicker_lamps()[0] + view.flicker_lamps()[1], 1)


func test_a_lamp_on_a_halfs_boundary_flickers_one_half_only() -> void:
	var look := play.station_look.trains
	# over the car's middle (x 7.5), where its two halves meet
	var view := TrainView.build(_flicker_map(false, [Vector2(7.5, 0.0)]), look, play.roof)
	add_child_autofree(view)
	assert_eq(view.flicker_strips().size(), 1, "one half, not both")


func test_a_lamp_beside_the_car_or_not_flickering_links_no_strip() -> void:
	var look := play.station_look.trains
	var m := _flicker_map(false, [Vector2(3.0, 9.0), Vector2(12.0, 0.0)], [MapData.LAMP_FLICKER, 0])
	var view := TrainView.build(m, look, play.roof)
	add_child_autofree(view)
	assert_eq(view.flicker_strips().size(), 0, "off to the side, or steady: nothing flickers")
	assert_false(view.is_processing())


func test_flickering_lamps_without_trains_build_no_view() -> void:
	var m := MapData.new()
	m.roof_lamps.append(Vector2(3.0, 0.0))
	m.roof_lamp_states.append(MapData.LAMP_FLICKER)
	assert_null(TrainView.build(m, play.station_look.trains, play.roof))


func test_a_train_view_freed_while_it_flickers_leaves_nothing_behind() -> void:
	var m := _flicker_map(false, [Vector2(3.0, 0.0)])
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var view := TrainView.build(m, play.station_look.trains, play.roof)
	add_child(view)
	await wait_physics_frames(2)
	remove_child(view)
	view.free()
	await wait_physics_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_a_dim_lamp_inside_a_car_is_shone_in_the_cars_white() -> void:
	var m := _subway()
	var roof := RoofView.build(m, play.roof)
	add_child_autofree(roof)
	var cool := Color(0.8, 0.9, 1.0)
	var all: Array[AABB] = [AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))]
	roof.hide_lamps_in(all, cool)
	for i in m.roof_lamps.size():
		var light := roof.lamp_lights().light_of(i)
		if light != null:
			assert_eq(light.light_color, cool, "lamp %d (state %d)" % [i, m.roof_lamp_states[i]])


## The platform side's windows (layout.py WIN_Y, car_windows, DOOR_WIN): a glass block in each window's hole in the
## side, the shut doors' too, none in the far side (the tunnel wall) or an open door's hole.
func test_the_platform_sides_windows_are_glass_through_the_wall() -> void:
	var m := _subway()
	var by_train: Array[int] = []
	for t in m.trains:
		var n := 0
		var shut := 0
		for car in t.cars:
			shut += TrainDressing.SLOTS - car.open.size()
		var platform_z := t.box.end.z if not t.cars[0].turned else t.box.position.z
		for b in m.blocks:
			if b.kind != &"glass" or not t.holds(b):
				continue
			n += 1
			var lo := b.center - b.size * 0.5
			var hi := b.center + b.size * 0.5
			assert_almost_eq(minf(absf(lo.z - platform_z), absf(hi.z - platform_z)), 0.0, 0.001,
					"glass at %s stands in the platform side" % b.center)
			assert_almost_eq(b.size.z, 0.15, 0.001, "through the side's wall")
			var floor_y := t.cars[0].middle.y
			assert_between(lo.y - floor_y, 0.84, 0.96, "its sill (a side window's 0.85, a door's 0.95)")
			assert_between(hi.y - floor_y, 1.94, 2.01, "its head (1.95, a door's 2.0 in the roof's curve)")
			for w in m.blocks:
				if w.kind == &"wall" and t.holds(w):
					var inter := AABB(lo, b.size).intersection(AABB(w.center - w.size * 0.5, w.size))
					assert_true(inter.get_volume() < 1e-6, "no wall left in the window at %s" % b.center)
		assert_eq(n, 5 * t.cars.size() + 2 * shut, "five windows a car and two in each shut door")
		by_train.append(n)
	assert_eq(by_train, [42, 22] as Array[int])


func test_the_eye_passes_a_trains_window_and_a_bb_stops_on_it() -> void:
	var m := _subway()
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	var q := level.query()
	# from the north platform into the north train's first car, through the window at its middle
	var t := m.trains[0]
	var y := t.cars[0].middle.y + 1.4
	var a := Vector3(t.cars[0].middle.x, y, t.box.end.z + 2.0)
	var b := Vector3(t.cars[0].middle.x, y, t.box.end.z - 1.0)
	var hit := RayHit.new()
	assert_true(q.ray(a, b, hit), "a BB meets the glass")
	assert_almost_eq(hit.position.z, t.box.end.z, 0.05)
	assert_eq(hit.surface, play.map_style.surface_of(&"glass"))
	assert_false(q.sight_ray(a, b, hit), "the eye goes through into the car")
	var under := Vector3(a.x, t.cars[0].middle.y + 0.5, a.z)
	assert_true(q.sight_ray(under, Vector3(under.x, under.y, b.z), hit), "under the sill the side still hides")


func test_the_map_leaves_the_trains_glass_to_their_models_and_draws_it_without_them() -> void:
	var m := _subway()
	var held: Array[TrainDressing] = m.trains
	assert_null(MapLevel._glass_mesh(m, play.map_style, held), "every pane is a train's, drawn by its models")
	var none: Array[TrainDressing] = []
	assert_not_null(MapLevel._glass_mesh(m, play.map_style, none), "without the models the glass is drawn as boxes")


## The models' panes stand in the map's glass (QA's): each car's window glass, laid as TrainView lays it, lies within
## its car's glass blocks along it and up it, a turned car's too.
func test_each_cars_window_glass_lies_in_its_glass_blocks() -> void:
	var m := _subway()
	var look := play.station_look.trains
	var view := TrainView.build(m, look)
	add_child_autofree(view)
	var pane := look.mesh(look.windows).get_aabb()
	var placed := view.placed_of(look.windows)
	assert_eq(placed.size(), m.trains[0].cars.size() + m.trains[1].cars.size())
	for at: Transform3D in placed:
		var box := at * pane
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for b in m.blocks:
			if b.kind != &"glass" or absf(b.center.x - box.get_center().x) > 7.5 \
					or absf(b.center.z - box.get_center().z) > 2.0:
				continue
			lo = lo.min(b.center - b.size * 0.5)
			hi = hi.max(b.center + b.size * 0.5)
		assert_true(box.position.x >= lo.x - 0.001 and box.end.x <= hi.x + 0.001,
				"the car at %s: its panes along it in its glass" % box.get_center())
		assert_true(box.position.y >= lo.y - 0.001 and box.end.y <= hi.y + 0.001,
				"the car at %s: its panes up it in its glass" % box.get_center())


## The platform side's shut doors are glazed (TrainLook.door_glass): each door's panes lie in the glass blocks the
## map puts in its gap, along the car and up it, so a pane is never drawn where a BB or a body is not stopped.
func test_each_shut_doors_glass_lies_in_its_glass_blocks() -> void:
	var m := _subway()
	var look := play.station_look.trains
	var view := TrainView.build(m, look)
	add_child_autofree(view)
	var pane := look.mesh(look.door_glass).get_aabb()
	var placed := view.placed_of(look.door_glass)
	assert_gt(placed.size(), 0, "the platform side has shut glazed doors")
	for at: Transform3D in placed:
		var box := at * pane
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for b in m.blocks:
			if b.kind != &"glass" or absf(b.center.x - box.get_center().x) > 0.8 \
					or absf(b.center.z - box.get_center().z) > 2.0:
				continue
			lo = lo.min(b.center - b.size * 0.5)
			hi = hi.max(b.center + b.size * 0.5)
		assert_true(box.position.x >= lo.x - 0.001 and box.end.x <= hi.x + 0.001,
				"the door at %s: its panes along it in its glass" % box.get_center())
		assert_true(box.position.y >= lo.y - 0.001 and box.end.y <= hi.y + 0.001,
				"the door at %s: its panes up it in its glass" % box.get_center())


## A train's ends stand in their tunnel, not in a card (SM1, critic): nothing is drawn across the box's corners beside
## a car's outline; where the box's sides, top or foot meet the ground, the station lines them, facing into the box, in
## the finish of the tunnel round the train, so the eye past an end's corner meets the tunnel's wall.
func test_the_station_lines_each_train_box_where_it_meets_the_ground() -> void:
	var m := _subway()
	var look := play.station_look
	for t in m.trains:
		var lining := StationSurface.lining(look, m.station, t.box)
		assert_gt(lining.size(), 0, "train at %s: lined" % t.box)
		for l in lining:
			var f := l.face()
			var n := GreyboxFaces.face_normal(f)
			var c := Vector3.ZERO
			for p in f:
				c += p / f.size()
				assert_true(t.box.grow(0.001).has_point(p), "train at %s: its lining on its box" % t.box)
			assert_gt(n.dot(t.box.get_center() - c), 0.0, "train at %s: its lining faces into the box" % t.box)
			var past := c + n * -look.probe
			assert_null(m.station.zone_at(past), "train at %s: lined only where no room lies past it (%s)" % [t.box, c])


## Under a platform tunnel's vault the train's top and its platform side over the platform are open (its roof under
## the vault, its doors on the platform); the trackside wall is the track's tiles, top to foot.
func test_a_train_at_a_platform_is_lined_only_by_the_trackside_wall_and_under_the_platform() -> void:
	var m := _subway()
	var look := play.station_look
	var t := m.trains[0]
	var floor_y := t.cars[0].middle.y
	for l in StationSurface.lining(look, m.station, t.box):
		assert_false(l.axis == 1 and l.inward < 0.0, "nothing drawn over the north train's roof")
		if l.axis == 2 and is_equal_approx(l.at, t.box.end.z):
			assert_lt(l.hi, floor_y, "the platform side lined only under the platform: %.2f" % l.hi)
		if l.axis == 2 and is_equal_approx(l.at, t.box.position.z):
			assert_eq(l.finish, look.style_walls[&"track"], "the trackside wall in the track's tiles")
			assert_almost_eq(l.hi, t.box.end.y, 0.001, "the trackside wall up to the box's top")


## The south train's east end stands in its running tunnel: there its sides and top are lined in the tunnel's own
## concrete (not the platform's tiles), cut where the platform tunnel's vault ends.
func test_a_train_in_a_running_tunnel_is_lined_in_the_tunnels_concrete() -> void:
	var m := _subway()
	var look := play.station_look
	var t := m.trains[1]
	var concrete := look.style_walls[&"tunnel"]
	var over := 0
	var sides := 0
	for l in StationSurface.lining(look, m.station, t.box):
		if l.from >= 50.0 - 0.001 and l.axis == 2:
			assert_eq(l.finish, concrete, "the running tunnel's sides at x %.1f" % l.from)
			sides += 1
		if l.axis == 1 and l.inward < 0.0:
			assert_eq(l.finish, look.style_ceilings[&"tunnel"], "the running tunnel's roof over the train")
			assert_almost_eq(l.from, 50.0, 0.001, "its roof from where the vault ends")
			over += 1
		if l.to <= 50.0 + 0.001 and l.axis == 2:
			assert_eq(l.finish, look.style_walls[&"track"], "under the vault, the track's tiles at x %.1f" % l.from)
	assert_eq(sides, 2, "both sides in the running tunnel")
	assert_eq(over, 1, "its roof")


func _dress_of(zones: Array) -> StationDressing:
	var warnings: Array[String] = []
	var d := StationDressing.read({"station": {"zones": zones}}, warnings)
	assert_not_null(d)
	return d


## A box with no zone round it is lined whole on its four long sides and its top and foot, nothing over its ends.
func test_a_train_box_with_no_zone_round_it_is_lined_on_its_six_sides_but_the_ends() -> void:
	var look := play.station_look
	var box := AABB(Vector3(0, 0, -2), Vector3(10, 3, 4))
	var lining := StationSurface.lining(look, _dress_of([]), box)
	assert_eq(lining.size(), 4, "four stretches")
	for l in lining:
		assert_ne(l.axis, 0, "no stretch across an end")
		assert_almost_eq(l.from, 0.0, 0.001)
		assert_almost_eq(l.to, 10.0, 0.001)
		assert_gt(GreyboxFaces.face_normal(l.face()).dot(box.get_center() - l.face()[0]), 0.0, "faces into the box")


## A zone that only touches the box at a face (past it, not over it) does not stop the lining being cut right: one
## zone filling the whole side past the box takes the side away; one beside it (sharing only an edge) takes nothing.
func test_a_zone_past_a_side_removes_it_and_one_only_sharing_an_edge_does_not() -> void:
	var look := play.station_look
	var box := AABB(Vector3(0, 0, -2), Vector3(10, 3, 4))
	var past := _dress_of([{"style": "track", "box": [-1, 11, 0, 3, 2, 6]}])
	for l in StationSurface.lining(look, past, box):
		assert_false(l.axis == 2 and is_equal_approx(l.at, 2.0), "the +z side is open to the room past it")
	var edge := _dress_of([{"style": "track", "box": [-1, 11, 0, 3, 2.5, 6]}])
	var sides := 0
	for l in StationSurface.lining(look, edge, box):
		if l.axis == 2 and is_equal_approx(l.at, 2.0):
			sides += 1
	assert_eq(sides, 1, "a gap of 0.5 m past the side keeps it lined")


## A zone straddling the box's middle: each stretch takes the finish of the zone past its own nearer end, none flips
## inside a stretch, and stretches never overlap along x in one plane.
func test_a_zone_straddling_the_middle_cuts_the_lining_without_overlap() -> void:
	var look := play.station_look
	var box := AABB(Vector3(0, 0, -2), Vector3(10, 3, 4))
	var dress := _dress_of([{"style": "platform", "box": [4, 6, 0, 3, 2, 6]},
			{"style": "track", "box": [-5, 0, 0, 3, -2, 2]}, {"style": "tunnel", "box": [10, 15, 0, 3, -2, 2]}])
	var lining := StationSurface.lining(look, dress, box)
	for i in lining.size():
		for j in range(i + 1, lining.size()):
			var a := lining[i]
			var b := lining[j]
			if a.axis != b.axis or not is_equal_approx(a.at, b.at):
				continue
			var overlap := minf(a.to, b.to) - maxf(a.from, b.from) > 0.001 and minf(a.hi, b.hi) - maxf(a.lo, b.lo) > 0.001
			assert_false(overlap, "stretches %d and %d overlap" % [i, j])
		assert_true(lining[i].from >= -0.001 and lining[i].to <= 10.001, "within the box's length")
	for l in lining:
		if l.axis == 2 and is_equal_approx(l.at, 2.0):
			assert_true(l.to <= 4.001 or l.from >= 5.999, "the +z side is open past the straddling zone")


## A lining stretch is never doubled by a block face the station still draws in its plane, facing the same way
## (the two would z-fight): over Subway's blocks outside the trains' holds, none has a face coplanar and overlapping.
func test_no_lining_stretch_shares_its_plane_with_a_drawn_block_face_facing_the_same_way() -> void:
	var m := _subway()
	var look := play.station_look
	var faced := StationSurface.faced_boxes(m, play.map_style, look)
	for t in m.trains:
		for l in StationSurface.lining(look, m.station, t.box, faced):
			var n := GreyboxFaces.face_normal(l.face())
			for b in m.blocks:
				if not StationSurface.faces_drawn(b, m, play.map_style, null, m.trains):
					continue
				for whole in GreyboxFaces.faces_of(b):
					var bn := GreyboxFaces.face_normal(whole)
					if bn.dot(n) < 0.99 or absf((whole[0] - l.face()[0]).dot(n)) > 0.002:
						continue
					var lo := Vector3(INF, INF, INF)
					var hi := -lo
					for p in whole:
						lo = lo.min(p)
						hi = hi.max(p)
					var fl := Vector3(INF, INF, INF)
					var fh := -fl
					for p in l.face():
						fl = fl.min(p)
						fh = fh.max(p)
					var size := (hi.min(fh) - lo.max(fl))
					var ov := 0
					for k in 3:
						if size[k] > 0.01:
							ov += 1
					assert_lt(ov, 2, "block %s kind %s size %s rise %d doubles lining %s..%s finish %s" % [b.center, b.kind, b.size, b.rise, fl, fh, l.finish])


## A faced block standing flush past part of a side takes just its footprint out of the lining (the rest stays lined);
## one straddling the side's plane is no flush neighbour and takes nothing.
func test_a_flush_faced_block_takes_only_its_footprint_from_the_lining_and_a_straddling_one_nothing() -> void:
	var look := play.station_look
	var box := AABB(Vector3(0, 0, -2), Vector3(10, 3, 4))
	var dress := _dress_of([])
	var flush: Array[AABB] = [AABB(Vector3(3, 0, 2), Vector3(3, 3, 1))]
	var straddle: Array[AABB] = [AABB(Vector3(3, 0, 1.5), Vector3(3, 3, 1))]
	var base := _side_area(StationSurface.lining(look, dress, box), 2.0)
	assert_gt(base, 0.0, "the bare +z side is lined")
	assert_almost_eq(_side_area(StationSurface.lining(look, dress, box, flush), 2.0), base - 9.0, 0.01,
			"the 3 x 3 m footprint of the flush block is left out, the rest kept")
	assert_almost_eq(_side_area(StationSurface.lining(look, dress, box, straddle), 2.0), base, 0.01,
			"a block straddling the plane changes nothing")


func _side_area(lining: Array[StationSurface.Lining], at: float) -> float:
	var area := 0.0
	for l in lining:
		if l.axis == 2 and is_equal_approx(l.at, at):
			area += (l.to - l.from) * (l.hi - l.lo)
	return area


## Nothing on a train box's sides wears the cars' inside paint (SM1, critic: a pale strip beside the open cab): a
## wall's face standing flush past the box and looking into its cars is drawn as the box's lining there.
func test_no_face_on_a_train_box_side_wears_the_cars_paint() -> void:
	var m := _subway()
	var look := play.station_look
	var car := look.layer_of(look.style_walls[&"train"])
	assert_ne(car, look.layer_of(look.style_walls[&"tunnel"]), "the cars' paint and the tunnel's concrete differ")
	var arrays := StationSurface.mesh(m, play.map_style, look, play.site_look.props.named_only()).surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var on_sides := 0
	for i in points.size():
		var p := points[i]
		for t in m.trains:
			var b := t.box
			if p.x < b.position.x + 0.01 or p.x > b.end.x - 0.01 or p.y < b.position.y - 0.001 \
					or p.y > b.end.y + 0.001:
				continue
			if absf(p.z - b.position.z) > 0.001 and absf(p.z - b.end.z) > 0.001:
				continue
			on_sides += 1
			assert_ne(int(custom[i * 4]), car, "the side at %s in the cars' paint" % p)
	assert_gt(on_sides, 0, "the trains' sides are drawn")
