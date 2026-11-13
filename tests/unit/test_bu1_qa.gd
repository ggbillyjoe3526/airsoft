extends GutTest
## BU1 QA · edges of the point-blank bush rule: the close_awareness boundary, vertical lines, several bushes, stances,
## and that a bot's BB at the separations the rule fires at reaches the body.

const DT := 1.0 / 60.0
const EAST := -PI * 0.5

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()


func _world(bushes: Array) -> BotWorld:
	var query := BoxWorld.new(tuning.body)
	for b: Array in bushes:
		query.add_bush(b[0], b[1], 3.0)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = config
	w.query = query
	w.planner = RoundPlanner.new(1)
	w.characters = []
	w.time = 10.0
	return w


func test_a_thin_bush_is_fired_through_at_exactly_close_awareness_and_held_just_past_it() -> void:
	var eye := Vector3(0.0, 1.5, 0.0)
	# One thin bush midway (about 0.56 m of leaves: under leaf_stop_depth, over foliage_fire_through).
	var at := config.close_awareness
	var w := _world([[Vector3(at * 0.5, 0.0, 0.0), 0.28]])
	assert_false(BotCombat.leaves_in_line(w, eye, Vector3(at, 1.5, 0.0)), "on the boundary: the point-blank rule")
	w = _world([[Vector3((at + 0.02) * 0.5, 0.0, 0.0), 0.28]])
	assert_true(BotCombat.leaves_in_line(w, eye, Vector3(at + 0.02, 1.5, 0.0)), "just past it: the 0.25 m rule")


func test_a_line_straight_up_counts_only_the_leaves_before_the_body() -> void:
	var w := _world([[Vector3.ZERO, 3.0]])
	var eye := Vector3(0.0, 0.5, 0.0)
	assert_false(BotCombat.leaves_in_line(w, eye, eye + Vector3(0.0, 0.7, 0.0)), "0.5 m of leaves before the body")
	assert_true(BotCombat.leaves_in_line(w, eye, eye + Vector3(0.0, 1.2, 0.0)), "1.0 m of leaves: held")
	assert_false(BotCombat.leaves_in_line(w, eye, eye + Vector3(0.0, -0.1, 0.0)), "a line shorter than a body")


func test_leaves_of_several_bushes_add_up_at_point_blank() -> void:
	var eye := Vector3(0.0, 1.5, 0.0)
	var aim := Vector3(1.6, 1.5, 0.0)
	var one := _world([[Vector3(0.8, 0.0, 0.0), 0.28]])
	assert_false(BotCombat.leaves_in_line(one, eye, aim), "one thin bush")
	var three := _world([[Vector3(0.3, 0.0, 0.0), 0.15], [Vector3(0.8, 0.0, 0.0), 0.15], [Vector3(1.3, 0.0, 0.0), 0.15]])
	assert_true(BotCombat.leaves_in_line(three, eye, aim), "three bushes in a row: over leaf_stop_depth")


func test_the_verdict_matches_the_leaf_depth_for_every_stance_at_point_blank() -> void:
	var w := _world([[Vector3(0.4, 0.0, 0.0), 3.0]])
	var loadout := ReplicaStats.default_loadout()
	for crouch: bool in [false, true]:
		var me := Character.new(0, 0, Vector3.ZERO, EAST, loadout)
		me.crouch_amount = 1.0 if crouch else 0.0
		me.prev_crouch_amount = me.crouch_amount
		var foe := Character.new(1, 1, Vector3(0.9, 0.0, 0.0), -EAST, loadout)
		var eye := BotSenses.eye_of(me, tuning)
		var chest := BotSenses.body_point(foe, tuning.hits, config.aim_height_fraction)
		var line := chest - eye
		var short := eye + line * ((line.length() - tuning.hits.body_radius) / line.length())
		var expect := w.query.foliage.depth(eye, short) > tuning.ballistics.leaf_stop_depth
		assert_eq(BotCombat.leaves_in_line(w, eye, chest), expect, "crouched=%s" % crouch)


## Two bots a `away` m apart in one big bush; true if one is hit within a few seconds of the round going live.
func _shoot_out(away: float) -> bool:
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
	w.add_bush(Vector3.ZERO, 3.0, 3.0)
	var half := away * 0.5
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-half if e == 0 else half, 0.0, 0.0), EAST if e == 0 else -EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-13.0 if e == 0 else 13.0, 0.0, 13.0), 0.0))
		m.ends.append(end)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var sim := Simulation.new(tuning, w, w.mover(), m.ends, m.kill_y)
	sim.nav = nav
	var state := GameState.new(11, tuning)
	var loadout := ReplicaStats.default_loadout()
	state.characters.append(Character.new(0, 0, Vector3(-half, 0.0, 0.0), EAST, loadout))
	state.characters.append(Character.new(1, 1, Vector3(half, 0.0, 0.0), -EAST, loadout))
	var bots := BotController.new(state, -1, m, nav, w, tuning, config, {0: &"normal", 1: &"normal"})
	sim.start_match(state)
	bots.observe(state)
	var commands: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	for t in roundi(20.0 / DT):
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		if not Elimination.is_in_play(state.characters[0]) or not Elimination.is_in_play(state.characters[1]):
			return true
	return false


func test_bbs_fired_at_the_separations_the_rule_allows_reach_the_body() -> void:
	for away: float in [0.5, 0.65, 0.8, 1.0]:
		var w := _world([[Vector3.ZERO, 3.0]])
		var eye := Vector3(-away * 0.5, 1.5, 0.0)
		var chest := Vector3(away * 0.5, 1.5, 0.0)
		var fires := not BotCombat.leaves_in_line(w, eye, chest)
		var hit := _shoot_out(away)
		gut.p("BU1 QA: %.2f m apart, rule fires %s, a hit lands %s" % [away, fires, hit])
		if fires:
			assert_true(hit, "%.2f m: the rule fires so a BB must land" % away)
