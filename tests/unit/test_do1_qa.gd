extends GutTest
## QA hunt on the hinged doors (DO1): a bot's Use must open the door it walks into, practice, maps without doors, and
## the out-of-play press (game/sim/doors.gd, simulation.gd, map_data.gd, door_view.gd).

const DT := 1.0 / 60.0
const GAP := 0.04
## Yaw that looks along +X (forward is -sin, -cos of the yaw).
const EAST := -PI * 0.5

var tuning: SimTuning = SimTuning.new()
var style: MapStyle = MapStyle.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-12.0 if e == 0 else 12.0, 0.0, 12.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-14.0 if e == 0 else 14.0, 0.0, 14.0), 0.0))
		ends.append(end)
	return ends


## [Simulation, GameState] on `w`: character 0 (team 0) at `at` facing `yaw`, character 1 (team 1) far off.
func _match(w: BoxWorld, at: Vector3, yaw: float, practice: bool = false) -> Array:
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	state.round_state.practice = practice
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var c := state.characters[0]
	c.position = at + Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.yaw = yaw
	c.grounded = true
	return [sim, state]


func _step(sim: Simulation, state: GameState, cmd: PlayerCommand) -> void:
	var cmds: Array[PlayerCommand] = [cmd, null]
	sim.step(state, cmds, DT)


func _press(yaw: float) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	cmd.reset(yaw, 0.0)
	cmd.use_door = true
	return cmd


## A wall across x = 0 with a gap at z -1..1 and a shut door in it (door 0, on the +x face), and a second wall across
## z = -1.5 with an open door (door 1) in it, both within a bot's reach at (-0.5, 0, 0).
func _two_doors() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(30.0, 30.0)
	w.add_door(Vector3(0.19, 1.3, 0.0), Vector3(0.08, 2.6, 2.0), true)
	w.add_door(Vector3(-0.5, 1.3, -1.2), Vector3(2.0, 2.6, 0.08), false)
	return w


## A bot walking east into a shut door (BotBrain picks it with Doors.shut_ahead) while its view is turned to an open door
## it passes (a bot fights or scans while it walks): the press has to open the door it walks into, not shut the other.
func test_a_walkers_use_opens_the_door_it_walks_into_not_the_one_it_looks_at() -> void:
	var r: Array = _match(_two_doors(), Vector3(-0.5, 0.0, 0.0), 0.0)
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	var cmd := _press(0.0)
	cmd.right = 1.0
	var way := Doors.way_of(cmd)
	# As BotBrain does: the door its walk goes into is the one it picks.
	cmd.door_to_use = Doors.shut_ahead(sim.query, tuning.doors, state.doors, state.characters[0].position, way)
	assert_eq(cmd.door_to_use, 0, "the door it walks into is door 0")
	_step(sim, state, cmd)
	assert_false(state.doors.is_shut(0), "door 0 opened")
	assert_false(state.doors.is_shut(1), "the open door it merely looks at is left open")


func test_practice_doors_toggle_and_are_never_reset() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(30.0, 30.0)
	w.add_door(Vector3(0.19, 1.3, 0.0), Vector3(0.08, 2.6, 2.0), true)
	var r: Array = _match(w, Vector3(-1.0, 0.0, 0.0), EAST, true)
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	_step(sim, state, _press(EAST))
	assert_false(state.doors.is_shut(0), "opened on the range of practice")
	for i in 600:
		var idle := PlayerCommand.new()
		idle.reset(EAST, 0.0)
		_step(sim, state, idle)
	assert_false(state.doors.is_shut(0), "practice has no rounds: nothing puts it back")


func test_a_map_without_doors_takes_a_press_quietly() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(30.0, 30.0)
	var r: Array = _match(w, Vector3(0.0, 0.0, 0.0), EAST)
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	_step(sim, state, _press(EAST))
	assert_eq(sim.doors.count(), 0)
	assert_eq(state.doors.count(), 0)
	assert_eq(state.events.count_of(GameEvent.Kind.DOOR), 0)


func test_the_range_has_no_doors_and_no_door_view() -> void:
	# Woodland's huts have doors since WR2 (test_woodland_layout).
	var m := MapData.load_map("range", style, 5)
	assert_eq(m.doors.size(), 0)
	assert_null(DoorView.build(m, style, tuning.doors.swing_time))


func test_someone_out_of_play_cannot_press_use() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(30.0, 30.0)
	w.add_door(Vector3(0.19, 1.3, 0.0), Vector3(0.08, 2.6, 2.0), false)
	var r: Array = _match(w, Vector3(-1.0, 0.0, 0.0), EAST)
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	Elimination.eliminate(state.characters[0], 1, state.characters, _ends())
	_step(sim, state, _press(EAST))
	assert_true(not state.doors.is_shut(0), "the door is as it was")
	assert_eq(state.events.count_of(GameEvent.Kind.DOOR), 0, "a hit player's press makes no sound")
