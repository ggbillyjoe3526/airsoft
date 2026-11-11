extends GutTest
## Bots and lifts (MT2): Subway's lift links (a ride from each stop's landing to each other's, priced as the ride's
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
	map = MapData.load_map("subway", MapStyle.new(), 6)
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


func test_subway_has_a_link_each_way_between_every_two_stops_of_each_lift() -> void:
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


## The link of lift `lift` from stop `from` to stop `to`, or -1.
func _link(lift: int, from: int, to: int) -> int:
	for l in nav.lift_to.size():
		if nav.lift_of[l] == lift and nav.lift_stop_from[l] == from and nav.lift_stop_to[l] == to:
			return l
	return -1


## [Simulation, GameState, BotController] on Subway with `n` bots, the round live (no start countdown).
func _bots_match(n: int) -> Array:
	var q := level.query()
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in n:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	var bots := BotController.new(state, -1, map, nav, q, tuning, config)
	sim.start_match(state)
	state.round_state.hold = 0.0
	bots.world.lifts = state.lifts
	return [sim, state, bots]


func _stand(c: Character, at: Vector3) -> void:
	c.position = at + Vector3(0.0, tuning.body.rest_gap, 0.0)
	c.prev_position = c.position
	c.velocity = Vector3.ZERO
	c.grounded = true


## A tick of every bot walking lift link `link` (BotLifts.ride, then keep_apart as BotBrain does) into `cmds`, then the
## simulation's; returns the LIFT cues seen.
func _ride_tick(sim: Simulation, state: GameState, bots: BotController, link: int,
		cmds: Array[PlayerCommand]) -> Array[int]:
	bots.world.time = state.time
	for b: Bot in bots.world.bots:
		var me := b.character
		var cmd := cmds[me.id]
		cmd.reset(me.yaw, 0.0)
		BotLifts.ride(b, bots.world, link, DT)
		if BotMovement.keep_apart(b, bots.world, b.move_dir != Vector3.ZERO, cmd) and b.move_dir != Vector3.ZERO:
			cmd.yaw = atan2(-b.move_dir.x, -b.move_dir.z)
			cmd.forward = 1.0
		if b.lift_press != Lifts.NONE:
			cmd.use_door = true
			cmd.lift_to_use = b.lift_press.x
			cmd.lift_stop = b.lift_press.y
	sim.step(state, cmds, DT)
	var cues: Array[int] = []
	for i in state.events.count:
		var e := state.events.items[i]
		if e.kind == GameEvent.Kind.LIFT:
			cues.append(e.value)
	return cues


func _commands(n: int) -> Array[PlayerCommand]:
	var cmds: Array[PlayerCommand] = []
	for i in n:
		cmds.append(PlayerCommand.new())
	return cmds


## PP1: a full car open at the hall shuts and leaves with its four while a fifth waits on the landing, which presses
## nothing while it stands open there (a press each tick held the doors and beeped 60 times a second).
func test_a_full_car_leaves_while_a_fifth_waits_and_the_call_button_isn_t_pressed_every_tick() -> void:
	var m := _bots_match(tuning.lifts.capacity + 1)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var bots: BotController = m[2]
	var spec := level.query().lifts[0]
	var link := _link(0, 2, 0)
	assert_gt(link, -1)
	assert_true(state.lifts.open_at(0, 2), "the west car stands open at the hall")
	var n := tuning.lifts.capacity
	for i in n:
		_stand(state.characters[i], spec.car_point(spec.stops[2]) + Vector3(0.3 * (i % 2) - 0.15, 0.0,
				0.3 * (i / 2) - 0.15))
	var fifth := state.characters[n]
	_stand(fifth, spec.landing_point(2, tuning.lifts))
	var cmds := _commands(n + 1)
	var buttons := 0
	var left_at := -1.0
	var aboard_then := -1
	for t in roundi((tuning.lifts.dwell + tuning.lifts.door_time * 2.0) / DT):
		var cues := _ride_tick(sim, state, bots, link, cmds)
		buttons += cues.count(Lifts.Cue.BUTTON)
		if cues.has(Lifts.Cue.DEPART) and left_at < 0.0:
			left_at = state.time
			aboard_then = sim.lifts.aboard(0, state.lifts, state.characters)
	assert_gt(left_at, 0.0, "the car left the hall")
	assert_eq(aboard_then, n, "with its four aboard")
	assert_false(spec.holds(fifth.position, state.lifts.y[0], tuning.lifts), "the fifth left behind")
	assert_lt(buttons, n + 3, "a press or so each, never one a tick")


## PP1: four bots walk in from the landing, each to its own spot clear of the doorway (none shoved into it by keeping
## apart), and the doors shut within the dwell of the last one aboard.
func test_four_riders_board_and_the_doors_shut_within_the_dwell() -> void:
	var m := _bots_match(tuning.lifts.capacity)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var bots: BotController = m[2]
	var spec := level.query().lifts[0]
	var link := _link(0, 2, 0)
	var n := tuning.lifts.capacity
	var out := Vector3(spec.out.x, 0.0, spec.out.y)
	for i in n:
		_stand(state.characters[i], spec.landing_point(2, tuning.lifts) + out * 0.3 * (i / 2)
				+ Vector3(0.4 * (i % 2) - 0.2, 0.0, 0.0))
	var cmds := _commands(n)
	var all_in := -1.0
	var shut_at := -1.0
	for t in roundi(12.0 / DT):
		var cues := _ride_tick(sim, state, bots, link, cmds)
		if all_in < 0.0 and sim.lifts.aboard(0, state.lifts, state.characters) == n:
			all_in = state.time
		assert_false(cues.has(Lifts.Cue.DEPART) and all_in < 0.0, "never off with one left behind")
		if all_in >= 0.0 and cues.has(Lifts.Cue.SHUTTING) and state.lifts.stop[0] == 2:
			shut_at = state.time
			break
	assert_gt(all_in, 0.0, "all four aboard: %d" % sim.lifts.aboard(0, state.lifts, state.characters))
	assert_gt(shut_at, 0.0, "the doors shut")
	assert_lte(shut_at - all_in, tuning.lifts.dwell + DT, "within the dwell of the last one in")
	assert_false(sim.lifts.doorway_blocked(0, 2, state.characters), "nobody in the doorway")
	for c in state.characters:
		var depth := (c.position.z - spec.face_at()) * -spec.out.y
		assert_gt(depth, tuning.body.radius, "%d stands a body's width in from the door's face" % c.id)


## PP1: a route planned inside a moving car starts at the landing of the stop it is making for, not the one nearest
## its height; a walk-off from a car waits for its doors and then starts at that stop's landing.
func test_a_route_planned_mid_ride_starts_at_the_car_s_destination_and_a_walk_off_waits_for_the_doors() -> void:
	var q := level.query()
	var spec := q.lifts[0]
	var lifts := LiftState.new()
	Lifts.new(tuning, q).reset(lifts)
	lifts.phase[0] = LiftState.Phase.MOVING
	lifts.y[0] = 4.0
	lifts.to[0] = 2
	var inside := spec.car_point(4.0) + Vector3(0.0, tuning.body.rest_gap, 0.0)
	var goal := spec.landing_point(2, tuning.lifts) + Vector3(-3.0, 0.0, -3.0)
	var route := PackedVector3Array()
	assert_true(nav.find_route(inside, goal, route, true, lifts))
	assert_almost_eq(route[0].y, spec.stops[2], tuning.body.max_step, "from the hall's landing, where it is going")
	assert_true(nav.find_route(inside, goal, route, true))
	assert_almost_eq(route[0].y, spec.stops[0], tuning.body.max_step, "without the cars: the nearest stop's")
	var c := Character.new(0, 0, inside, 0.0, ReplicaStats.default_loadout())
	c.dead_zone_target = goal
	c.walk_off_route_pending = true
	var chars: Array[Character] = [c]
	assert_false(Elimination.plan_walk_off_routes(chars, nav, lifts), "not while the car rides")
	assert_true(c.walk_off_route_pending)
	assert_false(Elimination.walk_off_due(c, nav, lifts))
	lifts.phase[0] = LiftState.Phase.OPEN
	lifts.stop[0] = 2
	lifts.y[0] = spec.stops[2]
	lifts.to[0] = -1
	c.position = spec.car_point(spec.stops[2]) + Vector3(0.0, tuning.body.rest_gap, 0.0)
	assert_true(Elimination.plan_walk_off_routes(chars, nav, lifts), "once it stands open")
	assert_almost_eq(c.walk_off_route[0].y, spec.stops[2], tuning.body.max_step, "out at the hall")
