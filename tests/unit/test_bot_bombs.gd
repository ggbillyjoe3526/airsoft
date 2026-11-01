extends GutTest
## Bots' smoke and flash bombs (SF2): the throw's aim (Grenades.throw_pitch, arc_point), when a bot smokes or flashes
## (BotBombs), its turn, its look away from its own flash, hearing a bang or a pop (BotHearing), the levels' chances and
## the bombs' own stream. Headless, on a BoxWorld floor with the default loadout; then whole bot matches on Depot.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var g: GrenadeConfig = tuning.grenades
var bots: BotConfig = BotConfig.load_default()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


## A floor 60 m by 60 m, and a wall `wall_height` tall across z = `wall_z` (12 m wide) if given.
func _world(wall_z: float = INF, wall_height: float = 3.0) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 60.0)
	if wall_z < INF:
		w.add_box(Vector3(0.0, wall_height * 0.5, wall_z), Vector3(12.0, wall_height, 0.2))
	return w


## A started match on `world`: the bot (character 0, team 0, facing -Z at the origin), a teammate far off, and an enemy
## at `foe_at` facing +Z: [Simulation, GameState, Bot, BotWorld]. The bot's skill throws every time it may.
func _match(world: BoxWorld, foe_at: Vector3) -> Array:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-20.0 if e == 0 else 20.0, 0.0, 20.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 25.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, world, world.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	s.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	s.characters.append(Character.new(1, 0, Vector3.ZERO, 0.0, loadout))
	s.characters.append(Character.new(2, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	_place(s.characters[0], Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0)
	_place(s.characters[1], Vector3(-25.0, tuning.body.rest_gap, 25.0), 0.0)
	_place(s.characters[2], foe_at + Vector3(0.0, tuning.body.rest_gap, 0.0), PI)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = bots
	w.query = world
	w.planner = RoundPlanner.new(1)
	w.characters = s.characters
	w.grenades = s.grenades
	w.time = s.time
	var skill := bots.skill_for(&"easy").duplicate() as BotSkill
	skill.smoke_chance = 1.0
	skill.flash_chance = 1.0
	var b := Bot.new(s.characters[0], 11, skill, s.characters.size())
	return [sim, s, b, w]


static func _place(c: Character, at: Vector3, yaw: float) -> void:
	c.position = at
	c.prev_position = at
	c.velocity = Vector3.ZERO
	c.yaw = yaw
	c.pitch = 0.0


## `ticks` ticks of the bot's bombs only (the rest of its brain left out), everyone else standing; `setup` runs before
## each tick. Returns the events of `kind` counted over them.
func _run(m: Array, ticks: int, setup: Callable, kind: int = -1) -> int:
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var b: Bot = m[2]
	var w: BotWorld = m[3]
	var cmds: Array[PlayerCommand] = []
	for c in s.characters:
		cmds.append(PlayerCommand.new())
	var n := 0
	for t in ticks:
		w.time = s.time
		for i in cmds.size():
			cmds[i].reset(s.characters[i].yaw, s.characters[i].pitch)
		setup.call()
		BotBombs.step(b, w, s.characters[2], cmds[0], DT)
		sim.step(s, cmds, DT)
		if kind >= 0:
			n += s.events.count_of(kind)
	return n


# --- The aim ---


func test_the_throw_pitch_comes_down_where_it_was_aimed_and_the_high_arc_rises_higher() -> void:
	var eye := Vector3(0.0, 1.6, 0.0)
	var at := Vector3(6.0, 0.0, -8.0)
	var yaw := atan2(-at.x, -at.z)
	for high: bool in [false, true]:
		var pitch := Grenades.throw_pitch(eye, at, g, high)
		assert_false(is_nan(pitch))
		var flight := Vector2(at.x, at.z).length() / (cos(pitch + g.loft) * g.throw_speed)
		var down := Grenades.arc_point(eye, yaw, pitch, g, flight)
		assert_almost_eq(down.distance_to(at), 0.0, 0.01, "high %s" % high)
	assert_gt(Grenades.throw_pitch(eye, at, g, true), Grenades.throw_pitch(eye, at, g, false))
	assert_true(is_nan(Grenades.throw_pitch(eye, Vector3(0.0, 0.0, -40.0), g)), "out of reach")
	assert_true(is_nan(Grenades.throw_pitch(eye, Vector3(0.0, 0.0, 0.0), g)), "straight down")


func test_a_bot_s_smoke_settles_near_where_it_meant_it_to() -> void:
	var m := _match(_world(), Vector3(0.0, 0.0, -20.0))
	var b: Bot = m[2]
	var s: GameState = m[1]
	b.mode = Bot.Mode.COVER
	b.target_visible = true
	var thrown := _run(m, 60, func() -> void: b.suppressed_at = s.time, GameEvent.Kind.GRENADE_THROW)
	assert_eq(thrown, 1, "one smoke thrown")
	assert_eq(s.characters[0].grenades.smoke, 0)
	_run(m, 240, func() -> void: b.mode = Bot.Mode.SEARCH)
	var bomb := s.grenades[0]
	assert_true(bomb.active and bomb.resting, "it has settled")
	# Half of 20 m, at most smoke_reach out.
	var meant := minf(20.0 * bots.smoke_at_share, bots.smoke_reach)
	assert_almost_eq(-bomb.position.z, meant, 3.0, "about where it meant (%.1f m)" % -bomb.position.z)
	assert_almost_eq(bomb.position.x, 0.0, 0.5)


# --- Smoke ---


func test_a_pinned_bot_turns_to_its_smoke_then_throws_it_along_the_line_to_the_threat() -> void:
	var m := _match(_world(), Vector3(8.0, 0.0, -16.0))
	var b: Bot = m[2]
	var s: GameState = m[1]
	var w: BotWorld = m[3]
	b.mode = Bot.Mode.COVER
	b.target_visible = true
	var cmd := PlayerCommand.new()
	cmd.reset(0.0, 0.0)
	b.suppressed_at = s.time
	w.time = s.time
	BotBombs.step(b, w, s.characters[2], cmd, DT)
	assert_eq(b.bomb_kind, Grenade.Kind.SMOKE, "it turns to throw")
	assert_eq(cmd.throw_grenade, Grenade.Kind.NONE, "not yet: it is off by %.0f°" % rad_to_deg(b.bomb_yaw))
	assert_true(BotBombs.busy(b, w))
	assert_eq(cmd.forward, 0.0, "it stands still")
	assert_false(cmd.fire)
	var thrown := _run(m, 40, func() -> void: b.suppressed_at = s.time, GameEvent.Kind.GRENADE_THROW)
	assert_eq(thrown, 1)
	var bomb := s.grenades[0]
	var toward := Vector2(8.0, -16.0).normalized()
	assert_almost_eq(Vector2(bomb.velocity.x, bomb.velocity.z).normalized().dot(toward), 1.0, 0.01,
			"thrown at the threat")


func test_a_pinned_bot_that_lost_sight_smokes_toward_where_it_knows_the_threat_to_be() -> void:
	var m := _match(_world(), Vector3(8.0, 0.0, -16.0))
	var b: Bot = m[2]
	var s: GameState = m[1]
	b.mode = Bot.Mode.COVER
	b.target_visible = false
	b.has_last_known = true
	b.last_known = Vector3(-8.0, tuning.body.rest_gap, -16.0)
	assert_eq(_run(m, 60, func() -> void: b.suppressed_at = s.time, GameEvent.Kind.GRENADE_THROW), 1)
	var bomb := s.grenades[0]
	assert_almost_eq(Vector2(bomb.velocity.x, bomb.velocity.z).normalized().dot(Vector2(-8.0, -16.0).normalized()), 1.0,
			0.01, "at the spot it knows, not where the enemy really is")
	var lost := _match(_world(), Vector3(8.0, 0.0, -16.0))
	var nowhere: Bot = lost[2]
	var ls: GameState = lost[1]
	nowhere.mode = Bot.Mode.COVER
	assert_eq(_run(lost, 60, func() -> void: nowhere.suppressed_at = ls.time, GameEvent.Kind.GRENADE_THROW), 0,
			"no idea where they are: no smoke")


func test_no_smoke_out_of_cover_unpinned_too_close_or_far_or_with_a_cloud_already_there() -> void:
	for case: int in 5:
		var foe := Vector3(0.0, 0.0, -20.0)
		if case == 2:
			foe = Vector3(0.0, 0.0, -(bots.smoke_min_distance - 1.0))
		elif case == 3:
			foe = Vector3(0.0, 0.0, -(bots.smoke_max_distance + 1.0))
		var m := _match(_world(), foe)
		var b: Bot = m[2]
		var s: GameState = m[1]
		b.mode = Bot.Mode.SEARCH if case == 0 else Bot.Mode.COVER
		b.target_visible = true
		if case == 4:
			var cloud := s.grenades[3]
			cloud.launch(Grenade.Kind.SMOKE, 2, Vector3(0.0, 0.04, -10.0), Vector3.ZERO)
			cloud.resting = true
			cloud.popped = true
			cloud.age = g.smoke_fuse
			cloud.smoking = g.smoke_grow
		var pin := func() -> void: b.suppressed_at = s.time
		var thrown := _run(m, 60, pin if case != 1 else func() -> void: pass, GameEvent.Kind.GRENADE_THROW)
		assert_eq(thrown, 0, "case %d" % case)


# --- Flash ---


## A bot searching toward where the enemy was heard round a corner: a wall 3 m tall from x = 1 to 13 at z = -6 hides
## the spot (`side` m to the right, `away` m ahead); its route goes straight on to z = -`away`, then right. With
## `tall_wall`, the wall reaches across its way too, so no throw clears it in time.
func _search_round_a_corner(away: float = 10.0, side: float = 6.0, tall_wall: bool = false) -> Array:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 60.0)
	if tall_wall:
		w.add_box(Vector3(0.0, 1.5, -away * 0.5), Vector3(30.0, 3.0, 0.2))
	else:
		w.add_box(Vector3(7.0, 1.5, -6.1), Vector3(12.0, 3.0, 0.2))
	var foe := Vector3(side, 0.0, -away)
	var m := _match(w, foe)
	var b: Bot = m[2]
	b.mode = Bot.Mode.SEARCH
	b.has_last_known = true
	b.last_known = foe + Vector3(0.0, tuning.body.rest_gap, 0.0)
	b.route = PackedVector3Array([Vector3(0.0, tuning.body.rest_gap, -away), b.last_known])
	b.route_leg = 0
	return m


func test_a_searching_bot_flashes_round_the_corner_looks_away_and_the_enemy_is_dazzled_the_most() -> void:
	var m := _search_round_a_corner()
	var b: Bot = m[2]
	var s: GameState = m[1]
	var w: BotWorld = m[3]
	var me := s.characters[0]
	var foe := s.characters[2]
	var thrown := _run(m, 50, func() -> void: pass, GameEvent.Kind.GRENADE_THROW)
	assert_eq(thrown, 1, "a flash thrown")
	assert_eq(me.grenades.flash, 0)
	assert_gt(b.bomb_away_until, s.time, "it waits on the bang")
	var bang := _run(m, roundi((g.flash_fuse + 0.5) / DT), func() -> void: pass, GameEvent.Kind.FLASH_BANG)
	assert_eq(bang, 1, "it went bang")
	assert_gt(absf(me.yaw), PI * 0.75, "it looked away")
	assert_gt(foe.dazzle_left, g.dazzle_min * 0.5, "the enemy round the corner is dazzled")
	assert_eq(me.dazzle_left, 0.0, "the thrower, looking away, not at all")
	_run(m, roundi(bots.flash_wait_after / DT) + 2, func() -> void: pass)
	assert_false(BotBombs.busy(b, w), "then it pushes")


func test_no_flash_that_would_go_off_in_the_air_over_a_wall() -> void:
	var m := _search_round_a_corner(10.0, 0.0, true)
	assert_eq(_run(m, 50, func() -> void: pass, GameEvent.Kind.GRENADE_THROW), 0)


func test_no_flash_at_a_spot_in_sight_too_near_or_far_by_a_teammate_or_with_none_left() -> void:
	for case: int in 5:
		var m: Array
		if case == 0:
			m = _search_round_a_corner(10.0, 0.0) # straight ahead, in sight
		elif case == 1:
			m = _search_round_a_corner(bots.flash_min_distance - 1.0, 2.0)
		elif case == 2:
			m = _search_round_a_corner(bots.flash_max_distance + 2.0)
		else:
			m = _search_round_a_corner()
		var s: GameState = m[1]
		if case == 3:
			_place(s.characters[1], Vector3(5.0, tuning.body.rest_gap, -9.0), 0.0)
		elif case == 4:
			s.characters[0].grenades.spend(Grenade.Kind.FLASH)
		var thrown := _run(m, 50, func() -> void: pass, GameEvent.Kind.GRENADE_THROW)
		assert_eq(thrown, 0, "case %d" % case)


func test_a_failed_roll_waits_its_gap_before_the_next() -> void:
	var m := _search_round_a_corner()
	var b: Bot = m[2]
	b.skill.flash_chance = 0.0
	var s: GameState = m[1]
	assert_eq(_run(m, 20, func() -> void: pass, GameEvent.Kind.GRENADE_THROW), 0)
	assert_almost_eq(b.bomb_roll_at, bots.bomb_roll_gap, 0.05, "rolled once, at the start")
	assert_lt(s.time, b.bomb_roll_at)


func test_a_throw_it_cannot_turn_to_in_time_is_given_up() -> void:
	var m := _match(_world(), Vector3(0.0, 0.0, -20.0))
	var b: Bot = m[2]
	var w: BotWorld = m[3]
	b.bomb_kind = Grenade.Kind.SMOKE
	b.bomb_yaw = PI
	b.bomb_aim_until = w.time + DT * 3.0
	b.skill.turn_rate = 0.5
	assert_eq(_run(m, 10, func() -> void: pass, GameEvent.Kind.GRENADE_PIN), 0)
	assert_eq(b.bomb_kind, Grenade.Kind.NONE)


# --- Hearing ---


func test_an_enemy_bang_or_pop_is_heard_and_a_teammate_s_is_not() -> void:
	var m := _match(_world(), Vector3(0.0, 0.0, -30.0))
	var s: GameState = m[1]
	var b: Bot = m[2]
	var w: BotWorld = m[3]
	w.bots = [b]
	# The guess's floor comes off a nav grid: Depot's will do (its floor is at 0 too).
	var depot := MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	w.nav = NavGrid.build(depot, tuning.nav, tuning.body)
	for kind: int in [GameEvent.Kind.FLASH_BANG, GameEvent.Kind.SMOKE_POP]:
		for thrower: int in [2, 1]:
			b.has_last_known = false
			s.events.clear()
			var e := s.events.add(kind)
			e.actor = thrower
			e.position = Vector3(3.0, 0.1, -15.0)
			BotHearing.observe(s, w)
			assert_eq(b.has_last_known, thrower == 2, "kind %d by %d" % [kind, thrower])
			if b.has_last_known:
				assert_lt(Vector2(b.last_known.x - 3.0, b.last_known.z + 15.0).length(), 16.0 * bots.hearing_error)
	b.has_last_known = false
	s.events.clear()
	var far := s.events.add(GameEvent.Kind.SMOKE_POP)
	far.actor = 2
	far.position = Vector3(0.0, 0.1, -(bots.pop_hearing + 2.0))
	BotHearing.observe(s, w)
	assert_false(b.has_last_known, "a pop past its reach")


func test_a_bang_or_pop_of_a_thrower_already_out_is_no_news() -> void:
	var m := _match(_world(), Vector3(0.0, 0.0, -30.0))
	var s: GameState = m[1]
	var b: Bot = m[2]
	var w: BotWorld = m[3]
	w.bots = [b]
	var depot := MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	w.nav = NavGrid.build(depot, tuning.nav, tuning.body)
	s.characters[2].status = Character.Status.WALKING_OFF
	for kind: int in [GameEvent.Kind.FLASH_BANG, GameEvent.Kind.SMOKE_POP]:
		b.has_last_known = false
		s.events.clear()
		var e := s.events.add(kind)
		e.actor = 2
		e.position = Vector3(3.0, 0.1, -15.0)
		BotHearing.observe(s, w)
		assert_false(b.has_last_known, "kind %d: its thrower is out (BP2)" % kind)


# --- Levels and seeds ---


func test_each_level_up_throws_more_often() -> void:
	var easy := bots.skill_for(&"easy")
	var normal := bots.skill_for(&"normal")
	var hard := bots.skill_for(&"hard")
	assert_gt(easy.smoke_chance, 0.0)
	assert_gt(easy.flash_chance, 0.0)
	assert_gt(normal.smoke_chance, easy.smoke_chance)
	assert_gt(hard.smoke_chance, normal.smoke_chance)
	assert_gt(normal.flash_chance, easy.flash_chance)
	assert_gt(hard.flash_chance, normal.flash_chance)


func test_the_bombs_rolls_are_their_own_stream() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var one := Bot.new(c, 77, bots.skill, 2)
	var two := Bot.new(c, 77, bots.skill, 2)
	for i in 5:
		one.bomb_rng.randf()
	assert_eq(one.rng.randf(), two.rng.randf(), "the bot's own rolls don't move")
	assert_ne(Seeds.bomb_seed(77), 77)


# --- Whole matches ---


## Whole bot matches on Depot at Normal, over seeds: both bombs get thrown, most bangs dazzle an enemy, and the matches
## still play out (the match guards hold the rest).
func test_bots_throw_both_bombs_in_whole_matches_on_depot() -> void:
	var map := MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var t := SimTuning.load_default()
	var smokes := 0
	var flashes := 0
	var enemies_dazzled := 0
	var own_dazzled := 0
	var self_dazzled := 0
	var rounds := 0
	var limit := roundi(t.rounds.round_time / DT) * 14
	for seed_value: int in [1, 2]:
		var sim := Simulation.new(t, level.query(), level.mover(t.body), map.ends, map.kill_y)
		sim.nav = nav
		var state := GameState.new(seed_value, t)
		var commands: Array[PlayerCommand] = []
		for i in t.rounds.team_size * 2:
			state.characters.append(Character.new(i, 0 if i < t.rounds.team_size else 1, Vector3.ZERO, 0.0, loadout))
			commands.append(PlayerCommand.new())
		var controller := BotController.new(state, -1, map, nav, level.query(), t, bots)
		sim.start_match(state)
		controller.observe(state)
		var finished := false
		for tick in limit:
			controller.think(state, commands, DT)
			sim.step(state, commands, DT)
			controller.observe(state)
			for i in state.events.count:
				var e := state.events.items[i]
				match e.kind:
					GameEvent.Kind.GRENADE_THROW:
						if e.value == Grenade.Kind.SMOKE:
							smokes += 1
						else:
							flashes += 1
					GameEvent.Kind.DAZZLED:
						if e.target == e.actor:
							self_dazzled += 1
						elif state.characters[e.target].team == state.characters[e.actor].team:
							own_dazzled += 1
						else:
							enemies_dazzled += 1
					GameEvent.Kind.ROUND_OVER:
						rounds += 1
					GameEvent.Kind.MATCH_OVER:
						finished = true
			if finished:
				break
		assert_true(finished, "seed %d: the match was won" % seed_value)
	level.free()
	gut.p("bombs on Depot: %d rounds, %d smokes, %d flashes, dazzled: %d enemies, %d teammates, %d throwers" % [
			rounds, smokes, flashes, enemies_dazzled, own_dazzled, self_dazzled])
	assert_gt(smokes, 0, "bots smoke")
	assert_gt(flashes, 0, "bots flash")
	assert_gt(enemies_dazzled, own_dazzled, "a flash blinds the enemy more than its own team")
	assert_lt(self_dazzled, flashes / 4 + 1, "a thrower looks away from its own bang")
