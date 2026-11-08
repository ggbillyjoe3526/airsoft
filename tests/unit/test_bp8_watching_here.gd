extends GutTest
## Watching here (BP8, William's playtest item 17): the order wheel's Watching Here marks the spot you look at as yours
## to cover. It travels as your command's ping (ping_watch), the simulation makes a PING event of it and the bots'
## controller hands it out (SquadOrderBook.give_watch): the nearest free teammate joins you beside you looking at the
## spot, at most one; the rest go back to the team plan and keep their hunts and held angles off the area
## (BotWorld.covered). Hold here's marker reads WATCHING over the spot, the teammate says so on the radio, and it ends
## with Team Plan, a new order, the next round or you walking off. On an open field, headless.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
## You, two teammates (one near, one further back) and the opponent far off.
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 22.0), Vector3(-36.0, 0.0, 26.0),
		Vector3(40.0, 0.0, -40.0)]
## Looking down this much (rad) from the eyes, the view meets the floor some 15 m ahead.
const LOOK_DOWN := -0.11

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
var near_mate: Bot = null
var far_mate: Bot = null
var _built: Array = []


func _field() -> Array:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	var floor := MapData.Block.new()
	floor.kind = &"floor"
	floor.center = Vector3(0.0, -0.25, 0.0)
	floor.size = Vector3(100.0, 0.5, 100.0)
	m.blocks.append(floor)
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		m.ends.append(end)
	return [m, w]


func before_each() -> void:
	var f := _field()
	var w: BoxWorld = f[1]
	if _built.is_empty():
		var m: MapData = f[0]
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
	cmd.reset(EAST, LOOK_DOWN)
	near_mate = bots.world.bot_of(state.characters[1])
	far_mate = bots.world.bot_of(state.characters[2])
	_run(0.5)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func _run(seconds: float) -> void:
	for t in roundi(seconds / DT):
		_tick()


## Watching here through your command for one tick; returns the order in force after.
func _watch() -> SquadOrder.Kind:
	cmd.ping = true
	cmd.ping_watch = true
	_tick()
	cmd.ping = false
	cmd.ping_watch = false
	return bots.order_of(YOU)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_the_command_carries_watching_here_and_reset_and_copy_from_include_it() -> void:
	var c := PlayerCommand.new()
	c.ping_watch = true
	var copy := PlayerCommand.new()
	copy.copy_from(c)
	assert_true(copy.ping_watch)
	c.reset()
	assert_false(c.ping_watch)


func test_watching_here_is_on_the_wheel_and_picked_there_is_a_watch_ping_along_the_view() -> void:
	var controls := ControlsConfig.new()
	var slot := controls.wheel_orders.find(SquadOrder.Kind.WATCH)
	assert_gt(slot, -1, "Watching Here is on the wheel")
	assert_eq(controls.wheel_labels[slot], "ORDER_WATCH")
	assert_eq(tr("ORDER_WATCH"), "Watching Here")
	var input := PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true
	Input.action_press(&"order_wheel")
	var e := InputEventAction.new()
	e.action = &"order_wheel"
	e.pressed = true
	input._unhandled_input(e)
	var angle := TAU * slot / controls.wheel_orders.size()
	var m := InputEventMouseMotion.new()
	m.screen_relative = Vector2(sin(angle) * 150.0, -cos(angle) * 150.0)
	input._unhandled_input(m)
	Input.action_release(&"order_wheel")
	var off := InputEventAction.new()
	off.action = &"order_wheel"
	off.pressed = false
	input._unhandled_input(off)
	var out := PlayerCommand.new()
	input.fill(out)
	assert_true(out.ping and out.ping_watch, "picked on the wheel: a Watching here ping")
	assert_false(out.ping_move or out.ping_on_map, "not a Go there, not on the map")
	assert_eq(out.squad_order, SquadOrder.Kind.NONE, "a ping, not an order")


func test_the_nearest_teammate_joins_you_and_only_one() -> void:
	assert_eq(_watch(), SquadOrder.Kind.WATCH)
	var w := bots.world
	var spot := w.watched[0]
	assert_true(SquadOrders.is_spot(spot), "the team's watched spot is set")
	assert_almost_eq(_flat(spot, you.position), 15.0, 3.0, "the floor you looked at, about 15 m ahead")
	assert_eq(near_mate.order, SquadOrder.Kind.WATCH, "the nearest joins you")
	assert_eq(far_mate.order, SquadOrder.Kind.NONE, "the other is on the team plan")
	assert_true(bots.hold_spot(YOU), "the marker's spot")
	assert_eq(bots.held_middle, spot)
	_run(4.0)
	assert_lt(_flat(near_mate.character.position, you.position), squad.hold_spacing + 1.0, "beside you")
	var look := Vector2(-sin(near_mate.character.yaw), -cos(near_mate.character.yaw))
	var to_spot := Vector2(spot.x - near_mate.character.position.x, spot.z - near_mate.character.position.z)
	assert_gt(look.dot(to_spot.normalized()), cos(deg_to_rad(25.0)), "looking at the spot")
	var with_you := 0
	for b in w.bots:
		if b.order == SquadOrder.Kind.WATCH:
			with_you += 1
	assert_eq(with_you, 1, "at most one teammate joins you")


func test_a_teammate_fighting_never_joins_and_one_still_answers() -> void:
	near_mate.mode = Bot.Mode.FIGHT
	assert_eq(bots.orders.give_watch(you, Vector3(-15.0, 0.0, 20.0)), SquadOrder.Kind.WATCH)
	assert_ne(near_mate.order, SquadOrder.Kind.WATCH, "busy fighting")
	assert_eq(far_mate.order, SquadOrder.Kind.WATCH, "the nearest free one comes instead")
	assert_eq(bots.orders.watch_speaker, far_mate)
	assert_true(bots.orders.watch_joined)
	far_mate.mode = Bot.Mode.FIGHT
	bots.orders.give_order(you, SquadOrder.Kind.TEAM_PLAN)
	assert_eq(bots.orders.give_watch(you, Vector3(-15.0, 0.0, 20.0)), SquadOrder.Kind.WATCH,
			"nobody free: you still watch it")
	assert_eq(bots.orders.watch_speaker, near_mate, "the nearest says it leaves it to you")
	assert_false(bots.orders.watch_joined)


func test_the_team_keeps_its_hunts_off_the_area_you_cover() -> void:
	var w := bots.world
	w.watched[0] = Vector3(0.0, 0.0, 0.0)
	assert_true(w.covered(0, Vector3(squad.watch_radius - 0.5, 0.0, 0.0)))
	assert_false(w.covered(0, Vector3(squad.watch_radius + 0.5, 0.0, 0.0)))
	assert_false(w.covered(1, Vector3.ZERO), "only your own team leaves it to you")
	for n in 60:
		if w.planner.hunt_point(far_mate, w):
			assert_false(w.covered(0, far_mate.hunt_goal), "a hunt spot outside the area (%s)" % far_mate.hunt_goal)


func test_team_plan_a_new_order_or_walking_off_ends_it() -> void:
	_watch()
	cmd.squad_order = SquadOrder.Kind.TEAM_PLAN
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE, "Team Plan ends it")
	assert_false(SquadOrders.is_spot(bots.world.watched[0]), "the area is the team's again")
	assert_eq(near_mate.order, SquadOrder.Kind.NONE)
	_watch()
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.FOLLOW, "a new order takes over")
	assert_false(SquadOrders.is_spot(bots.world.watched[0]))
	bots.give_order(you, SquadOrder.Kind.TEAM_PLAN)
	_watch()
	you.position += Vector3(0.0, 0.0, squad.watch_leave + 1.0)
	_tick()
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE, "walked off: back on the team plan")
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.CANCELLED)
	assert_false(SquadOrders.is_spot(bots.world.watched[0]))


func test_the_same_spot_again_keeps_it_and_a_new_round_clears_it() -> void:
	_watch()
	var spot := bots.world.watched[0]
	assert_eq(bots.orders.give_watch(you, spot + Vector3(1.0, 0.0, 0.0)), SquadOrder.Kind.WATCH)
	assert_eq(bots.world.watched[0], spot, "near the spot watched: it stays")
	bots.orders.clear()
	assert_false(SquadOrders.is_spot(bots.world.watched[0]), "no watch outlasts a round")


func test_watching_at_nothing_says_nowhere() -> void:
	assert_eq(bots.orders.give_watch(you, SquadOrders.NO_SPOT), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NOWHERE)


func test_the_marker_reads_watching() -> void:
	var marker := HudHoldMarker.new()
	add_child_autofree(marker)
	marker.setup(HudConfig.new(), Color.WHITE)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	marker.set_watching(true)
	marker.place(camera, Vector3(0.0, 0.0, -18.0), true, Vector2(1920.0, 1080.0), Rect2())
	assert_eq(marker.text(), "WATCHING · 18 M")
	marker.set_watching(false)
	marker.place(camera, Vector3(0.0, 0.0, -18.0), true, Vector2(1920.0, 1080.0), Rect2())
	assert_eq(marker.text(), "HOLD · 18 M")


func test_the_teammate_answers_on_the_radio() -> void:
	var file := CalloutsFile.shared()
	var join := CalloutsFile.Event.WATCH_JOIN
	var rest := CalloutsFile.Event.WATCH_REST
	assert_lt(file.rules[join].priority, CalloutsFile.Event.size(), "Watching with you has a row")
	assert_lt(file.rules[rest].priority, CalloutsFile.Event.size(), "Leaving it to you has a row")
	assert_eq(file.rules[join].chance, 1.0, "always answered")
	var talk := Callouts.new(file, config.callouts, map.areas, 7)
	talk.orders = bots.orders
	_watch()
	for n in 30:
		_tick()
		talk.observe(state, bots.world)
	var said := false
	for n in range(talk.said.oldest(), talk.said.total):
		var c := talk.said.entry(n)
		if c != null and c.event == join and c.speaker_id == near_mate.character.id:
			said = true
	assert_true(said, "the teammate joining you said so")
