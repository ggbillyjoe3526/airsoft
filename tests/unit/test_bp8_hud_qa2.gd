extends GutTest
## QA's second pass on BP8's HUD part: RoundState.is_live() is false in the start countdown, so what reads it must cope in
## the first seconds of a round and across round changes: bots do not count as stuck or replan, the round plays on after
## GO, a new round counts down again, and nobody fires, talks or scores before GO.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null
var sim: Simulation = null
var state: GameState = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []


func before_all() -> void:
	map = YardMap.load_map(MapStyle.new(), tuning.rounds.team_size)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	level.free()


func _start(mode: RoundState.Mode) -> void:
	tuning = SimTuning.load_default().duplicate() as SimTuning
	tuning.rounds = tuning.rounds.duplicate() as RoundConfig
	tuning.rounds.start_countdown = 3.0
	sim = Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state = GameState.new(5, tuning)
	commands.clear()
	var size := tuning.rounds.team_size
	for i in size * 2:
		state.characters.append(Character.new(i, 0 if i < size else 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
		commands.append(PlayerCommand.new())
	if mode == RoundState.Mode.ATTACK_DEFEND:
		state.round_state.mode = mode
		state.round_state.pole = map.pole
	bots = BotController.new(state, -1, map, nav, level.query(), tuning, BotConfig.load_default())
	sim.start_match(state)
	bots.observe(state)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func test_bots_are_not_stuck_or_replanning_through_the_countdown() -> void:
	_start(RoundState.Mode.ELIMINATION)
	var stuck := 0.0
	var start_pos: Array[Vector3] = []
	for i in 5:
		_tick() # settles onto the floor
	for c in state.characters:
		start_pos.append(c.position)
	var n := 0
	while state.round_state.held() and n < 600:
		_tick()
		n += 1
		for b in bots.world.bots:
			stuck = maxf(stuck, b.stuck_for)
	assert_gt(n, 100, "a countdown ran")
	assert_almost_eq(stuck, 0.0, 0.001, "a held bot is not counted as stuck")
	for i in state.characters.size():
		var d := state.characters[i].position - start_pos[i]
		assert_lt(Vector2(d.x, d.z).length(), 0.01, "nobody moved in the countdown")


func test_the_round_plays_on_after_go_bots_move_and_fire() -> void:
	var modes: Array[RoundState.Mode] = [RoundState.Mode.ELIMINATION, RoundState.Mode.ATTACK_DEFEND]
	for mode in modes:
		_start(mode)
		var shots := 0
		for i in 60 * 40:
			_tick()
			shots += state.events.count_of(GameEvent.Kind.SHOT)
			if not state.round_state.is_live() and not state.round_state.held():
				break
		assert_gt(shots, 0, "bots fired once it was live (mode %d)" % mode)


func test_no_shot_no_callout_and_no_hit_before_go_and_a_new_round_counts_down_again() -> void:
	_start(RoundState.Mode.ELIMINATION)
	var said := 0
	while state.round_state.held():
		_tick()
		said += state.events.count_of(GameEvent.Kind.SHOT) + state.events.count_of(GameEvent.Kind.CHARACTER_HIT)
	assert_eq(said, 0, "no shot or hit in the hold")
	assert_true(state.round_state.is_live())
	assert_true(Round.run_clock_out(state.round_state), "ends the live round")
	var n := 0
	while not state.round_state.held() and n < 60 * 60:
		_tick()
		n += 1
	assert_true(state.round_state.held(), "the next round holds everyone again")
	assert_false(state.round_state.is_live())
	assert_gt(state.round_state.hold, 2.0)
	var out := 0
	for c in state.characters:
		if not Elimination.is_in_play(c):
			out += 1
	assert_eq(out, 0, "everyone is back in play for the countdown")
