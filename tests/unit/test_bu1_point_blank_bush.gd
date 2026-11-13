extends GutTest
## BU1 · two foes in one bush: a bush hides no one within close_awareness, and there a bot fires through as much leaf as
## a BB gets through to the body (leaf_stop_depth), so the two shoot it out instead of each walking into the other.

const DT := 1.0 / 60.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
## The shared bush: wide and tall enough that both stand deep in its leaves.
const BUSH_RADIUS := 3.0
const BUSH_HEIGHT := 3.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var _w: BotWorld = null


## A BotWorld with one foe `away` m east of the bot at the origin, and `bush` (when not null) round them.
func _pair(away: float, bush: bool) -> Bot:
	var query := BoxWorld.new(tuning.body)
	if bush:
		query.add_bush(Vector3(away * 0.5, 0.0, 0.0), BUSH_RADIUS, BUSH_HEIGHT)
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, Vector3.ZERO, EAST, loadout)
	var foe := Character.new(1, 1, Vector3(away, 0.0, 0.0), -EAST, loadout)
	_w = BotWorld.new()
	_w.tuning = tuning
	_w.cfg = config
	_w.query = query
	_w.planner = RoundPlanner.new(1)
	_w.characters = [me, foe]
	_w.time = 10.0
	return Bot.new(me, 1, config.skill_for(&"normal"), 2)


func _held(away: float) -> bool:
	var b := _pair(away, true)
	var eye := BotSenses.eye_of(b.character, tuning)
	var chest := BotSenses.body_point(_w.characters[1], tuning.hits, config.aim_height_fraction)
	return BotCombat.leaves_in_line(_w, eye, chest)


func test_point_blank_in_one_bush_the_bot_fires_where_a_bb_gets_through_and_holds_where_none_would() -> void:
	# Pressed together (two capsules' width apart) a BB crosses well under leaf_stop_depth before it meets the body.
	assert_false(_held(tuning.body.radius * 2.0), "pressed together: it fires")
	# 1.5 m apart deep in the leaves no BB reaches the body, so it still holds: not a shot into the leaves.
	assert_true(_held(1.5), "1.5 m of leaves: no BB gets through, it holds")


func test_past_close_awareness_the_quarter_metre_rule_stands() -> void:
	# Both in the bush past close_awareness: the old rule, more than foliage_fire_through holds fire.
	assert_true(_held(config.close_awareness + 0.3), "past close_awareness: held for the leaves")


func test_point_blank_with_no_bushes_or_no_line_holds_for_nothing() -> void:
	var b := _pair(0.7, false)
	var eye := BotSenses.eye_of(b.character, tuning)
	assert_false(BotCombat.leaves_in_line(_w, eye, eye + Vector3(0.6, -0.4, 0.0)), "no bushes")
	_pair(0.7, true)
	assert_false(BotCombat.leaves_in_line(_w, eye, eye), "a line shorter than a body")


## A 30 m floor with one bush round two opposing bots 1.8 m apart, each facing the other (no player). Returns
## [sim, state, bots].
func _bush_match(away: float) -> Array:
	var m := MapData.new()
	m.id = "one bush"
	m.kill_y = -10.0
	var w := BoxWorld.new(tuning.body)
	w.add_floor(30.0, 30.0)
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, 0.0)
	floor_block.size = Vector3(30.0, 0.5, 30.0)
	m.blocks.append(floor_block)
	w.add_bush(Vector3.ZERO, BUSH_RADIUS, BUSH_HEIGHT)
	var half := away * 0.5
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-half if e == 0 else half, 0.0, 0.0), EAST if e == 0 else -EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-13.0 if e == 0 else 13.0, 0.0, 13.0), 0.0))
		m.ends.append(end)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var sim := Simulation.new(tuning, w, w.mover(), m.ends, m.kill_y)
	sim.nav = nav
	var state := GameState.new(7, tuning)
	var loadout := ReplicaStats.default_loadout()
	state.characters.append(Character.new(0, 0, Vector3(-half, 0.0, 0.0), EAST, loadout))
	state.characters.append(Character.new(1, 1, Vector3(half, 0.0, 0.0), -EAST, loadout))
	var bots := BotController.new(state, -1, m, nav, w, tuning, config, {0: &"normal", 1: &"normal"})
	sim.start_match(state)
	bots.observe(state)
	return [sim, state, bots]


func test_two_foes_inside_one_bush_shoot_it_out_instead_of_walking_into_each_other() -> void:
	var f := _bush_match(1.8)
	var sim: Simulation = f[0]
	var state: GameState = f[1]
	var bots: BotController = f[2]
	var commands: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	var hit_at := -1.0
	var live_at := -1.0
	for t in roundi(30.0 / DT):
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		if live_at < 0.0 and state.round_state.is_live():
			live_at = t * DT
		if not Elimination.is_in_play(state.characters[0]) or not Elimination.is_in_play(state.characters[1]):
			hit_at = t * DT
			break
	assert_gt(live_at, -0.5, "the round went live")
	assert_gt(hit_at, -0.5, "one of them is hit")
	gut.p("BU1: round live at %.2f s, first hit %.2f s after" % [live_at, hit_at - live_at])
	assert_lt(hit_at - live_at, config.no_shot_move_after + 6.0, "within a few seconds, not stuck pushing")
