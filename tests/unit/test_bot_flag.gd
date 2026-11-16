extends GutTest
## Bots in Attack / Defend (FG2; the browser game's ai.test.ts › in Attack / Defend and botTactics.test.ts flag cases):
## defenders hold their first or second lane point and go after only what is near the pole, the two nearest pull a
## raised flag down, attackers walk to the middle then make for the pole, one raises while the others guard from cover,
## and Elimination is untouched. On Depot, headless (game/ai/bot_flag.gd, round_planner.gd, bot_movement.gd,
## bot_brain.gd, bot_controller.gd).

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
	map = YardMap.load_map(MapStyle.new(), tuning.rounds.team_size)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	level.free()


## A match on Depot, every character a bot at Normal and none with a personality, in `mode` (team 0 attacks first),
## played to its first round's plan with `cfg`. `player`: that character is nobody's bot.
func _start(mode: RoundState.Mode = RoundState.Mode.ATTACK_DEFEND, cfg: BotConfig = config, seed_value: int = 3,
		player: int = -1) -> void:
	sim = Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state = GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	var size := tuning.rounds.team_size
	for i in size * 2:
		state.characters.append(Character.new(i, 0 if i < size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	if mode == RoundState.Mode.ATTACK_DEFEND:
		state.round_state.mode = mode
		state.round_state.pole = map.pole
	bots = BotController.new(state, player, map, nav, level.query(), tuning, cfg)
	sim.start_match(state)
	bots.observe(state)


func _bot(id: int) -> Bot:
	for b in bots.world.bots:
		if b.character.id == id:
			return b
	return null


## A fresh plan for every bot, as at a round's start.
func _replan() -> void:
	bots._new_round(state)


func _to_pole(c: Character) -> float:
	return Vector2(c.position.x - map.pole.x, c.position.z - map.pole.z).length()


func test_bots_read_the_round_attackers_and_flag_and_the_roles_follow() -> void:
	_start()
	var w := bots.world
	assert_eq(w.mode, RoundState.Mode.ATTACK_DEFEND)
	assert_eq(w.attackers, 0, "team 0 attacks first")
	assert_same(w.flag, state.round_state.flag, "the round's own flag, read only")
	assert_eq(BotFlag.role(_bot(0), w), BotFlag.Role.ATTACK)
	assert_eq(BotFlag.role(_bot(3), w), BotFlag.Role.DEFEND)
	assert_true(BotFlag.holds_post(_bot(3), w))
	assert_false(BotFlag.holds_post(_bot(0), w))
	_start(RoundState.Mode.ELIMINATION)
	assert_eq(bots.world.attackers, -1)
	assert_eq(BotFlag.role(_bot(0), bots.world), BotFlag.Role.NONE)
	assert_false(BotFlag.wants_flag(_bot(0), bots.world))


func test_defenders_hold_their_first_or_second_point_never_all_on_one_lane() -> void:
	_start()
	var holds := {}
	for round in 40:
		_replan()
		assert_ne(bots.world.planner.plans[1], RoundPlanner.Plan.STACK, "round %d: defenders never stack" % round)
		var lanes := {}
		for id: int in [3, 4, 5]:
			var b := _bot(id)
			assert_true(b.lane_points == 1 or b.lane_points == 2, "round %d: a defender holds point 1 or 2" % round)
			holds[b.lane_points] = true
			lanes[b.lane] = true
		assert_gt(lanes.size(), 1, "round %d: not all on one lane" % round)
	assert_eq(holds.size(), 2, "both the first and the second point held over the rounds")


func test_attackers_walk_to_the_first_point_past_the_middle_then_want_the_pole() -> void:
	_start()
	var w := bots.world
	for round in 10:
		_replan()
		for id: int in [0, 1, 2]:
			var b := _bot(id)
			var lane := map.lanes[b.lane]
			assert_eq(b.lane_points, w.planner._points_to_middle(lane, 0, b.character.end))
			assert_lt(b.lane_points, lane.size(), "Depot's lanes run past the middle")
	var b := _bot(0)
	var lane := map.lanes[b.lane]
	b.lane_index = (b.lane_points - 1) if b.lane_dir > 0 else lane.size() - b.lane_points
	b.hold_left = 0.0
	b.wait_for_team = false
	b.route_state = Bot.RouteState.NONE
	var cmd := PlayerCommand.new()
	BotMovement.move(b, w, cmd, DT, null)
	assert_true(b.lane_done, "its lane walked")
	assert_false(b.hunting, "an attacker never hunts")
	BotBrain._choose_mode(b, w, null, DT)
	assert_eq(b.mode, Bot.Mode.FLAG)


func test_defenders_stop_at_their_point_and_never_hunt() -> void:
	_start()
	var w := bots.world
	var cmd := PlayerCommand.new()
	for id: int in [3, 4, 5]:
		var b := _bot(id)
		var lane := map.lanes[b.lane]
		b.lane_index = (b.lane_points - 1) if b.lane_dir > 0 else lane.size() - b.lane_points
		b.lane_goal = lane[b.lane_index]
		b.character.position = b.lane_goal
		b.hold_left = 0.0
		b.wait_for_team = false
		b.route_state = Bot.RouteState.NONE
		b.route.clear()
		for i in 30:
			w.time += DT
			BotMovement.move(b, w, cmd, DT, null)
			assert_false(b.hunting, "defender %d tick %d: no hunt" % [id, i])
			assert_ne(b.route_state, Bot.RouteState.WANTED, "defender %d tick %d: no goal" % [id, i])
		assert_true(b.holding, "defender %d holds" % id)
		assert_true(b.at_post)
		assert_lt(_to_pole(b.character), 20.0, "within reach of the pole")


func test_the_two_defenders_nearest_pull_the_flag_down_and_the_third_holds() -> void:
	_start()
	var w := bots.world
	var near := _bot(3)
	var mid := _bot(4)
	var far := _bot(5)
	for pair: Array in [[near, 1.0], [mid, 3.0], [far, 9.0]]:
		var b: Bot = pair[0]
		b.character.position = map.pole + Vector3(pair[1] as float, 0.0, 0.0)
		b.mode = Bot.Mode.ADVANCE
	BotFlag.pick_retakers(w)
	assert_true(near.retake and mid.retake and not far.retake, "the two nearest")
	for b: Bot in [near, mid, far]:
		BotBrain._choose_mode(b, w, null, DT)
		assert_eq(b.mode, Bot.Mode.ADVANCE, "the flag at the bottom: everyone holds")
	state.round_state.flag.progress = 0.3
	for b: Bot in [near, mid, far]:
		BotBrain._choose_mode(b, w, null, DT)
	assert_eq(near.mode, Bot.Mode.FLAG)
	assert_eq(mid.mode, Bot.Mode.FLAG)
	assert_eq(far.mode, Bot.Mode.ADVANCE, "the third holds its post")
	for b: Bot in [near, mid]:
		assert_lte(Vector2(b.flag_goal.x - map.pole.x, b.flag_goal.z - map.pole.z).length(), config.flag_stand + 1e-4)
	assert_lt(config.flag_stand + config.flag_arrive, tuning.flag.radius, "a spot by the pole reaches the rope")
	near.character.status = Character.Status.OUT
	BotFlag.pick_retakers(w)
	BotBrain._choose_mode(far, w, null, DT)
	assert_eq(far.mode, Bot.Mode.FLAG, "one hit: the next nearest takes over")
	state.round_state.flag.progress = 0.0
	for b: Bot in [mid, far]:
		BotBrain._choose_mode(b, w, null, DT)
		assert_eq(b.mode, Bot.Mode.ADVANCE, "down again: back to their posts")


func test_one_attacker_raises_and_the_others_guard_from_cover() -> void:
	_start()
	var w := bots.world
	var a: Array[Bot] = [_bot(0), _bot(1), _bot(2)]
	for i in 3:
		var b := a[i]
		b.character.position = map.pole + Vector3(-2.0 - 3.0 * i, 0.0, 0.0)
		b.lane_done = true
	BotFlag.pick_raiser(w)
	assert_true(a[0].raiser, "the nearest raises")
	assert_false(a[1].raiser or a[2].raiser, "one raiser: a second adds nothing")
	for b in a:
		BotBrain._choose_mode(b, w, null, DT)
		assert_eq(b.mode, Bot.Mode.FLAG)
	assert_false(a[0].flag_guard)
	assert_true(a[1].flag_guard and a[2].flag_guard, "the others guard")
	for b: Bot in [a[1], a[2]]:
		assert_lte(Vector2(b.flag_goal.x - map.pole.x, b.flag_goal.z - map.pole.z).length(),
				config.flag_guard_radius + config.lane_jitter + 1e-4, "a guard spot by the pole")
	assert_ne(a[1].flag_goal, a[2].flag_goal, "not on one spot")
	# Someone nearer, but the raiser keeps the rope inside raiser_switch_margin.
	a[1].character.position = map.pole + Vector3(-2.0 + config.raiser_switch_margin * 0.5, 0.0, 0.0)
	BotFlag.pick_raiser(w)
	assert_true(a[0].raiser, "kept inside the margin")
	a[0].character.status = Character.Status.OUT
	BotFlag.pick_raiser(w)
	assert_true(a[1].raiser, "the raiser hit: the rope handed on")
	var cmd := PlayerCommand.new()
	BotMovement.move(a[1], w, cmd, DT, null)
	assert_false(a[1].flag_guard, "the new raiser goes to the rope")


func test_the_raiser_crouches_at_its_spot_and_stays() -> void:
	_start()
	var w := bots.world
	var b := _bot(0)
	b.lane_done = true
	BotFlag.pick_raiser(w)
	BotBrain._choose_mode(b, w, null, DT)
	assert_eq(b.mode, Bot.Mode.FLAG)
	b.character.position = b.flag_goal
	var cmd := PlayerCommand.new()
	for i in 60:
		w.time += DT
		cmd.reset(0.0, 0.0)
		assert_false(BotMovement.move(b, w, cmd, DT, null), "tick %d: stands" % i)
		assert_true(cmd.crouch, "tick %d: crouched at the rope" % i)
		assert_eq(b.route_state, Bot.RouteState.NONE, "tick %d: no route searches" % i)
	assert_true(Flag.at_pole(b.character, w.flag, tuning.flag))


func test_a_raiser_with_no_route_tries_the_pole_foot_then_tries_again() -> void:
	_start()
	var w := bots.world
	var b := _bot(0)
	b.lane_done = true
	b.raiser = true
	BotMovement.enter_flag(b, w)
	b.flag_goal = map.pole + Vector3(0.5, 0.0, 0.0)
	b.route_state = Bot.RouteState.FAILED
	b.route_retry_at = w.time + config.route_retry_delay
	var cmd := PlayerCommand.new()
	BotMovement.move(b, w, cmd, DT, null)
	assert_eq(Vector2(b.flag_goal.x, b.flag_goal.z), Vector2(map.pole.x, map.pole.z), "the pole's foot")
	assert_eq(b.route_state, Bot.RouteState.WANTED)
	b.route_state = Bot.RouteState.FAILED
	BotMovement.move(b, w, cmd, DT, null)
	assert_eq(b.route_state, Bot.RouteState.FAILED, "waits out the retry delay")
	w.time = b.route_retry_at
	BotMovement.move(b, w, cmd, DT, null)
	assert_eq(b.route_state, Bot.RouteState.WANTED, "then asks again")


func test_no_bot_raises_while_the_player_attacking_is_at_the_pole() -> void:
	_start(RoundState.Mode.ATTACK_DEFEND, config, 3, 0)
	var w := bots.world
	var b := _bot(1)
	b.lane_done = true
	b.character.position = map.pole + Vector3(-3.0, 0.0, 0.0)
	state.characters[0].position = map.pole
	BotFlag.pick_raiser(w)
	assert_false(b.raiser, "you work the rope: it guards")
	state.characters[0].position = map.pole + Vector3(-10.0, 0.0, 0.0)
	BotFlag.pick_raiser(w)
	assert_true(b.raiser)


func test_defenders_go_after_noise_near_the_pole_and_watch_far_noise_from_their_post() -> void:
	_start()
	var w := bots.world
	var b := _bot(3)
	b.mode = Bot.Mode.ADVANCE
	b.has_last_known = true
	b.heard_at = w.time
	b.last_known = map.pole + Vector3(-(config.defend_search_radius + 4.0), 0.0, 0.0)
	BotBrain._choose_mode(b, w, null, DT)
	assert_eq(b.mode, Bot.Mode.ADVANCE, "far off: it holds")
	assert_true(b.has_last_known, "watching that way")
	b.last_known = map.pole + Vector3(-(config.defend_search_radius - 3.0), 0.0, 0.0)
	BotBrain._choose_mode(b, w, null, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH, "near the pole: it goes")
	b.mode = Bot.Mode.ADVANCE
	b.heard_at = w.time - config.memory_time - 1.0
	BotBrain._choose_mode(b, w, null, DT)
	assert_false(b.has_last_known, "old news forgotten at its post")


func test_no_late_push_in_attack_defend_and_flag_spots_kept_off_in_cover_searches() -> void:
	_start()
	var w := bots.world
	var b := _bot(3)
	b.skill = config.skill_for(&"hard")
	for id: int in [4, 5]:
		state.characters[id].status = Character.Status.OUT
	w.live = true
	w.round_clock = 1.0
	assert_false(w.pushing_late(b), "the defenders hold the pole to the end")
	var raiser := _bot(0)
	raiser.mode = Bot.Mode.FLAG
	raiser.flag_goal = map.pole + Vector3(0.3, 0.0, 0.2)
	var n := BotRoutes.teammate_spots(_bot(1), w)
	var found := false
	for i in n:
		found = found or BotRoutes.taken()[i] == raiser.flag_goal
	assert_true(found, "a teammate's flag spot is taken")


func test_bots_play_attack_defend_allocating_nothing_once_warm() -> void:
	_start()
	state.round_state.flag.progress = 0.4
	for id: int in [0, 1, 2]:
		_bot(id).lane_done = true
	var before := 0
	for t in 360:
		if t == 240:
			before = Performance.get_monitor(Performance.OBJECT_COUNT)
		state.time += DT
		bots.think(state, commands, DT)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
	var modes := {}
	for b in bots.world.bots:
		modes[b.mode] = true
	assert_true(modes.has(Bot.Mode.FLAG), "the pole was worked throughout")


func test_an_anchor_holds_by_the_pole_on_defence_and_goes_for_it_on_attack() -> void:
	_start()
	var w := bots.world
	var file := BotsFile.read_file()
	for id: int in [0, 3]:
		_bot(id).style = file.style(&"anchor")
	w.round_clock = file.style(&"anchor").hold_until + 1.0
	for round in 10:
		_replan()
		var defender := _bot(3)
		assert_true(defender.lane_points == 1 or defender.lane_points == 2, "round %d: a defender's point" % round)
		assert_true(BotFlag.holds_post(defender, w))
		var attacker := _bot(0)
		assert_eq(attacker.lane_points, w.planner._points_to_middle(map.lanes[attacker.lane], 0, attacker.character.end),
				"round %d: no short lane on attack" % round)
		assert_false(BotPersonality.anchor_holding(attacker, w), "its hold is Elimination's")


func test_a_defender_holds_from_cover_by_its_last_point_but_only_pauses_in_cover_on_the_way() -> void:
	_start()
	var w := bots.world
	var b := _bot(3)
	var lane := map.lanes[b.lane]
	b.lane_points = 2
	b.lane_index = 0 if b.lane_dir > 0 else lane.size() - 1
	b.character.position = lane[b.lane_index]
	b.hold_left = 0.0
	b.wait_for_team = false
	b.hold_cover = true
	b.route_state = Bot.RouteState.NONE
	b.route.clear()
	var cmd := PlayerCommand.new()
	BotMovement.move(b, w, cmd, DT, null)
	assert_gt(b.hold_left, 0.0, "the first of two points: a pause in the cover, then on")
	b.lane_index += b.lane_dir
	b.hold_left = 0.0
	b.wait_for_team = false
	b.hold_cover = true
	b.post_cover = true
	b.route_state = Bot.RouteState.NONE
	BotMovement.move(b, w, cmd, DT, null)
	assert_eq(b.hold_left, 0.0, "its post: no pause, it stays")
	assert_ne(b.route_state, Bot.RouteState.WANTED, "and goes nowhere")


## The Beta 1 pass: a defender dealt two lane points that stepped into cover by the first (as the real flow leaves it:
## _next_goal has already named the second point by then) stopped there for good, one point short of its post.
func test_a_defender_that_takes_cover_by_a_point_on_the_way_still_goes_on_to_its_post() -> void:
	# BP9: a defender with two or more lane points that stepped into cover by a point on the way stayed there for good,
	# one point short of its post (the lane's index already named the next point, so it read as "at my last point").
	var found := 0
	for seed_value in range(3, 6):
		_start(RoundState.Mode.ATTACK_DEFEND, config, seed_value)
		var w := bots.world
		var size := tuning.rounds.team_size
		var b: Bot = null
		for id in range(size, size * 2):
			var o := _bot(id)
			if o != null and BotFlag.role(o, w) == BotFlag.Role.DEFEND:
				b = o
				break
		if b == null:
			continue
		# Sure to look for cover by a point, and alone on its lane (two that play as a team hold a crossfire instead).
		b.skill = b.skill.duplicate() as BotSkill
		b.skill.hold_cover_chance = 1.0
		b.skill.team_play = false
		for lane_id in map.lanes.size():
			var lane := map.lanes[lane_id]
			for at in lane.size():
				var next := at + b.lane_dir
				if next < 0 or next >= lane.size():
					continue
				# Just arrived at point `at`, the walk there done, the point after it its last (its post).
				b.mode = Bot.Mode.ADVANCE
				b.hunting = false
				b.lane = lane_id
				b.lane_points = (next if b.lane_dir > 0 else lane.size() - 1 - next) + 1
				b.lane_index = at
				b.character.position = lane[at]
				b.hold_left = 0.0
				b.wait_for_team = false
				b.hold_cover = false
				b.post_cover = false
				b.route_state = Bot.RouteState.NONE
				b.route.clear()
				b.route.append(lane[at])
				var cmd := PlayerCommand.new()
				BotMovement.move(b, w, cmd, DT, null)
				if not b.hold_cover:
					continue
				found += 1
				var where := "seed %d lane %d point %d" % [seed_value, lane_id, at]
				assert_eq(b.lane_index, next, "%s: the point after is already named" % where)
				assert_false(b.post_cover, "%s: cover on the way, not its post's" % where)
				# In the cover it picked, the walk there done.
				b.character.position = b.hold_spot.position
				b.route_state = Bot.RouteState.NONE
				b.route.clear()
				b.route.append(b.hold_spot.position)
				BotMovement.move(b, w, cmd, DT, null)
				assert_false(b.hold_cover, "%s: the step into cover is over" % where)
				assert_gt(b.hold_left, 0.0, "%s: a pause in the cover on the way" % where)
				assert_eq(b.route_state, Bot.RouteState.WANTED, "%s: then on to its post" % where)
				assert_eq(b.route_goal, b.lane_goal, "%s: the lane's point after it" % where)
	assert_gt(found, 0, "a defender found cover by a lane point on some seed (else this test proves nothing)")
