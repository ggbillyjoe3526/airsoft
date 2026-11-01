extends GutTest
## Hinged doors (DO1; the owner's door defaults of 2026-10-31): Depot's file lists them, a shut leaf stops BBs and
## bodies on BoxWorld and Jolt alike, Use toggles the door in reach, a swing takes no press, a door won't shut on a
## body, each toggle is heard 20 m through walls, a new round puts every door back, a walk-off and a bot open what they
## walk into, the leaves fold flat against the wall, and the prompt and the key (game/sim/doors.gd, door_state.gd,
## game/map/map_level.gd, jolt_query.gd, game/play/door_view.gd).

const DT := 1.0 / 60.0
const GAP := 0.04
## Yaw that looks along +X (forward is -sin, -cos of the yaw).
const EAST := -PI * 0.5

var tuning: SimTuning = SimTuning.new()
var cfg: DoorConfig = tuning.doors
var style: MapStyle = MapStyle.new()
var loadout: Array[ReplicaConfig] = []
var depot: MapData = null


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()
	depot = MapData.load_map("depot", style, 5)


## A 30 m floor with a wall across x = 0 from z = -10 to 10 and a 2 m gap in it at z -1..1, its door hung on the +x
## face, starting `shut`.
func _hall(shut: bool) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(30.0, 30.0)
	w.add_prop(&"plywood", Vector3(0.0, 1.3, -5.5), Vector3(0.3, 2.6, 9.0), RayHit.Surface.WOOD)
	w.add_prop(&"plywood", Vector3(0.0, 1.3, 5.5), Vector3(0.3, 2.6, 9.0), RayHit.Surface.WOOD)
	w.add_door(Vector3(0.19, 1.3, 0.0), Vector3(0.08, 2.6, 2.0), shut)
	return w


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-12.0 if e == 0 else 12.0, 0.0, 12.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-14.0 if e == 0 else 14.0, 0.0, 14.0), 0.0))
		ends.append(end)
	return ends


## [Simulation, GameState] on `w`: character 0 (team 0) at `at` facing `yaw`, character 1 (team 1) far off.
func _match(w: BoxWorld, at: Vector3, yaw: float = EAST) -> Array:
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	_place(state.characters[0], at, yaw)
	return [sim, state]


func _place(c: Character, at: Vector3, yaw: float) -> void:
	c.position = at + Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.yaw = yaw
	c.grounded = true


## Steps one tick with character 0 pressing Use (or not); returns that tick's DOOR events.
func _tick(sim: Simulation, state: GameState, use: bool, cmd: PlayerCommand = null) -> Array[GameEvent]:
	var c := cmd if cmd != null else PlayerCommand.new()
	if cmd == null:
		c.reset(state.characters[0].yaw, 0.0)
	c.use_door = use
	var cmds: Array[PlayerCommand] = [c, null]
	sim.step(state, cmds, DT)
	var out: Array[GameEvent] = []
	for i in state.events.count:
		var e := state.events.items[i]
		if e.kind == GameEvent.Kind.DOOR:
			var copy := GameEvent.new()
			copy.reset(e.kind)
			copy.actor = e.actor
			copy.target = e.target
			copy.value = e.value
			copy.position = e.position
			copy.reach = e.reach
			out.append(copy)
	return out


func _wait_swing(sim: Simulation, state: GameState) -> void:
	for t in ceili(cfg.swing_time / DT) + 1:
		_tick(sim, state, false)


func test_depot_lists_its_doors_some_shut_some_open() -> void:
	assert_eq(depot.warnings, [] as Array[String])
	assert_eq(depot.doors.size(), 15, "the concept's 15 doors")
	var shut := 0
	for d in depot.doors:
		shut += 1 if d.shut else 0
		assert_almost_eq(d.size.y, 2.6, 1e-3, "as tall as the wall it hangs in")
		assert_almost_eq(minf(d.size.x, d.size.z), 0.08, 1e-3, "a plywood leaf")
		assert_almost_eq(maxf(d.size.x, d.size.z), 2.0, 1e-3, "across a 2 m gap")
		assert_eq(d.side, 1)
	assert_between(shut, 5, 10, "some start shut, some open: %d shut" % shut)


func test_a_door_that_isnt_one_is_left_out() -> void:
	var text := JSON.stringify({"blocks": [{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0},
			"size": {"x": 10, "y": 0.5, "z": 10}}], "doors": [{"center": {"x": 0, "y": 1, "z": 0},
			"size": {"x": 0, "y": 2, "z": 2}}, {"center": {"x": 1, "y": 1.3, "z": 0},
			"size": {"x": 0.08, "y": 2.6, "z": 2}, "side": -1, "shut": true}]})
	var m := MapData.parse(text, style, 1)
	assert_eq(m.doors.size(), 1, "the sizeless one is left out")
	assert_eq(m.warnings.size(), 1)
	assert_true(m.doors[0].shut)
	assert_eq(m.doors[0].side, -1)


func test_a_shut_leaf_stops_a_bb_and_an_open_one_is_nothing() -> void:
	var w := _hall(true)
	var hit := RayHit.new()
	assert_true(w.ray(Vector3(-5.0, 1.5, 0.0), Vector3(5.0, 1.5, 0.0), hit), "shut, the leaf stops it")
	assert_eq(hit.surface, RayHit.Surface.WOOD)
	assert_almost_eq(hit.position.x, 0.15, 1e-3, "on the leaf's near face")
	w.set_door_shut(0, false)
	assert_false(w.ray(Vector3(-5.0, 1.5, 0.0), Vector3(5.0, 1.5, 0.0), hit), "open, through the gap")
	assert_true(w.ray(Vector3(-5.0, 1.5, 3.0), Vector3(5.0, 1.5, 3.0), hit), "the wall beside it still stands")


func test_a_shut_door_stops_a_walk_and_an_open_one_lets_it_through() -> void:
	var r: Array = _match(_hall(true), Vector3(-1.5, 0.0, 0.0))
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	var c := state.characters[0]
	var walk := PlayerCommand.new()
	walk.reset(EAST, 0.0)
	walk.forward = 1.0
	for t in 90:
		_tick(sim, state, false, walk)
	assert_lt(c.position.x, 0.15 - tuning.body.radius + 0.01, "stopped at the shut leaf")
	_tick(sim, state, true, walk)
	for t in 90:
		_tick(sim, state, false, walk)
	assert_gt(c.position.x, 1.5, "through once it opens")


func test_use_opens_the_door_in_reach_heard_twenty_metres() -> void:
	var r: Array = _match(_hall(true), Vector3(-1.0, 0.0, 0.0))
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	var heard := _tick(sim, state, true)
	assert_eq(heard.size(), 1, "one DOOR event")
	assert_false(state.doors.is_shut(0), "open")
	if heard.size() == 1:
		assert_eq(heard[0].actor, 0)
		assert_eq(heard[0].target, 0)
		assert_eq(heard[0].value, 0, "opening")
		assert_eq(heard[0].reach, 20.0)
		assert_almost_eq(heard[0].position.x, 0.19, 1e-4, "from the door")
	var hit := RayHit.new()
	assert_false(sim.query.ray(Vector3(-5.0, 1.5, 0.0), Vector3(5.0, 1.5, 0.0), hit), "the level was told")


func test_a_swing_takes_no_press_then_use_shuts_it() -> void:
	var r: Array = _match(_hall(true), Vector3(-1.0, 0.0, 0.0))
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	_tick(sim, state, true)
	assert_eq(_tick(sim, state, true).size(), 0, "mid-swing, a press does nothing")
	assert_false(state.doors.is_shut(0))
	_wait_swing(sim, state)
	var heard := _tick(sim, state, true)
	assert_eq(heard.size(), 1)
	assert_true(state.doors.is_shut(0), "shut again")
	if heard.size() == 1:
		assert_eq(heard[0].value, 1, "shutting")


func test_out_of_reach_a_press_does_nothing() -> void:
	var r: Array = _match(_hall(true), Vector3(-2.5, 0.0, 0.0))
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	assert_eq(_tick(sim, state, true).size(), 0, "2.5 m off, past the 1.6 m reach")
	assert_true(state.doors.is_shut(0))
	_place(state.characters[0], Vector3(-1.0, 3.0, 0.0), EAST)
	assert_eq(Doors.in_reach(sim.query, cfg, state.characters[0].position, EAST), -1, "a storey up is out of reach")


func test_a_door_wont_shut_on_a_body() -> void:
	var r: Array = _match(_hall(false), Vector3(-1.0, 0.0, 0.0))
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	_place(state.characters[1], Vector3(0.2, 0.0, 0.3), -EAST)
	assert_eq(_tick(sim, state, true).size(), 0, "someone in the doorway")
	assert_false(state.doors.is_shut(0))
	_place(state.characters[1], Vector3(6.0, 0.0, 6.0), -EAST)
	assert_eq(_tick(sim, state, true).size(), 1, "clear, it shuts")
	assert_true(state.doors.is_shut(0))


func test_a_new_round_puts_every_door_back() -> void:
	var r: Array = _match(_hall(true), Vector3(-1.0, 0.0, 0.0))
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	_tick(sim, state, true)
	assert_false(state.doors.is_shut(0))
	sim.doors.reset(state.doors)
	assert_true(state.doors.is_shut(0), "as the map starts it")
	assert_eq(state.doors.swing_left[0], 0.0, "at rest")
	var hit := RayHit.new()
	assert_true(sim.query.ray(Vector3(-5.0, 1.5, 0.0), Vector3(5.0, 1.5, 0.0), hit), "and solid again")


func test_round_start_resets_the_doors_in_the_step() -> void:
	var r: Array = _match(_hall(true), Vector3(-1.0, 0.0, 0.0))
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	_tick(sim, state, true)
	# A round over and its wait done: the next tick starts the next round.
	var rs := state.round_state
	rs.phase = RoundState.Phase.OVER
	rs.timer = 0.0
	_tick(sim, state, false)
	assert_true(rs.is_live(), "a new round")
	assert_true(state.doors.is_shut(0), "the door is back as the map starts it")


func test_shut_ahead_finds_the_shut_door_its_walk_goes_into() -> void:
	var w := _hall(true)
	var doors := DoorState.new()
	var rules := Doors.new(tuning, w)
	rules.reset(doors)
	var feet := Vector3(-1.0, GAP, 0.0)
	assert_eq(Doors.shut_ahead(w, cfg, doors, feet, Vector2(1.0, 0.0)), 0, "walking at it")
	assert_eq(Doors.shut_ahead(w, cfg, doors, feet, Vector2(-1.0, 0.0)), -1, "walking away")
	assert_eq(Doors.shut_ahead(w, cfg, doors, feet, Vector2(0.0, 1.0)), -1, "walking along the wall")
	w.set_door_shut(0, false)
	doors.shut[0] = 0
	assert_eq(Doors.shut_ahead(w, cfg, doors, feet, Vector2(1.0, 0.0)), -1, "an open one needs nothing")


func test_way_of_turns_a_command_into_the_world() -> void:
	var cmd := PlayerCommand.new()
	cmd.reset(EAST, 0.0)
	cmd.forward = 1.0
	assert_almost_eq(Doors.way_of(cmd), Vector2(1.0, 0.0), Vector2(1e-5, 1e-5), "forward facing east is +x")
	cmd.forward = 0.0
	cmd.right = 1.0
	assert_almost_eq(Doors.way_of(cmd), Vector2(0.0, 1.0), Vector2(1e-5, 1e-5), "right facing east is +z")


func test_a_walk_off_opens_a_shut_door_it_walks_into() -> void:
	var r: Array = _match(_hall(true), Vector3(-1.0, 0.0, 0.0))
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	var walk := PlayerCommand.new()
	walk.reset(EAST, 0.0)
	walk.forward = 1.0
	sim.doors.walk_through(state.characters[0], walk, state)
	assert_false(state.doors.is_shut(0), "it opens what it walks into")
	assert_eq(state.events.count_of(GameEvent.Kind.DOOR), 1, "with the noise anyone's makes")


func test_bots_hear_an_enemys_door_twenty_metres_through_a_wall() -> void:
	var map := MapData.new()
	map.id = "door field"
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, 0.0)
	floor_block.size = Vector3(60.0, 0.5, 12.0)
	map.blocks.append(floor_block)
	map.ends = _ends()
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	for case: Array in [[18.0, true], [22.0, false]]:
		var w := BoxWorld.new(tuning.body)
		w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(60.0, 0.5, 12.0))
		# A wall between, floor to well over head, the whole width.
		w.add_box(Vector3(-15.0 + case[0] * 0.5, 2.0, 0.0), Vector3(0.3, 4.0, 12.0))
		var state := GameState.new(9, tuning)
		state.characters.append(Character.new(0, 0, Vector3(-15.0, GAP, 0.0), EAST, loadout))
		state.characters.append(Character.new(1, 1, Vector3(-15.0 + case[0], GAP, 0.0), -EAST, loadout))
		var levels: Dictionary[int, StringName] = {0: &"hard", 1: &"hard"}
		var bots := BotController.new(state, -1, map, nav, w, tuning, BotConfig.load_default(), levels)
		bots.world.time = 10.0
		state.time = 10.0
		state.events.clear()
		var e := state.events.add(GameEvent.Kind.DOOR)
		e.actor = 1
		e.target = 0
		e.position = state.characters[1].position + Vector3(0.5, 1.3, 0.0)
		e.reach = cfg.heard
		BotHearing.observe(state, bots.world)
		var hearer := bots.world.bots[0]
		assert_eq(hearer.has_last_known, case[1], "a door %.0f m off through a wall is heard: %s" % [case[0], case[1]])


func test_jolt_switches_a_depot_door_for_rays_and_movers() -> void:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(depot, style, tuning.body)
	var q := level.query()
	assert_eq(q.door_count(), depot.doors.size())
	var i := -1
	for k in depot.doors.size():
		if depot.doors[k].shut and depot.doors[k].size.x < depot.doors[k].size.z:
			i = k
			break
	assert_gte(i, 0, "a shut door across x")
	if i < 0:
		return
	var c := depot.doors[i].center
	var from := Vector3(c.x - 3.0, 1.5, c.z)
	var to := Vector3(c.x + 3.0, 1.5, c.z)
	var hit := RayHit.new()
	assert_true(q.ray(from, to, hit), "shut, the leaf stops a BB")
	assert_eq(hit.surface, RayHit.Surface.WOOD)
	assert_almost_eq(hit.position.x, c.x - 0.04, 1e-3, "on its near face")
	q.set_door_shut(i, false)
	assert_false(q.ray(from, to, hit), "open, nothing in the gap")
	var mover := level.mover(tuning.body)
	var walker := Character.new(0, 0, Vector3(c.x - 1.0, GAP, c.z), EAST, loadout)
	walker.grounded = true
	var moved := mover.move(walker, Vector3(2.0, 0.0, 0.0))
	assert_gt(moved.x, 1.9, "open, a body walks through")
	q.set_door_shut(i, true)
	moved = mover.move(walker, Vector3(2.0, 0.0, 0.0))
	assert_lt(moved.x, 1.0, "shut, it stops a body")


func test_the_view_folds_open_leaves_flat_against_the_wall() -> void:
	var view := DoorView.build(depot, style, cfg.swing_time)
	add_child_autofree(view)
	assert_not_null(view)
	if view == null:
		return
	var mm := (view.get_child(0) as MultiMeshInstance3D).multimesh
	assert_eq(mm.instance_count, depot.doors.size() * 2, "two leaves a door, one draw")
	var i := -1
	for k in depot.doors.size():
		if depot.doors[k].shut and depot.doors[k].size.x < depot.doors[k].size.z:
			i = k
			break
	var d := depot.doors[i]
	var shut_leaf := view.leaf_at(i * 2)
	assert_almost_eq(shut_leaf.origin.x, d.center.x, 1e-4, "shut, in the door's plane")
	assert_between(shut_leaf.origin.z, d.center.z - 1.0, d.center.z, "the first leaf on its own half")
	var doors := DoorState.new()
	doors.shut.resize(depot.doors.size())
	doors.swing_left.resize(depot.doors.size())
	for k in depot.doors.size():
		doors.shut[k] = 1 if depot.doors[k].shut else 0
	doors.shut[i] = 0
	doors.swing_left[i] = cfg.swing_time * 0.5
	view.refresh(doors)
	assert_almost_eq(view.drawn_open(i), 0.5, 1e-4, "half way through its swing")
	var mid := view.leaf_at(i * 2)
	assert_gt(mid.origin.x, d.center.x + 0.3, "swinging out to its side, not into the wall")
	doors.swing_left[i] = 0.0
	view.refresh(doors)
	var open := view.leaf_at(i * 2)
	assert_almost_eq(open.origin.x, d.center.x, 1e-4, "folded flat in the door's plane, against the wall's face")
	assert_lt(open.origin.z, d.center.z - 1.0, "over the wall beyond its jamb")
	assert_null(DoorView.build(YardMap.load_map(style, 3), style, cfg.swing_time), "no doors, no view")


func test_use_is_on_g_and_named_on_the_controls() -> void:
	assert_true(InputMap.has_action(&"use_door"))
	assert_true(KeyBindings.ACTIONS.has(&"use_door"))
	# On G since MC1 (owner, 2026-11-01: U was awkward).
	assert_eq(Array(KeyBindings.DEFAULTS[&"use_door"]), [KEY_G])
	assert_ne(tr("ACT_USE_DOOR"), "ACT_USE_DOOR", "a name on the controls list")
	assert_ne(tr("HUD_DOOR_OPEN"), "HUD_DOOR_OPEN")
	assert_ne(tr("HUD_DOOR_SHUT"), "HUD_DOOR_SHUT")


func test_the_door_sounds_are_rendered() -> void:
	for stem: String in ["door_open", "door_shut"]:
		for n in 3:
			var path := "res://assets/audio/cues/%s_%d.wav" % [stem, n + 1]
			assert_not_null(load(path), path)


func test_a_picked_door_is_the_one_used_not_the_one_in_view() -> void:
	var w := _hall(true)
	# A second leaf just south, open, the one the view looks at.
	w.add_door(Vector3(-1.0, 1.3, 1.5), Vector3(2.0, 2.6, 0.08), false)
	var r: Array = _match(w, Vector3(-1.0, 0.0, 0.0), PI)
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	var c := state.characters[0]
	assert_eq(Doors.in_reach(w, cfg, c.position, c.yaw), 1, "the view picks the open one")
	var cmd := PlayerCommand.new()
	cmd.reset(PI, 0.0)
	cmd.door_to_use = 0
	_tick(sim, state, true, cmd)
	assert_false(state.doors.is_shut(0), "the picked door opened")
	assert_false(state.doors.is_shut(1), "the one in view was left open")
	cmd.reset(PI, 0.0)
	cmd.door_to_use = -1
	_wait_swing(sim, state)
	_tick(sim, state, true, cmd)
	assert_true(state.doors.is_shut(1), "none picked: the one in view")


## A floor split by a wall from side to side whose one way through is a shut door: block data for the nav, the same
## boxes for the BoxWorld.
func _split_field() -> Array:
	var map := MapData.new()
	map.id = "door split"
	var w := BoxWorld.new(tuning.body)
	for spec: Array in [[&"floor", Vector3(0.0, -0.25, 0.0), Vector3(30.0, 0.5, 30.0)],
			[&"plywood", Vector3(0.0, 1.3, -8.0), Vector3(0.3, 2.6, 14.0)],
			[&"plywood", Vector3(0.0, 1.3, 8.0), Vector3(0.3, 2.6, 14.0)]]:
		var b := MapData.Block.new()
		b.kind = spec[0]
		b.center = spec[1]
		b.size = spec[2]
		map.blocks.append(b)
		w.add_box(b.center, b.size, RayHit.Surface.WOOD)
	map.ends = _ends()
	w.add_door(Vector3(0.19, 1.3, 0.0), Vector3(0.08, 2.6, 2.0), true)
	return [map, w]


func test_a_bot_opens_the_shut_door_its_route_goes_through() -> void:
	var field: Array = _split_field()
	var map: MapData = field[0]
	var w: BoxWorld = field[1]
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var sim := Simulation.new(tuning, w, w.mover(), map.ends, -10.0)
	sim.nav = nav
	var state := GameState.new(5, tuning)
	var commands: Array[PlayerCommand] = []
	for i in 2:
		state.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	var levels: Dictionary[int, StringName] = {0: &"normal", 1: &"normal"}
	var bots := BotController.new(state, -1, map, nav, w, tuning, BotConfig.load_default(), levels)
	sim.start_match(state)
	bots.observe(state)
	var opener := -1
	for t in roundi(60.0 / DT):
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		var e := state.events.first(GameEvent.Kind.DOOR)
		if e != null and opener < 0:
			opener = e.actor
			break
	assert_gte(opener, 0, "a bot hunting the other opened the door within a minute")
	assert_false(state.doors.is_shut(0), "and it stands open")
