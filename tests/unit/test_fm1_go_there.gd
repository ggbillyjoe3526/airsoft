extends GutTest
## Go there (FM1): a ping that sends your bot teammates to a spot, along your view (its key, the order wheel's Go There)
## or picked on the full-screen map. It travels as your command's ping, the simulation makes a PING event of it, and the
## bots' controller hands it out as a squad order (SquadOrderBook.give_move): side by side across the way there, looking
## on, and once all are there it reads Hold here. A plain ping on the map marks the floor there for the team. On the
## squad orders' open field (test_squad_orders.gd's), headless.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0)]

const CRATE_AT := Vector3(10.0, 1.3, 19.8)
const CRATE_SIZE := Vector3(2.0, 2.6, 1.6)
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
## The fields built so far and their nav grids, by whether the thin wall stands: [MapData, NavGrid].
var _built: Dictionary[bool, Array] = {}


## A 100 m square field (with a thin wall along X at z 18.6 to 19.0 if `thin_wall`), as map data and its BoxWorld.
func _field(thin_wall: bool = false) -> Array:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	m.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	if thin_wall:
		m.blocks.append(_block(&"wall", Vector3(0.0, 1.5, 18.8), Vector3(80.0, 3.0, 0.4)))
		w.add_box(Vector3(0.0, 1.5, 18.8), Vector3(80.0, 3.0, 0.4))
		# A tall stack against its south side at x 10: no floor in front of the wall above it.
		m.blocks.append(_block(&"crate", CRATE_AT, CRATE_SIZE))
		w.add_box(CRATE_AT, CRATE_SIZE)
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		m.ends.append(end)
	return [m, w]


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## You and two bot teammates at SPOTS, the opponent far off and driven by nobody, round 1 live and half a second gone.
func _squad(thin_wall: bool = false) -> void:
	var f := _field(thin_wall)
	var w: BoxWorld = f[1]
	# The field's nav grid takes seconds to build: once a layout, for the whole file (nothing here changes it).
	if not _built.has(thin_wall):
		var m: MapData = f[0]
		_built[thin_wall] = [m, NavGrid.build(m, tuning.nav, tuning.body)]
	map = _built[thin_wall][0]
	nav = _built[thin_wall][1]
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
	# The opponent stands still: nobody fights.
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


## Gives `kind` through your command for one tick (picked on the wheel if `wheel`); returns the order in force after.
func _order(kind: SquadOrder.Kind, wheel: bool = false) -> SquadOrder.Kind:
	cmd.squad_order = kind
	cmd.order_from_wheel = wheel
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	cmd.order_from_wheel = false
	return bots.order_of(YOU)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Pings for one tick through your command: a Go there (`move`) or a plain ping, on the map at `at` (`on_map`) or along
## the view.
func _ping(move: bool, on_map: bool, at: Vector3 = Vector3.ZERO) -> void:
	cmd.ping = true
	cmd.ping_move = move
	cmd.ping_on_map = on_map
	cmd.ping_target = at
	_tick()
	cmd.ping = false
	cmd.ping_move = false
	cmd.ping_on_map = false


func test_the_command_carries_go_there_and_a_map_point_and_reset_and_copy_from_include_them() -> void:
	var c := PlayerCommand.new()
	c.ping = true
	c.ping_move = true
	c.ping_on_map = true
	c.ping_target = Vector3(3.0, 1.0, -4.0)
	var copy := PlayerCommand.new()
	copy.copy_from(c)
	assert_true(copy.ping_move and copy.ping_on_map)
	assert_eq(copy.ping_target, Vector3(3.0, 1.0, -4.0))
	c.reset()
	assert_false(c.ping_move or c.ping_on_map)
	assert_eq(c.ping_target, Vector3.ZERO)


func test_the_simulation_makes_a_ping_on_the_map_an_event_at_the_point_picked() -> void:
	_squad()
	cmd.ping = true
	cmd.ping_move = true
	cmd.ping_on_map = true
	cmd.ping_target = Vector3(10.0, 0.0, -10.0)
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	var e: GameEvent = null
	for i in state.events.count:
		if state.events.items[i].kind == GameEvent.Kind.PING:
			e = state.events.items[i]
	assert_not_null(e)
	if e != null:
		assert_eq(e.actor, YOU)
		assert_eq(e.value, GameEvent.PING_ON_MAP)
		assert_eq(e.value2, 1, "a Go there")
		assert_eq(e.position, Vector3(10.0, 0.0, -10.0))
	bots.observe(state)
	cmd.ping = false


func test_go_there_on_the_map_sends_the_squad_side_by_side_and_turns_to_hold_once_there() -> void:
	_squad()
	var spot := Vector3(10.0, 0.0, -10.0)
	_ping(true, true, spot)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE)
	assert_eq(bots.order_outcome.order, SquadOrder.Kind.MOVE)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NONE)
	assert_true(bots.hold_spot(YOU), "its spot is marked as Hold here's is")
	assert_lt(_flat(bots.held_middle, spot), 1.0)
	var way := SquadOrders.yaw_towards(you.position, spot, 0.0)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.MOVE)
		assert_almost_eq(b.order_yaw, way, 0.02, "looking on the way there")
	assert_gt(_flat(mates[0].order_goal, mates[1].order_goal), squad.hold_spacing - 0.6, "side by side")
	_run(12.0)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.HOLD, "all there: it reads Hold here")
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.HOLD)
		assert_lt(_flat(b.character.position, b.order_goal), squad.hold_arrive + 0.3)
		assert_lt(absf(wrapf(b.character.yaw - way, -PI, PI)), 0.4, "looking on")
	assert_true(bots.hold_spot(YOU))


func test_go_there_along_the_view_goes_where_the_view_meets_the_floor() -> void:
	_squad()
	cmd.pitch = -0.2
	_run(0.3)
	_ping(true, false)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE)
	assert_true(bots.hold_spot(YOU))
	var expected := you.position.x + BotSenses.eye_of(you, tuning).y / tan(0.2)
	assert_almost_eq(bots.held_middle.x, expected, 1.0)
	assert_eq(bots.pings.placed, 0, "a Go there is an order, not a ping in the book")


func test_go_there_at_the_sky_goes_nowhere_and_says_so() -> void:
	_squad()
	cmd.pitch = 1.0
	_run(0.3)
	_ping(true, false)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NOWHERE)
	assert_eq(HudOrderWheel.notice_key(SquadOrders.Notice.NOWHERE), "HUD_ORDER_NOWHERE")


func test_go_there_again_moves_it_but_never_cancels_it() -> void:
	_squad()
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	_run(0.5)
	_ping(true, true, Vector3(10.5, 0.0, -10.0))
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE, "the same spot again: it stays")
	_run(0.5)
	_ping(true, true, Vector3(-20.0, 0.0, -30.0))
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE)
	assert_true(bots.hold_spot(YOU))
	assert_lt(_flat(bots.held_middle, Vector3(-20.0, 0.0, -30.0)), 1.0, "somewhere else: it moves")
	# Hold here's key while you look somewhere: a hold there instead.
	cmd.pitch = -0.2
	_run(0.2)
	assert_eq(_order(SquadOrder.Kind.HOLD), SquadOrder.Kind.HOLD)


func test_a_plain_ping_on_the_map_marks_the_floor_there_and_gives_no_order() -> void:
	_squad()
	_ping(false, true, Vector3(12.0, 0.0, 8.0))
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	var p := bots.pings.of(YOU)
	assert_true(bots.pings.is_up(p, state.time))
	assert_eq(p.kind, Pings.Kind.SPOT)
	assert_lt(_flat(p.spot, Vector3(12.0, 0.0, 8.0)), 1.0)
	# Off the field: nothing to mark.
	_run(0.5)
	var before := bots.pings.placed
	_ping(false, true, Vector3(500.0, 0.0, 500.0))
	assert_eq(bots.pings.placed, before)


func test_go_there_ends_when_you_are_out_like_every_order() -> void:
	_squad()
	_ping(true, true, Vector3(10.0, 0.0, -10.0))
	you.status = Character.Status.OUT
	_run(0.2)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.NONE)
	you.status = Character.Status.ALIVE


func test_ticks_walking_to_a_go_there_allocate_nothing() -> void:
	_squad()
	_moving_go_theres(600)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	_moving_go_theres(600)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


## `ticks` ticks giving Go there each second, north and south of you in turn, so the squad keeps walking.
func _moving_go_theres(ticks: int) -> void:
	for t in ticks:
		if t % 60 == 0:
			cmd.ping = true
			cmd.ping_move = true
			cmd.ping_on_map = true
			cmd.ping_target = Vector3(-10.0, 0.0, -10.0 if t % 120 == 0 else 30.0)
		_tick()
		cmd.ping = false


func test_go_there_at_a_wall_stops_at_its_foot_on_your_side_never_past_it() -> void:
	_squad(true)
	# You stand south of the thin wall (z 18.6 to 19.0) and look north at it, a little down.
	cmd.yaw = 0.0
	cmd.pitch = -0.1
	_run(0.3)
	_ping(true, false)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.MOVE)
	assert_true(bots.hold_spot(YOU))
	assert_gt(bots.held_middle.z, 19.0, "on your side of the wall, never beyond what you see")
	for b in mates:
		assert_gt(b.order_goal.z, 19.0)


func test_a_ping_at_a_wall_over_a_stack_finds_the_floor_on_your_side() -> void:
	_squad(true)
	_run(0.2)
	# Eyes 12 m off look a little up at the wall's south face just over the stack against it: no floor in reach in front
	# of that (the old spot was the wall itself), so it is looked for further back, and never past the wall.
	var dir := Vector3(0.0, 0.1, -1.0).normalized()
	var spot: Vector3 = bots.pings._floor_spot(Vector3(10.0, 2.8, 19.0), dir, 12.0, bots.world)
	assert_gt(spot.z, 19.0, "on your side of the wall: %s" % spot)
