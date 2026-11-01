extends GutTest
## BP2 railings, QA's additions: the three switches test_bp2_railings.gd leaves unpinned (slicing towards a last-known
## spot, the crossfire spot, the ping's floor spot), each against the same geometry as a bar railing and as a wall.

const EAST := -PI * 0.5

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()


## A nav grid that calls every point walkable floor at y = 0, and whose nearest walkable node is a fixed spot.
class FlatNav:
	extends NavGrid
	var spot: Vector3 = Vector3.ZERO

	func is_walkable_at(_p: Vector3) -> bool:
		return true

	func floor_at(_p: Vector3) -> float:
		return 0.0

	func nearest_walkable(_p: Vector3, _max_radius: float) -> int:
		return 0

	func node_position(_k: int) -> Vector3:
		return spot


## A floor and, across `center`, a 2 m high line of bars or a wall.
func _world(railing: bool, center: Vector3, size: Vector3, floor_too: bool = true) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	if floor_too:
		w.add_floor(80.0, 80.0)
	if railing:
		w.add_railing(center, size)
	else:
		w.add_box(center, size)
	return w


func _bot_world(query: WorldQuery, me: Character) -> BotWorld:
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = config
	w.query = query
	w.planner = RoundPlanner.new(1)
	w.planner.enemy_yaw[0] = 0.0
	w.characters = [me]
	w.time = 10.0
	return w


func test_slicing_a_spot_seen_through_a_railing_is_not_a_corner_to_slice() -> void:
	# A 3 m line from x = -30 to 0 at z = -8.5 (the spot is behind it), the bot at (0, -3) facing it, the spot behind at (-6, -14).
	for railing: bool in [true, false]:
		var q := _world(railing, Vector3(-15.0, 1.5, -8.5), Vector3(30.0, 3.0, 1.0))
		# A wall behind it, ending at x = -8: a corner for the bot to slice that the railing does not hide.
		q.add_box(Vector3(-19.0, 1.5, -12.0), Vector3(22.0, 3.0, 1.0))
		var me := Character.new(0, 0, Vector3(0.0, 0.0, -3.0), 0.0, ReplicaStats.default_loadout())
		var w := _bot_world(q, me)
		var b := Bot.new(me, 1, config.skill_for(&"hard"), 2)
		b.last_known = Vector3(-6.0, 0.0, -14.0)
		b.has_last_known = true
		var cmd := PlayerCommand.new()
		var sliced := BotCombat._slice_towards_last_known(b, w, BotSenses.eye_of(me, tuning), cmd)
		if railing:
			assert_false(sliced, "in plain view through the bars: it watches the spot, not a corner")
		else:
			assert_true(sliced, "behind a wall it slices the corner")


func test_a_crossfire_spot_with_a_shot_through_a_railing_is_taken_and_one_behind_a_wall_is_not() -> void:
	# The lane runs north from (0, 0) to the choke at (0, -10); a 2 m line across z = -8 stands between the choke and
	# every spot swung round it towards the south.
	for railing: bool in [true, false]:
		var q := _world(railing, Vector3(0.0, 1.0, -8.0), Vector3(60.0, 2.0, 0.08))
		var me := Character.new(0, 1, Vector3(0.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
		var w := _bot_world(q, me)
		w.nav = FlatNav.new()
		w.lanes = [PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -10.0)])]
		var b := Bot.new(me, 1, config.skill_for(&"hard"), 2)
		b.lane = 0
		b.lane_index = 0
		b.lane_dir = 1
		b.lane_goal = Vector3.ZERO
		var found := BotMovement._crossfire_spot(b, w, Vector3.ZERO)
		if railing:
			assert_true(found, "a shot at the choke through the bars is a crossfire spot")
			assert_ne(b.lane_goal, Vector3.ZERO, "and the goal moves to it")
		else:
			assert_false(found, "no shot through a wall")
			assert_eq(b.lane_goal, Vector3.ZERO, "so the goal stays")


func test_a_ping_floor_spot_behind_a_railing_is_in_sight_and_behind_a_wall_is_not() -> void:
	# The view met the ground at (10, 0, 0) from 2 m of eyes; the only floor near is at (3, 0, 0), a line across x = 5
	# between (a railing's bars, or a wall).
	for railing: bool in [true, false]:
		var q := _world(railing, Vector3(5.0, 1.0, 0.0), Vector3(0.08, 2.0, 60.0), false)
		var me := Character.new(0, 0, Vector3.ZERO, EAST, ReplicaStats.default_loadout())
		var w := _bot_world(q, me)
		var nav := FlatNav.new()
		nav.spot = Vector3(3.0, 0.0, 0.0)
		w.nav = nav
		var pings := Pings.new([me], tuning.pings)
		var point := Vector3(10.0, 0.0, 0.0)
		var spot := pings._floor_spot(point, Vector3(1.0, 0.0, 0.0), 2.0, w)
		if railing:
			assert_eq(spot, nav.spot, "seen through the bars, the floor beyond is the spot")
		else:
			assert_eq(spot, point, "behind a wall it is never the spot")


func test_a_hold_order_across_a_railing_holds_beyond_it_and_one_at_a_wall_short_of_it() -> void:
	# The giver at the origin looks level east: a line across x = 4 (bars or a wall), and a wall at x = 15 beyond.
	for railing: bool in [true, false]:
		var q := _world(railing, Vector3(4.0, 1.0, 0.0), Vector3(0.08, 2.0, 60.0))
		q.add_box(Vector3(15.0, 1.5, 0.0), Vector3(0.3, 3.0, 60.0))
		var me := Character.new(0, 0, Vector3.ZERO, EAST, ReplicaStats.default_loadout())
		me.pitch = 0.0
		var w := _bot_world(q, me)
		var nav := FlatNav.new()
		nav.cell = 0.5
		w.nav = nav
		var at := SquadOrders.hold_point(me, w)
		assert_ne(at, SquadOrders.NO_SPOT, "a spot to hold")
		if railing:
			assert_gt(at.x, 10.0, "on the road beyond the bars, short of the far wall")
		else:
			assert_lt(at.x, 4.0, "short of the wall")
