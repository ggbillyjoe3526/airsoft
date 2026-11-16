extends GutTest
## BP9 part 4 (the full pass before 0.1 Beta 1: performance). Woodland stuttered: a bot with nobody in sight picks a
## spot to go and look at (RoundPlanner.hunt_point) anywhere a route reaches, and 2.8 % of Woodland's walkable ground
## is the stream's bed. Wading is priced eight times a dry step (WS1), so the search to a spot in the water priced
## every dry way round it first: 38 ms on average over 300 such searches and 241 ms at worst, in one tick of the
## simulation, against 3 ms to the bank beside the same spot. The grid now marks its wading nodes (NavGrid.wade) and a
## hunt never picks one. Nobody stands in a stream to look for someone.

## A height over every floor of Woodland (m), for drawing its hunt spots as BotController does.
const WOODLAND_TOP := 60.0

var tuning: SimTuning = SimTuning.load_default()
var cfg: BotConfig = BotConfig.load_default()
var style: MapStyle = PlayTuning.load_default().map_style

var _brook: MapData = null
var _brook_nav: NavGrid = null
var _woodland: MapData = null
var _woodland_nav: NavGrid = null


## A 60 m square of floor with a stream down its middle (x = 0), 4 m across and 0.3 m deep: wading depth all over.
func _brook_map() -> MapData:
	if _brook == null:
		_brook = MapData.parse(JSON.stringify({"name": "Brook", "blocks": [{"kind": "floor",
			"center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 60, "y": 0.5, "z": 60}}],
			"spawns": [[{"x": -20, "z": 0}], [{"x": 20, "z": 0}]],
			"deadZones": [[{"x": -25, "z": 0}], [{"x": 25, "z": 0}]],
			"water": [{"points": [{"x": 0, "y": 0.3, "z": -30}, {"x": 0, "y": 0.3, "z": 30}], "width": 4}]}), style, 1)
		_brook_nav = NavGrid.build(_brook, tuning.nav, tuning.body)
	return _brook


func _woodland_map() -> MapData:
	if _woodland == null:
		_woodland = MapData.load_map("woodland", style, 6)
		_woodland_nav = NavGrid.build(_woodland, tuning.nav, tuning.body)
	return _woodland


## A bot of team 0 at `at` on `nav` with `bot_seed` for its own stream, in a bare world that hunts inside `lo` to `hi`
## from `top_y` down.
func _hunter(nav: NavGrid, at: Vector3, lo: Vector2, hi: Vector2, bot_seed: int, top_y: float = 5.0) -> Array:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, at, 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(hi.x, 0.0, hi.y), 0.0, loadout)
	foe.status = Character.Status.OUT
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = cfg
	w.query = BoxWorld.new()
	w.nav = nav
	w.planner = RoundPlanner.new(1)
	w.planner.bounds_lo = lo
	w.planner.bounds_hi = hi
	w.planner.top_y = top_y
	w.characters = [me, foe]
	w.time = 10.0
	w.setup_sectors(lo, hi)
	return [Bot.new(me, bot_seed, cfg.skill_for(&"normal"), 2), w]


func _wades(map: MapData, at: Vector3) -> bool:
	return map.water.depth_at(at) >= tuning.nav.wade_from


func test_the_grid_marks_each_node_under_wading_water_and_no_other() -> void:
	var map := _brook_map()
	var nav := _brook_nav
	assert_eq(nav.wade.size(), nav.floor_y.size(), "a mark a node")
	var marked := 0
	var wrong := 0
	for k in nav.floor_y.size():
		if nav.walkable[k] == 0:
			continue
		marked += nav.wade[k]
		if (nav.wade[k] == 1) != _wades(map, nav.node_position(k)):
			wrong += 1
	assert_eq(wrong, 0, "each mark agrees with the water's depth over its node")
	assert_gt(marked, 0, "the stream's bed is marked")
	var mid := nav.nearest_walkable(Vector3(0.0, 0.0, 5.0), nav.snap)
	var bank := nav.nearest_walkable(Vector3(10.0, 0.0, 5.0), nav.snap)
	assert_eq(nav.wade[mid], 1, "midstream")
	assert_eq(nav.wade[bank], 0, "on the bank")


func test_a_field_with_no_water_marks_nothing() -> void:
	var dry := MapData.parse(JSON.stringify({"name": "Yard", "blocks": [{"kind": "floor",
		"center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 20, "y": 0.5, "z": 20}}],
		"spawns": [[{"x": -5, "z": 0}], [{"x": 5, "z": 0}]],
		"deadZones": [[{"x": -8, "z": 0}], [{"x": 8, "z": 0}]]}), style, 1)
	var nav := NavGrid.build(dry, tuning.nav, tuning.body)
	assert_true(nav.wade.is_empty(), "nothing to mark, nothing kept")
	var f := _hunter(nav, Vector3(-5.0, 0.0, 0.0), Vector2(-9.0, -9.0), Vector2(9.0, 9.0), 3)
	var b: Bot = f[0]
	var w: BotWorld = f[1]
	assert_true(w.planner.hunt_point(b, w), "a dry field's hunts are as they were")


func test_a_hunt_never_picks_a_spot_in_wading_water() -> void:
	var map := _brook_map()
	# A strip 6 m wide over the stream's 4: two draws in three fall in the water.
	var lo := Vector2(-3.0, -25.0)
	var hi := Vector2(3.0, 25.0)
	var picked := 0
	for bot_seed in 40:
		var f := _hunter(_brook_nav, Vector3(-20.0, 0.0, 0.0), lo, hi, bot_seed + 1)
		var b: Bot = f[0]
		var w: BotWorld = f[1]
		for n in 5:
			if not w.planner.hunt_point(b, w):
				continue
			picked += 1
			assert_false(_wades(map, b.hunt_goal), "a spot on a bank, not in the stream (%s)" % b.hunt_goal)
			assert_gt(absf(b.hunt_goal.x), 1.9, "beside the water (%s)" % b.hunt_goal)
	assert_gt(picked, 150, "and the banks still give it spots (%d of 200)" % picked)


func test_a_strip_that_is_all_water_gives_no_spot() -> void:
	var f := _hunter(_brook_nav, Vector3(-20.0, 0.0, 0.0), Vector2(-1.0, -20.0), Vector2(1.0, 20.0), 7)
	var b: Bot = f[0]
	var w: BotWorld = f[1]
	assert_false(w.planner.hunt_point(b, w), "nowhere dry to look: no spot, as with nowhere walkable")


func test_woodlands_bed_is_marked_and_its_crossings_are_not() -> void:
	var map := _woodland_map()
	var nav := _woodland_nav
	assert_eq(nav.wade.size(), nav.floor_y.size())
	var t := map.terrain
	# Down the bed between the crossings (test_ws1_stream's wading spots).
	for at: Vector2 in [Vector2(-1.0, -37.0), Vector2(-5.0, -25.0), Vector2(12.6, 12.0), Vector2(8.6, 30.0)]:
		var k := nav.nearest_walkable(Vector3(at.x, t.height_at(at.x, at.y), at.y), nav.snap)
		assert_eq(nav.wade[k], 1, "the bed at %s" % at)
	# The Ford is ankle deep (it splashes, it doesn't slow) and the bridge's deck is dry: both stay places to look at.
	var ford := nav.nearest_walkable(Vector3(9.5, t.height_at(9.5, 0.5), 0.5), nav.snap)
	assert_eq(nav.wade[ford], 0, "the Ford")
	var deck := nav.nearest_walkable(Vector3(-1.0, map.floor_top(-1.0, -41.5), -41.5), nav.snap)
	assert_eq(nav.wade[deck], 0, "the North bridge")
	var marked := 0
	var walkable := 0
	for k in nav.floor_y.size():
		walkable += nav.walkable[k]
		marked += nav.wade[k]
	gut.p("Woodland: %d of %d walkable nodes are wading water (%.1f %%)" % [marked, walkable,
			100.0 * marked / walkable])
	assert_between(100.0 * marked / walkable, 0.2, 5.0, "a stream, not a lake")


func test_woodlands_hunts_stay_out_of_its_stream() -> void:
	var map := _woodland_map()
	var nav := _woodland_nav
	var lo := Vector2(nav.min_x, nav.min_z)
	var hi := Vector2(nav.max_x, nav.max_z)
	var camp := map.ends[0].spawns[0].position
	var picked := 0
	for bot_seed in 30:
		var f := _hunter(nav, camp, lo, hi, bot_seed + 1, WOODLAND_TOP)
		var b: Bot = f[0]
		var w: BotWorld = f[1]
		for n in 10:
			if not w.planner.hunt_point(b, w):
				continue
			picked += 1
			assert_false(_wades(map, b.hunt_goal), "a dry spot (%s)" % b.hunt_goal)
	assert_gt(picked, 250, "the field still gives its spots (%d of 300)" % picked)
