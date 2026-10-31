extends GutTest
## QA for FM1 (the full-screen map and Go there): what the worker's tests leave out. Go there's loose ends (a teammate
## lost on the way, all lost, over a hold where each stood, a ping far off the field, a new round) on the squad orders'
## open field, and the map's input edges (the pointer's first open, the key let go unseen, the map shut under it, pause).

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const EAST := -PI * 0.5
const YOU := 0
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0)]

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var squad: SquadConfig = config.squad

var map: MapData = null
var nav: NavGrid = null
var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []
var cmd: PlayerCommand = null
var you: Character = null
var mates: Array[Bot] = []
var _built: Array = []

var input: PlayerInput = null
var controls: ControlsConfig = ControlsConfig.new()
var icmd: PlayerCommand = PlayerCommand.new()


func before_each() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.HOVER
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true
	input.allow_map(true)


func after_each() -> void:
	for action: StringName in [&"field_map", &"order_wheel", &"fire", &"aim", &"ping", &"ping_move", &"scoreboard"]:
		Input.action_release(action)


# --- the squad ---

static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


func _squad() -> void:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	m.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		m.ends.append(end)
	if _built.is_empty():
		_built = [m, NavGrid.build(m, tuning.nav, tuning.body)]
	map = _built[0]
	nav = _built[1]
	sim = Simulation.new(tuning, w, w.mover(), map.ends, KILL_Y)
	sim.nav = nav
	state = GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in SPOTS.size():
		state.characters.append(Character.new(i, 0 if i < 3 else 1, SPOTS[i], EAST, loadout))
		commands.append(PlayerCommand.new())
	bots = BotController.new(state, YOU, map, nav, w, tuning, config)
	sim.start_match(state)
	bots.observe(state)
	for b in bots.world.bots:
		if b.character.team == 1:
			bots.world.bots.erase(b)
			break
	for i in SPOTS.size():
		state.characters[i].position = SPOTS[i]
	you = state.characters[YOU]
	cmd = commands[YOU]
	cmd.reset(EAST, 0.0)
	mates.clear()
	mates.append_array(bots.world.bots)
	_run(0.5)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func _run(seconds: float) -> void:
	for t in roundi(seconds / DT):
		_tick()


func _ping(move: bool, on_map: bool, at: Vector3 = Vector3.ZERO) -> void:
	cmd.ping = true
	cmd.ping_move = move
	cmd.ping_on_map = on_map
	cmd.ping_target = at
	_tick()
	cmd.ping = false
	cmd.ping_move = false
	cmd.ping_on_map = false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_a_teammate_lost_on_the_way_does_not_hold_up_the_rest() -> void:
	_squad()
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE)
	mates[0].character.status = Character.Status.OUT
	_run(14.0)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.HOLD, "the one still in play got there: it reads Hold here")
	assert_eq(mates[0].order, SquadOrder.Kind.NONE)
	assert_eq(mates[1].order, SquadOrder.Kind.HOLD)


func test_every_teammate_lost_on_the_way_ends_the_go_there() -> void:
	_squad()
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	for b in mates:
		b.character.status = Character.Status.OUT
	_run(0.2)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	assert_false(bots.hold_spot(YOU), "no marker over a spot nobody goes to")


func test_go_there_over_a_hold_where_each_stood_goes_to_its_spot() -> void:
	_squad()
	cmd.pitch = 1.0
	_run(0.3)
	cmd.squad_order = SquadOrder.Kind.HOLD
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.HOLD)
	assert_false(bots.hold_spot(YOU), "a hold where each stood has no one spot")
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE)
	assert_true(bots.hold_spot(YOU), "now there is one")
	assert_lt(_flat(bots.held_middle, Vector3(10.0, 0.0, -10.0)), 1.0)


func test_a_go_there_far_off_the_field_goes_nowhere_and_keeps_what_is_in_force() -> void:
	_squad()
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	_run(0.3)
	for far: Vector3 in [Vector3(1.0e7, 0.0, -1.0e7), Vector3(-60.0, 0.0, 60.0), Vector3(10.0, 500.0, -10.0)]:
		_ping(true, true, far)
		assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE, "%s: the order in force stays" % far)
		assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NOWHERE)
		assert_true(bots.hold_spot(YOU))
		assert_lt(_flat(bots.held_middle, Vector3(10.0, 0.0, -10.0)), 1.0, "%s: still the first spot" % far)
		_run(0.2)


func test_a_go_there_with_no_teammate_in_play_gives_nobody() -> void:
	_squad()
	for b in mates:
		b.character.status = Character.Status.OUT
	_run(0.1)
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NOBODY)


func test_a_go_there_pressed_between_rounds_gives_nothing() -> void:
	_squad()
	state.round_state.phase = RoundState.Phase.OVER
	state.round_state.timer = 100.0
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.NONE)


func test_a_go_there_in_force_does_not_carry_into_the_next_round() -> void:
	_squad()
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	_run(0.5)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE)
	state.events.clear()
	var e := state.events.add(GameEvent.Kind.ROUND_START)
	e.value = 2
	bots.observe(state)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.NONE, "a teammate still walking to last round's Go there")


# --- the map's input ---

func _event(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	input._unhandled_input(e)


func _tap(action: StringName) -> void:
	_event(action, true)
	_event(action, false)


func _move(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(dx, dy)
	input._unhandled_input(e)


func _field_map(st: GameState, who: Character) -> HudFieldMap:
	var cfg := MinimapConfig.new()
	var depot := MapData.load_map("depot", MapStyle.new(), 1)
	var heard := MinimapHearing.new(cfg)
	heard.on_tick(st, who)
	var root := Control.new()
	root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(root)
	var mm := HudMinimap.new()
	root.add_child(mm)
	mm.setup(cfg, TeamConfig.new(), depot, heard, "Depot", st.characters.size(), Vector2(32.0, 26.0))
	var fm := HudFieldMap.new()
	root.add_child(fm)
	fm.setup(cfg, mm, depot, "Depot", st.characters.size(), 8.0, 2.0)
	return fm


func _frame(fm: HudFieldMap, st: GameState, who: Character) -> void:
	fm.update(st, who, 0.0, 1.0, false, Vector3.ZERO, null, input.field_map(), true, false)


func _hud_state() -> Array:
	var st := GameState.new(5)
	var kit: Array[ReplicaConfig] = [ReplicaConfig.new()]
	var me := Character.new(0, 0, Vector3(-10.0, 0.0, 1.5), 0.0, kit)
	st.characters.append(me)
	me.prev_position = me.position
	return [st, me]


func test_the_first_open_puts_the_pointer_on_you() -> void:
	var hs := _hud_state()
	var st: GameState = hs[0]
	var me: Character = hs[1]
	var fm := _field_map(st, me)
	_event(&"field_map", true)
	_frame(fm, st, me)
	var on_you := fm.view().panel_of(Vector2(me.position.x, me.position.z))
	assert_gt(on_you.length(), 20.0, "(you are not in the middle of the field)")
	assert_eq(input.field_map().at, on_you, "the pointer opens on you, as MapPointer says")


func test_opened_again_after_you_walked_the_pointer_opens_where_you_stand_now() -> void:
	var hs := _hud_state()
	var st: GameState = hs[0]
	var me: Character = hs[1]
	var fm := _field_map(st, me)
	_event(&"field_map", true)
	_frame(fm, st, me)
	_event(&"field_map", false)
	_frame(fm, st, me)
	me.position = Vector3(25.0, 0.0, -15.0)
	me.prev_position = me.position
	_event(&"field_map", true)
	_frame(fm, st, me)
	var on_you := fm.view().panel_of(Vector2(me.position.x, me.position.z))
	assert_eq(input.field_map().at, on_you, "on you now, not where you were last time")


func test_a_click_before_the_first_frame_is_no_go_there_to_the_field_s_origin() -> void:
	_event(&"field_map", true)
	_event(&"fire", true)
	input.fill(icmd)
	assert_false(icmd.ping and icmd.ping_on_map, "no map square yet: nothing to point at")


func test_the_key_let_go_unseen_closes_the_map_and_the_trigger_stays_held_back() -> void:
	input.field_map().frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	Input.action_release(&"field_map")
	Input.action_press(&"fire")
	input.fill(icmd)
	assert_false(input.field_map().open)
	assert_false(icmd.fire, "held back until let go")
	Input.action_release(&"fire")
	input.fill(icmd)
	Input.action_press(&"fire")
	input.fill(icmd)
	assert_true(icmd.fire)


func test_the_map_shutting_under_you_closes_it_and_keeps_the_trigger_held_back() -> void:
	input.field_map().frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	input.allow_map(false)
	assert_false(input.field_map().open)
	Input.action_press(&"fire")
	input.fill(icmd)
	assert_false(icmd.fire)


func test_pausing_with_the_map_open_closes_it_and_drops_a_click_not_yet_sent() -> void:
	input.field_map().frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	_tap(&"fire")
	input.release()
	assert_false(input.field_map().open)
	input.active = true
	input.fill(icmd)
	assert_false(icmd.ping, "a click latched before the pause is not sent after it")
	_event(&"field_map", true)
	assert_true(input.field_map().open, "and it opens again")


func test_a_click_and_the_wheel_s_go_there_in_one_tick_send_one_ping() -> void:
	input.field_map().frame(Vector2(5.0, 5.0), 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	_tap(&"fire")
	_tap(&"ping")
	input.fill(icmd)
	assert_true(icmd.ping and icmd.ping_on_map)
	assert_eq(icmd.ping_target, Vector3(5.0, 0.0, 5.0))


func test_dying_with_the_map_open_leaves_it_open_without_a_ping_and_the_next_round_restores_it() -> void:
	input.field_map().frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	input.allow_orders(true, false)
	_tap(&"fire")
	_tap(&"ping")
	input.fill(icmd)
	assert_false(icmd.ping)
	input.allow_orders(true, true)
	_tap(&"fire")
	input.fill(icmd)
	assert_true(icmd.ping_on_map, "pinging again once back in play, the map still held")


func test_the_map_hides_under_the_pause_menu_while_the_tree_is_paused() -> void:
	var hs := _hud_state()
	var st: GameState = hs[0]
	var me: Character = hs[1]
	var fm := _field_map(st, me)
	_event(&"field_map", true)
	_frame(fm, st, me)
	assert_true(fm.visible)
	get_tree().paused = true
	await wait_process_frames(2)
	var hidden := not fm.visible
	get_tree().paused = false
	assert_true(hidden, "the dimmed map does not stay over the pause menu")


func test_go_there_s_key_on_the_open_map_is_a_go_there_at_the_pointer() -> void:
	input.field_map().frame(Vector2(5.0, 5.0), 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	_move(20.0, -40.0)
	_tap(&"ping_move")
	input.fill(icmd)
	assert_true(icmd.ping and icmd.ping_move and icmd.ping_on_map)
	assert_eq(icmd.ping_target, Vector3(15.0, 0.0, -15.0), "at the pointer, not along the frozen view")
	assert_false(icmd.fire)


func test_go_there_s_key_does_nothing_on_the_open_map_while_you_are_out() -> void:
	input.field_map().frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	input.allow_orders(true, false)
	_tap(&"ping_move")
	input.fill(icmd)
	assert_false(icmd.ping, "out: no ping along the view either")


func test_the_pointer_follows_you_while_the_map_is_shut_so_the_next_open_is_on_you() -> void:
	var map_pointer := input.field_map()
	map_pointer.frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2(10.0, 10.0))
	map_pointer.frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2(-60.0, 30.0))
	_event(&"field_map", true)
	_tap(&"fire")
	input.fill(icmd)
	assert_eq(icmd.ping_target, Vector3(-30.0, 0.0, 15.0), "a click at once is where you are")


func test_a_moved_pointer_stays_where_it_was_put_when_a_frame_comes() -> void:
	var map_pointer := input.field_map()
	map_pointer.frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2(10.0, 10.0))
	_event(&"field_map", true)
	_move(50.0, 0.0)
	var put := map_pointer.at
	map_pointer.frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2(99.0, 99.0))
	assert_eq(map_pointer.at, put, "a frame after a move does not drag it back to you")


func test_the_area_words_are_laid_out_again_when_the_screen_resizes() -> void:
	var hs := _hud_state()
	var st: GameState = hs[0]
	var me: Character = hs[1]
	var fm := _field_map(st, me)
	var root := fm.get_parent() as Control
	_event(&"field_map", true)
	_frame(fm, st, me)
	var before: Vector2 = fm._overlay._at[0]
	root.size = Vector2(1000.0, 700.0)
	_frame(fm, st, me)
	var ov: Control = fm._overlay
	var words := HudFieldMap.areas_of(MapData.load_map("depot", MapStyle.new(), 1).areas)
	var want: Vector2 = ov.size * 0.5 + fm.view().panel_of(words[0].at)
	assert_ne(fm._overlay._at[0], before, "moved with the square")
	assert_almost_eq(fm._overlay._at[0].x + fm._overlay._sizes[0].x * 0.5, want.x, 0.01)
