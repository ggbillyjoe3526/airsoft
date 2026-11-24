extends GutTest
## Bot hunting tests on Depot, headless: the same seed plays the same match, a bot knows nothing of an enemy it can
## neither see nor hear, and a match goes on with the human player out (or idle) until a team wins.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var style: MapStyle = MapStyle.new()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null

var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []


func before_all() -> void:
	map = YardMap.load_map(style, tuning.rounds.team_size)
	level = MapLevel.new()
	add_child(level)
	level.build(map, style, tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	level.free()


func _start(seed_value: int, player_id: int) -> void:
	sim = Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state = GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in tuning.rounds.team_size * 2:
		state.characters.append(Character.new(i, 0 if i < tuning.rounds.team_size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	bots = BotController.new(state, player_id, map, nav, level.query(), tuning, config)
	sim.start_match(state)
	bots.observe(state)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func _trace(seed_value: int, ticks: int) -> PackedVector3Array:
	_start(seed_value, -1)
	for t in ticks:
		_tick()
	var out := PackedVector3Array()
	for c in state.characters:
		out.append(c.position)
	return out


func test_the_same_seed_plays_the_same_bot_match() -> void:
	var a := _trace(7, 1500)
	var b := _trace(7, 1500)
	assert_eq(a, b, "same seed, same positions")
	assert_ne(_trace(8, 1500), a, "another seed plays another match")


func test_a_bot_knows_nothing_of_an_unseen_silent_enemy() -> void:
	_start(11, -1)
	var watcher: Bot = null
	for b in bots.world.bots:
		if b.character.id == 0:
			watcher = b
	var hidden := state.characters[3]
	for c in state.characters:
		if c != watcher.character and c != hidden:
			c.status = Character.Status.OUT
	watcher.character.position = Vector3(-14.0, 0.0, 0.0)
	watcher.character.yaw = PI * 0.5
	hidden.position = Vector3(-21.0, 0.0, 0.0)
	watcher.has_last_known = false
	for t in 120:
		bots.think(state, commands, DT)
		state.time += DT
		watcher.character.position = Vector3(-14.0, 0.0, 0.0)
		watcher.character.yaw = PI * 0.5
		hidden.position = Vector3(-21.0, 0.0, 0.0)
	assert_false(watcher.target_visible, "does not see through the wall")
	assert_false(watcher.has_last_known, "has no guess of a silent enemy it cannot see")
	assert_false(commands[0].fire, "does not shoot at nothing")


func test_the_match_goes_on_with_the_player_idle_and_out() -> void:
	# Character 0 is the human, here doing nothing: the bots must still finish the match, with no friendly hit. (Seed 2:
	# on seed 3 the idle player has lived to every round's end since BBs met the yard's props as drawn, DG1; seeds 1, 2
	# and 4 to 8 all put them out while the round runs on.)
	_start(2, 0)
	var limit := roundi(tuning.rounds.round_time / DT) * 14
	var finished := false
	var friendly := 0
	var player_out_while_live := false
	for t in limit:
		_tick()
		if state.round_state.is_live() and not Elimination.is_in_play(state.characters[0]):
			player_out_while_live = true
		for i in state.events.count:
			var e := state.events.items[i]
			if e.kind == GameEvent.Kind.CHARACTER_HIT and e.actor >= 0 \
					and state.characters[e.actor].team == state.characters[e.target].team:
				friendly += 1
			elif e.kind == GameEvent.Kind.MATCH_OVER:
				finished = true
		if finished:
			break
	assert_true(finished, "the match ends")
	assert_true(player_out_while_live, "the player was out while the round ran on")
	assert_eq(friendly, 0)


func test_a_rematch_replans_the_bots_and_plays_again() -> void:
	_start(4, -1)
	var limit := roundi(tuning.rounds.round_time / DT) * 14
	var finished := false
	for t in limit:
		_tick()
		if state.events.count_of(GameEvent.Kind.MATCH_OVER) > 0:
			finished = true
			break
	assert_true(finished)
	sim.start_match(state)
	bots.observe(state)
	var rounds := 0
	for t in roundi(tuning.rounds.round_time / DT) * 3:
		_tick()
		rounds += state.events.count_of(GameEvent.Kind.ROUND_OVER)
		if rounds > 0:
			break
	assert_gt(rounds, 0, "the second match plays rounds")
