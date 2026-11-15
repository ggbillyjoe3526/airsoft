extends GutTest
## Hard crossfires on defence (FG2b; the browser game's botMovement.ts staggerHold and crossfireSpot): two defenders at
## one lane point stand apart, a pair that plays as a team in a crossfire on the lane's next point, holding those points
## rather than cover beside them; attackers and Elimination are untouched. On Depot, headless
## (game/ai/bot_movement.gd).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null
var state: GameState = null
var bots: BotController = null


func before_all() -> void:
	map = YardMap.load_map(MapStyle.new(), tuning.rounds.team_size)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	level.free()


## Depot in `mode` (team 0 attacks first), every bot at `level`, lane points never jittered or shifted (RV1).
func _start(level_id: StringName, mode: RoundState.Mode = RoundState.Mode.ATTACK_DEFEND) -> BotWorld:
	var cfg: BotConfig = config.duplicate()
	cfg.lane_jitter = 0.0
	cfg.lane_shift = 0.0
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state = GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in tuning.rounds.team_size * 2:
		state.characters.append(Character.new(i, 0 if i < tuning.rounds.team_size else 1, Vector3.ZERO, 0.0, loadout))
	if mode == RoundState.Mode.ATTACK_DEFEND:
		state.round_state.mode = mode
		state.round_state.pole = map.pole
	bots = BotController.new(state, -1, map, nav, level.query(), tuning, cfg, {0: level_id, 1: level_id})
	sim.start_match(state)
	bots.observe(state)
	return bots.world


func _bot(id: int) -> Bot:
	for b in bots.world.bots:
		if b.character.id == id:
			return b
	return null


## `b` (with `mate` standing at the lane's first point from its end) picks its first point on `lane`. Returns that point.
func _first_point_beside(b: Bot, mate: Bot, lane: int) -> Vector3:
	var w := bots.world
	var points := map.lanes[lane]
	for o: Bot in [b, mate]:
		o.lane = lane
		o.lane_dir = 1 if o.character.end == 0 else -1
		o.lane_index = -1
		o.lane_points = 2
		o.hunting = false
		o.mode = Bot.Mode.ADVANCE
	var first := points[0] if b.lane_dir > 0 else points[points.size() - 1]
	mate.character.position = first
	assert_true(BotMovement._next_goal(b, w))
	return first


func test_pro_defenders_at_one_point_set_a_crossfire_on_the_next() -> void:
	var w := _start(&"hard")
	var b := _bot(3)
	var mate := _bot(4)
	var crossed := 0
	for lane in map.lanes.size():
		var first := _first_point_beside(b, mate, lane)
		var choke := map.lanes[lane][b.lane_index + b.lane_dir]
		var g := b.lane_goal
		if g.is_equal_approx(first):
			continue
		var d0 := Vector2(first.x - choke.x, first.z - choke.z).length()
		var d1 := Vector2(g.x - choke.x, g.z - choke.z).length()
		if absf(d1 - d0) > 1e-3:
			# No crossfire spot on this lane: side by side instead.
			assert_almost_eq(Vector2(g.x - first.x, g.z - first.z).length(), config.lane_hold_offset, 1e-3)
			continue
		crossed += 1
		var apart := absf(angle_difference(atan2(first.x - choke.x, first.z - choke.z), atan2(g.x - choke.x,
				g.z - choke.z)))
		assert_gte(apart, deg_to_rad(config.crossfire_min_deg) - 1e-4, "lane %d: seen from another angle" % lane)
		var eye := Vector3(0.0, tuning.body.stand_eye_height, 0.0)
		assert_true(BotSenses.line_clear(w.query, g + eye, choke + eye), "lane %d: the choke in view" % lane)
	assert_gt(crossed, 0, "a crossfire on at least one of Depot's lanes")


func test_defenders_without_team_play_stand_side_by_side_and_attackers_never_move_aside() -> void:
	var w := _start(&"easy")
	var b := _bot(3)
	var first := _first_point_beside(b, _bot(4), 0)
	assert_almost_eq(Vector2(b.lane_goal.x - first.x, b.lane_goal.z - first.z).length(), config.lane_hold_offset, 1e-3,
			"a step to one side")
	var yaw := w.enemy_yaw(b.character.team)
	var across := Vector2(cos(yaw), -sin(yaw))
	assert_almost_eq(absf(Vector2(b.lane_goal.x - first.x, b.lane_goal.z - first.z).normalized().dot(across)), 1.0,
			1e-3, "across the way to the enemy")
	var attacker := _bot(0)
	first = _first_point_beside(attacker, _bot(1), 0)
	assert_eq(attacker.lane_goal, first, "an attacker walks on to its point")
	_start(&"hard", RoundState.Mode.ELIMINATION)
	var plain := _bot(3)
	first = _first_point_beside(plain, _bot(4), 0)
	assert_eq(plain.lane_goal, first, "Elimination untouched")


## Whether a teammate holds the bot's lane; the hold-cover gate it feeds is test_fg2b_qa.gd's.
func test_a_lane_is_shared_while_a_teammate_holds_it() -> void:
	var w := _start(&"hard")
	var b := _bot(3)
	var mate := _bot(4)
	_first_point_beside(b, mate, 0)
	assert_true(BotMovement._lane_shared(b, w), "a teammate on its lane")
	mate.lane = (b.lane + 1) % map.lanes.size()
	_bot(5).lane = mate.lane
	assert_false(BotMovement._lane_shared(b, w), "alone on its lane: hold cover as before")
