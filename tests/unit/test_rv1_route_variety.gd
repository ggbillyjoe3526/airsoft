extends GutTest
## Route variety (RV1, owner 2026-11-15: bots "too predictable, the same routes each time"): each round a team draws a
## tempo that scales its pauses, pauses in a bot's own half are shorter, each bot that walks its lane walks it shifted
## to one side, may cross onto another lane once a round, and in Attack / Defend one defender may hold well up its
## lane. All on a stream of its own, so the team plans don't move. On a flat 60 by 30 m field with two lanes, headless
## (game/ai/round_planner.gd, game/ai/bot_movement.gd).

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
	map.id = "variety field"
	map.kill_y = KILL_Y
	world = BoxWorld.new(tuning.body)
	world.add_floor(60.0, 30.0)
	map.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(60.0, 0.5, 30.0)))
	# A wall along z = 9.5 for most of the field: a lane at z = 8 can't shift through it.
	map.blocks.append(_block(&"wall", Vector3(0.0, 1.5, 9.5), Vector3(40.0, 3.0, 0.4)))
	world.add_box(Vector3(0.0, 1.5, 9.5), Vector3(40.0, 3.0, 0.4))
	for e in 2:
		var x := -27.0 if e == 0 else 27.0
		var end := MapEnd.new()
		for z: float in [-3.0, -1.0, 1.0, 3.0]:
			end.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), -PI * 0.5 if e == 0 else PI * 0.5))
		for z: float in [12.0, 13.0, 14.0]:
			end.dead_zone.append(SpawnPoint.new(Vector3(-29.0 if e == 0 else 29.0, 0.0, z), 0.0))
		map.ends.append(end)
	# Lane 0 down the south side, lane 1 along the north wall; both cross the middle.
	var south := PackedVector3Array()
	var north := PackedVector3Array()
	for i in 9:
		var x := -24.0 + i * 6.0
		south.append(Vector3(x, 0.0, -4.0))
		north.append(Vector3(x, 0.0, 4.0))
	map.lanes.append(south)
	map.lanes.append(north)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## A fresh match seeded `seed_value` in `mode` (team 0 attacks first), every bot on `cfg`.
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


func _quiet(cfg: BotConfig) -> BotConfig:
	var out: BotConfig = cfg.duplicate()
	out.lane_jitter = 0.0
	out.tempo_quick_weight = 0.0
	out.tempo_slow_weight = 0.0
	out.lane_shift = 0.0
	out.lane_cross_chance = 0.0
	out.defend_push_chance = 0.0
	out.own_half_pace = 1.0
	return out


func _bot(id: int) -> Bot:
	for b in bots.world.bots:
		if b.character.id == id:
			return b
	return null


func test_variety_never_moves_the_team_plans() -> void:
	for seed_value: int in [1, 2, 3, 7, 11]:
		var w := _start(_quiet(config), seed_value)
		var plans := w.planner.plans.duplicate()
		var lanes: Array[int] = []
		for b in w.bots:
			lanes.append(b.lane)
		w = _start(config, seed_value)
		assert_eq(w.planner.plans, plans, "seed %d: the same plans" % seed_value)
		for i in w.bots.size():
			assert_eq(w.bots[i].lane, lanes[i], "seed %d: the same lanes" % seed_value)
	assert_ne(Seeds.variety_seed(5), Seeds.plan_seed(5), "a stream of its own")


func test_each_team_draws_a_tempo_by_its_weights_and_its_bots_take_its_pace() -> void:
	var counts := [0, 0, 0]
	var planner := RoundPlanner.new(9)
	for i in 3000:
		counts[planner._pick_tempo(config)] += 1
	var total := config.tempo_quick_weight + config.tempo_steady_weight + config.tempo_slow_weight
	assert_almost_eq(counts[RoundPlanner.Tempo.QUICK] / 3000.0, config.tempo_quick_weight / total, 0.04)
	assert_almost_eq(counts[RoundPlanner.Tempo.SLOW] / 3000.0, config.tempo_slow_weight / total, 0.04)
	var all_quick: BotConfig = config.duplicate()
	all_quick.tempo_steady_weight = 0.0
	all_quick.tempo_slow_weight = 0.0
	var w := _start(all_quick)
	for b in w.bots:
		assert_eq(w.planner.tempos[b.character.team], RoundPlanner.Tempo.QUICK)
		assert_almost_eq(b.pace, all_quick.tempo_quick_pace, 1e-9, "the team's pace")
	var none: BotConfig = config.duplicate()
	none.tempo_quick_weight = 0.0
	none.tempo_steady_weight = 0.0
	none.tempo_slow_weight = 0.0
	assert_eq(planner._pick_tempo(none), RoundPlanner.Tempo.STEADY, "no weights: steady")


func test_a_pause_is_scaled_by_the_pace_and_shorter_in_its_own_half() -> void:
	var cfg := _quiet(config)
	cfg.own_half_pace = 0.5
	var w := _start(cfg)
	var b := _bot(0)
	b.skill = b.skill.duplicate()
	b.skill.hold_time = Vector2(2.0, 2.0)
	b.pace = 0.8
	var home := w.planner.spawn_centre[b.character.team]
	var way := w.planner.attack_dir[b.character.team]
	b.character.position = home + Vector3(way.x, 0.0, way.y) * 10.0
	BotMovement._start_hold(b, w)
	assert_almost_eq(b.hold_left, 2.0 * 0.8 * 0.5, 1e-6, "own half: pace times own_half_pace")
	b.character.position = home + Vector3(way.x, 0.0, way.y) * 40.0
	BotMovement._start_hold(b, w)
	assert_almost_eq(b.hold_left, 2.0 * 0.8, 1e-6, "enemy half: the pace alone")


func test_a_shifted_lane_moves_across_the_way_to_the_enemy_unless_a_wall_is_in_the_way() -> void:
	var cfg := _quiet(config)
	var w := _start(cfg)
	var b := _bot(0)
	b.lane_shift = 2.0
	var way := w.planner.attack_dir[b.character.team]
	var p := Vector3(-12.0, 0.0, -4.0)
	var to := BotMovement._shifted(b, w, p)
	assert_almost_eq(to.distance_to(p), 2.0, 1e-3, "the whole shift")
	assert_almost_eq(Vector2(to.x - p.x, to.z - p.z).dot(way), 0.0, 1e-3, "square to the way to the enemy")
	# Lane 1 runs 1.5 m short of the wall: a 3 m shift towards it is cut to half (1.5 m lands on the wall's face, so
	# the point stays), away from it is whole.
	var by_wall := Vector3(-12.0, 0.0, 8.0)
	b.lane_shift = 3.0
	var side := BotMovement._shifted(b, w, by_wall)
	b.lane_shift = -3.0
	var other := BotMovement._shifted(b, w, by_wall)
	var north := side if side.z > other.z else other
	var south := other if side.z > other.z else side
	assert_lt(north.z, 9.5 - 0.2, "never into or past the wall")
	assert_almost_eq(south.distance_to(by_wall), 3.0, 1e-3, "away from the wall: the whole shift")
	b.lane_shift = 0.0
	assert_eq(BotMovement._shifted(b, w, p), p, "no shift: the point itself")


func test_setting_off_a_bot_may_cross_once_onto_the_other_lane_never_back_towards_home() -> void:
	var cfg := _quiet(config)
	cfg.lane_cross_chance = 1.0
	cfg.lane_cross_reach = 10.0
	var w := _start(cfg)
	var b := _bot(0)
	b.lane = 0
	b.lane_dir = 1 if b.character.end == 0 else -1
	b.lane_points = map.lanes[0].size()
	b.lane_index = 2 if b.lane_dir > 0 else map.lanes[0].size() - 3
	b.hunting = false
	b.lanes_crossed = 0
	var from := map.lanes[0][b.lane_index + b.lane_dir]
	assert_true(BotMovement._next_goal(b, w))
	assert_eq(b.lane, 1, "onto the other lane")
	assert_eq(b.lanes_crossed, 1)
	var way := w.planner.attack_dir[b.character.team]
	var home := w.planner.spawn_centre[b.character.team]
	var now := map.lanes[1][b.lane_index]
	assert_gte(Vector2(now.x - home.x, now.z - home.z).dot(way), Vector2(from.x - home.x, from.z - home.z).dot(way)
			- 1e-3, "no nearer home than the point it set off for")
	assert_lte(Vector2(now.x - from.x, now.z - from.z).length(), cfg.lane_cross_reach)
	assert_eq(b.lane_goal, now, "making for that point")
	# Once a round (lane_cross_max 1): the next point is on the same lane.
	assert_true(BotMovement._next_goal(b, w))
	assert_eq(b.lane, 1, "crossed once only")


func test_a_defender_or_a_bot_under_an_order_never_crosses() -> void:
	var cfg := _quiet(config)
	cfg.lane_cross_chance = 1.0
	var w := _start(cfg, 5, RoundState.Mode.ATTACK_DEFEND)
	for b in w.bots:
		b.lane = 0
		b.lane_dir = 1 if b.character.end == 0 else -1
		b.lane_points = map.lanes[0].size()
		b.lane_index = 2 if b.lane_dir > 0 else map.lanes[0].size() - 3
		b.lanes_crossed = 0
		var crossed := BotMovement._cross_lane(b, w, b.lane_index + b.lane_dir)
		if BotFlag.role(b, w) == BotFlag.Role.DEFEND:
			assert_false(crossed, "a defender holds its lane")
		else:
			assert_true(crossed, "an attacker may cross")
	var o := _bot(0)
	o.lane = 0
	o.lanes_crossed = 0
	o.order = SquadOrder.Kind.HOLD
	assert_false(BotMovement._cross_lane(o, w, 3 if o.lane_dir > 0 else 5), "a bot under an order goes its own way")


func test_a_pushed_defender_holds_further_up_its_lane_and_defenders_never_shift() -> void:
	var cfg := _quiet(config)
	cfg.lane_shift = 2.0
	var plain := _start(cfg, 5, RoundState.Mode.ATTACK_DEFEND)
	var posts: Array[int] = []
	for b in plain.bots:
		posts.append(b.lane_points)
	cfg.defend_push_chance = 1.0
	cfg.defend_push_share = 1.0
	var w := _start(cfg, 5, RoundState.Mode.ATTACK_DEFEND)
	var pushed := 0
	for i in w.bots.size():
		var b := w.bots[i]
		if BotFlag.role(b, w) != BotFlag.Role.DEFEND:
			continue
		assert_eq(b.lane_shift, 0.0, "a defender holds its own points")
		if b.lane_points > posts[i]:
			pushed += 1
			var short := w.planner._points_to_middle(map.lanes[b.lane], b.character.team, b.character.end) - 1
			assert_eq(b.lane_points, short, "all the way to the last point short of the middle")
		else:
			assert_eq(b.lane_points, posts[i], "the others hold their posts")
	assert_eq(pushed, 1, "one defender pushed")


func test_a_match_with_variety_plays_on_without_errors() -> void:
	var w := _start(config, 3)
	var commands: Array[PlayerCommand] = []
	for c in state.characters:
		commands.append(PlayerCommand.new())
	var walked := 0.0
	var start: Array[Vector3] = []
	for c in state.characters:
		start.append(c.position)
	for t in roundi(20.0 / DT):
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
	for i in state.characters.size():
		walked = maxf(walked, state.characters[i].position.distance_to(start[i]))
	assert_gt(walked, 10.0, "bots walked their lanes")
	assert_not_null(w)


func test_in_elimination_an_anchor_keeps_its_authored_points_and_the_others_shift() -> void:
	var cfg := _quiet(config)
	cfg.lane_shift = 2.0
	var shifted := 0
	for seed_value: int in [1, 2, 3]:
		var w := _start(cfg, seed_value)
		for b in w.bots:
			if b.style.holds:
				assert_eq(b.lane_shift, 0.0, "an anchor holds its authored post")
			elif not is_zero_approx(b.lane_shift):
				shifted += 1
				assert_lte(absf(b.lane_shift), cfg.lane_shift)
	assert_gt(shifted, 0, "the others walk shifted")
