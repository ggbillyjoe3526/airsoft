extends GutTest
## BP13 QA · the pass's fixes: a Sprint press no longer stands a toggled crouch up, a ping in Z's tap window is taken,
## Enter is unbindable, the minimum window, the spread-out check ignores another storey, a shut begun from ajar doesn't
## hang its leaves, and the tuning's invariants.

const DT := 1.0 / 60.0
const LOW := 0.0
const GAP := 0.04
const SPOT := Vector3(0.0, 0.0, 30.0)
const CYBER := "000019"
const PISTOL := "000001"

var input: PlayerInput = null
var cmd: PlayerCommand = PlayerCommand.new()


func after_each() -> void:
	for action: StringName in [&"sprint", &"move_forward", &"crouch"]:
		Input.action_release(action)


func _input_node(controls: ControlsConfig) -> void:
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


func _press(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	input._unhandled_input(e)


# --- Input ---

func test_a_sprint_press_standing_still_keeps_a_toggled_crouch() -> void:
	var c := ControlsConfig.new()
	c.crouch_toggle = true
	_input_node(c)
	_press(&"crouch")
	_press(&"sprint")
	input.fill(cmd)
	assert_true(cmd.crouch, "Alt+Tab or Alt+Enter behind cover leaves you down")
	input.fill(cmd)
	assert_true(cmd.crouch, "and still down a tick later")


func test_running_forward_still_stands_a_toggled_crouch_up() -> void:
	var c := ControlsConfig.new()
	c.crouch_toggle = true
	_input_node(c)
	_press(&"crouch")
	input.fill(cmd)
	assert_true(cmd.crouch)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	input.fill(cmd)
	assert_false(cmd.crouch, "sprinting forward stands you up")


func test_a_ping_in_the_z_tap_window_is_taken_and_one_past_the_tap_is_not() -> void:
	var c := ControlsConfig.new()
	c.wheel_tap = 600.0
	_input_node(c)
	_press(&"order_wheel")
	assert_true(input.wheel().open, "the wheel is open, not yet held")
	_press(&"ping")
	input.fill(cmd)
	assert_true(cmd.ping, "within the tap the view still turns: the ping is taken")
	input.release()
	input.active = true
	var held := ControlsConfig.new()
	held.wheel_tap = 0.0
	input.setup(held, 1.5)
	input.allow_orders(true, true)
	_press(&"order_wheel")
	_press(&"ping")
	input.fill(cmd)
	assert_false(cmd.ping, "the wheel held past its tap holds the view still: no ping")


func test_enter_and_keypad_enter_cannot_be_bound() -> void:
	assert_false(KeyBindings.bindable(KEY_ENTER))
	assert_false(KeyBindings.bindable(KEY_KP_ENTER))
	var b := KeyBindings.new()
	var before := b.action_of(KEY_SPACE)
	assert_ne(b.rebind(&"jump", KEY_ENTER), KeyBindings.Result.SWAPPED)
	assert_eq(b.action_of(KEY_ENTER), &"", "nothing is on Enter")
	assert_eq(b.action_of(KEY_SPACE), before, "jump is untouched")


# --- Window ---

func test_the_window_watch_sets_the_960_by_540_minimum_through_the_screens_seam() -> void:
	var fake := FakeScreens.new()
	SettingsApply.use_screens(fake)
	assert_eq(fake.config.min_window, Vector2i(960, 540))
	var w := WindowWatch.new()
	add_child_autofree(w)
	assert_true(fake.calls.has("min 960 x 540"), "the minimum is set when the watch is up")
	SettingsApply.use_screens(null)


# --- Bots on another storey ---

var world: BotWorld = null


func _world() -> void:
	var config := BotConfig.load_default()
	world = BotWorld.new()
	world.cfg = config
	world.tuning = SimTuning.load_default()
	world.time = 10.0
	var skill := config.skill_for(&"normal").duplicate() as BotSkill
	skill.flank_chance = 0.0
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3(-60.0, 0.0, 0.0), Vector3(60.0, 0.0, 0.0),
			Vector3(0.0, 0.0, -60.0)]
	for id in spots.size():
		var c := Character.new(id, 0, spots[id], 0.0, ReplicaStats.default_loadout())
		c.position = spots[id]
		world.characters.append(c)
		world.bots.append(Bot.new(c, id + 1, skill, spots.size()))


## A nav grid of 1 m cells over x -40..40, z 0..80: one floor at y 0 everywhere, but where `floors` (cell index to
## the floors stacked there) says otherwise.
func _nav(floors: Callable) -> NavGrid:
	var g := NavGrid.new()
	g.cell = 1.0
	g.cols = 80
	g.rows = 80
	g.min_x = -40.0
	g.min_z = 0.0
	g.pick_above = 0.5
	var starts := PackedInt32Array([0])
	var ys := PackedFloat32Array()
	var cells := PackedInt32Array()
	for c in g.cols * g.rows:
		var here: PackedFloat32Array = floors.call(g.cell_x(c % g.cols), g.cell_z(c / g.cols))
		for y in here:
			ys.append(y)
			cells.append(c)
		starts.append(ys.size())
	g.cell_start = starts
	g.floor_y = ys
	g.node_cell = cells
	return g


func _deck(x: float, z: float) -> PackedFloat32Array:
	if absf(x) < 6.0 and absf(z - 30.0) < 6.0:
		return PackedFloat32Array([0.0, 4.0])
	return PackedFloat32Array([0.0])


func test_teammates_on_a_deck_above_the_spot_do_not_crowd_it() -> void:
	_world()
	world.nav = _nav(_deck)
	world.characters[1].position = SPOT + Vector3(1.0, 4.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 4.0, 0.0)
	assert_false(BotSpread.crowded(world.bots[0], world, SPOT), "two on the deck leave the floor below free")
	world.characters[1].position = SPOT + Vector3(1.0, 0.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 0.0, 0.0)
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT), "the same two on the floor do")


func test_a_spot_on_the_deck_is_not_crowded_by_teammates_below_it() -> void:
	_world()
	world.nav = _nav(_deck)
	var up := SPOT + Vector3(0.0, 4.0, 0.0)
	world.characters[1].position = SPOT + Vector3(1.0, 0.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 0.0, 0.0)
	assert_false(BotSpread.crowded(world.bots[0], world, up))
	world.characters[1].position = up + Vector3(1.0, 0.0, 0.0)
	world.characters[2].position = up + Vector3(-1.0, 0.0, 0.0)
	assert_true(BotSpread.crowded(world.bots[0], world, up))


func test_a_hunter_on_the_deck_does_not_fan_a_hunter_below_out() -> void:
	_world()
	world.nav = _nav(_deck)
	world.characters[1].position = SPOT + Vector3(1.0, 4.0, 0.0)
	assert_false(BotSpread.hunt_crowded(world.bots[0], world, SPOT), "a teammate on the deck")
	world.characters[1].position = SPOT + Vector3(1.0, 0.0, 0.0)
	assert_true(BotSpread.hunt_crowded(world.bots[0], world, SPOT), "on the same floor: crowded")
	world.characters[1].position = Vector3(-60.0, 0.0, 0.0)
	var m := world.bots[2]
	m.hunting = true
	m.hunt_goal = SPOT + Vector3(0.0, 4.0, 0.0)
	assert_false(BotSpread.hunt_crowded(world.bots[0], world, SPOT), "a goal on the deck")
	m.hunt_goal = SPOT
	assert_true(BotSpread.hunt_crowded(world.bots[0], world, SPOT), "a goal on the floor")


func test_teammates_on_a_steep_single_floor_slope_still_crowd_the_spot() -> void:
	_world()
	# one floor everywhere, rising 3.5 m in the 8 m before the spot: a hill, not a storey
	world.nav = _nav(func(_x: float, z: float) -> PackedFloat32Array:
		return PackedFloat32Array([3.5 if z < 24.0 else 0.0]))
	world.characters[1].position = Vector3(1.0, 3.5, 22.0)
	world.characters[2].position = Vector3(-1.0, 3.5, 22.0)
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT), "the slope is one floor")
	assert_true(BotSpread.hunt_crowded(world.bots[0], world, Vector3(0.0, 0.0, 22.0)))


func test_teammates_on_a_crate_top_under_the_rise_still_crowd_the_spot() -> void:
	_world()
	world.nav = _nav(func(x: float, z: float) -> PackedFloat32Array:
		return PackedFloat32Array([0.0, 1.0]) if absf(x) < 6.0 and absf(z - 30.0) < 6.0 else PackedFloat32Array([0.0]))
	world.characters[1].position = SPOT + Vector3(1.0, 1.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 1.0, 0.0)
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT), "a crate is not a storey")


func test_a_bot_already_at_the_spot_a_deck_off_is_not_one_of_the_crowd() -> void:
	_world()
	world.nav = _nav(_deck)
	world.bots[0].character.position = SPOT + Vector3(0.5, 4.0, 0.0)
	world.characters[1].position = SPOT + Vector3(1.0, 0.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 0.0, 0.0)
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT), "it is not there: it is drawn in like the rest")


func test_without_a_nav_grid_the_storey_never_splits_teammates() -> void:
	_world()
	world.characters[1].position = SPOT + Vector3(1.0, 4.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 4.0, 0.0)
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT))


# --- Lifts ---

const HIGH := 4.0

var tuning: SimTuning = SimTuning.new()


func _lift_spec() -> LiftSpec:
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
	s.start = 0
	return s


func _lift_match() -> Array:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, -6.0), Vector3(20.0, 0.5, 9.4))
	w.add_box(Vector3(0.0, HIGH - 0.15, -6.0), Vector3(20.0, 0.3, 9.4))
	w.add_box(Vector3(-0.9, 3.0, -1.15), Vector3(0.8, 8.0, 0.3))
	w.add_box(Vector3(0.9, 3.0, -1.15), Vector3(0.8, 8.0, 0.3))
	w.add_box(Vector3(0.0, -0.5, -1.15), Vector3(1.0, 1.0, 0.3))
	w.add_box(Vector3(0.0, 3.05, -1.15), Vector3(1.0, 1.9, 0.3))
	w.add_box(Vector3(0.0, 6.55, -1.15), Vector3(1.0, 0.9, 0.3))
	w.add_box(Vector3(0.0, 3.0, 1.15), Vector3(2.6, 8.0, 0.3))
	w.add_box(Vector3(-1.15, 3.0, 0.0), Vector3(0.3, 8.0, 2.0))
	w.add_box(Vector3(1.15, 3.0, 0.0), Vector3(0.3, 8.0, 2.0))
	w.add_lift(_lift_spec(), tuning.lifts)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-8.0 if e == 0 else 8.0, 0.0, -9.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-9.0 if e == 0 else 9.0, 0.0, -10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var state := GameState.new(3, tuning)
	for i in 2:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(state)
	for i in 2:
		_place(state.characters[i], Vector3(-8.0 + i * 0.8, LOW, -9.0))
	return [sim, state]


func _place(c: Character, at: Vector3) -> void:
	c.position = at + Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.velocity = Vector3.ZERO
	c.grounded = true


## `ticks` ticks; with `pin`, character 1 is put back at it before each (a rider easing in is held in the doorway).
func _step(sim: Simulation, state: GameState, ticks: int, pin: Vector3 = Vector3.INF) -> void:
	for t in ticks:
		if pin != Vector3.INF:
			_place(state.characters[1], pin)
		var cmds: Array[PlayerCommand] = []
		for c in state.characters:
			var k := PlayerCommand.new()
			k.reset(c.yaw, c.pitch)
			cmds.append(k)
		sim.step(state, cmds, DT)


func test_a_shut_begun_from_ajar_with_someone_in_the_doorway_does_not_hold_its_leaves_for_the_whole_shut() -> void:
	var m := _lift_match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cfg := tuning.lifts
	var span := cfg.shut_time()
	# Shutting from half open, a rider standing in the doorway (inside the car, so the doors wait for them).
	_place(state.characters[1], Vector3(0.0, LOW, -0.85))
	state.lifts.phase[0] = LiftState.Phase.SHUTTING
	state.lifts.doors[0] = 0.5
	state.lifts.left[0] = cfg.door_time
	state.lifts.sealed[0] = 0
	_step(sim, state, ceili((cfg.door_time + 1.0) / DT), Vector3(0.0, LOW, -0.85))
	assert_eq(state.lifts.sealed[0], 0, "someone is still in the doorway (the test's premise)")
	assert_eq(state.lifts.phase[0], LiftState.Phase.SHUTTING)
	assert_lte(state.lifts.left[0], span * 0.5 + 0.02, "the countdown waits at what the half-open leaves still need")
	assert_almost_eq(state.lifts.doors[0], 0.5, 0.02, "the leaves hold where they stood")


func test_a_shut_from_ajar_completes_in_the_time_the_open_part_needs_once_the_doorway_clears() -> void:
	var m := _lift_match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cfg := tuning.lifts
	var span := cfg.shut_time()
	_place(state.characters[1], Vector3(0.0, LOW, -0.85))
	state.lifts.phase[0] = LiftState.Phase.SHUTTING
	state.lifts.doors[0] = 0.5
	state.lifts.left[0] = cfg.door_time
	state.lifts.sealed[0] = 0
	_step(sim, state, ceili((cfg.door_time + 1.0) / DT), Vector3(0.0, LOW, -0.85))
	_place(state.characters[1], Vector3(-8.0, LOW, -9.0))
	_step(sim, state, ceili(span * 0.5 / DT) + 6)
	assert_ne(state.lifts.phase[0], LiftState.Phase.SHUTTING, "shut within half the shut time, not a whole one")


# --- Tuning invariants ---

func _carried(id: String) -> ReplicaConfig:
	var rules := LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	var l := rules.default_loadout("T")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, id), "equip %s" % id)
	return rules.carried(l).replicas[0]


func _run_hip(r: ReplicaConfig) -> float:
	return r.spread_deg * r.hip_spread * (1.0 + (tuning.accuracy.run - 1.0) * r.move_spread)


func test_the_cyber_pistol_is_wider_on_the_run_than_the_gbb_pistol() -> void:
	var cyber := _carried(CYBER)
	var gbb := _carried(PISTOL)
	assert_gt(_run_hip(cyber), _run_hip(gbb), "the Cyber's run spread stays above the GBB's")
	assert_gt(cyber.move_spread, gbb.move_spread)
	assert_lt(cyber.spread_deg, gbb.spread_deg, "while standing the Cyber is still the tighter")


func test_an_older_save_with_an_action_on_enter_keeps_that_actions_default_and_the_rest() -> void:
	var b := KeyBindings.new()
	var default_jump := b.codes(&"jump")
	var used := b.load_dict({"jump": [KEY_ENTER], "reload": [KEY_J]})
	assert_false(used, "the save is not used as it came")
	assert_eq(b.codes(&"jump"), default_jump, "jump keeps a key")
	assert_eq(b.action_of(KEY_ENTER), &"", "Enter stays free")
	assert_eq(b.action_of(KEY_J), &"reload", "the rest of the save loads")
