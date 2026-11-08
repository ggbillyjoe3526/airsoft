extends GutTest
## BP8 bots QA (items 17, 23): edges of Watching here beyond the worker's tests, on the same open field.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const EAST := -PI * 0.5
const YOU := 0
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 22.0), Vector3(-36.0, 0.0, 26.0),
		Vector3(40.0, 0.0, -40.0)]
const SPOT_A := Vector3(-15.0, 0.0, 20.0)
const SPOT_B := Vector3(-15.0, 0.0, 30.0)

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var map: MapData = null
var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []
var you: Character = null
var near_mate: Bot = null
var far_mate: Bot = null


func before_each() -> void:
	map = MapData.new()
	map.id = "open field"
	map.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	var floor := MapData.Block.new()
	floor.kind = &"floor"
	floor.center = Vector3(0.0, -0.25, 0.0)
	floor.size = Vector3(100.0, 0.5, 100.0)
	map.blocks.append(floor)
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		map.ends.append(end)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
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
	near_mate = bots.world.bot_of(state.characters[1])
	far_mate = bots.world.bot_of(state.characters[2])
	for t in 30:
		_tick()


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func test_a_new_spot_far_from_the_first_moves_the_watch_and_keeps_one_helper() -> void:
	bots.orders.give_watch(you, SPOT_A)
	assert_eq(bots.world.watched[0], SPOT_A)
	bots.orders.give_watch(you, SPOT_B)
	assert_eq(bots.world.watched[0], SPOT_B, "the covered area follows the new spot")
	var joined := 0
	for b in bots.world.bots:
		if b.order == SquadOrder.Kind.WATCH:
			joined += 1
	assert_eq(joined, 1, "still at most one teammate")


func test_you_going_out_frees_the_area_and_the_helper() -> void:
	bots.orders.give_watch(you, SPOT_A)
	assert_eq(near_mate.order, SquadOrder.Kind.WATCH)
	Elimination.eliminate(you, 3, state.characters, map.ends)
	for t in 3:
		_tick()
	assert_false(SquadOrders.is_spot(bots.world.watched[0]), "no area left to you")
	assert_eq(near_mate.order, SquadOrder.Kind.NONE, "the helper is back on the team plan")
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)


func test_the_helper_going_out_leaves_your_watch_standing_without_a_helper() -> void:
	bots.orders.give_watch(you, SPOT_A)
	Elimination.eliminate(near_mate.character, 3, state.characters, map.ends)
	for t in 3:
		_tick()
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.WATCH)
	assert_eq(near_mate.order, SquadOrder.Kind.NONE)
	var joined := 0
	for b in bots.world.bots:
		if b.order == SquadOrder.Kind.WATCH:
			joined += 1
	assert_eq(joined, 0, "nobody is pulled in later")


func test_with_every_teammate_out_a_watch_gives_nobody_and_marks_nothing() -> void:
	Elimination.eliminate(near_mate.character, 3, state.characters, map.ends)
	Elimination.eliminate(far_mate.character, 3, state.characters, map.ends)
	assert_eq(bots.orders.give_watch(you, SPOT_A), SquadOrder.Kind.NONE)
	assert_false(SquadOrders.is_spot(bots.world.watched[0]))


func test_an_out_player_cannot_watch() -> void:
	Elimination.eliminate(you, 3, state.characters, map.ends)
	assert_eq(bots.orders.give_watch(you, SPOT_A), SquadOrder.Kind.NONE)
	assert_false(SquadOrders.is_spot(bots.world.watched[0]))


func test_covered_ignores_a_team_out_of_range_and_a_nan_spot() -> void:
	assert_false(bots.world.covered(-1, Vector3.ZERO))
	assert_false(bots.world.covered(7, Vector3.ZERO))
	assert_false(bots.world.covered(0, Vector3.ZERO), "nothing watched")
