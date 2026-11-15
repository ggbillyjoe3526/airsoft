extends GutTest
## QA's hunt for CW1's Cover me against the rest of the squad's orders and a helper or giver put out, and Spotted over
## a round's end. Open field: you (team 0) with two bot teammates, one opponent nobody drives.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
const ORANGE := 3
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0)]
const ENEMY_AT := Vector3(-10.0, 0.0, 20.0)
## A wall across the view 10 m east of you: [centre, size].
const WALL: Array[Vector3] = [Vector3(-20.0, 1.5, 20.0), Vector3(0.4, 3.0, 8.0)]

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default().duplicate() as BotConfig
var cfg: PingConfig = tuning.pings

var map: MapData = null
var nav: NavGrid = null
var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []
var cmd: PlayerCommand = null
var you: Character = null
var orange: Character = null
var mates: Array[Bot] = []
var _navs: Dictionary[String, NavGrid] = {}


func before_each() -> void:
	config.ping_follow_chance = 1.0
	config.ping_follow_reach = BotConfig.new().ping_follow_reach


# --- the field ---

func _field(walls: Array) -> Array:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	m.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	for pair: Array in walls:
		m.blocks.append(_block(&"wall", pair[0], pair[1]))
		w.add_box(pair[0], pair[1])
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


## You and two bot teammates at SPOTS, the opponent at `enemy` (still, driven by nobody), round 1 live and half a
## second gone.
func _squad(enemy: Vector3 = SPOTS[3], walls: Array = []) -> void:
	var f := _field(walls)
	var w: BoxWorld = f[1]
	map = f[0]
	var layout := str(walls)
	if not _navs.has(layout):
		_navs[layout] = NavGrid.build(map, tuning.nav, tuning.body)
	nav = _navs[layout]
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
	# Nobody shoots: the opponent stays in play for as long as a test watches the mark.
	state.cheats.bots_hold_fire = true
	bots.observe(state)
	for b in bots.world.bots:
		if b.character.team == 1:
			bots.world.bots.erase(b)
			break
	for i in SPOTS.size():
		state.characters[i].position = enemy if i == ORANGE else SPOTS[i]
	you = state.characters[YOU]
	orange = state.characters[ORANGE]
	cmd = commands[YOU]
	cmd.reset(EAST, 0.0)
	mates.clear()
	for b in bots.world.bots:
		if b.character.team == 0:
			mates.append(b)
	_run(0.5)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func _run(seconds: float) -> void:
	for t in roundi(seconds / DT):
		_tick()


## You spot (one tick) looking straight at `point`.
func _spot_toward(point: Vector3) -> void:
	var to := point - BotSenses.eye_of(you, tuning)
	cmd.yaw = atan2(-to.x, -to.z)
	cmd.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	cmd.ping = true
	cmd.ping_spot = true
	_tick()
	cmd.ping = false
	cmd.ping_spot = false


## You ping (one tick) looking `yaw`, `pitch`.
func _ping_at(yaw: float, pitch: float) -> Pings.Ping:
	cmd.yaw = yaw
	cmd.pitch = pitch
	cmd.ping = true
	var before := bots.pings.placed
	_tick()
	cmd.ping = false
	return bots.pings.of(YOU) if bots.pings.placed > before else null


func _chest(c: Character) -> Vector3:
	return BotSenses.body_point(c, tuning.hits, config.aim_height_fraction)


func _event(kind: GameEvent.Kind) -> GameEvent:
	for i in state.events.count:
		if state.events.items[i].kind == kind:
			return state.events.items[i]
	return null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()



func _order(kind: SquadOrder.Kind) -> void:
	cmd.squad_order = kind
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE


func _covering() -> Bot:
	for b in mates:
		if b.order == SquadOrder.Kind.COVER:
			return b
	return null


func test_a_helper_put_out_ends_cover_me_for_good_and_you_can_ask_again() -> void:
	_squad()
	_order(SquadOrder.Kind.COVER)
	var helper := _covering()
	assert_not_null(helper)
	Elimination.eliminate(helper.character, ORANGE, state.characters, sim.ends)
	_run(0.5)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.NONE, "nobody left covering you: not in force")
	_order(SquadOrder.Kind.COVER)
	var next := _covering()
	assert_not_null(next, "asked again, the other covers")
	assert_ne(next, helper)


func test_the_giver_put_out_ends_cover_me_and_frees_the_helper() -> void:
	_squad()
	_order(SquadOrder.Kind.COVER)
	var helper := _covering()
	Elimination.eliminate(you, ORANGE, state.characters, sim.ends)
	_run(0.5)
	assert_eq(helper.order, SquadOrder.Kind.NONE)
	assert_null(helper.order_giver)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.NONE)


func test_another_order_replaces_cover_me_and_leaves_no_covering_bot() -> void:
	_squad()
	for kind: SquadOrder.Kind in [SquadOrder.Kind.FOLLOW, SquadOrder.Kind.HOLD, SquadOrder.Kind.REGROUP,
			SquadOrder.Kind.TEAM_PLAN]:
		_order(SquadOrder.Kind.COVER)
		assert_not_null(_covering())
		_order(kind)
		assert_null(_covering(), "after kind %d no bot still covers" % kind)
		assert_ne(bots.orders.order_of(YOU), SquadOrder.Kind.COVER)


func test_cover_me_after_watching_here_ends_the_watch() -> void:
	_squad()
	_order(SquadOrder.Kind.WATCH)
	_order(SquadOrder.Kind.COVER)
	var n := 0
	for b in mates:
		if b.order != SquadOrder.Kind.NONE:
			n += 1
			assert_eq(b.order, SquadOrder.Kind.COVER)
	assert_eq(n, 1, "one teammate on one order")
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.COVER)


func test_cover_me_given_twice_from_the_wheel_stays_and_from_the_key_stays_too() -> void:
	_squad()
	_order(SquadOrder.Kind.COVER)
	var first := _covering()
	_order(SquadOrder.Kind.COVER)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.COVER)
	assert_not_null(_covering())
	assert_not_null(first)


func test_a_new_round_clears_cover_me_and_spotted_together() -> void:
	_squad(ENEMY_AT)
	_order(SquadOrder.Kind.COVER)
	_spot_toward(_chest(orange))
	assert_true(bots.spots.is_spotted(ORANGE, state.time))
	bots._new_round(state)
	assert_false(bots.spots.is_spotted(ORANGE, state.time))
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.NONE)
	assert_null(_covering())
