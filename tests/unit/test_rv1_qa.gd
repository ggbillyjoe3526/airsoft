extends GutTest
## QA for route variety (RV1): lane crossings, shifts, pushed defenders and tempo on edge cases. The two-lane field of
## test_rv1_route_variety, plus a second map whose lanes differ in length.

const DT := 1.0 / 60.0
const KILL_Y := -10.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var map: MapData = null
var world: BoxWorld = null
var nav: NavGrid = null
var state: GameState = null
var bots: BotController = null
var sim: Simulation = null


func before_all() -> void:
	map = MapData.new()
	map.id = "qa field"
	map.kill_y = KILL_Y
	world = BoxWorld.new(tuning.body)
	world.add_floor(60.0, 30.0)
	map.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(60.0, 0.5, 30.0)))
	for e in 2:
		var x := -27.0 if e == 0 else 27.0
		var end := MapEnd.new()
		for z: float in [-3.0, -1.0, 1.0, 3.0]:
			end.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), -PI * 0.5 if e == 0 else PI * 0.5))
		for z: float in [12.0, 13.0, 14.0]:
			end.dead_zone.append(SpawnPoint.new(Vector3(-29.0 if e == 0 else 29.0, 0.0, z), 0.0))
		map.ends.append(end)
	# Three lanes of different lengths: 9 points, 4 points (the middle only), 2 points (only the far end).
	var long_lane := PackedVector3Array()
	var mid_lane := PackedVector3Array()
	var short_lane := PackedVector3Array()
	for i in 9:
		long_lane.append(Vector3(-24.0 + i * 6.0, 0.0, -6.0))
	for i in 4:
		mid_lane.append(Vector3(-9.0 + i * 6.0, 0.0, 0.0))
	for i in 2:
		short_lane.append(Vector3(18.0 + i * 5.0, 0.0, 6.0))
	map.lanes.append(long_lane)
	map.lanes.append(mid_lane)
	map.lanes.append(short_lane)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


func _start(cfg: BotConfig, seed_value: int = 5, mode: RoundState.Mode = RoundState.Mode.ELIMINATION) -> BotWorld:
	sim = Simulation.new(tuning, world, world.mover(), map.ends, KILL_Y)
	sim.nav = nav
	state = GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in 8:
		state.characters.append(Character.new(i, 0 if i < 4 else 1, Vector3.ZERO, 0.0, loadout))
	if mode == RoundState.Mode.ATTACK_DEFEND:
		state.round_state.mode = mode
		state.round_state.pole = Vector3(24.0, 0.0, 0.0)
	bots = BotController.new(state, -1, map, nav, world, tuning, cfg)
	sim.start_match(state)
	bots.observe(state)
	return bots.world


func _step(ticks: int) -> void:
	var commands: Array[PlayerCommand] = []
	for c in state.characters:
		commands.append(PlayerCommand.new())
	for t in ticks:
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)


## A lane state a bot may hold: -1 (not set off) or a point on its lane that it walks.
func _lane_state_ok(b: Bot, w: BotWorld) -> bool:
	if b.hunting or b.lane < 0:
		return true
	if b.lane >= w.lanes.size():
		return false
	var size := w.lanes[b.lane].size()
	if b.lane_index < -1 or b.lane_index >= size:
		return false
	if b.lane_index < 0:
		return true
	var walked := b.lane_index if b.lane_dir > 0 else size - 1 - b.lane_index
	return walked < maxi(b.lane_points, 1)


func test_a_match_with_every_bot_always_crossing_keeps_every_lane_state_valid() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_cross_chance = 1.0
	cfg.plan_stack_weight = 0.0
	cfg.lane_cross_reach = 30.0
	cfg.lane_cross_max = 5
	for seed_value: int in [1, 2, 3]:
		var w := _start(cfg, seed_value)
		for t in 60:
			_step(30)
			for b in w.bots:
				assert_true(_lane_state_ok(b, w), "seed %d bot %d lane %d index %d points %d" % [
						seed_value, b.character.id, b.lane, b.lane_index, b.lane_points])
				assert_lte(b.lanes_crossed, cfg.lane_cross_max)


func test_after_a_cross_resuming_from_a_fight_stays_on_the_new_lane_and_its_points() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_cross_chance = 1.0
	cfg.plan_stack_weight = 0.0
	cfg.lane_cross_reach = 30.0
	cfg.lane_shift = 0.0
	var w := _start(cfg)
	var checked := 0
	for b in w.bots:
		b.lane = 0
		b.lane_dir = 1 if b.character.end == 0 else -1
		b.lane_points = map.lanes[0].size()
		b.lane_index = 3 if b.lane_dir > 0 else map.lanes[0].size() - 4
		b.lanes_crossed = 0
		b.hunting = false
		if not BotMovement._next_goal(b, w) or b.lane == 0:
			continue
		checked += 1
		var at := BotMovement.resume_point(b, w)
		var size := w.lanes[b.lane].size()
		assert_true(at >= 0 and at < size, "a resume point on the new lane")
		var walked := at if b.lane_dir > 0 else size - 1 - at
		assert_lt(walked, b.lane_points, "within the points it walks there")
	assert_gt(checked, 0, "some bot crossed")


func test_a_bot_never_crosses_when_there_is_only_one_lane_or_no_point_in_reach() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_cross_chance = 1.0
	cfg.plan_stack_weight = 0.0
	cfg.lane_cross_reach = 0.5
	var w := _start(cfg)
	var b := w.bots[0]
	b.lane = 0
	b.lane_dir = 1 if b.character.end == 0 else -1
	b.lane_points = map.lanes[0].size()
	b.lanes_crossed = 0
	assert_false(BotMovement._cross_lane(b, w, 4 if b.lane_dir > 0 else 3), "nothing within 0.5 m")
	assert_eq(b.lane, 0)
	assert_eq(b.lanes_crossed, 0)
	var saved := w.lanes.duplicate()
	w.lanes.resize(1)
	cfg.lane_cross_reach = 100.0
	assert_false(BotMovement._cross_lane(b, w, 4 if b.lane_dir > 0 else 3), "one lane: nowhere to cross")
	w.lanes.assign(saved)


func test_a_cross_never_lands_on_a_point_the_bot_would_not_walk_on_that_lane() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_cross_chance = 1.0
	cfg.plan_stack_weight = 0.0
	cfg.lane_cross_reach = 40.0
	var w := _start(cfg, 5, RoundState.Mode.ATTACK_DEFEND)
	for b in w.bots:
		if BotFlag.role(b, w) != BotFlag.Role.ATTACK:
			continue
		for from_index in range(1, 8):
			b.lane = 0
			b.lane_dir = 1 if b.character.end == 0 else -1
			b.lane_points = w.planner.walk_points(b, 0, w)
			b.lanes_crossed = 0
			var next := from_index if b.lane_dir > 0 else map.lanes[0].size() - 1 - from_index
			if BotMovement._cross_lane(b, w, next):
				var size := w.lanes[b.lane].size()
				var walked := b.lane_index if b.lane_dir > 0 else size - 1 - b.lane_index
				assert_lt(walked, b.lane_points, "attacker %d from %d: a point it walks" % [b.character.id, from_index])
				assert_eq(b.lane_points, w.planner.walk_points(b, b.lane, w))


func test_a_bomb_carrier_never_crosses_even_with_certain_chance() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_cross_chance = 1.0
	cfg.plan_stack_weight = 0.0
	cfg.lane_cross_reach = 40.0
	var w := _start(cfg)
	var b := w.bots[0]
	b.lane = 0
	b.lane_dir = 1 if b.character.end == 0 else -1
	b.lane_points = map.lanes[0].size()
	b.raiser = true
	assert_false(BotMovement._cross_lane(b, w, 4 if b.lane_dir > 0 else 3))


func test_a_huge_shift_never_leaves_the_field_or_the_floor() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_shift = 500.0
	var w := _start(cfg)
	for b in w.bots:
		b.lane_shift = 500.0
		for lane in map.lanes:
			for p in lane:
				var to := BotMovement._shifted(b, w, p)
				assert_true(absf(to.x) <= 30.0 and absf(to.z) <= 15.0, "inside the field")
				assert_almost_eq(to.y, p.y, tuning.body.max_step)


func test_a_pushed_defender_never_holds_past_the_end_of_its_lane_even_with_the_whole_share() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.defend_push_chance = 1.0
	cfg.defend_push_share = 1.0
	for seed_value: int in [1, 2, 3, 4]:
		var w := _start(cfg, seed_value, RoundState.Mode.ATTACK_DEFEND)
		for b in w.bots:
			if b.lane >= 0:
				assert_lte(b.lane_points, w.lanes[b.lane].size(), "seed %d bot %d" % [seed_value, b.character.id])


func test_zero_tempo_pace_and_zero_weights_never_stall_a_plan() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.tempo_quick_weight = 0.0
	cfg.tempo_steady_weight = 0.0
	cfg.tempo_slow_weight = 0.0
	cfg.tempo_quick_pace = 0.0
	cfg.own_half_pace = 0.0
	var w := _start(cfg)
	for b in w.bots:
		assert_eq(b.pace, 1.0)
	cfg.tempo_steady_weight = 0.0
	cfg.tempo_quick_weight = 1.0
	w = _start(cfg)
	_step(600)
	var moved := 0
	for i in state.characters.size():
		if state.characters[i].position.distance_to(Vector3(-27.0 if i < 4 else 27.0, 0.0, 0.0)) > 5.0:
			moved += 1
	assert_gt(moved, 0, "bots still walk with a zero pace")


func test_a_planner_with_no_lanes_still_plans_with_variety_on() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.defend_push_chance = 1.0
	var saved := map.lanes.duplicate()
	map.lanes.clear()
	var w := _start(cfg, 5, RoundState.Mode.ATTACK_DEFEND)
	for b in w.bots:
		assert_eq(b.lane, -1)
	map.lanes.assign(saved)


func test_the_same_seed_plays_the_same_match_with_variety_on() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_cross_chance = 0.5
	cfg.plan_stack_weight = 0.0
	var end: Array[Array] = []
	for run in 2:
		_start(cfg, 9)
		_step(1500)
		var out: Array = []
		for c in state.characters:
			out.append(c.position)
			out.append(c.status)
		end.append(out)
	assert_eq(end[0], end[1], "same seed, same positions")
	assert_ne(Seeds.variety_seed(9), Seeds.variety_seed(10))


func test_attackers_that_crossed_still_finish_their_lane_in_attack_and_defend() -> void:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_cross_chance = 1.0
	cfg.lane_cross_reach = 30.0
	var w := _start(cfg, 4, RoundState.Mode.ATTACK_DEFEND)
	# Crossing is off for a stacked team (RV1); here every team may cross.
	w.planner.plans[0] = RoundPlanner.Plan.SPLIT
	w.planner.plans[1] = RoundPlanner.Plan.SPLIT
	var commands: Array[PlayerCommand] = []
	for c in state.characters:
		commands.append(PlayerCommand.new())
	# Through the first round only (the next one starts every lane afresh): an attacker that crossed walks on to its
	# lane's end (lane_done), hunts, or leaves its advance for a fight (or is hit), never stopping on the new lane for
	# good.
	var crossed := 0
	var finished := 0
	var seen: Dictionary[int, bool] = {}
	for t in 60 * 60:
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		if state.events.count_of(GameEvent.Kind.ROUND_OVER) > 0:
			break
		for b in w.bots:
			if BotFlag.role(b, w) != BotFlag.Role.ATTACK or b.lanes_crossed == 0 or seen.has(b.character.id):
				continue
			if not seen.has(-1 - b.character.id):
				seen[-1 - b.character.id] = true
				crossed += 1
			if b.lane_done or b.hunting or b.mode != Bot.Mode.ADVANCE or not Elimination.is_in_play(b.character):
				seen[b.character.id] = true
				finished += 1
	assert_gt(crossed, 0, "attackers crossed lanes")
	assert_eq(finished, crossed, "every attacker that crossed went on past its new lane")
