extends GutTest
## QA hunt on the lifts (MT2): a press while the car moves, two cars at once, a hit player's press, a restart mid-ride,
## maps without lifts, the drawn position's previous tick, a jump on a rising car, and a bot giving up on a car that
## never comes (game/sim/lifts.gd, simulation.gd, game/ai/bot_lifts.gd).

const DT := 1.0 / 60.0
const GAP := 0.04

var tuning: SimTuning = SimTuning.new()
var cfg: LiftConfig = tuning.lifts
var loadout: Array[ReplicaConfig] = []
var map: MapData = null
var level: MapLevel = null


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()
	map = MapData.load_map("subway", MapStyle.new(), 6)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body, null, null, false, null, cfg)


func after_all() -> void:
	level.free()


func _match(n: int) -> Array:
	var q := level.query()
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(5, tuning)
	for i in n:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	return [sim, state]


func _put(c: Character, at: Vector3) -> void:
	c.position = at + Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.velocity = Vector3.ZERO
	c.grounded = true


## Steps `ticks`; each character i presses Use on `picks[i]` (a Vector2i) at tick 0 when given.
func _run(sim: Simulation, state: GameState, ticks: int, picks: Array = []) -> void:
	var cmds: Array[PlayerCommand] = []
	for c in state.characters:
		cmds.append(PlayerCommand.new())
	for t in ticks:
		for i in cmds.size():
			var c := state.characters[i]
			cmds[i].reset(c.yaw, c.pitch)
			if t == 0 and i < picks.size() and picks[i] != Lifts.NONE:
				cmds[i].use_door = true
				cmds[i].lift_to_use = picks[i].x
				cmds[i].lift_stop = picks[i].y
		sim.step(state, cmds, DT)


func _ticks(seconds: float) -> int:
	return ceili(seconds / DT) + 4


func test_a_press_while_the_car_moves_is_kept_and_answered_after_the_stop() -> void:
	var m := _match(1)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var spec := level.query().lifts[1]
	var me := state.characters[0]
	_put(me, spec.car_point(spec.stops[0]))
	_run(sim, state, 1, [Vector2i(1, 1)])
	_run(sim, state, _ticks(cfg.door_time + 1.0))
	assert_eq(state.lifts.phase[1], LiftState.Phase.MOVING)
	_run(sim, state, 1, [Vector2i(1, 0)])
	assert_true(state.lifts.called(1, 0), "the stop it left is called again")
	_run(sim, state, _ticks(cfg.floor_time * 2.0))
	assert_eq(state.lifts.stop[1], 1, "it still finishes the ride it was on")
	_run(sim, state, _ticks(cfg.dwell + cfg.door_time * 2.0 + cfg.floor_time + cfg.door_time))
	assert_true(state.lifts.open_at(1, 0), "then it goes back")
	assert_almost_eq(me.position.y, spec.stops[0] + tuning.body.rest_gap, 0.05)


func test_two_cars_called_at_once_ride_on_their_own() -> void:
	var m := _match(2)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var q := level.query()
	_put(state.characters[0], q.lifts[0].car_point(q.lifts[0].stops[2]))
	_put(state.characters[1], q.lifts[1].car_point(q.lifts[1].stops[0]))
	_run(sim, state, 1, [Vector2i(0, 0), Vector2i(1, 2)])
	assert_eq(state.lifts.calls[0], 1)
	assert_eq(state.lifts.calls[1], 4)
	_run(sim, state, _ticks(cfg.door_time + cfg.floor_time * 2.0 + cfg.door_time + 1.0))
	assert_true(state.lifts.open_at(0, 0))
	assert_true(state.lifts.open_at(1, 2))
	assert_almost_eq(state.characters[0].position.y, q.lifts[0].stops[0] + tuning.body.rest_gap, 0.05)
	assert_almost_eq(state.characters[1].position.y, q.lifts[1].stops[2] + tuning.body.rest_gap, 0.05)


func test_a_hit_player_s_press_calls_nothing() -> void:
	var m := _match(2)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var spec := level.query().lifts[1]
	var me := state.characters[0]
	Elimination.eliminate(me, 1, state.characters, sim.ends)
	_put(me, spec.landing_point(2, cfg))
	_put(state.characters[1], Vector3(75.5, 0.0, 7.5))
	_run(sim, state, 5, [Vector2i(1, 2)])
	assert_eq(state.lifts.calls[1], 0, "a player who is out of play presses no button")
	assert_eq(state.lifts.caller[1], -1)


func test_a_new_match_mid_ride_puts_every_car_back_with_nothing_left_over() -> void:
	var m := _match(1)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var q := level.query()
	var spec := q.lifts[1]
	_put(state.characters[0], spec.car_point(spec.stops[0]))
	_run(sim, state, 1, [Vector2i(1, 2)])
	_run(sim, state, _ticks(cfg.door_time + cfg.floor_time * 0.7))
	assert_eq(state.lifts.phase[1], LiftState.Phase.MOVING)
	sim.start_match(state)
	for i in 2:
		assert_eq(state.lifts.phase[i], LiftState.Phase.OPEN)
		assert_eq(state.lifts.calls[i], 0)
		assert_eq(state.lifts.caller[i], -1)
		assert_eq(state.lifts.to[i], -1)
		assert_eq(state.lifts.prev_y[i], state.lifts.y[i], "no glide from where the old car was")
		assert_eq(state.lifts.rise[i], 0.0)
		assert_eq(state.lifts.stop[i], map.lifts[i].start)
	var door := spec.door_center(0)
	var hit := RayHit.new()
	assert_false(q.ray(door - Vector3(0, 0, 1), door + Vector3(0, 0, 1), hit) and absf(hit.position.z - door.z) < 0.2,
			"its start doorway is clear again")
	# The car is back to answer: the whole ride works a second time.
	_put(state.characters[0], spec.car_point(spec.stops[0]))
	_run(sim, state, 1, [Vector2i(1, 1)])
	_run(sim, state, _ticks(cfg.door_time + cfg.floor_time + cfg.door_time))
	assert_true(state.lifts.open_at(1, 1))


func test_the_drawn_car_is_between_last_tick_and_this() -> void:
	var m := _match(1)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var spec := level.query().lifts[1]
	_put(state.characters[0], spec.car_point(spec.stops[0]))
	_run(sim, state, 1, [Vector2i(1, 2)])
	_run(sim, state, _ticks(cfg.door_time) + 10)
	assert_eq(state.lifts.phase[1], LiftState.Phase.MOVING)
	for t in 30:
		var before := state.lifts.y[1]
		_run(sim, state, 1)
		assert_eq(state.lifts.prev_y[1], before, "prev_y is where the car stood a tick ago")
		assert_almost_eq(state.lifts.y[1] - state.lifts.prev_y[1], state.lifts.rise[1], 1e-6)


func test_a_jump_on_a_rising_car_never_goes_under_its_floor_and_lands_on_the_upper_landing() -> void:
	var m := _match(1)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var spec := level.query().lifts[1]
	var me := state.characters[0]
	_put(me, spec.car_point(spec.stops[0]))
	_run(sim, state, 1, [Vector2i(1, 1)])
	var cmds: Array[PlayerCommand] = [PlayerCommand.new()]
	var lowest := INF
	for t in _ticks(cfg.door_time + cfg.floor_time + cfg.door_time):
		cmds[0].reset(me.yaw, 0.0)
		cmds[0].jump = state.lifts.phase[1] == LiftState.Phase.MOVING and t % 25 == 0
		sim.step(state, cmds, DT)
		if Lifts.riding(level.query(), cfg, state.lifts, me.position) == 1:
			lowest = minf(lowest, me.position.y - state.lifts.y[1])
	assert_gt(lowest, -0.01, "the car never rises through its rider's feet")
	assert_true(state.lifts.open_at(1, 1))
	assert_almost_eq(me.position.y, spec.stops[1] + tuning.body.rest_gap, 0.05)


func test_a_map_without_lifts_has_no_lift_state_and_use_goes_to_the_doors() -> void:
	for id: String in ["depot", "woodland", "range"]:
		var mp := MapData.load_map(id, MapStyle.new(), 6)
		assert_not_null(mp, id)
		assert_eq(mp.lifts.size(), 0, id)
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 40.0))
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-5.0 + e * 10.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-5.0 + e * 10.0, 0.0, 5.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var state := GameState.new(3, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var cmd := PlayerCommand.new()
	var cmds: Array[PlayerCommand] = [cmd, null]
	for t in 20:
		cmd.reset(0.0, 0.0)
		cmd.use_door = true
		sim.step(state, cmds, DT)
	assert_eq(state.lifts.count(), 0)
	assert_eq(sim.lifts.count(), 0)
	var cmd2 := PlayerCommand.new()
	assert_false(sim.lifts.press(state.characters[0], cmd2, state), "no lift button to press")
	assert_eq(Lifts.pick(w, cfg, state.lifts, Vector3.ZERO, Vector3(0, 1.6, 0), 0.0, 0.0), Lifts.NONE)


func test_a_bot_gives_up_on_a_car_that_never_comes() -> void:
	var config := BotConfig.load_default()
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var q := level.query()
	NavLifts.link(nav, q, cfg, tuning.movement.run_speed, config.lift_wait)
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(5, tuning)
	for i in 3:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	var bots := BotController.new(state, -1, map, nav, q, tuning, config)
	sim.start_match(state)
	var spec := q.lifts[0]
	var bot: Bot = bots.world.bots[0]
	var me := bot.character
	_put(me, spec.landing_point(0, cfg))
	# A body holds the hall doorway: the car waiting there can never shut and come.
	var door := spec.door_center(2)
	_put(state.characters[1], Vector3(door.x, spec.stops[2], door.z))
	_put(state.characters[2], Vector3(75.5, 0.0, 7.5))
	var goal := spec.landing_point(2, cfg) + Vector3(-2.0, 0.0, -3.0)
	assert_true(nav.find_route(me.position, goal, bot.route, true))
	bot.route_from = me.position
	bot.route_leg = 0
	bot.route_state = Bot.RouteState.OK
	var cmd := PlayerCommand.new()
	var cmds: Array[PlayerCommand] = [cmd, null, null]
	var gave_up := false
	for t in roundi((config.lift_patience + 8.0) / DT):
		cmd.reset(me.yaw, 0.0)
		bots.world.time = state.time
		bots.world.lifts = state.lifts
		if not BotRoutes.follow(bot, bots.world, DT):
			gave_up = true
			break
		if bot.lift_press != Lifts.NONE:
			cmd.use_door = true
			cmd.lift_to_use = bot.lift_press.x
			cmd.lift_stop = bot.lift_press.y
		sim.step(state, cmds, DT)
	assert_true(gave_up or bot.route_state == Bot.RouteState.WANTED, "waiting is bounded by lift_patience")
