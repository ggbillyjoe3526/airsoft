extends GutTest
## Lifts (MT2; the concept's defaults of 2026-11-10: 4 a car, doors 1.5 s, 4 s a floor): a call brings the car, its
## doors shut, it rides and opens; its riders rise and fall with it; a doorway is solid but where the car stands open;
## the doors never shut on a body, with anyone hit aboard or too many aboard; the panel and the call button the view
## picks; a new round puts every car back; Subway's file lists its two and Jolt moves their cars
## (game/sim/lifts.gd, lift_state.gd, lift_spec.gd, game/map/map_data.gd, map_level.gd, jolt_query.gd).

const DT := 1.0 / 60.0
const GAP := 0.04
## The test shaft's stops: the ground at 0, a landing at 4 m.
const LOW := 0.0
const HIGH := 4.0

var tuning: SimTuning = SimTuning.new()
var cfg: LiftConfig = tuning.lifts
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


## A lift whose well is x -1..1, z -1..1, its 1 m door in the north (-z) face, stopping at LOW and HIGH, waiting at
## `start`.
func _spec(start: int = 0) -> LiftSpec:
	var s := LiftSpec.new()
	s.name = "test"
	s.well = Rect2(-1.0, -1.0, 2.0, 2.0)
	s.out = Vector2(0.0, -1.0)
	s.door_from = -0.5
	s.door_to = 0.5
	s.door_height = 2.1
	s.door_depth = 0.3
	s.stops = PackedFloat32Array([LOW, HIGH])
	s.stop_names = PackedStringArray(["Ground", "Upper"])
	s.start = start
	return s


## The shaft (its walls, a door hole at each stop), a landing north of it at each stop and the lift.
func _world(start: int = 0) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, -6.0), Vector3(20.0, 0.5, 9.4))         # the ground landing, z -10.7..-1.3
	w.add_box(Vector3(0.0, HIGH - 0.15, -6.0), Vector3(20.0, 0.3, 9.4))    # the upper landing
	w.add_box(Vector3(-0.9, 3.0, -1.15), Vector3(0.8, 8.0, 0.3))           # the north wall beside the door
	w.add_box(Vector3(0.9, 3.0, -1.15), Vector3(0.8, 8.0, 0.3))
	w.add_box(Vector3(0.0, -0.5, -1.15), Vector3(1.0, 1.0, 0.3))           # under, between and over the doors
	w.add_box(Vector3(0.0, 3.05, -1.15), Vector3(1.0, 1.9, 0.3))
	w.add_box(Vector3(0.0, 6.55, -1.15), Vector3(1.0, 0.9, 0.3))
	w.add_box(Vector3(0.0, 3.0, 1.15), Vector3(2.6, 8.0, 0.3))             # south, west and east walls
	w.add_box(Vector3(-1.15, 3.0, 0.0), Vector3(0.3, 8.0, 2.0))
	w.add_box(Vector3(1.15, 3.0, 0.0), Vector3(0.3, 8.0, 2.0))
	w.add_lift(_spec(start), cfg)
	return w


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-8.0 if e == 0 else 8.0, 0.0, -9.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-9.0 if e == 0 else 9.0, 0.0, -10.0), 0.0))
		ends.append(end)
	return ends


## [Simulation, GameState] on `w` with `n` characters (alternating teams) far off on the ground landing.
func _match(w: BoxWorld, n: int = 2) -> Array:
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	for i in n:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	for i in n:
		_place(state.characters[i], Vector3(-8.0 + i * 0.8, LOW, -9.0), 0.0)
	return [sim, state]


func _place(c: Character, at: Vector3, yaw: float) -> void:
	c.position = at + Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.yaw = yaw
	c.pitch = 0.0
	c.velocity = Vector3.ZERO
	c.grounded = true


## Steps `ticks` ticks, character 0 pressing Use on the first (its controller's pick `at`, or the view's); returns the
## LIFT cues seen, in order.
func _run(sim: Simulation, state: GameState, ticks: int, use: bool = false, at: Vector2i = Lifts.NONE) -> Array[int]:
	var cues: Array[int] = []
	for t in ticks:
		var cmds: Array[PlayerCommand] = []
		for c in state.characters:
			var cmd := PlayerCommand.new()
			cmd.reset(c.yaw, c.pitch)
			cmds.append(cmd)
		cmds[0].use_door = use and t == 0
		cmds[0].lift_to_use = at.x
		cmds[0].lift_stop = at.y
		sim.step(state, cmds, DT)
		for i in state.events.count:
			var e := state.events.items[i]
			if e.kind == GameEvent.Kind.LIFT:
				cues.append(e.value)
	return cues


## Whether a level ray across stop `k`'s doorway (at knee height) meets anything.
func _doorway_solid(w: BoxWorld, k: int) -> bool:
	var y := (LOW if k == 0 else HIGH) + 0.5
	return w.ray(Vector3(0.0, y, -2.0), Vector3(0.0, y, -0.5), RayHit.new())


## Ticks enough for `seconds` of the car's doings, with a tick of each phase's rounding to spare.
func _ticks(seconds: float) -> int:
	return ceili(seconds / DT) + 4


func test_a_round_starts_with_the_car_open_at_its_start_stop_and_the_other_doorway_shut() -> void:
	var w := _world(0)
	var state: GameState = _match(w)[1]
	assert_eq(state.lifts.count(), 1)
	assert_eq(state.lifts.stop[0], 0)
	assert_true(state.lifts.open_at(0, 0))
	assert_almost_eq(state.lifts.y[0], LOW, 1e-6)
	assert_false(_doorway_solid(w, 0), "the car stands open at the ground: its doorway is clear")
	assert_true(_doorway_solid(w, 1), "the upper doorway is shut: the car isn't there")


func test_a_call_brings_the_car_shut_ride_open_in_the_set_times() -> void:
	var w := _world(0)
	var m := _match(w)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var me := state.characters[0]
	_place(me, Vector3(0.0, HIGH, -2.0), 0.0)
	var cues := _run(sim, state, 2, true)
	assert_eq(cues, [Lifts.Cue.BUTTON, Lifts.Cue.SHUTTING], "the call beeps and the car shuts its doors next tick")
	assert_true(state.lifts.called(0, 1))
	assert_true(_doorway_solid(w, 0), "shutting, the doorway is solid at once")
	cues = _run(sim, state, _ticks(cfg.door_time) - 2)
	assert_eq(cues, [Lifts.Cue.DEPART])
	assert_eq(state.lifts.phase[0], LiftState.Phase.MOVING)
	# Half the ride: half the way up.
	_run(sim, state, roundi(cfg.floor_time * 0.5 / DT))
	assert_almost_eq(state.lifts.y[0], (LOW + HIGH) * 0.5, 0.1)
	cues = _run(sim, state, _ticks(cfg.floor_time * 0.5))
	assert_eq(cues, [Lifts.Cue.ARRIVE])
	assert_almost_eq(state.lifts.y[0], HIGH, 1e-6)
	assert_true(_doorway_solid(w, 1), "opening, the doorway stays solid until the doors stand open")
	_run(sim, state, _ticks(cfg.door_time))
	assert_true(state.lifts.open_at(0, 1))
	assert_false(_doorway_solid(w, 1))
	assert_true(_doorway_solid(w, 0))
	assert_false(state.lifts.called(0, 1), "arriving answers the call")


func test_a_rider_rises_with_the_car_and_steps_out_on_the_upper_landing() -> void:
	var w := _world(0)
	var m := _match(w)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var me := state.characters[0]
	_place(me, Vector3(0.0, LOW, 0.2), 0.0)
	_run(sim, state, 1, true, Vector2i(0, 1))
	assert_true(state.lifts.called(0, 1), "the panel's button calls the stop")
	var lowest := INF
	var last := me.position.y
	var steady := true
	for t in _ticks(cfg.door_time + cfg.floor_time + cfg.door_time):
		_run(sim, state, 1)
		lowest = minf(lowest, me.position.y - state.lifts.y[0])
		steady = steady and me.position.y >= last - 1e-4
		last = me.position.y
	assert_true(steady, "never falls back on the way up")
	assert_gt(lowest, -0.01, "never under the car's floor")
	assert_true(state.lifts.open_at(0, 1))
	assert_almost_eq(me.position.y, HIGH + tuning.body.rest_gap, 0.02)
	assert_true(me.grounded, "grounded at %s, velocity %s" % [me.position, me.velocity])
	# Out of the car onto the landing.
	for t in 90:
		var cmds: Array[PlayerCommand] = []
		var cmd := PlayerCommand.new()
		cmd.reset(0.0, 0.0)
		cmd.forward = 1.0
		cmds.append(cmd)
		cmds.append(null)
		sim.step(state, cmds, DT)
	assert_lt(me.position.z, -2.0, "walked out north")
	assert_almost_eq(me.position.y, HIGH + tuning.body.rest_gap, 0.05, "on the upper landing")


func test_a_rider_rides_down_standing_on_the_floor() -> void:
	var w := _world(1)
	var m := _match(w)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var me := state.characters[0]
	_place(me, Vector3(0.3, HIGH, 0.3), 0.0)
	_run(sim, state, 1, true, Vector2i(0, 0))
	var off := 0.0
	for t in _ticks(cfg.door_time + cfg.floor_time):
		_run(sim, state, 1)
		off = maxf(off, absf(me.position.y - state.lifts.y[0] - tuning.body.rest_gap))
	assert_lt(off, 0.05, "stays on the floor all the way down")
	assert_almost_eq(me.position.y, LOW + tuning.body.rest_gap, 0.02)


func test_the_doors_never_shut_on_a_body_in_the_doorway() -> void:
	var w := _world(0)
	var m := _match(w, 3)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	_place(state.characters[0], Vector3(0.0, HIGH, -2.0), 0.0)
	_place(state.characters[1], Vector3(0.0, LOW, -1.15), 0.0)
	_run(sim, state, 60, true)
	assert_eq(state.lifts.phase[0], LiftState.Phase.OPEN, "held open by the body in its doorway")
	_place(state.characters[1], Vector3(4.0, LOW, -6.0), 0.0)
	_run(sim, state, 2)
	assert_eq(state.lifts.phase[0], LiftState.Phase.SHUTTING, "shuts once the doorway is clear")


func test_a_press_while_shutting_opens_the_doors_again() -> void:
	var w := _world(0)
	var m := _match(w)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var me := state.characters[0]
	_place(me, Vector3(0.0, HIGH, -2.0), 0.0)
	_run(sim, state, 30, true)
	_place(me, Vector3(0.0, LOW, -2.0), 0.0)
	var cues := _run(sim, state, 1, true)
	assert_eq(cues, [Lifts.Cue.BUTTON, Lifts.Cue.OPENING])
	assert_eq(state.lifts.phase[0], LiftState.Phase.OPENING)
	assert_true(state.lifts.called(0, 1), "the upper call is kept")
	_run(sim, state, _ticks(cfg.door_time))
	assert_true(state.lifts.open_at(0, 0), "open again where it stood")


func test_too_many_aboard_it_buzzes_and_stays() -> void:
	var w := _world(0)
	var n := cfg.capacity + 2
	var m := _match(w, n)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	_place(state.characters[0], Vector3(0.0, HIGH, -2.0), 0.0)
	for i in range(1, n):
		_place(state.characters[i], Vector3(-0.6 + 0.4 * ((i - 1) % 3), LOW, -0.5 + 0.6 * ((i - 1) / 3)), 0.0)
	var cues := _run(sim, state, 90, true)
	assert_eq(state.lifts.phase[0], LiftState.Phase.OPEN)
	assert_has(cues, Lifts.Cue.BUZZ)
	assert_false(cues.has(Lifts.Cue.SHUTTING))


func test_it_never_shuts_with_anyone_hit_aboard() -> void:
	var w := _world(0)
	var m := _match(w, 3)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	_place(state.characters[0], Vector3(0.0, HIGH, -2.0), 0.0)
	var hit := state.characters[1]
	_place(hit, Vector3(0.0, LOW, 0.3), 0.0)
	Elimination.eliminate(hit, 0, state.characters, sim.ends)
	var cues := _run(sim, state, 30, true)
	assert_false(cues.has(Lifts.Cue.SHUTTING), "it waits for them to walk off")


## PP1: someone hit while the car rides stands in it, calling the hit, until its doors open (no walking into its walls,
## no leaving the field for being stuck), then walks off.
func test_a_body_hit_mid_ride_walks_off_only_once_the_doors_open() -> void:
	var w := _world(0)
	var m := _match(w)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var me := state.characters[0]
	_place(me, Vector3(0.0, LOW, 0.2), 0.0)
	_run(sim, state, 1, true, Vector2i(0, 1))
	_run(sim, state, _ticks(cfg.door_time))
	assert_eq(state.lifts.phase[0], LiftState.Phase.MOVING, "on its way up")
	Elimination.eliminate(me, 1, state.characters, sim.ends)
	var at := Vector2(me.position.x, me.position.z)
	var drift := 0.0
	var ticks := 0
	while not state.lifts.open_at(0, 1) and ticks < _ticks(cfg.floor_time + cfg.door_time):
		_run(sim, state, 1)
		drift = maxf(drift, (Vector2(me.position.x, me.position.z) - at).length())
		ticks += 1
	assert_true(state.lifts.open_at(0, 1), "the car opened upstairs")
	assert_eq(me.status, Character.Status.WALKING_OFF, "walking off, not left the field")
	assert_lt(drift, 0.05, "stood still while the doors were shut")
	_run(sim, state, 60)
	assert_gt((Vector2(me.position.x, me.position.z) - at).length(), 0.5, "walks off once they are open")


## PB1: Plant The Bomb's carrier hit in a moving car leaves the bomb on the landing the car last stood at, never in the
## car or hanging in the shaft.
func test_a_bomb_carrier_hit_mid_ride_leaves_the_bomb_on_the_landing_it_left() -> void:
	var w := _world(0)
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	for i in 3:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	state.round_state.mode = RoundState.Mode.PLANT_THE_BOMB
	sim.start_match(state)
	for i in 3:
		_place(state.characters[i], Vector3(-8.0 + i * 0.8, LOW, -9.0), 0.0)
	var me := state.characters[0]
	var ps := state.round_state.plant
	ps.status = PlantState.Status.CARRIED
	ps.carrier = me.id
	_place(me, Vector3(0.0, LOW, 0.2), 0.0)
	_run(sim, state, 1, true, Vector2i(0, 1))
	_run(sim, state, _ticks(cfg.door_time + cfg.floor_time * 0.5))
	assert_eq(state.lifts.phase[0], LiftState.Phase.MOVING, "on its way up")
	assert_gt(me.position.y, LOW + 0.5, "the carrier rides with it")
	assert_true(ps.on_lift)
	Elimination.eliminate(me, 1, state.characters, sim.ends)
	_run(sim, state, 1)
	assert_eq(ps.status, PlantState.Status.DOWN, "dropped")
	var landing := _spec().landing_point(0, cfg)
	assert_eq(ps.position, landing, "on the landing the car left")
	assert_lt(ps.position.z, -1.3, "outside the shaft")
	assert_almost_eq(ps.position.y, LOW, 1e-4, "on its floor")
	# Out of a car, the carrier's own floor is the resting place again.
	ps.status = PlantState.Status.CARRIED
	ps.carrier = state.characters[2].id
	_run(sim, state, 2)
	assert_false(ps.on_lift)
	assert_almost_eq(ps.rest.y, state.characters[2].position.y, 1e-4)


## PP1: a bomb lying on the car's floor rides up with it and still lies on it at the top.
func test_a_bomb_on_the_car_s_floor_rides_with_it() -> void:
	var w := _world(0)
	var m := _match(w)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var me := state.characters[0]
	_place(me, Vector3(0.3, LOW, 0.3), 0.0)
	var r := tuning.grenades.radius
	var g := state.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 0, Vector3(-0.5, LOW + r, 0.5), Vector3.ZERO)
	g.resting = true
	_run(sim, state, 1, true, Vector2i(0, 1))
	var off := 0.0
	for t in _ticks(cfg.door_time + cfg.floor_time + cfg.door_time):
		_run(sim, state, 1)
		off = maxf(off, absf(g.position.y - state.lifts.y[0] - r))
	assert_true(state.lifts.open_at(0, 1))
	assert_true(g.active)
	assert_lt(off, 0.02, "on the car's floor all the way up")
	assert_almost_eq(g.position.y, HIGH + r, 0.02)


func test_the_view_picks_the_panel_button_inside_and_the_call_button_outside() -> void:
	var w := _world(0)
	var state: GameState = _match(w)[1]
	var spec := w.lifts[0]
	var eye := Vector3(0.0, LOW + tuning.body.stand_eye_height, 0.4)
	var feet := Vector3(0.0, LOW + GAP, 0.4)
	for k in 2:
		var to := spec.panel_button(k, state.lifts.y[0], cfg) - eye
		var yaw := atan2(-to.x, -to.z)
		var pitch := atan2(to.y, Vector2(to.x, to.z).length())
		assert_eq(Lifts.pick(w, cfg, state.lifts, feet, eye, yaw, pitch), Vector2i(0, k), "panel button %d" % k)
	var out := Vector3(0.3, HIGH + GAP, -2.2)
	assert_eq(Lifts.pick(w, cfg, state.lifts, out, out + Vector3(0, 1.6, 0), 0.0, 0.0), Vector2i(0, 1),
			"the upper landing's call")
	var far := Vector3(4.0, LOW + GAP, -6.0)
	assert_eq(Lifts.pick(w, cfg, state.lifts, far, far + Vector3(0, 1.6, 0), 0.0, 0.0), Lifts.NONE, "out of reach")
	var under := Vector3(0.0, LOW + GAP, -2.0)
	assert_eq(Lifts.pick(w, cfg, state.lifts, under, under + Vector3(0, 1.6, 0), 0.0, 0.0), Vector2i(0, 0),
			"the ground's call, not the landing over it")


func test_a_new_round_puts_the_car_back() -> void:
	var w := _world(0)
	var m := _match(w)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	_place(state.characters[0], Vector3(0.0, HIGH, -2.0), 0.0)
	_run(sim, state, _ticks(cfg.door_time + cfg.floor_time * 0.5), true)
	assert_eq(state.lifts.phase[0], LiftState.Phase.MOVING)
	sim.lifts.reset(state.lifts)
	assert_true(state.lifts.open_at(0, 0))
	assert_almost_eq(state.lifts.y[0], LOW, 1e-6)
	assert_false(_doorway_solid(w, 0))
	assert_true(_doorway_solid(w, 1))
	assert_eq(state.lifts.calls[0], 0)


func test_a_stop_called_on_the_way_is_stopped_at() -> void:
	var w := BoxWorld.new(tuning.body)
	var spec := _spec(0)
	spec.stops = PackedFloat32Array([0.0, 4.0, 8.0])
	spec.stop_names = PackedStringArray(["a", "b", "c"])
	w.add_lift(spec, cfg)
	var m := _match(w)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	state.lifts.calls[0] = 1 << 2
	_run(sim, state, _ticks(cfg.door_time + cfg.floor_time * 0.5))
	assert_eq(state.lifts.to[0], 2)
	state.lifts.calls[0] |= 1 << 1
	_run(sim, state, _ticks(cfg.floor_time * 0.5))
	assert_eq(state.lifts.stop[0], 1, "stopped at the middle stop called on the way up")
	assert_true(state.lifts.called(0, 2), "the top still called")
	_run(sim, state, _ticks(cfg.door_time + cfg.dwell + cfg.door_time + cfg.floor_time))
	assert_eq(state.lifts.stop[0], 2, "then on up")


func test_subway_lists_two_lifts_of_three_stops() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	assert_not_null(m)
	assert_eq(m.lifts.size(), 2)
	for spec in m.lifts:
		assert_eq(spec.stop_count(), 3)
		assert_eq(spec.stop_names[2], "Ticket hall")
	assert_eq(m.lifts[0].start, 2, "one car waits at the hall")
	assert_eq(m.lifts[1].start, 0, "the other at the platforms")


## PP1: a body in either of Subway's cars is in the "Lift" area at every stop (no area, or the ticket hall's, before),
## and one on a landing outside its door in the landing's.
func test_subway_s_cars_are_the_lift_area_at_every_stop() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	for spec in m.lifts:
		for k in spec.stop_count():
			var inside := spec.car_point(spec.stops[k]) + Vector3(0.0, GAP, 0.0)
			assert_eq(MapAreas.area_at(m.areas, inside), "Lift", "%s at %s" % [spec.name, spec.stop_names[k]])
			var out := spec.landing_point(k, cfg) + Vector3(0.0, GAP, 0.0)
			assert_ne(MapAreas.area_at(m.areas, out), "Lift", "%s's landing at %s" % [spec.name, spec.stop_names[k]])


func test_a_malformed_lift_is_left_out_with_a_warning() -> void:
	var m := MapData.new()
	m._read_lifts([{"well": {"x0": 0, "x1": 2, "z0": 0, "z1": 2}, "door": {"face": "n", "from": 0.5, "to": 1.5,
			"height": 2.1}, "stops": [4, 0]}, {"well": {"x0": 0, "x1": 2, "z0": 0, "z1": 2},
			"door": {"face": "up", "from": 0.5, "to": 1.5, "height": 2.1}, "stops": [0, 4]}])
	assert_eq(m.lifts.size(), 0)
	assert_eq(m.warnings.size(), 2)


func test_jolt_moves_subway_s_car_and_switches_its_doorways_at_once() -> void:
	var map := MapData.load_map("subway", MapStyle.new(), 6)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, MapStyle.new(), tuning.body, null, null, false, null, cfg)
	var q := level.query()
	assert_eq(q.lift_count(), 2)
	var spec := q.lifts[0]
	var mid := spec.car_point(spec.stops[1])
	var hit := RayHit.new()
	q.set_lift_car(0, spec.stops[1])
	assert_true(q.ray(mid + Vector3(0, 1.0, 0), mid - Vector3(0, 1.0, 0), hit), "the car's floor at the concourse")
	assert_almost_eq(hit.position.y, spec.stops[1], 1e-3)
	assert_eq(hit.surface, RayHit.Surface.METAL)
	q.set_lift_car(0, spec.stops[2])
	assert_false(q.ray(mid + Vector3(0, 1.0, 0), mid - Vector3(0, 1.0, 0), hit), "moved up, at once")
	var door := spec.door_center(1)
	var across := Vector3(0.0, 0.0, 1.0)
	q.set_lift_door(0, 1, true)
	assert_true(q.ray(door - across, door + across, hit), "the concourse's doorway shut")
	q.set_lift_door(0, 1, false)
	q.set_lift_car(0, spec.stops[0])
	assert_false(q.ray(door - across + Vector3(0, -0.5, 0), door + across * 0.6, hit), "open, a clear doorway")


func test_a_ride_on_subway_takes_a_body_from_the_platforms_to_the_hall() -> void:
	var map := MapData.load_map("subway", MapStyle.new(), 6)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, MapStyle.new(), tuning.body, null, null, false, null, cfg)
	var q := level.query()
	var sim := Simulation.new(tuning, q, level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(3, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	# The east car waits at the platforms: walk in from its landing, press the hall's button, ride, walk out.
	var spec := q.lifts[1]
	var me := state.characters[0]
	_place(me, spec.landing_point(0, cfg), 0.0)
	var cmd := PlayerCommand.new()
	var cmds: Array[PlayerCommand] = [cmd]
	for t in 120:
		cmd.reset(PI, 0.0)
		cmd.forward = 1.0 if me.position.z < spec.well.get_center().y else 0.0
		sim.step(state, cmds, DT)
	assert_eq(Lifts.riding(q, cfg, state.lifts, me.position), 1, "aboard the east car")
	cmd.reset(PI, 0.0)
	cmd.use_door = true
	cmd.lift_to_use = 1
	cmd.lift_stop = 2
	sim.step(state, cmds, DT)
	for t in _ticks(cfg.door_time + cfg.floor_time * 2.0 + cfg.door_time):
		cmd.reset(PI, 0.0)
		sim.step(state, cmds, DT)
	assert_true(state.lifts.open_at(1, 2), "open at the hall")
	assert_almost_eq(me.position.y, spec.stops[2] + tuning.body.rest_gap, 0.05, "rode up with it")
	for t in 120:
		cmd.reset(0.0, 0.0)
		cmd.forward = 1.0
		sim.step(state, cmds, DT)
	assert_lt(me.position.z, spec.landing_point(2, cfg).z + 0.3, "walked out into the ticket hall")
	assert_almost_eq(me.position.y, spec.stops[2] + tuning.body.rest_gap, 0.05)
