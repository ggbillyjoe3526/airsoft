extends GutTest
## The bots (game/ai/) on Depot, headless: whole matches of bots play out over several seeds with no friendly hits and
## nobody stuck or off the map; a bot sees only what it could, holds fire with a teammate in the line (or turned into it
## by its route, WL10), hears gunfire through walls no better than you (a silenced shot and a rattling magazine less
## far), finds cover that hides it, and settles its aim; a tick allocates nothing once warm.

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


## A match on Depot with seed `seed_value`: every character a bot when `player_id` is -1, each team at its level in
## `levels` (Normal if not given).
func _start(seed_value: int, player_id: int = -1, levels: Dictionary[int, StringName] = {}) -> void:
	sim = Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state = GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in tuning.rounds.team_size * 2:
		state.characters.append(Character.new(i, 0 if i < tuning.rounds.team_size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	bots = BotController.new(state, player_id, map, nav, level.query(), tuning, config, levels)
	sim.start_match(state)
	bots.observe(state)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func _bot(id: int) -> Bot:
	for b in bots.world.bots:
		if b.character.id == id:
			return b
	return null


func test_whole_bot_matches_play_out_fairly_over_seeds() -> void:
	var blind_shots := 0
	var friendly := 0
	var rescued := 0
	var timeouts := 0
	var rounds := 0
	var holsters := 0
	var away_in_enemy_half := 0
	var limit := roundi(tuning.rounds.round_time / DT) * 14
	for seed_value: int in [1, 2, 3]:
		_start(seed_value)
		var finished := false
		for t in limit:
			bots.think(state, commands, DT)
			# A bot pulls the trigger only at someone it sees now (M37): never at a guess, a sound or a memory.
			for b in bots.world.bots:
				if commands[b.character.id].fire and (not b.target_visible or b.contact == null
						or b.contact.seen_at < state.time - config.think_interval * 2.0):
					blind_shots += 1
			sim.step(state, commands, DT)
			bots.observe(state)
			for i in state.events.count:
				var e := state.events.items[i]
				if e.kind == GameEvent.Kind.CHARACTER_HIT and e.actor >= 0 \
						and state.characters[e.actor].team == state.characters[e.target].team:
					friendly += 1
				elif e.kind == GameEvent.Kind.ROUND_OVER:
					rounds += 1
					if e.value2 == GameEvent.RoundEnd.TIME:
						timeouts += 1
				elif e.kind == GameEvent.Kind.MATCH_OVER:
					finished = true
				elif e.kind == GameEvent.Kind.HOLSTER:
					holsters += 1
			for c in state.characters:
				if c.position.y < map.kill_y + 1.0:
					rescued += 1
			# A bot puts its replica away only in its own half, and draws it once past halfway (BotHolster).
			for b in bots.world.bots:
				# A bomb's throw puts the replica down too (SF2): not a holster.
				if b.character.armament.holstered and bots.world.planner.in_enemy_half(b) \
						and Elimination.is_in_play(b.character) and not Grenades.throwing(b.character):
					away_in_enemy_half += 1
			if finished:
				break
		assert_true(finished, "seed %d: the match was won" % seed_value)
	gut.p("bot matches: %d rounds, %d by the clock, %d friendly hits, %d holsters" % [rounds, timeouts, friendly,
			holsters])
	assert_gt(holsters, 0, "bots holster on a calm sprint")
	assert_lt(away_in_enemy_half, 3 * 60, "holstered past halfway only for the moment of the draw")
	assert_eq(friendly, 0, "no bot hit a teammate")
	assert_eq(blind_shots, 0, "every trigger pull was at someone in sight")
	assert_eq(rescued, 0, "nobody fell off the map")
	assert_lt(timeouts, rounds / 4 + 1, "rounds end in eliminations, not stand-offs")


## Ricochets counting (the browser game's depotMatch.ricochet tests, half its seeds): matches still play out, no bot
## shoots a teammate directly, a stray bounce only rarely catches a teammate or its own shooter, and bounced BBs decide
## some hits but under a quarter (G12). Measured: 45 of 251 hits off a bounce, 4 on a teammate, 4 on the shooter.
func test_bot_matches_with_ricochets_counting_stay_playable() -> void:
	tuning.hits.ricochets_count = true
	var hits := 0
	var bounced := 0
	var direct_friendly := 0
	var friendly_bounces := 0
	var self_hits := 0
	var won := 0
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		_start(seed_value)
		var finished := false
		for t in roundi(tuning.rounds.round_time / DT) * 14:
			_tick()
			for i in state.events.count:
				var e := state.events.items[i]
				if e.kind == GameEvent.Kind.CHARACTER_HIT and e.actor >= 0:
					hits += 1
					bounced += e.value
					if e.actor == e.target:
						self_hits += 1
					elif state.characters[e.actor].team == state.characters[e.target].team:
						if e.value == 0:
							direct_friendly += 1
						else:
							friendly_bounces += 1
				elif e.kind == GameEvent.Kind.MATCH_OVER:
					finished = true
			if finished:
				won += 1
				break
	tuning.hits.ricochets_count = false
	gut.p("ricochets counting: %d hits, %d off a bounce, %d on a teammate, %d on the shooter" % [hits, bounced,
			friendly_bounces, self_hits])
	assert_eq(won, 8, "every match was won")
	assert_eq(direct_friendly, 0, "no bot shot a teammate directly")
	assert_lte(friendly_bounces, 6, "a bounce catches a teammate only rarely")
	assert_lt(float(self_hits) / maxi(1, hits), 0.04, "a bounce catches its own shooter only rarely")
	var share := float(bounced) / maxi(1, hits)
	assert_between(share, 0.05, 0.25, "bounced BBs decide some hits, under a quarter")


func test_a_bot_does_not_see_an_enemy_behind_a_wall() -> void:
	_start(5)
	var watcher := _bot(0)
	var hidden := state.characters[3]
	# Either side of West yard's long wall (x = -17.5), facing each other, both still.
	watcher.character.position = Vector3(-14.0, 0.0, 0.0)
	watcher.character.yaw = PI * 0.5
	hidden.position = Vector3(-21.0, 0.0, 0.0)
	for c in state.characters:
		if c != watcher.character and c != hidden:
			c.status = Character.Status.OUT
	BotSenses.perceive(watcher, bots.world)
	assert_eq(watcher.target_id, -1, "a wall hides the enemy")
	hidden.position = Vector3(-16.0, 0.0, -2.5)
	BotSenses.perceive(watcher, bots.world)
	assert_eq(watcher.target_id, hidden.id, "in the open, in front, it is seen")


func test_a_bot_holds_fire_with_a_teammate_in_the_line() -> void:
	_start(6)
	var shooter := _bot(0)
	var mate := state.characters[1]
	var enemy := state.characters[3]
	# An open stretch of East yard, 12 m long, the teammate halfway and just off the line: the enemy shows past them.
	shooter.character.position = Vector3(20.0, 0.0, 0.0)
	enemy.position = Vector3(20.0, 0.0, -12.0)
	mate.position = Vector3(20.45, 0.0, -6.0)
	# Facing up the yard at the enemy, so it is in view from the first look.
	shooter.character.yaw = 0.0
	shooter.aim_yaw = 0.0
	for c in state.characters:
		c.prev_position = c.position
		if c != shooter.character and c != mate and c != enemy:
			c.status = Character.Status.OUT
	# Stands and fights (no dash for cover first); time runs, nobody moves.
	shooter.skill = config.skill.duplicate() as BotSkill
	shooter.skill.contact_cover_min_distance = INF
	var shots := 0
	for t in 180:
		mate.position = Vector3(20.45, 0.0, -6.0)
		bots.think(state, commands, DT)
		if commands[0].fire:
			shots += 1
		state.time += DT
	assert_eq(shooter.target_id, enemy.id, "it sees the enemy past its teammate")
	assert_eq(shots, 0, "never fires through a teammate")
	# The same duel with the teammate stepped aside: it does fire.
	for t in 180:
		mate.position = Vector3(24.0, 0.0, -6.0)
		bots.think(state, commands, DT)
		if commands[0].fire:
			shots += 1
		state.time += DT
	assert_gt(shots, 0, "with the line clear it fires")


## Shots bot 0 fires in 3 s at an enemy 12 m up East yard while bot teammate 1 stands at `mate_at` in `mode`, moving at
## `velocity` on `route` (none: no route), held there each tick.
func _shots_past_a_walker(mate_at: Vector3, route: PackedVector3Array, mode: Bot.Mode = Bot.Mode.ADVANCE,
		velocity: Vector3 = Vector3.ZERO, mate_status: Character.Status = Character.Status.ALIVE) -> int:
	_start(6)
	var shooter := _bot(0)
	var mate := state.characters[1]
	var walker := _bot(1)
	var enemy := state.characters[3]
	shooter.character.position = Vector3(20.0, 0.0, 0.0)
	enemy.position = Vector3(20.0, 0.0, -12.0)
	shooter.character.yaw = 0.0
	shooter.aim_yaw = 0.0
	for c in state.characters:
		c.prev_position = c.position
		if c != shooter.character and c != mate and c != enemy:
			c.status = Character.Status.OUT
	shooter.skill = config.skill.duplicate() as BotSkill
	shooter.skill.contact_cover_min_distance = INF
	mate.status = mate_status
	var shots := 0
	for t in 180:
		# Bot 0 thinks before its teammate, so it judges the route as given here.
		mate.position = mate_at
		mate.velocity = velocity
		walker.mode = mode
		walker.route = route
		walker.route_leg = 0
		walker.route_state = Bot.RouteState.NONE if route.is_empty() else Bot.RouteState.OK
		bots.think(state, commands, DT)
		if commands[0].fire:
			shots += 1
		state.time += DT
	return shots


func test_a_bot_holds_fire_while_a_teammate_could_run_into_the_line() -> void:
	# WL10 (KNOWN_ISSUES: a teammate breaking for cover across a shot's line): a teammate standing 1.1 m off the line
	# may strafe, break for cover or turn to a fight as the BBs fly, whatever it does now.
	assert_eq(_shots_past_a_walker(Vector3(21.1, 0.0, -10.0), PackedVector3Array()), 0, "never past one that close")
	assert_eq(_shots_past_a_walker(Vector3(21.1, 0.0, -10.0), PackedVector3Array(), Bot.Mode.FIGHT), 0,
			"walking or fighting")
	assert_gt(_shots_past_a_walker(Vector3(21.7, 0.0, -10.0), PackedVector3Array(), Bot.Mode.FIGHT), 0,
			"but past one out of a run's reach of the line")


func test_a_bot_holds_fire_while_a_sprinting_teammate_s_route_turns_it_across_the_line() -> void:
	# Faster than a run, a teammate sprinting up the yard (-z) is clear straight on and on a route turning away, but its
	# route's corner turns it across the line before the BBs pass.
	var at := Vector3(21.3, 0.0, -10.0)
	var sprint := Vector3(0.0, 0.0, -6.3)
	var corner := Vector3(21.3, 0.0, -10.1)
	assert_gt(_shots_past_a_walker(at, PackedVector3Array(), Bot.Mode.ADVANCE, sprint), 0, "clear straight on")
	assert_gt(_shots_past_a_walker(at, PackedVector3Array([corner, Vector3(30.0, 0.0, -10.1)]), Bot.Mode.ADVANCE,
			sprint), 0, "or turning away")
	assert_eq(_shots_past_a_walker(at, PackedVector3Array([corner, Vector3(10.0, 0.0, -10.1)]), Bot.Mode.ADVANCE,
			sprint), 0, "never turning across")


func test_a_bot_keeps_firing_with_a_teammate_nowhere_near_the_line() -> void:
	# QA (WL10): the wider check must not freeze an ordinary firefight. Bot 0 shoots up East yard at an enemy 12 m off.
	for mode: Bot.Mode in [Bot.Mode.ADVANCE, Bot.Mode.FIGHT]:
		assert_gt(_shots_past_a_walker(Vector3(20.0, 0.0, 6.0), PackedVector3Array(), mode), 0, "mate behind the shooter")
		assert_gt(_shots_past_a_walker(Vector3(20.0, 0.0, 4.0), PackedVector3Array(), mode, Vector3(0.0, 0.0, -4.0)),
				0, "mate behind the shooter, running up the line")
		assert_gt(_shots_past_a_walker(Vector3(20.0, 0.0, -12.0) + Vector3(6.0, 0.0, 0.0), PackedVector3Array(), mode),
				0, "mate in another lane, level with the enemy")
	assert_gt(_shots_past_a_walker(Vector3(21.5, 0.0, 0.0), PackedVector3Array(), Bot.Mode.FIGHT), 0,
			"mate shoulder to shoulder")


func test_a_teammate_who_is_out_stops_only_the_bbs_before_the_target() -> void:
	var out := Character.Status.OUT
	var walking := Character.Status.WALKING_OFF
	assert_gt(_shots_past_a_walker(Vector3(20.0, 0.0, -25.0), PackedVector3Array(), Bot.Mode.FIGHT, Vector3.ZERO, out),
			0, "out, past the target in the line")
	assert_gt(_shots_past_a_walker(Vector3(21.2, 0.0, -9.0), PackedVector3Array(), Bot.Mode.FIGHT, Vector3.ZERO, out),
			0, "out, just off the line, no run to fear")
	assert_eq(_shots_past_a_walker(Vector3(20.0, 0.0, -6.0), PackedVector3Array(), Bot.Mode.FIGHT, Vector3.ZERO, walking),
			0, "walking off, in the line before the target: every body stops a BB")


func test_a_miss_flies_on_past_a_near_target_as_far_as_a_bb_carries() -> void:
	# WL10: on Woodland a miss at a target 23 m off knocked out a teammate 33 m past it.
	assert_eq(BotCombat.miss_reach(config, 10.0), config.friendly_carry, "a near target: as far as a BB carries")
	assert_eq(BotCombat.miss_reach(config, 50.0), 50.0 + config.friendly_beyond_target, "a far one: past it")
	assert_gt(config.friendly_carry, 56.0, "farther than that teammate stood")


func test_a_bot_s_point_ahead_follows_its_route_round_corners() -> void:
	_start(6)
	var b := _bot(0)
	b.character.position = Vector3(0.0, 1.0, 0.0)
	b.route = PackedVector3Array([Vector3(0.0, 0.0, -2.0), Vector3(3.0, 0.0, -2.0)])
	b.route_leg = 0
	b.route_state = Bot.RouteState.OK
	b.mode = Bot.Mode.ADVANCE
	assert_almost_eq(BotRoutes.point_ahead(b, 1.0), Vector3(0.0, 1.0, -1.0), Vector3.ONE * 1e-5, "along its leg")
	assert_almost_eq(BotRoutes.point_ahead(b, 3.0), Vector3(1.0, 1.0, -2.0), Vector3.ONE * 1e-5, "round the corner")
	assert_almost_eq(BotRoutes.point_ahead(b, 9.0), Vector3(3.0, 1.0, -2.0), Vector3.ONE * 1e-5, "stopping at its end")
	b.route_leg = 1
	assert_almost_eq(BotRoutes.point_ahead(b, 1.0), Vector3(0.832050, 1.0, -0.554700), Vector3.ONE * 1e-5,
			"from where it stands to its next corner")
	b.mode = Bot.Mode.FIGHT
	assert_eq(BotRoutes.point_ahead(b, 1.0), b.character.position, "in a fight it walks no route")
	b.mode = Bot.Mode.ADVANCE
	b.route_state = Bot.RouteState.WANTED
	assert_eq(BotRoutes.point_ahead(b, 1.0), b.character.position, "nor while it waits for one")


func test_gunfire_is_heard_and_walls_muffle_it() -> void:
	_start(7)
	var ear := _bot(0)
	ear.character.position = Vector3(-14.0, 0.0, 0.0)
	var shooter := state.characters[3]
	shooter.position = Vector3(-14.0, 0.0, -10.0)
	var e := state.events
	e.clear()
	var shot := e.add(GameEvent.Kind.SHOT)
	shot.actor = 3
	shot.position = shooter.position + Vector3(0.0, 1.5, 0.0)
	BotHearing.observe(state, bots.world)
	assert_true(ear.has_last_known, "a shot 10 m off is heard, walls or not")
	assert_lt(Vector2(ear.last_known.x + 14.0, ear.last_known.z + 10.0).length(), 4.0, "about where it was")
	ear.has_last_known = false
	ear.heard_at = -INF
	# 19 m through the yard wall: beyond the wall's share of the range.
	shooter.position = Vector3(-21.0, 0.0, -18.0)
	shot.position = shooter.position + Vector3(0.0, 1.5, 0.0)
	BotHearing.observe(state, bots.world)
	assert_false(ear.has_last_known, "a wall cuts the range")


func test_a_silenced_shot_and_a_rattling_magazine_carry_less_far() -> void:
	_start(7)
	var ear := _bot(0)
	ear.character.position = Vector3(-14.0, 0.0, 0.0)
	var shooter := state.characters[3]
	var silenced := shooter.armament.replica().duplicate() as ReplicaConfig
	silenced.heard_scale = 0.5
	var e := state.events
	for case: Array in [[-12.0, false, true], [-12.0, true, false], [-5.0, true, true]]:
		shooter.armament.replicas[shooter.armament.active] = silenced if case[1] else ReplicaStats.default_loadout()[0]
		shooter.position = Vector3(-14.0, 0.0, case[0])
		ear.has_last_known = false
		ear.heard_at = -INF
		e.clear()
		var shot := e.add(GameEvent.Kind.SHOT)
		shot.actor = 3
		shot.position = shooter.position + Vector3(0.0, 1.5, 0.0)
		BotHearing.observe(state, bots.world)
		assert_eq(ear.has_last_known, case[2], "a shot %s m off, silenced %s" % [-case[0], case[1]])
	for case: Array in [[-4.0, true], [-8.0, false]]:
		shooter.position = Vector3(-14.0, 0.0, case[0])
		ear.has_last_known = false
		ear.heard_at = -INF
		e.clear()
		var step := e.add(GameEvent.Kind.FOOTSTEP)
		step.actor = 3
		step.value = GameEvent.Footstep.RATTLE
		step.position = shooter.position
		BotHearing.observe(state, bots.world)
		assert_eq(ear.has_last_known, case[1], "a rattle %s m off" % -case[0])


func test_cover_found_hides_from_the_threat() -> void:
	_start(8)
	var b := _bot(0)
	var w := bots.world
	var found := 0
	for i in 20:
		var from := w.nav.random_walkable_near(Vector3(0.0, 0.0, 0.0), 14.0, b.rng)
		var threat := w.nav.random_walkable_near(from, 14.0, b.rng) + Vector3(0.0, tuning.body.stand_eye_height, 0.0)
		if BotCover.find(from, threat, w, b.rng, b.cover, config.cover_radius, config.cover_candidates, false,
				BotRoutes.taken(), 0):
			found += 1
			assert_true(b.cover.lean != 0 or BotCover.hides_from(b.cover.position, threat, w),
					"cover at %s hides from %s" % [b.cover.position, threat])
	assert_gt(found, 5, "Depot has cover nearly everywhere")


func test_aim_error_settles_with_time_on_target() -> void:
	var skill := config.skill
	var fresh := BotAim.error_size(0.0, false, 20.0, 0.0, skill)
	var settled := BotAim.error_size(skill.aim_settle_time * 2.0, false, 20.0, 0.0, skill)
	assert_gt(fresh, settled)
	assert_gt(BotAim.error_size(skill.aim_settle_time * 2.0, true, 20.0, 0.0, skill), settled, "worse on the move")


func test_bot_ticks_allocate_no_objects_once_warm() -> void:
	_start(9)
	_assert_warm_ticks_allocate_nothing()


func test_pro_bot_ticks_allocate_no_objects_once_warm() -> void:
	# Held angles, slicing, the careful walk, pre-aim and the peek watch (DF2a).
	_start(9, -1, {0: &"hard", 1: &"hard"})
	_assert_warm_ticks_allocate_nothing()


func _assert_warm_ticks_allocate_nothing() -> void:
	# Warm: a whole round played (contacts, cover searches, BBs in flight, the round's reset).
	var rounds := 0
	for t in roundi(tuning.rounds.round_time / DT) * 2:
		_tick()
		rounds += state.events.count_of(GameEvent.Kind.ROUND_START)
		if rounds >= 1:
			break
	for t in 600:
		_tick()
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var events_before := state.events.items.size()
	for t in 600:
		_tick()
	# The tick's event pool grows to the busiest tick yet (SimEvents), a one-off a new high costs; nothing else may.
	var grown := state.events.items.size() - events_before
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before + grown)
