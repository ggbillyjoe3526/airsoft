extends GutTest
## QA for FG2 (bots play Attack / Defend): the half-time swap of roles, a retaker that loses sight of someone going back
## to the rope rather than chasing, a retaker walking back to its post once the flag is down, the raiser holding still at
## the rope in a fight, the retaker count at its edges, and Elimination untouched by the flag. On Depot, headless.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null
var sim: Simulation = null
var state: GameState = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []


func before_all() -> void:
	map = MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	level.free()


func _start(mode: RoundState.Mode = RoundState.Mode.ATTACK_DEFEND, cfg: BotConfig = config) -> void:
	sim = Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state = GameState.new(3, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	var size := tuning.rounds.team_size
	for i in size * 2:
		state.characters.append(Character.new(i, 0 if i < size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	if mode == RoundState.Mode.ATTACK_DEFEND:
		state.round_state.mode = mode
		state.round_state.pole = map.pole
	bots = BotController.new(state, -1, map, nav, level.query(), tuning, cfg)
	sim.start_match(state)
	bots.observe(state)


func _bot(id: int) -> Bot:
	for b in bots.world.bots:
		if b.character.id == id:
			return b
	return null


func test_the_roles_swap_with_the_attackers_at_half_time() -> void:
	_start()
	var w := bots.world
	state.round_state.attackers = 1
	for round in 20:
		bots._new_round(state)
		assert_eq(w.attackers, 1, "the planner reads the new attackers")
		assert_ne(w.planner.plans[0], RoundPlanner.Plan.STACK, "round %d: team 0 defends, never stacked" % round)
		for id: int in [0, 1, 2]:
			assert_eq(BotFlag.role(_bot(id), w), BotFlag.Role.DEFEND)
			assert_lte(_bot(id).lane_points, 2, "round %d: a defender holds point 1 or 2" % round)
		for id: int in [3, 4, 5]:
			var b := _bot(id)
			assert_eq(BotFlag.role(b, w), BotFlag.Role.ATTACK)
			assert_false(b.lane_done, "a fresh lane each round")
			assert_eq(b.lane_points, w.planner._points_to_middle(map.lanes[b.lane], 1, b.character.end),
					"round %d: attackers walk to the middle" % round)


func test_a_retaker_that_loses_sight_goes_back_to_the_rope_not_after_the_noise() -> void:
	_start()
	var w := bots.world
	var b := _bot(3)
	b.character.position = map.pole + Vector3(1.0, 0.0, 0.0)
	state.round_state.flag.progress = 0.5
	BotFlag.pick_retakers(w)
	assert_true(b.retake)
	b.mode = Bot.Mode.FIGHT
	b.has_last_known = true
	b.heard_at = w.time
	b.last_known = map.pole + Vector3(4.0, 0.0, 0.0)
	assert_true(b.threat_in_mind(w.time, config), "a fresh threat by the pole: it would search without the flag")
	BotBrain._choose_mode(b, w, null, DT)
	assert_eq(b.mode, Bot.Mode.FLAG, "the flag is up: back to the rope")
	assert_false(b.flag_guard, "a retaker goes to the rope, it doesn't guard")


func test_a_retaker_walks_back_to_its_post_once_the_flag_is_down_and_never_hunts() -> void:
	_start()
	var w := bots.world
	var b := _bot(4)
	var lane := map.lanes[b.lane]
	var last := (b.lane_points - 1) if b.lane_dir > 0 else lane.size() - b.lane_points
	b.lane_index = last
	b.character.position = map.pole + Vector3(0.5, 0.0, 0.0)
	b.retake = true
	b.retake_pole = 0
	state.round_state.flag.progress = 0.2
	BotBrain._choose_mode(b, w, null, DT)
	assert_eq(b.mode, Bot.Mode.FLAG)
	state.round_state.flag.progress = 0.0
	BotBrain._choose_mode(b, w, null, DT)
	assert_eq(b.mode, Bot.Mode.ADVANCE, "down again: back to its post")
	assert_true(BotMovement._next_goal(b, w), "its post is the next goal")
	assert_eq(b.lane_index, last, "the last point it holds, not one further")
	assert_false(BotMovement._next_goal(b, w), "and nothing after it")
	assert_false(b.hunting, "a defender never hunts")


func test_the_raiser_at_the_rope_fights_without_stepping_off_it() -> void:
	_start()
	var w := bots.world
	var raiser := _bot(0)
	var guard := _bot(1)
	var enemy := state.characters[3]
	enemy.position = map.pole + Vector3(8.0, 0.0, 0.0)
	raiser.character.position = map.pole + Vector3(0.4, 0.0, 0.0)
	guard.character.position = map.pole + Vector3(-0.4, 0.0, 0.0)
	raiser.raiser = true
	raiser.mode = Bot.Mode.FIGHT
	guard.mode = Bot.Mode.FIGHT
	var cmd := PlayerCommand.new()
	var guard_stepped := false
	for i in 240:
		w.time += DT
		cmd.reset(0.0, 0.0)
		assert_false(BotMovement.move(raiser, w, cmd, DT, enemy))
		assert_eq(Vector2(cmd.right, cmd.forward), Vector2.ZERO, "tick %d: the raiser stays on the rope" % i)
		cmd.reset(0.0, 0.0)
		BotMovement.move(guard, w, cmd, DT, enemy)
		guard_stepped = guard_stepped or cmd.right != 0.0 or cmd.forward != 0.0
	assert_true(guard_stepped, "control: a bot that isn't raising sidesteps in the same spot")


func test_no_retaker_with_none_set_and_every_defender_with_many() -> void:
	var none := config.duplicate() as BotConfig
	none.retakers = 0
	_start(RoundState.Mode.ATTACK_DEFEND, none)
	state.round_state.flag.progress = 0.5
	BotFlag.pick_retakers(bots.world)
	for id: int in [3, 4, 5]:
		assert_false(_bot(id).retake, "retakers 0: everyone holds")
		assert_false(BotFlag.wants_flag(_bot(id), bots.world))
	var many := config.duplicate() as BotConfig
	many.retakers = 99
	_start(RoundState.Mode.ATTACK_DEFEND, many)
	state.round_state.flag.progress = 0.5
	state.characters[5].status = Character.Status.OUT
	BotFlag.pick_retakers(bots.world)
	assert_true(_bot(3).retake and _bot(4).retake, "every defender in play")
	assert_false(_bot(5).retake, "never one that is out")
	for id: int in [0, 1, 2]:
		assert_false(_bot(id).retake, "never an attacker")


func test_elimination_never_sends_a_bot_to_the_pole() -> void:
	_start(RoundState.Mode.ELIMINATION)
	var w := bots.world
	state.round_state.flag.progress = 0.5
	for b in w.bots:
		b.lane_done = true
		b.character.position = map.pole
	for t in 120:
		state.time += DT
		bots.think(state, commands, DT)
		for b in w.bots:
			assert_ne(b.mode, Bot.Mode.FLAG, "tick %d: no flag mode in Elimination" % t)
			assert_false(b.raiser or b.retake, "tick %d: no flag jobs in Elimination" % t)
