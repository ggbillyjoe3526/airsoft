extends GutTest
## Bots and lifts (MT2): Kingsmere's lift links (a ride from each stop's landing to each other's, priced as the ride's
## time on foot), a bot's route from the platforms to the ticket hall riding one while a walk-off's never does, a route
## planned inside a car starting at its landing, and a bot walking its lift leg through the simulation: calling the car,
## boarding, pressing its stop, riding and walking out (game/nav/nav_lifts.gd, nav_grid.gd, game/ai/bot_lifts.gd,
## bot_routes.gd).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var config: BotConfig = BotConfig.load_default()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null


func before_all() -> void:
	map = MapData.load_map("kingsmere", MapStyle.new(), 6)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body, null, null, false, null, tuning.lifts)
	nav = NavGrid.build(map, tuning.nav, tuning.body)
	NavLifts.link(nav, level.query(), tuning.lifts, tuning.movement.run_speed, config.lift_wait)


func after_all() -> void:
	level.free()


## The lift legs in `route` from `start`, as [link, ...].
func _lift_legs(route: PackedVector3Array, start: Vector3) -> Array[int]:
	var out: Array[int] = []
	var a := start
	for b in route:
		var l := nav.lift_leg(a, b)
		if l >= 0:
			out.append(l)
		a = b
	return out


func test_kingsmere_has_a_link_each_way_between_every_two_stops_of_each_lift() -> void:
	assert_eq(nav.lift_to.size(), 12, "2 lifts, 3 stops: 6 rides each")
	assert_eq(NavLifts.link(nav, level.query(), tuning.lifts, 4.2, 4.0), 12, "a second call adds none")
	for l in nav.lift_to.size():
		var spec := level.query().lifts[nav.lift_of[l]]
		assert_almost_eq(nav.floor_y[nav.lift_from[l]], spec.stops[nav.lift_stop_from[l]], tuning.body.max_step)
		assert_almost_eq(nav.floor_y[nav.lift_to[l]], spec.stops[nav.lift_stop_to[l]], tuning.body.max_step)


func test_a_bot_s_route_from_the_platforms_lift_landing_to_the_hall_rides_and_a_walk_off_walks() -> void:
	var spec := level.query().lifts[1]
	var start := spec.landing_point(0, tuning.lifts)
	var goal := spec.landing_point(2, tuning.lifts) + Vector3(-2.0, 0.0, -3.0)
	var route := PackedVector3Array()
	assert_true(nav.find_route(start, goal, route, true))
	var legs := _lift_legs(route, start)
	assert_eq(legs.size(), 1, "one ride")
	if legs.size() == 1:
		assert_eq(nav.lift_stop_from[legs[0]], 0)
		assert_eq(nav.lift_stop_to[legs[0]], 2, "straight up to the hall")
	var walk := PackedVector3Array()
	assert_true(nav.find_route(start, goal, walk, false))
	assert_eq(_lift_legs(walk, start).size(), 0, "a walk-off goes by the stairs")
	assert_true(nav.find_route(start, goal, route, true), "the links back on after it")
	assert_eq(_lift_legs(route, start).size(), 1)


func test_a_route_planned_inside_a_car_starts_at_its_landing() -> void:
	var spec := level.query().lifts[0]
	var inside := spec.car_point(spec.stops[1]) + Vector3(0.0, tuning.body.rest_gap, 0.0)
	var route := PackedVector3Array()
	assert_true(nav.find_route(inside, spec.landing_point(1, tuning.lifts) + Vector3(-3.0, 0.0, -3.0), route, true))
	assert_almost_eq(route[0].y, spec.stops[1], tuning.body.max_step, "on the car's floor's landing")
	assert_lt(Vector2(route[0].x - spec.landing_point(1, tuning.lifts).x,
			route[0].z - spec.landing_point(1, tuning.lifts).z).length(), 0.5, "out of the door first")


func test_a_bot_calls_boards_rides_and_walks_out_at_the_hall() -> void:
	var q := level.query()
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in 2:
		state.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, loadout))
	var bots := BotController.new(state, -1, map, nav, q, tuning, config)
	sim.start_match(state)
	# The west car waits at the hall: a bot on the platforms' landing calls it down and rides it up.
	var spec := q.lifts[0]
	var bot: Bot = bots.world.bots[0]
	var me := bot.character
	me.position = spec.landing_point(0, tuning.lifts) + Vector3(0.0, tuning.body.rest_gap, 0.0)
	me.prev_position = me.position
	me.grounded = true
	state.characters[1].position = Vector3(75.5, 0.04, 7.5)
	var goal := spec.landing_point(2, tuning.lifts) + Vector3(-2.0, 0.0, -3.0)
	assert_true(nav.find_route(me.position, goal, bot.route, true))
	bot.route_from = me.position
	bot.route_leg = 0
	bot.route_state = Bot.RouteState.OK
	var cmd := PlayerCommand.new()
	var cmds: Array[PlayerCommand] = [cmd, null]
	var departs := 0
	var rode := false
	for t in roundi(40.0 / DT):
		cmd.reset(me.yaw, 0.0)
		bots.world.time = state.time
		bots.world.lifts = state.lifts
		if BotRoutes.follow(bot, bots.world, DT) and bot.move_dir != Vector3.ZERO:
			cmd.yaw = atan2(-bot.move_dir.x, -bot.move_dir.z)
			cmd.forward = 1.0
		if bot.lift_press != Lifts.NONE:
			cmd.use_door = true
			cmd.lift_to_use = bot.lift_press.x
			cmd.lift_stop = bot.lift_press.y
		sim.step(state, cmds, DT)
		for i in state.events.count:
			var e := state.events.items[i]
			if e.kind == GameEvent.Kind.LIFT and e.value == Lifts.Cue.DEPART:
				departs += 1
		rode = rode or Lifts.riding(q, tuning.lifts, state.lifts, me.position) == 0
		if BotRoutes.arrived(bot):
			break
	assert_true(rode, "aboard on the way")
	assert_eq(departs, 2, "down for it, up with it")
	assert_true(BotRoutes.arrived(bot), "at its goal in the hall")
	assert_almost_eq(me.position.y, spec.stops[2] + tuning.body.rest_gap, 0.1, "on the hall's floor")


func test_one_too_many_aboard_the_highest_id_steps_back_out() -> void:
	var q := level.query()
	var state := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	var spec := q.lifts[0]
	var n := tuning.lifts.capacity + 1
	for i in n:
		var at := spec.car_point(spec.stops[2]) + Vector3(0.1 * i - 0.2, tuning.body.rest_gap, 0.0)
		state.characters.append(Character.new(i, i % 2, at, 0.0, loadout))
	var bots := BotController.new(state, -1, map, nav, q, tuning, config)
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
	sim.start_match(state)
	for c in state.characters:
		c.position = spec.car_point(spec.stops[2]) + Vector3(0.1 * c.id - 0.2, tuning.body.rest_gap, 0.0)
	bots.world.lifts = state.lifts
	var link := -1
	for l in nav.lift_to.size():
		if nav.lift_of[l] == 0 and nav.lift_stop_from[l] == 2 and nav.lift_stop_to[l] == 0:
			link = l
	assert_gt(link, -1, "a ride from the hall down")
	assert_true(state.lifts.open_at(0, 2), "the west car stands open at the hall")
	var out := Vector3(spec.out.x, 0.0, spec.out.y)
	var last: Bot = bots.world.bots[n - 1]
	assert_true(BotLifts.ride(last, bots.world, link, DT))
	assert_gt(last.move_dir.dot(out), 0.5, "the highest id walks back out to the landing")
	var first: Bot = bots.world.bots[0]
	BotLifts.ride(first, bots.world, link, DT)
	assert_lt(first.move_dir.dot(out), 0.5, "the rest stay aboard")
