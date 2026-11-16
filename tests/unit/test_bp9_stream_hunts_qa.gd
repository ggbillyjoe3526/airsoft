extends GutTest
## QA for BP9 part 4 (hunts keep out of wading water): the depth edge, a deck over the water, the night pick moved out
## of a light pool, and a bot on a field with nowhere dry to look.

var tuning: SimTuning = SimTuning.load_default()
var cfg: BotConfig = BotConfig.load_default()
var style: MapStyle = PlayTuning.load_default().map_style


## A 100 m square of floor (top 0) with a stream down x = 0, `width` m across at surface height `level`; an optional
## deck over it (top 1.5) and a lamp at (`lamp_x`, 0) lighting `lamp_r` m.
func _map(width: float, level: float, deck: bool = false, lamp_x: float = 0.0, lamp_r: float = 0.0) -> MapData:
	var blocks: Array = [{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 100, "y": 0.5, "z": 100}}]
	if deck:
		blocks.append({"kind": "floor", "center": {"x": 0, "y": 1.4, "z": 0}, "size": {"x": 12, "y": 0.2, "z": 6}})
	var data := {"name": "Brook", "blocks": blocks, "spawns": [[{"x": -40, "z": 0}], [{"x": 40, "z": 0}]],
			"deadZones": [[{"x": -45, "z": 0}], [{"x": 45, "z": 0}]],
			"water": [{"points": [{"x": 0, "y": level, "z": -50}, {"x": 0, "y": level, "z": 50}], "width": width}]}
	if lamp_r > 0.0:
		data["lights"] = [{"position": {"x": lamp_x, "y": 2, "z": 0}, "radius": lamp_r, "colour": 16751178,
				"kind": "fire"}]
	return MapData.parse(JSON.stringify(data), style, 1)


func _hunter(nav: NavGrid, at: Vector3, lo: Vector2, hi: Vector2, bot_seed: int) -> Array:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, at, 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(40.0, 0.0, 0.0), 0.0, loadout)
	foe.status = Character.Status.OUT
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = cfg
	w.query = BoxWorld.new()
	w.nav = nav
	w.planner = RoundPlanner.new(1)
	w.planner.bounds_lo = lo
	w.planner.bounds_hi = hi
	w.planner.top_y = 5.0
	w.characters = [me, foe]
	w.time = 10.0
	w.setup_sectors(lo, hi)
	return [Bot.new(me, bot_seed, cfg.skill_for(&"normal"), 2), w]


func test_ankle_deep_water_is_not_marked_but_knee_deep_is() -> void:
	var splash := NavGrid.build(_map(6.0, tuning.nav.wade_from - 0.05), tuning.nav, tuning.body)
	var wade := NavGrid.build(_map(6.0, tuning.nav.wade_from + 0.05), tuning.nav, tuning.body)
	var mid_s := splash.nearest_walkable(Vector3(0.0, 0.0, 5.0), splash.snap)
	var mid_w := wade.nearest_walkable(Vector3(0.0, 0.0, 5.0), wade.snap)
	assert_eq(splash.wade[mid_s], 0, "ankle deep (a splash, the Ford) is a place to look at")
	assert_eq(wade.wade[mid_w], 1, "wading deep is marked")


func test_a_deck_over_the_water_is_not_marked_while_the_bed_under_it_may_be() -> void:
	var map := _map(6.0, 0.4, true)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var deck := -1
	var bed := -1
	for k in nav.floor_y.size():
		if nav.walkable[k] == 0 or absf(nav.node_position(k).x) > 0.5 or absf(nav.node_position(k).z) > 0.5:
			continue
		if nav.floor_y[k] > 1.0:
			deck = k
		elif nav.floor_y[k] < 0.5:
			bed = k
	assert_gt(deck, -1, "the deck has a node")
	assert_eq(nav.wade[deck], 0, "the deck is dry")
	if bed > -1:
		assert_eq(nav.wade[bed], 1, "the bed under it is wading water")


## A bot standing on the deck (a route reaches the deck's floor, not the bed under it).
func test_a_hunt_on_a_deck_over_the_water_still_picks_it() -> void:
	var nav := NavGrid.build(_map(6.0, 0.4, true), tuning.nav, tuning.body)
	var picked_deck := 0
	for bot_seed in 40:
		var f := _hunter(nav, Vector3(-5.0, 1.5, 0.0), Vector2(-1.0, -2.0), Vector2(1.0, 2.0), bot_seed + 1)
		var b: Bot = f[0]
		var w: BotWorld = f[1]
		for n in 4:
			if w.planner.hunt_point(b, w) and b.hunt_goal.y > 1.0:
				picked_deck += 1
	assert_gt(picked_deck, 0, "the bridge stays a hunt spot")


func test_a_night_hunt_pick_moved_out_of_a_lamp_does_not_land_in_the_stream() -> void:
	# A 20 m wide stream (x -10 to 10); a lamp on the west bank lights 4 m round (-12, 0): the first dark ring east of
	# it is water.
	var map := _map(20.0, 0.4, false, -12.0, 4.0)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var in_water := 0
	var picked := 0
	for bot_seed in 30:
		var f := _hunter(nav, Vector3(-30.0, 0.0, 0.0), Vector2(-13.0, -1.0), Vector2(-11.0, 1.0), bot_seed + 1)
		var b: Bot = f[0]
		var w: BotWorld = f[1]
		w.night = NightField.build(map, cfg, true)
		if w.planner.hunt_point(b, w):
			picked += 1
			if map.water.depth_at(b.hunt_goal) >= tuning.nav.wade_from:
				in_water += 1
	assert_gt(picked, 0, "spots turn up")
	assert_eq(in_water, 0, "none of the %d night picks moved into the water" % picked)


func test_a_hunting_bot_with_nowhere_dry_to_look_asks_again_without_a_goal() -> void:
	var nav := NavGrid.build(_map(6.0, 0.4), tuning.nav, tuning.body)
	var f := _hunter(nav, Vector3(-20.0, 0.0, 0.0), Vector2(-1.0, -20.0), Vector2(1.0, 20.0), 7)
	var b: Bot = f[0]
	var w: BotWorld = f[1]
	b.hunting = true
	assert_false(BotMovement._next_goal(b, w), "no goal, no crash")
	assert_true(b.hunting, "still hunting; it asks again next think")
	assert_false(BotMovement._pick_hunt(b, w), "nothing picked")


## Reported, not asserted: how many of Woodland's night hunt picks end in the stream after the move out of the light.
func test_report_woodland_night_picks_in_the_stream() -> void:
	var map := MapData.load_map("woodland", style, 6)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var camp := map.ends[0].spawns[0].position
	var lo := Vector2(nav.min_x, nav.min_z)
	var hi := Vector2(nav.max_x, nav.max_z)
	var picked := 0
	var wet := 0
	for bot_seed in 60:
		var f := _hunter(nav, camp, lo, hi, bot_seed + 1)
		var b: Bot = f[0]
		var w: BotWorld = f[1]
		w.planner.top_y = 60.0
		w.night = NightField.build(map, cfg, true)
		for n in 10:
			if w.planner.hunt_point(b, w):
				picked += 1
				if map.water.depth_at(b.hunt_goal) >= tuning.nav.wade_from:
					wet += 1
	gut.p("Woodland at night: %d of %d hunt picks in wading water (night field %s)" % [wet, picked, w_night_ok(map)])
	assert_gt(picked, 0, "spots turn up")


func w_night_ok(map: MapData) -> bool:
	return NightField.build(map, cfg, true) != null
