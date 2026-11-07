extends GutTest
## Smoke and flash bombs (SF1): the throw (the pin, the release, the redraw, what stops one), a bomb's flight (falling,
## bouncing, settling), a smoke's cloud (its pop, growth, the smoke a line passes through, its end), a flash's dazzle
## (distance, the view's angle, walls, teammates) and what bots make of both. Headless, on a BoxWorld floor; the
## default loadout.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var cfg: GrenadeConfig = tuning.grenades
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


## A floor 60 m by 30 m, and a wall 3 m tall across x = `wall_x` if given.
func _world(wall_x: float = INF) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	if wall_x < INF:
		w.add_box(Vector3(wall_x, 1.5, 0.0), Vector3(0.2, 3.0, 30.0))
	return w


## A started match of `count` characters (the first three team 0) on `w`: [Simulation, GameState].
func _match(w: BoxWorld, count: int = 4) -> Array:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, i * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	for i in count:
		s.characters.append(Character.new(i, 0 if i < 3 else 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	return [sim, s]


func _commands(s: GameState) -> Array[PlayerCommand]:
	var out: Array[PlayerCommand] = []
	for c in s.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		out.append(cmd)
	return out


## Steps `ticks` ticks with every command as it is (one-shot presses cleared after the first).
func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int, counted: int = -1) -> int:
	var n := 0
	for t in ticks:
		sim.step(s, cmds, DT)
		if counted >= 0:
			n += s.events.count_of(counted)
		for cmd in cmds:
			cmd.throw_grenade = Grenade.Kind.NONE
	return n


## Puts `c` at `at` facing `yaw` (pitch `pitch`), standing still.
static func _place(c: Character, at: Vector3, yaw: float, pitch: float = 0.0) -> void:
	c.position = at
	c.prev_position = at
	c.velocity = Vector3.ZERO
	c.yaw = yaw
	c.pitch = pitch


static func _active(s: GameState) -> int:
	var n := 0
	for g in s.grenades:
		if g.active:
			n += 1
	return n


## A smoke bomb resting at `at`, popped `smoking` s ago, in slot 0 of `s`.
static func _smoke_at(s: GameState, at: Vector3, smoking: float) -> Grenade:
	var g := s.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 0, at, Vector3.ZERO)
	g.resting = true
	g.popped = true
	g.smoking = smoking
	return g


# --- Carrying ---


func test_everyone_carries_one_smoke_and_one_flash_and_a_respawn_refills_them() -> void:
	var m := _match(_world())
	var s: GameState = m[1]
	for c in s.characters:
		assert_eq(c.grenades.smoke, cfg.smoke_carried)
		assert_eq(c.grenades.flash, cfg.flash_carried)
	assert_eq(cfg.smoke_carried, 1)
	assert_eq(cfg.flash_carried, 1)
	var c := s.characters[0]
	c.grenades.smoke = 0
	c.grenades.flash = 0
	c.dazzle_left = 2.0
	c.respawn()
	assert_eq(c.grenades.smoke, 1)
	assert_eq(c.grenades.flash, 1)
	assert_eq(c.dazzle_left, 0.0, "a respawn ends a dazzle")
	assert_eq(s.grenades.size(), cfg.max_grenades, "the pool is made once with the state")


# --- The throw ---


func test_a_press_pulls_the_pin_puts_the_replica_down_and_the_bomb_leaves_after_the_windup() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	sim.step(s, cmds, DT)
	cmds[0].throw_grenade = Grenade.Kind.NONE
	var pin := s.events.first(GameEvent.Kind.GRENADE_PIN)
	assert_not_null(pin)
	assert_eq(pin.actor, 0)
	assert_eq(pin.value, Grenade.Kind.SMOKE)
	assert_true(Grenades.throwing(c))
	assert_true(c.armament.holstered, "the replica goes down for the throw")
	assert_eq(c.grenades.smoke, 1, "not spent until it leaves the hand")
	var ticks := ceili(cfg.windup / DT) + 1
	var thrown := _run(sim, s, cmds, ticks, GameEvent.Kind.GRENADE_THROW)
	assert_eq(thrown, 1)
	assert_eq(c.grenades.smoke, 0)
	assert_eq(_active(s), 1)


func test_the_replica_comes_back_up_after_the_throw_and_a_holstered_one_stays_away() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	cmds[0].throw_grenade = Grenade.Kind.FLASH
	var draws := _run(sim, s, cmds, ceili((cfg.windup + cfg.recover) / DT) + 3, GameEvent.Kind.DRAW)
	assert_eq(draws, 1, "drawn again once")
	assert_false(c.armament.holstered)
	assert_almost_eq(c.armament.draw_total, c.armament.replica().draw_time * cfg.redraw_scale, 1e-4)
	assert_false(Grenades.throwing(c))
	# Holstered first: it stays away.
	c.armament.holstered = true
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	draws = _run(sim, s, cmds, ceili((cfg.windup + cfg.recover) / DT) + 3, GameEvent.Kind.DRAW)
	assert_eq(draws, 0)
	assert_true(c.armament.holstered)


func test_nothing_fires_while_throwing_even_with_the_trigger_held() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	cmds[0].fire = true
	cmds[0].aim = true
	var shots := 0
	for t in ceili((cfg.windup + cfg.recover) / DT):
		sim.step(s, cmds, DT)
		cmds[0].throw_grenade = Grenade.Kind.NONE
		shots += s.events.count_of(GameEvent.Kind.SHOT)
	assert_eq(shots, 0)
	assert_false(s.characters[0].aiming)


func test_a_throw_stops_a_reload_under_way() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	c.armament.ammo[0].mag = 0
	cmds[0].reload = true
	sim.step(s, cmds, DT)
	cmds[0].reload = false
	assert_true(c.armament.reloading())
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	sim.step(s, cmds, DT)
	assert_false(c.armament.reloading())


func test_a_press_is_refused_with_none_left_while_throwing_between_rounds_or_out() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	c.grenades.flash = 0
	cmds[0].throw_grenade = Grenade.Kind.FLASH
	assert_eq(_run(sim, s, cmds, 1, GameEvent.Kind.GRENADE_PIN), 0, "none left")
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(sim, s, cmds, 1, GameEvent.Kind.GRENADE_PIN), 1)
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(sim, s, cmds, 1, GameEvent.Kind.GRENADE_PIN), 0, "already throwing")
	var other := s.characters[1]
	Elimination.eliminate(other, 3, s.characters, sim.ends)
	cmds[1].throw_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(sim, s, cmds, 1, GameEvent.Kind.GRENADE_PIN), 0, "out of play")
	s.round_state.phase = RoundState.Phase.OVER
	cmds[2].throw_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(sim, s, cmds, 1, GameEvent.Kind.GRENADE_PIN), 0, "between rounds")


func test_a_press_is_refused_with_every_slot_taken() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	for g in s.grenades:
		g.launch(Grenade.Kind.SMOKE, 3, Vector3(20.0, 0.04, 0.0), Vector3.ZERO)
		g.resting = true
		g.popped = true
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(sim, s, cmds, 1, GameEvent.Kind.GRENADE_PIN), 0)


func test_a_hit_during_the_windup_drops_the_throw_and_keeps_the_bomb() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	cmds[0].throw_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 2)
	Elimination.eliminate(c, 3, s.characters, sim.ends)
	var thrown := _run(sim, s, cmds, ceili(cfg.windup / DT) + 2, GameEvent.Kind.GRENADE_THROW)
	assert_eq(thrown, 0)
	assert_false(Grenades.throwing(c))
	assert_eq(c.grenades.flash, 1)


func test_no_vault_starts_mid_throw_but_one_does_after_it() -> void:
	var w := _world()
	# A 0.85 m wall 0.7 m ahead of character 0, which faces -Z.
	w.add_box(Vector3(0.0, 0.425, -0.85), Vector3(6.0, 0.85, 0.3))
	var m := _match(w)
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0)
	_run(sim, s, cmds, 2)
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	sim.step(s, cmds, DT)
	cmds[0].throw_grenade = Grenade.Kind.NONE
	cmds[0].jump = true
	sim.step(s, cmds, DT)
	assert_true(Grenades.throwing(c))
	assert_false(c.vault.active, "the bomb leaves the hand first")
	cmds[0].jump = false
	# The press hopped instead; a second after it the throw is over and the feet are down again.
	_run(sim, s, cmds, 60)
	assert_false(Grenades.throwing(c))
	assert_true(c.grounded)
	cmds[0].jump = true
	sim.step(s, cmds, DT)
	assert_true(c.vault.active, "the same wall is vaulted once the throw is over")


func test_the_bomb_leaves_the_eyes_along_the_lofted_view_at_the_throw_speed() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
	cmds[0].yaw = -PI * 0.5
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	var e: GameEvent = null
	for t in ceili(cfg.windup / DT) + 2:
		sim.step(s, cmds, DT)
		cmds[0].throw_grenade = Grenade.Kind.NONE
		var found := s.events.first(GameEvent.Kind.GRENADE_THROW)
		if found != null:
			assert_almost_eq(found.direction.length(), cfg.throw_speed, 0.05)
			assert_gt(found.direction.x, 0.0, "yaw -90 degrees faces +X")
			assert_almost_eq(found.direction.y / found.direction.x, tan(cfg.loft), 0.01, "lofted")
			assert_almost_eq(found.position, Lean.eye(c, tuning.body, tuning.hits), Vector3.ONE * 1e-3)
			e = found
	assert_not_null(e)


# --- Flight ---


func test_a_thrown_bomb_lands_on_the_floor_and_settles() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
	cmds[0].yaw = -PI * 0.5
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	var bounces := _run(sim, s, cmds, 150, GameEvent.Kind.GRENADE_BOUNCE)
	var g := s.grenades[0]
	assert_true(g.active)
	assert_true(g.resting, "settled within 2.5 s")
	assert_gt(bounces, 0, "it bounced first")
	assert_almost_eq(g.position.y, cfg.radius, 0.01, "lying on the floor")
	assert_gt(g.position.x, -10.0 + 8.0, "a good throw's length on")
	assert_lt(g.position.x, -10.0 + 25.0)


func test_a_bomb_bounces_back_off_a_wall() -> void:
	var w := _world(-5.0)
	var m := _match(w)
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
	cmds[0].yaw = -PI * 0.5
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 150)
	var g := s.grenades[0]
	assert_lt(g.position.x, -5.0, "stopped on the thrower's side of the wall")
	assert_true(g.resting)


func test_a_bomb_bounces_off_a_body_in_its_way_and_hits_nobody() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
	_place(s.characters[3], Vector3(-7.0, 0.0, 0.0), PI * 0.5)
	cmds[0].yaw = -PI * 0.5
	cmds[0].pitch = -0.2
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	var bounces := _run(sim, s, cmds, 150, GameEvent.Kind.GRENADE_BOUNCE)
	var g := s.grenades[0]
	assert_gt(bounces, 0)
	assert_lt(g.position.x, -7.0 - tuning.body.radius, "stopped short of the body it struck")
	assert_true(g.resting, "settled on the floor, not on the body")
	assert_almost_eq(g.position.y, cfg.radius, 0.01)
	for x in s.characters:
		assert_true(Elimination.is_in_play(x), "a bomb hits nobody")


func test_a_bomb_passes_its_thrower_and_those_out_of_play() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
	_place(s.characters[3], Vector3(-7.0, 0.0, 0.0), PI * 0.5)
	s.characters[3].status = Character.Status.OUT
	cmds[0].yaw = -PI * 0.5
	cmds[0].pitch = -0.2
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 150)
	assert_gt(s.grenades[0].position.x, -7.0 + tuning.body.radius, "through the one out of play")


## BP6: a bomb thrown from cover past a teammate at the thrower's side passes through them for the first moment of its
## flight (GrenadeConfig.team_pass_time), so it never bounces back off them onto the thrower; an enemy there stops it.
func test_a_fresh_bomb_passes_a_teammate_beside_the_thrower_but_not_an_enemy() -> void:
	for mate: bool in [true, false]:
		var m := _match(_world())
		var sim: Simulation = m[0]
		var s: GameState = m[1]
		var cmds := _commands(s)
		_place(s.characters[0], Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
		var near := s.characters[1] if mate else s.characters[3]
		_place(near, Vector3(-7.8, 0.0, 0.1), PI * 0.5)
		var away := s.characters[3] if mate else s.characters[1]
		_place(away, Vector3(-10.0, 0.0, 12.0), PI * 0.5)
		cmds[0].yaw = -PI * 0.5
		cmds[0].pitch = -0.1
		cmds[0].throw_grenade = Grenade.Kind.SMOKE
		var bounces := _run(sim, s, cmds, 150, GameEvent.Kind.GRENADE_BOUNCE)
		var g := s.grenades[0]
		if mate:
			assert_gt(g.position.x, -7.8 + tuning.body.radius, "on past the teammate, never back at the thrower")
		else:
			assert_gt(bounces, 0)
			assert_lt(g.position.x, -7.8, "off the enemy, back on the thrower's side")
	assert_gt(cfg.team_pass_time, 0.0)
	assert_lt(cfg.team_pass_time * cfg.throw_speed, 5.0, "past a few metres a teammate stops it, as anyone does")


func test_a_bomb_off_the_level_is_gone() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var g := s.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 0, Vector3(100.0, 2.0, 0.0), Vector3.ZERO)
	_run(sim, s, _commands(s), 120)
	assert_false(g.active)


# --- Smoke ---


func test_a_smoke_pops_at_its_fuse_and_its_cloud_grows_holds_thins_and_ends() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var g := s.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 0, Vector3(0.0, 0.04, 0.0), Vector3.ZERO)
	var pops := _run(sim, s, cmds, ceili(cfg.smoke_fuse / DT) + 1, GameEvent.Kind.SMOKE_POP)
	assert_eq(pops, 1)
	assert_true(g.popped)
	assert_lt(Grenades.cloud_scale(g, cfg), 0.1, "small at first")
	_run(sim, s, cmds, ceili(cfg.smoke_grow / DT) + 1)
	assert_eq(Grenades.cloud_scale(g, cfg), 1.0, "full grown")
	assert_eq(Grenades.cloud_density(g, cfg), 1.0)
	_run(sim, s, cmds, ceili((cfg.smoke_time - cfg.smoke_grow - cfg.smoke_fade * 0.5) / DT))
	assert_almost_eq(Grenades.cloud_density(g, cfg), 0.5, 0.05, "thinning")
	_run(sim, s, cmds, ceili(cfg.smoke_fade / DT) + 2)
	assert_false(g.active, "gone once its time is up")


func test_smoke_depth_is_the_line_through_the_cloud_times_its_density() -> void:
	var s := GameState.new(1, tuning)
	var g := _smoke_at(s, Vector3.ZERO, cfg.smoke_grow + 1.0)
	var mid := Grenades.cloud_middle(g, cfg)
	var a := mid + Vector3(-10.0, 0.0, 0.0)
	var b := mid + Vector3(10.0, 0.0, 0.0)
	assert_almost_eq(Grenades.smoke_depth(s.grenades, cfg, a, b), cfg.smoke_radius * 2.0, 1e-3, "straight through")
	var over := mid + Vector3(0.0, cfg.smoke_height + 0.1, 0.0)
	assert_eq(Grenades.smoke_depth(s.grenades, cfg, over - Vector3(10.0, 0.0, 0.0), over + Vector3(10.0, 0.0, 0.0)), 0.0,
			"over the top")
	assert_almost_eq(Grenades.smoke_depth(s.grenades, cfg, a, mid), cfg.smoke_radius, 1e-3, "to the middle")
	assert_lt(Grenades.smoke_depth(s.grenades, cfg, a, b, 1.0), cfg.smoke_radius * 2.0, "stops counting past most")
	g.smoking = cfg.smoke_time - cfg.smoke_fade * 0.5
	assert_almost_eq(Grenades.smoke_depth(s.grenades, cfg, a, b), cfg.smoke_radius, 1e-3, "half as thick thinning")
	g.popped = false
	assert_eq(Grenades.smoke_depth(s.grenades, cfg, a, b), 0.0, "no cloud before the pop")


func test_a_flash_has_no_cloud() -> void:
	var s := GameState.new(1, tuning)
	var g := _smoke_at(s, Vector3.ZERO, 5.0)
	g.kind = Grenade.Kind.FLASH
	assert_eq(Grenades.smoke_depth(s.grenades, cfg, Vector3(-9.0, 1.0, 0.0), Vector3(9.0, 1.0, 0.0)), 0.0)


func test_bbs_fly_through_smoke() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var shooter := s.characters[0]
	var target := s.characters[3]
	_place(shooter, Vector3(-8.0, 0.0, 0.0), -PI * 0.5)
	_place(target, Vector3(8.0, 0.0, 0.0), PI * 0.5)
	_smoke_at(s, Vector3(0.0, 0.04, 0.0), cfg.smoke_grow + 1.0)
	# No spread, and the shooter settled into its stance a tick first, so the aim is the BB's line (HV1: the hit area is
	# the drawn figure's, so a lucky spread over the chest no longer grazes a head that isn't there).
	var arms := shooter.armament
	var steady := arms.replicas[arms.active].duplicate() as ReplicaConfig
	steady.spread_deg = 0.0
	arms.replicas[arms.active] = steady
	cmds[0].yaw = -PI * 0.5
	sim.step(s, cmds, DT)
	var eye := Lean.eye(shooter, tuning.body, tuning.hits)
	var chest := BotSenses.body_point(target, tuning.hits, 0.7)
	assert_gt(Grenades.smoke_depth(s.grenades, cfg, eye, chest), 5.0, "the line runs through the cloud")
	cmds[0].pitch = atan2(chest.y - eye.y, chest.x - eye.x) + 0.004
	cmds[0].fire = true
	var hits := 0
	for t in 60:
		sim.step(s, cmds, DT)
		cmds[0].fire = false
		hits += s.events.count_of(GameEvent.Kind.CHARACTER_HIT)
	assert_eq(hits, 1, "a BB through the cloud still hits")


# --- Flash ---


## A flash resting at `at` thrown by character 0, about to go bang.
static func _flash_at(s: GameState, at: Vector3, c: GrenadeConfig) -> Grenade:
	var g := s.grenades[0]
	g.launch(Grenade.Kind.FLASH, 0, at, Vector3.ZERO)
	g.resting = true
	g.age = c.flash_fuse - 0.001
	return g


func test_a_flash_goes_bang_at_its_fuse_and_dazzles_someone_looking_at_it_up_close_the_longest() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var c := s.characters[3]
	_place(c, Vector3(0.0, 0.0, 4.0), 0.0) # facing -Z, at the bang
	for i in 3:
		_place(s.characters[i], Vector3(-25.0, 0.0, i * 2.0), 0.0)
	var g := _flash_at(s, Vector3(0.0, 0.04, 0.0), cfg)
	sim.step(s, _commands(s), DT)
	assert_false(g.active, "a flash is gone at its bang")
	assert_eq(s.events.count_of(GameEvent.Kind.FLASH_BANG), 1)
	var e := s.events.first(GameEvent.Kind.DAZZLED)
	assert_not_null(e)
	assert_eq(e.target, 3)
	assert_eq(e.actor, 0)
	assert_almost_eq(c.dazzle_left, cfg.dazzle_max, 0.02)
	assert_eq(c.dazzle_total, c.dazzle_left)


func test_a_dazzle_is_shorter_looking_away_and_further_off_and_none_past_its_reach() -> void:
	var eye := Vector3(0.0, 1.6, 0.0)
	var ahead := Vector3(0.0, 0.0, -1.0)
	var at := Vector3(0.0, 1.6, -4.0)
	assert_eq(Grenades.dazzle_strength(eye, ahead, at, cfg), 1.0, "looking at it up close")
	assert_almost_eq(Grenades.dazzle_strength(eye, -ahead, at, cfg), cfg.behind_share, 1e-4, "looking straight away")
	var side := Grenades.dazzle_strength(eye, Vector3(1.0, 0.0, 0.0), at, cfg)
	assert_gt(side, cfg.behind_share)
	assert_lt(side, 1.0)
	var mid := Vector3(0.0, 1.6, -(cfg.flash_full + cfg.flash_reach) * 0.5)
	assert_almost_eq(Grenades.dazzle_strength(eye, ahead, mid, cfg), 0.5, 1e-3, "half way out")
	assert_eq(Grenades.dazzle_strength(eye, ahead, Vector3(0.0, 1.6, -cfg.flash_reach - 0.1), cfg), 0.0)
	assert_eq(Grenades.dazzle_time(0.0, cfg), 0.0)
	assert_eq(Grenades.dazzle_time(cfg.dazzle_least, cfg), cfg.dazzle_min, "a glance still dazzles a moment")
	assert_eq(Grenades.dazzle_time(cfg.dazzle_least * 0.5, cfg), 0.0, "turned nearly away, nothing (SF2)")
	assert_eq(Grenades.dazzle_time(1.0, cfg), cfg.dazzle_max)


func test_a_wall_between_shields_from_a_flash_and_teammates_are_dazzled_too() -> void:
	var m := _match(_world(3.0))
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var behind := s.characters[3]
	var mate := s.characters[1]
	_place(behind, Vector3(5.0, 0.0, 0.0), PI * 0.5) # behind the wall, facing it
	_place(mate, Vector3(-3.0, 0.0, 0.0), -PI * 0.5) # the thrower's teammate, facing the bang
	_place(s.characters[0], Vector3(-25.0, 0.0, 0.0), 0.0)
	_place(s.characters[2], Vector3(-25.0, 0.0, 4.0), 0.0)
	_flash_at(s, Vector3(0.0, 0.04, 0.0), cfg)
	sim.step(s, _commands(s), DT)
	assert_eq(behind.dazzle_left, 0.0, "the wall shields")
	assert_gt(mate.dazzle_left, 0.0, "a teammate in the open is dazzled")


func test_a_shorter_dazzle_keeps_the_longer_one_and_makes_no_event() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var c := s.characters[3]
	_place(c, Vector3(0.0, 0.0, 4.0), 0.0)
	for i in 3:
		_place(s.characters[i], Vector3(-25.0, 0.0, i * 2.0), 0.0)
	c.dazzle_left = cfg.dazzle_max + 1.0
	c.dazzle_total = c.dazzle_left
	_flash_at(s, Vector3(0.0, 0.04, 0.0), cfg)
	sim.step(s, _commands(s), DT)
	assert_eq(s.events.count_of(GameEvent.Kind.FLASH_BANG), 1)
	assert_eq(s.events.count_of(GameEvent.Kind.DAZZLED), 0, "nothing changed for it")
	assert_almost_eq(c.dazzle_left, cfg.dazzle_max + 1.0, DT * 1.5)


func test_a_dazzle_wears_off() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var c := s.characters[0]
	c.dazzle_left = 1.0
	c.dazzle_total = 1.0
	_run(sim, s, _commands(s), 30)
	assert_almost_eq(c.dazzle_left, 0.5, 0.02)
	_run(sim, s, _commands(s), 40)
	assert_eq(c.dazzle_left, 0.0)


# --- Rounds and the range ---


func test_a_new_round_clears_the_bombs() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	_smoke_at(s, Vector3.ZERO, 1.0)
	s.grenades[0].smoking = 0.0
	# Every Beta out: the round ends, and the next starts after its reset delay.
	Elimination.eliminate(s.characters[3], 0, s.characters, sim.ends)
	var ticks := ceili((tuning.rounds.reset_delay + 2.0) / DT)
	var started := false
	for t in ticks:
		sim.step(s, _commands(s), DT)
		if s.events.first(GameEvent.Kind.ROUND_START) != null:
			started = true
			break
	assert_true(started)
	assert_eq(_active(s), 0)


func test_on_the_range_bombs_come_back_after_every_throw() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	s.round_state.practice = true
	var cmds := _commands(s)
	cmds[0].throw_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, ceili((cfg.windup + cfg.recover) / DT) + 2)
	assert_eq(s.characters[0].grenades.flash, 1)


# --- Bots ---


## Bot 0 at the origin facing -Z, its enemy `away` m in front: [Bot, BotWorld].
func _duel(away: float) -> Array:
	var bots := BotConfig.load_default()
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(0.0, 0.0, -away), 0.0, loadout)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = bots
	w.query = _world()
	w.planner = RoundPlanner.new(1)
	w.characters = [me, foe]
	w.time = 10.0
	w.grenades = Grenades.make_pool(2)
	return [Bot.new(me, 1, bots.skill_for(&"easy"), 2), w]


func test_a_bot_cannot_see_through_a_smoke_cloud_but_does_once_it_has_gone() -> void:
	var d := _duel(15.0)
	var b: Bot = d[0]
	var w: BotWorld = d[1]
	var foe := w.characters[1]
	assert_gt(BotSenses.visible_part(b.character, foe, w), 0.0, "seen in the open")
	var g := w.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 1, Vector3(0.0, 0.04, -7.5), Vector3.ZERO)
	g.popped = true
	g.smoking = cfg.smoke_grow + 1.0
	assert_eq(BotSenses.visible_part(b.character, foe, w), 0.0, "hidden by the cloud")
	assert_false(BotSenses.sees_spot(b.character, foe.position, 30.0, w), "nor the spot seen empty")
	g.smoking = cfg.smoke_time - 0.05
	assert_gt(BotSenses.visible_part(b.character, foe, w), 0.0, "seen through the last thin wisp")
	g.active = false
	assert_gt(BotSenses.visible_part(b.character, foe, w), 0.0)


func test_a_bot_sees_someone_beside_it_in_a_cloud() -> void:
	var d := _duel(0.6)
	var b: Bot = d[0]
	var w: BotWorld = d[1]
	var g := w.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 1, Vector3(0.0, 0.04, 0.0), Vector3.ZERO)
	g.popped = true
	g.smoking = cfg.smoke_grow + 1.0
	assert_gt(BotSenses.visible_part(b.character, w.characters[1], w), 0.0)


func test_a_dazzled_bot_sees_nothing_and_ducks_where_it_stands() -> void:
	var d := _duel(10.0)
	var b: Bot = d[0]
	var w: BotWorld = d[1]
	var me := b.character
	me.dazzle_left = 2.0
	assert_eq(BotSenses.visible_part(me, w.characters[1], w), 0.0)
	assert_false(BotSenses.sees_spot(me, w.characters[1].position, 30.0, w))
	var cmd := PlayerCommand.new()
	BotBrain.think(b, w, cmd, DT)
	assert_true(cmd.crouch)
	assert_false(cmd.fire)
	assert_eq(cmd.forward, 0.0)
	assert_false(b.target_visible)


# --- Allocation ---


func test_throws_flights_smoke_and_bangs_allocate_nothing_once_warm() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var kinds: Array[Grenade.Kind] = [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]
	var steps := func(ticks: int) -> void:
		for t in ticks:
			for c in s.characters:
				if not Grenades.throwing(c):
					c.grenades.refill()
				cmds[c.id].throw_grenade = kinds[(t / 30 + c.id) % 2] if t % 30 == c.id else Grenade.Kind.NONE
				cmds[c.id].yaw = c.id * 1.3
			sim.step(s, cmds, DT)
			s.characters[0].dazzle_left = 0.0
	steps.call(900)
	# The tick's events grow to the busiest tick seen (SimEvents): grown up front, so a busier tick to come isn't counted.
	for i in 32:
		s.events.add(GameEvent.Kind.SHOT)
	s.events.clear()
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	steps.call(600)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
