extends GutTest
## SO1 QA: what the squad orders must hold to beyond the worker's tests (test_squad_orders.gd). Orders only come through
## a command in play (never from a bot's own thinking), a refused one changes nothing in force, switching and wheel
## picks, two leaders, an order given the tick its giver is hit, Hold here on real geometry (a wall, a balcony, under
## a ceiling, a raised floor nobody can climb to), Attack / Defend with an order and back, seeded determinism, and
## ticks with every kind of order given allocate nothing. On an open 100 m field, headless: you (team 0) with two bot
## teammates and one opponent nobody drives.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0)]

## One life a round (RS1): the rules here as they play without respawns.
var tuning: SimTuning = MatchGuard.one_life(SimTuning.load_default())
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
static var _plain_nav: NavGrid = null


func after_all() -> void:
	_plain_nav = null


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## You and two bot teammates at SPOTS on a 100 m square, `extra` [kind, centre, size] blocks added (a &"floor" block is
## a surface to walk on, any other a solid), the opponent far off and driven by nobody, round 1 live and half a second
## gone. `attack_defend`: Attack / Defend with a pole at the middle, `attackers` the team attacking.
func _squad(extra: Array = [], attack_defend: bool = false, attackers: int = 0) -> void:
	var m := MapData.new()
	m.id = "qa field"
	m.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	m.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	for e: Array in extra:
		m.blocks.append(_block(e[0], e[1], e[2]))
		w.add_box(e[1], e[2])
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		m.ends.append(end)
	map = m
	# The plain field's grid is the slow part of a test and never changes: built once.
	if extra.is_empty():
		if _plain_nav == null:
			_plain_nav = NavGrid.build(map, tuning.nav, tuning.body)
		nav = _plain_nav
	else:
		nav = NavGrid.build(map, tuning.nav, tuning.body)
	sim = Simulation.new(tuning, w, w.mover(), map.ends, KILL_Y)
	sim.nav = nav
	state = GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in SPOTS.size():
		state.characters.append(Character.new(i, 0 if i < 3 else 1, SPOTS[i], EAST, loadout))
		commands.append(PlayerCommand.new())
	if attack_defend:
		state.round_state.mode = RoundState.Mode.ATTACK_DEFEND
		state.round_state.pole = Vector3.ZERO
		state.round_state.first_attackers = attackers
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


func _order(kind: SquadOrder.Kind, wheel: bool = false) -> SquadOrder.Kind:
	cmd.squad_order = kind
	cmd.order_from_wheel = wheel
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	cmd.order_from_wheel = false
	return bots.order_of(YOU)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _count(kind: GameEvent.Kind) -> int:
	return state.events.count_of(kind)


# ---- Orders come only through a command ------------------------------------------------------------------------------


func test_bots_never_order_by_thinking_and_a_stale_order_in_their_command_is_cleared() -> void:
	_squad()
	# A command a bot's brain is handed with an old order left in it: the brain writes a fresh one (nothing orders).
	for b in mates:
		commands[b.character.id].squad_order = SquadOrder.Kind.HOLD
	bots.think(state, commands, DT)
	for b in mates:
		assert_eq(commands[b.character.id].squad_order, SquadOrder.Kind.NONE, "a bot's command carries no order")
	var events := 0
	for t in 300:
		_tick()
		events += _count(GameEvent.Kind.SQUAD_ORDER) + _count(GameEvent.Kind.SQUAD_ORDER_REFUSED)
	assert_eq(events, 0, "five seconds of bots playing: no order given by anyone")
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.NONE)


func test_a_missing_or_short_command_list_and_events_from_nobody_are_harmless() -> void:
	_squad()
	commands[YOU] = null
	_tick()
	assert_eq(_count(GameEvent.Kind.SQUAD_ORDER), 0)
	commands.resize(1)
	commands[0] = cmd
	cmd.squad_order = SquadOrder.Kind.HOLD
	sim.step(state, commands, DT)
	assert_eq(_count(GameEvent.Kind.SQUAD_ORDER), 1, "your own command is still read")
	# An order event from a character that does not exist, or from an id off the end: nothing happens, nothing crashes.
	for who: int in [-1, 99]:
		state.events.clear()
		var e := state.events.add(GameEvent.Kind.SQUAD_ORDER)
		e.actor = who
		e.value = SquadOrder.Kind.HOLD
		bots.observe(state)
		var r := state.events.add(GameEvent.Kind.SQUAD_ORDER_REFUSED)
		r.actor = who
		bots.observe(state)
	assert_eq(bots.order_of(99), SquadOrder.Kind.NONE)
	assert_eq(bots.order_of(-1), SquadOrder.Kind.NONE)
	assert_false(bots.hold_spot(99))


func test_a_dead_zone_giver_is_refused_and_does_not_end_anyone_elses_order() -> void:
	_squad()
	_order(SquadOrder.Kind.HOLD)
	var bot_giver := mates[0]
	# A teammate bot that is out (parked) giving an order: refused, the order you gave stands.
	bot_giver.character.status = Character.Status.OUT
	commands[bot_giver.character.id].squad_order = SquadOrder.Kind.TEAM_PLAN
	sim.step(state, commands, DT)
	assert_eq(_count(GameEvent.Kind.SQUAD_ORDER_REFUSED), 1)
	assert_eq(_count(GameEvent.Kind.SQUAD_ORDER), 0)
	bots.observe(state)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.HOLD)
	assert_eq(mates[1].order, SquadOrder.Kind.HOLD)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NOT_NOW)


# ---- Refused orders change nothing -----------------------------------------------------------------------------------


func test_an_order_between_rounds_is_refused_and_the_order_in_force_stays() -> void:
	_squad()
	assert_eq(_order(SquadOrder.Kind.HOLD), SquadOrder.Kind.HOLD)
	var serial := bots.order_outcome.serial
	state.round_state.phase = RoundState.Phase.OVER
	state.round_state.timer = 100.0
	for kind: SquadOrder.Kind in [SquadOrder.Kind.TEAM_PLAN, SquadOrder.Kind.HOLD, SquadOrder.Kind.FOLLOW]:
		assert_eq(_order(kind), SquadOrder.Kind.HOLD, "the cease-fire: the order in force is not touched")
		assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NOT_NOW)
	assert_eq(bots.order_outcome.serial, serial + 3, "each refusal is an outcome")
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.HOLD)
	# A refused order from the wheel is refused the same.
	assert_eq(_order(SquadOrder.Kind.TEAM_PLAN, true), SquadOrder.Kind.HOLD)
	assert_eq(bots.order_outcome.order, SquadOrder.Kind.HOLD, "the record says what is in force")


func test_giving_an_order_in_the_tick_you_are_hit_leaves_no_order_in_force() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.HOLD
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	assert_eq(_count(GameEvent.Kind.SQUAD_ORDER), 1, "in play when the tick began: taken")
	# Hit in that same tick (a hit makes you CALLING, out of play).
	you.status = Character.Status.CALLING
	bots.observe(state)
	cmd.squad_order = SquadOrder.Kind.NONE
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.NONE, "nothing is left carrying it")
	_run(1.0)
	for b in mates:
		assert_ne(b.mode, Bot.Mode.ORDER)


func test_an_order_ends_for_the_calling_walking_off_and_leaving_states_too() -> void:
	for status: Character.Status in [Character.Status.CALLING, Character.Status.WALKING_OFF,
			Character.Status.LEAVING]:
		_squad()
		_order(SquadOrder.Kind.REGROUP)
		mates[1].character.status = status
		_tick()
		assert_eq(mates[1].order, SquadOrder.Kind.NONE, "a bot that is hit drops it (%d)" % status)
		# A bot that reaches you turns Regroup into Follow me (SO2), so it only has to keep an order.
		assert_ne(mates[0].order, SquadOrder.Kind.NONE)
		mates[0].character.status = status
		_tick()
		assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE, "nobody carries it: nothing in force (%d)" % status)


# ---- Toggling, switching, the wheel, two leaders -----------------------------------------------------------------------


func test_switching_to_another_order_replaces_it_and_each_kind_toggles_on_its_own() -> void:
	_squad()
	cmd.pitch = -0.2
	_run(0.2)
	assert_eq(_order(SquadOrder.Kind.HOLD), SquadOrder.Kind.HOLD)
	assert_eq(_order(SquadOrder.Kind.FOLLOW), SquadOrder.Kind.FOLLOW, "another key replaces, never cancels")
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.FOLLOW)
	assert_false(bots.hold_spot(YOU), "no hold is marked once it is not a hold")
	assert_eq(_order(SquadOrder.Kind.HOLD, true), SquadOrder.Kind.HOLD, "the wheel too replaces")
	assert_true(bots.hold_spot(YOU))
	# Picked again on the wheel at the same spot: stays; at a far spot: moves; the key at that same spot: cancels.
	assert_eq(_order(SquadOrder.Kind.HOLD, true), SquadOrder.Kind.HOLD)
	var first := bots.held_middle
	cmd.yaw = 0.0
	_run(0.2)
	assert_eq(_order(SquadOrder.Kind.HOLD, true), SquadOrder.Kind.HOLD)
	assert_true(bots.hold_spot(YOU))
	assert_gt(_flat(bots.held_middle, first), squad.hold_move, "picked on the wheel looking elsewhere moves it")
	assert_eq(_order(SquadOrder.Kind.HOLD), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.CANCELLED)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.NONE)


func test_a_hold_looked_at_a_little_over_hold_move_away_moves_and_a_little_under_cancels() -> void:
	_squad()
	cmd.pitch = -0.2
	_run(0.2)
	_order(SquadOrder.Kind.HOLD)
	assert_true(bots.hold_spot(YOU))
	var at := bots.held_middle
	# The view's spot is where the line meets the floor: 1.6 m eye over a 0.2 rad slope is 7.9 m away; turn the view so
	# that point shifts by about hold_move across.
	var eye := BotSenses.eye_of(you, tuning).y
	var radius := eye / tan(0.2)
	var shift := 2.0 * asin((squad.hold_move + 0.4) / (2.0 * radius))
	cmd.yaw = EAST + shift
	_run(0.2)
	assert_eq(_order(SquadOrder.Kind.HOLD), SquadOrder.Kind.HOLD, "well past hold_move: moved")
	assert_true(bots.hold_spot(YOU))
	assert_gt(_flat(bots.held_middle, at), squad.hold_move)
	at = bots.held_middle
	var near := 2.0 * asin((squad.hold_move - 0.8) / (2.0 * radius))
	cmd.yaw = EAST + shift + near
	_run(0.2)
	assert_eq(_order(SquadOrder.Kind.HOLD), SquadOrder.Kind.NONE, "less than hold_move from the held spot: cancels")


func test_a_second_leader_takes_over_the_squad_and_the_first_leader_has_nothing_in_force() -> void:
	_squad()
	var leader := mates[0]
	bots.think(state, commands, DT)
	commands[leader.character.id].squad_order = SquadOrder.Kind.HOLD
	sim.step(state, commands, DT)
	bots.observe(state)
	var lid := leader.character.id
	assert_eq(bots.order_of(lid), SquadOrder.Kind.HOLD)
	assert_eq(_order(SquadOrder.Kind.FOLLOW), SquadOrder.Kind.FOLLOW, "you order the squad, the bot leader among it")
	assert_eq(bots.order_of(lid), SquadOrder.Kind.NONE, "nobody carries the leader's order any more")
	assert_eq(mates[1].order_giver, you)
	assert_eq(leader.order_giver, you)
	# The leader hit and out: your order for the other bot stays.
	leader.character.status = Character.Status.OUT
	_tick()
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.FOLLOW)


func test_an_order_given_with_nobody_in_play_is_nobody_and_leaves_no_state_behind() -> void:
	_squad()
	for b in mates:
		b.character.status = Character.Status.OUT
	assert_eq(_order(SquadOrder.Kind.HOLD), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NOBODY)
	assert_eq(_order(SquadOrder.Kind.TEAM_PLAN, true), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.ON_PLAN)
	# Both mates come back at the next round: a clean slate for the first order.
	for b in mates:
		b.character.status = Character.Status.ALIVE
	assert_eq(_order(SquadOrder.Kind.REGROUP), SquadOrder.Kind.REGROUP)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NONE)


# ---- Hold here on real geometry --------------------------------------------------------------------------------------


func test_hold_here_at_a_wall_in_range_stops_short_of_it_and_a_wall_beyond_range_is_nothing() -> void:
	# A wall 35 m ahead of you (x 5), and another across the field 55 m ahead (x 25) for the second look.
	_squad([[&"wall", Vector3(5.0, 1.5, 20.0), Vector3(0.4, 3.0, 30.0)]])
	var w := bots.world
	var spot := SquadOrders.hold_point(you, w)
	assert_true(SquadOrders.is_spot(spot), "a wall 35 m off is within hold_range")
	assert_between(spot.x, 5.0 - 0.2 - squad.hold_wall_gap - nav.cell, 5.0 - 0.2 - squad.hold_wall_gap + 0.1)
	assert_almost_eq(spot.y, 0.0, 0.05)
	# Nothing within 40 m: no spot.
	you.position = Vector3(-40.0, 0.0, 20.0)
	assert_false(SquadOrders.is_spot(SquadOrders.hold_point(you, w)), "45 m to the wall is out of range")
	you.position = SPOTS[0]
	# Straight up or straight down: nothing to hold, and nothing that is not a number.
	for pitch: float in [-PI * 0.5, PI * 0.5, -1.55]:
		you.pitch = pitch
		var p := SquadOrders.hold_point(you, w)
		if SquadOrders.is_spot(p):
			assert_true(is_finite(p.x) and is_finite(p.y) and is_finite(p.z), "a finite spot for pitch %f" % pitch)
	you.pitch = 0.0


func test_hold_here_looking_down_from_a_balcony_holds_the_street_not_the_balcony() -> void:
	# A balcony 3 m up at x -36..-24, you on it looking east and down.
	_squad([[&"floor", Vector3(-30.0, 2.75, 40.0), Vector3(12.0, 0.5, 12.0)]])
	you.position = Vector3(-30.0, 3.0, 40.0)
	you.yaw = EAST
	you.pitch = -0.15
	var spot := SquadOrders.hold_point(you, bots.world)
	assert_true(SquadOrders.is_spot(spot))
	assert_almost_eq(spot.y, 0.0, 0.05, "the street under the line, at the level it meets")
	assert_gt(spot.x, -24.0, "past the balcony's edge")


func test_hold_here_on_a_balcony_looking_level_at_a_wall_holds_the_balcony() -> void:
	# A balcony 3 m up over x -36..-6 with a wall across it at x -6; you stand on it looking straight at the wall.
	_squad([[&"floor", Vector3(-21.0, 2.75, 40.0), Vector3(30.0, 0.5, 12.0)],
			[&"wall", Vector3(-6.0, 4.5, 40.0), Vector3(0.4, 3.0, 12.0)]])
	you.position = Vector3(-30.0, 3.0, 40.0)
	you.yaw = EAST
	you.pitch = 0.0
	var spot := SquadOrders.hold_point(you, bots.world)
	assert_true(SquadOrders.is_spot(spot))
	assert_almost_eq(spot.y, 3.0, 0.05, "the balcony's floor, not the street 3 m under it")
	assert_between(spot.x, -8.0, -6.2)


func test_hold_here_looking_up_at_a_wall_on_a_balcony_holds_the_floor_upstairs() -> void:
	# From the street you look up, over the balcony's edge, at a wall standing on it (x 8, 36 m ahead).
	_squad([[&"floor", Vector3(0.0, 2.75, 20.0), Vector3(20.0, 0.5, 12.0)],
			[&"wall", Vector3(8.0, 4.5, 20.0), Vector3(0.4, 3.0, 12.0)]])
	you.position = SPOTS[0]
	you.yaw = EAST
	you.pitch = 0.1
	var spot := SquadOrders.hold_point(you, bots.world)
	assert_true(SquadOrders.is_spot(spot))
	assert_almost_eq(spot.y, 3.0, 0.05, "the floor upstairs, where the line meets the wall")
	assert_between(spot.x, -10.0, 8.0)


func test_hold_here_under_a_ceiling_holds_the_hall_not_the_roof() -> void:
	# A roof slab 2.9 to 3.4 m up over x -10..10; you look east and a little up at its underside.
	_squad([[&"floor", Vector3(0.0, 3.15, 20.0), Vector3(20.0, 0.5, 30.0)]])
	you.position = SPOTS[0]
	you.yaw = EAST
	you.pitch = 0.05
	var spot := SquadOrders.hold_point(you, bots.world)
	assert_true(SquadOrders.is_spot(spot), "the hall under the slab is a place")
	assert_almost_eq(spot.y, 0.0, 0.05, "on the hall floor, not on the roof")
	assert_lt(spot.x, -3.0)


func test_a_hold_on_a_raised_floor_nobody_can_climb_to_ends_with_the_bots_holding_where_they_got_to() -> void:
	# A 1.5 m platform (no ramp) x -35..-15, z 30..46; you stand on it looking east and down at its surface.
	_squad([[&"floor", Vector3(-25.0, 0.75, 38.0), Vector3(20.0, 1.5, 16.0)]])
	you.position = Vector3(-33.0, 1.5, 38.0)
	you.prev_position = you.position
	cmd.yaw = EAST
	cmd.pitch = -0.2
	_run(0.3)
	assert_eq(_order(SquadOrder.Kind.HOLD), SquadOrder.Kind.HOLD)
	assert_true(bots.hold_spot(YOU))
	assert_almost_eq(bots.held_middle.y, 1.5, 0.05, "the spot is on the platform")
	_run(8.0)
	for b in mates:
		assert_lt(b.character.position.y, 0.3, "still on the ground: it cannot climb to the spot")
		assert_ne(b.route_state, Bot.RouteState.WANTED, "no replan loop for an unreachable spot")
		assert_eq(b.mode, Bot.Mode.ORDER)
	var rest: Array[Vector3] = [mates[0].character.position, mates[1].character.position]
	_run(2.0)
	for i in mates.size():
		assert_lt(_flat(mates[i].character.position, rest[i]), 0.3, "settled: it holds where it got to")


# ---- Attack / Defend and the team plan --------------------------------------------------------------------------------


func test_ordered_bots_are_not_picked_to_raise_and_are_again_once_the_order_ends() -> void:
	_squad([], true, 0)
	for b in mates:
		b.lane_done = true
	_tick()
	var picked := 0
	for b in mates:
		picked += 1 if b.raiser else 0
	assert_eq(picked, 1, "without an order one raises")
	_order(SquadOrder.Kind.HOLD)
	_tick()
	for b in mates:
		assert_false(b.raiser, "ordered: nobody raises")
		assert_eq(b.mode, Bot.Mode.ORDER)
	_order(SquadOrder.Kind.TEAM_PLAN, true)
	_run(0.5)
	picked = 0
	for b in mates:
		picked += 1 if b.raiser else 0
	assert_eq(picked, 1, "the order ended: one raises again")


func test_ordered_defenders_do_not_retake_the_flag_and_go_back_to_their_posts() -> void:
	_squad([], true, 1)
	state.round_state.flag.progress = 0.4
	_run(0.2)
	var retakers := 0
	for b in mates:
		retakers += 1 if b.retake else 0
	assert_gt(retakers, 0, "someone goes to pull the flag down")
	_order(SquadOrder.Kind.HOLD)
	_run(0.2)
	for b in mates:
		assert_false(b.retake, "ordered: not picked")
		assert_eq(b.mode, Bot.Mode.ORDER)
	_order(SquadOrder.Kind.TEAM_PLAN, true)
	_run(0.5)
	retakers = 0
	for b in mates:
		assert_ne(b.mode, Bot.Mode.ORDER)
		retakers += 1 if b.retake else 0
	assert_gt(retakers, 0, "back on the plan: they retake")


func test_an_anchor_ordered_to_hold_stands_aside_and_goes_on_hunting_from_where_it_is_after() -> void:
	_squad()
	var b := mates[0]
	var style := BotsFile.Style.new()
	style.holds = true
	style.hold_until = 0.0
	style.pushes_in = true
	b.style = style
	bots.world.round_clock = 100.0
	b.hunting = false
	assert_true(BotPersonality.anchor_holding(b, bots.world))
	_order(SquadOrder.Kind.HOLD)
	assert_false(BotPersonality.anchor_holding(b, bots.world))
	assert_false(BotPersonality.pushes_in(b))
	_order(SquadOrder.Kind.TEAM_PLAN, true)
	assert_true(b.hunting, "an ended order sends it on from where it stands")
	_run(0.2)
	assert_eq(b.mode, Bot.Mode.ADVANCE)


# ---- Determinism -----------------------------------------------------------------------------------------------------


## Plays 6 s on a fresh field, giving `orders` (a list of [second, kind, yaw]) through your command; returns where
## everyone stands and the stream.
func _scripted(orders: Array) -> Array:
	_squad()
	cmd.pitch = -0.2
	var out: Array = []
	var next := 0
	for t in 360:
		if next < orders.size() and t >= int(orders[next][0] * 60.0):
			cmd.yaw = orders[next][2]
			cmd.squad_order = orders[next][1]
			next += 1
		_tick()
		cmd.squad_order = SquadOrder.Kind.NONE
	for c in state.characters:
		out.append(c.position)
		out.append(c.yaw)
	out.append(state.rng.state)
	out.append(bots.order_of(YOU))
	return out


func test_the_same_seed_and_orders_play_out_exactly_alike_and_an_order_makes_a_difference() -> void:
	var script := [[0.5, SquadOrder.Kind.HOLD, EAST], [2.0, SquadOrder.Kind.HOLD, 0.0],
			[3.5, SquadOrder.Kind.FOLLOW, 0.0], [4.0, SquadOrder.Kind.TEAM_PLAN, 0.0]]
	var a := _scripted(script)
	var b := _scripted(script)
	assert_eq(a, b)
	var none := _scripted([])
	assert_ne(a, none, "orders did something")


# ---- Allocations -----------------------------------------------------------------------------------------------------


func _cycle(ticks: int, from_tick: int) -> void:
	var kinds: Array[SquadOrder.Kind] = [SquadOrder.Kind.HOLD, SquadOrder.Kind.FOLLOW, SquadOrder.Kind.HOLD,
			SquadOrder.Kind.REGROUP, SquadOrder.Kind.TEAM_PLAN, SquadOrder.Kind.HOLD, SquadOrder.Kind.HOLD]
	for t in range(from_tick, from_tick + ticks):
		if t % 30 == 0:
			var n := t / 30
			cmd.squad_order = kinds[n % kinds.size()]
			cmd.order_from_wheel = n % 3 == 0
			cmd.yaw = EAST if n % 2 == 0 else EAST + 1.0
			cmd.pitch = -0.2 if n % 5 != 0 else 0.3
			# Now and then, out for a while: orders refused.
			you.status = Character.Status.OUT if n % 11 == 10 else Character.Status.ALIVE
		_tick()
		cmd.squad_order = SquadOrder.Kind.NONE
		cmd.order_from_wheel = false


func test_ticks_giving_every_kind_of_order_cancelling_and_being_refused_allocate_nothing() -> void:
	_squad()
	_cycle(600, 0)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_cycle(900, 600)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "no objects made or left")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)


func test_attack_defend_ticks_with_orders_allocate_nothing() -> void:
	_squad([], true, 1)
	state.round_state.flag.progress = 0.4
	# Long enough a warm-up for the event pool to reach its size once followers move.
	_cycle(1050, 0)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	_cycle(600, 1050)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects)
