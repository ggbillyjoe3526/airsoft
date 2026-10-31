class_name Simulation
extends RefCounted
## The fixed 60 Hz step (the browser game's sim/simulation.ts): everything the rules need from outside (tuning, the
## level, the map's ends) and one `step` that advances a GameState by a tick. The player and bots are indistinguishable
## here: each character follows the PlayerCommand stored under its id. Nodes call `step` from _physics_process and read
## the state and its events; headless tests call it directly.
##
## Order within a tick: each character moves (stance, pace, jump, collision; a Jump press at a low obstacle vaults it
## instead, and a vault under way follows its path), its legs swing, it leans and its aim settles, then it uses its
## replica (BBs leave from the new, leaned eye position); then every BB flies (hitting the level, bodies or range
## targets); then the round flow, or in practice (RoundState.practice) the range's targets, the timed challenge and full
## spares instead.
## Characters without a command keep their view and stand still; hit characters follow the hit-calling routine instead
## of their command, and once out and standing in the dead zone they are only timed. A squad order in a command becomes
## an event for the bots' controller and changes nothing here, and so does a ping (PN1). A run into a noisy prop knocks it, and a BB landing hard
## on steel rings it (PropNoise, NP1). The weapon torch switches after the replica (Torch); hit, it goes out. The
## magazine hand-off's press is taken with the squad order, before the character moves (out of play it is refused), and
## the magazines in the air land after the BBs fly, so a catcher hit this tick loses it (MagShare, MH1). A smoke or
## flash bomb's press is taken after the vault (none while vaulting) and puts the replica down before it is used; the
## throw under way lets go of the trigger and sights and releases the bomb after the replica, and the bombs fly, pop and
## go bang after the magazines land; a new round clears them (Grenades, SF1). A Use press is taken after the bomb's,
## before the character moves (a door it opens is open for its step), a walk-off opens a shut door it walks into, the
## swings run on after the bombs, and each match and round starts with the doors as the map sets them (Doors, DO1).

var tuning: SimTuning = null
var query: WorldQuery = null
var mover: CharacterMover = null
## The map's two ends: spawns and dead zones.
var ends: Array[MapEnd] = []
## Anything below this height has left the level (map data).
var kill_y: float = -10.0
## The map's nav grid, for walk-off routes round cover (set once the map is built); null walks them off in a straight
## line, as headless BoxWorld tests do.
var nav: NavGrid = null
## The level's noisy props (WorldQuery.block_kinds that tuning.noise lists), made with the simulation.
var noise: PropNoise = null
## The magazine hand-off's rules (MH1), made with the simulation.
var mag_share: MagShare = null
## The smoke and flash bombs' rules (SF1), made with the simulation.
var grenades: Grenades = null
## The hinged doors' rules (DO1), made with the simulation.
var doors: Doors = null
## Followed by characters with no command this tick.
var _idle: PlayerCommand = PlayerCommand.new()
## Followed by characters that have been hit: they take no orders from their controller.
var _eliminated: PlayerCommand = PlayerCommand.new()
## Followed while vaulting (the view, the trigger as the vault found it), and the first command after a vault, with the
## presses made during it (Vault).
var _vaulting: PlayerCommand = PlayerCommand.new()
var _after_vault: PlayerCommand = PlayerCommand.new()
## Followed while throwing a bomb: the command with its trigger and sights let go (Grenades.throwing_command).
var _throwing: PlayerCommand = PlayerCommand.new()
## Where a ping's view met the field (one at a time).
var _ping_hit: RayHit = RayHit.new()


func _init(sim_tuning: SimTuning, world: WorldQuery, character_mover: CharacterMover, map_ends: Array[MapEnd],
		level_kill_y: float) -> void:
	tuning = sim_tuning
	query = world
	mover = character_mover
	ends = map_ends
	kill_y = level_kill_y
	noise = PropNoise.new(sim_tuning.noise, world)
	mag_share = MagShare.new(sim_tuning, world)
	grenades = Grenades.new(sim_tuning, world)
	doors = Doors.new(sim_tuning, world)


## A fresh match: a new breeze, everyone at their end's spawns with the bombs everyone carries, round 1 live.
func start_match(state: GameState) -> void:
	state.events.clear()
	state.match_number += 1
	state.off_record = state.dev_content or state.cheats.any()
	state.wind.draw(Seeds.wind_seed(state.match_seed, state.match_number), tuning.wind)
	for t in state.mag_tosses:
		t.active = false
	Grenades.clear(state.grenades)
	doors.reset(state.doors)
	for c in state.characters:
		c.grenades.carry(tuning.grenades.smoke_carried, tuning.grenades.flash_carried)
	Round.start_match(state.round_state, state.characters, ends, state.bbs, tuning, state.events)


## Advances `state` by one tick of `dt` seconds (none at all when `dt` isn't positive). `commands[id]` drives character `id` (null or missing: no input).
func step(state: GameState, commands: Array[PlayerCommand], dt: float) -> void:
	state.events.clear()
	# A step of no time is no tick: speeds are worked out as distance over dt.
	if not (dt > 0.0):
		return
	# Once the round is decided it's a cease-fire, as after the end whistle at a site: nobody can fire, and BBs still in
	# the air stop on whoever they reach without knocking them out.
	var live := state.round_state.is_live()
	# The hand-off is for rounds only: never on the range, where the spares stay full.
	var sharing := live and not state.round_state.practice
	Elimination.plan_walk_off_routes(state.characters, nav)
	var noisy := noise.count() > 0
	var has_doors := doors.count() > 0
	# A state the match never started for (a test's, a tool's) meets the doors as the map sets them.
	if has_doors and state.doors.count() != doors.count():
		doors.reset(state.doors)
	if noisy:
		noise.prepare(state)
	for c in state.characters:
		c.prev_position = c.position
		c.prev_crouch_amount = c.crouch_amount
		c.prev_lean = c.lean
		c.prev_walk_cycle = c.walk_cycle
		c.prev_yaw = c.yaw
		c.prev_pitch = c.pitch
		_squad_order(c, commands, live, state.events)
		_mag_hand_off(c, commands, sharing, state)
		var in_play := Elimination.is_in_play(c)
		# Hit, the torch goes out as the hand goes up (silently: the hit call is the sound).
		if not in_play:
			Torch.put_out(c)
		# Out and standing in the dead zone: only its clock runs (audit SIM-15).
		if Elimination.is_parked(c):
			Elimination.step(c, tuning.hits, dt)
			continue
		var cmd: PlayerCommand = null
		if in_play:
			cmd = commands[c.id] if c.id >= 0 and c.id < commands.size() else null
		else:
			cmd = Elimination.fill_eliminated_command(c, tuning, _eliminated)
		if cmd == null:
			cmd = _idle
			cmd.reset(c.yaw, c.pitch)
		# The torch's thumb switch works through a vault too (the vault's own command drops other presses until its end).
		var toggle_torch := in_play and cmd.toggle_torch
		# A Jump press at a low obstacle vaults it instead; while vaulting only the view follows the command, the trigger
		# stays as it was and other presses wait for the vault's end (BP5).
		if in_play and not c.vault.active:
			cmd = Vault.with_held_presses(c.vault, cmd, _after_vault)
			# No vault mid-throw: the bomb leaves the hand first.
			if not Grenades.throwing(c):
				Vault.try_start(c, cmd, tuning, query, state.events)
		if in_play and c.vault.active:
			cmd = Vault.vaulting_command(c, cmd, _vaulting)
		# A bomb's press puts the replica down; while throwing, the trigger and sights are let go.
		if in_play:
			grenades.press(c, cmd, live, state.grenades, state.events)
			if Grenades.throwing(c):
				cmd = Grenades.throwing_command(cmd, _throwing)
			if cmd.use_door and has_doors:
				doors.press(c, cmd.door_to_use, state)
		elif has_doors and not c.vault.active:
			doors.walk_through(c, cmd, state)
		if in_play:
			Aiming.step(c, cmd, tuning.movement, dt)
		else:
			c.aiming = false
			c.aim_raise = 0.0
		# A vault under way finishes even if its vaulter is hit meanwhile: nobody is left hanging over the obstacle.
		if c.vault.active:
			Vault.step(c, cmd, tuning, dt, mover)
		else:
			Movement.step(c, cmd, tuning.movement, tuning.accuracy, dt, mover)
			# Ran into a noisy prop: it knocks. A vault makes its own noise; someone hit and walking off makes none.
			if in_play and noisy:
				noise.knock(c, tuning.body, dt, state)
		c.rescue_if_out_of_world(kill_y)
		Hitbox.step_walk_cycle(c, tuning.hits) # the legs' swing, for their hit volumes and the drawn figure
		Lean.step(c, cmd, tuning, query, dt)
		Accuracy.step(c, tuning.movement, tuning.accuracy, dt)
		if not in_play:
			Elimination.step(c, tuning.hits, dt)
			continue
		Footsteps.step(c, tuning.footsteps, state.events, query, tuning.noise)
		# Fired on the run the kick grows, as the spread does (the owner's 0.1 Dev 5 note 9).
		var kick := tuning.accuracy.sprint_kick if c.sprinting else 1.0
		# BBs leave from the eyes, wherever a lean puts them; none through a vault or the moment after it.
		Armament.step(c, cmd, Lean.eye(c, tuning.body, tuning.hits), kick, live and c.fire_lockout <= 0.0, state.bbs,
				state.rng, state.events, tuning, dt, 0.0 if c.vault.active else c.fire_lockout)
		# The bomb leaves the hand from the eyes, as BBs do; the replica comes back up after it.
		grenades.step_throw(c, Lean.eye(c, tuning.body, tuning.hits), state.grenades, state.events, dt)
		# After the armament and the throw: a switch, holster or throw this tick to no light in hand puts the torch out.
		Torch.step(c, toggle_torch, state.events, dt)
		# A ping looks where the view is now, after the turn and the shot's kick.
		_ping(c, commands, live and not state.round_state.practice, state.events)
	var first_bb_event := state.events.count
	BBStep.step(state.bbs, state.characters, query, tuning, kill_y, not live, ends, state.events, dt,
			state.wind.at(state.time), state.rng, state.targets)
	if noisy:
		noise.ring(state, first_bb_event)
	# After the BBs: a catcher hit this tick is out of play, and the magazine is lost.
	mag_share.step(state, sharing, dt)
	grenades.step(state, dt, kill_y)
	if has_doors:
		Doors.step(state.doors, dt)
	if state.round_state.practice:
		# Practice has no rounds: it's always live, with no clock.
		RangeTargets.step(state.targets, tuning, dt, state.rng)
		state.challenge.step(state.targets, state.events, tuning.targets, dt, state.rng, state.cheats.any())
		for c in state.characters:
			RangeTargets.refill_spares(c.armament)
			# Bombs too: practise as many throws as you like.
			if not Grenades.throwing(c):
				c.grenades.refill()
	else:
		Round.step(state.round_state, state.characters, ends, state.bbs, tuning, state.events, dt)
		# A new round: the last round's bombs and smoke are gone.
		if state.events.first(GameEvent.Kind.ROUND_START) != null:
			Grenades.clear(state.grenades)
			doors.reset(state.doors)
	state.tick += 1
	state.time += dt


## A squad order in `c`'s command this tick: a SQUAD_ORDER event from a character in play in a `live` round, otherwise
## a refused one (out, or between rounds).
static func _squad_order(c: Character, commands: Array[PlayerCommand], live: bool, events: SimEvents) -> void:
	var cmd: PlayerCommand = commands[c.id] if c.id >= 0 and c.id < commands.size() else null
	if cmd == null or cmd.squad_order == SquadOrder.Kind.NONE:
		return
	var taken := live and Elimination.is_in_play(c)
	var e := events.add(GameEvent.Kind.SQUAD_ORDER if taken else GameEvent.Kind.SQUAD_ORDER_REFUSED)
	e.actor = c.id
	e.value = cmd.squad_order
	e.value2 = 1 if cmd.order_from_wheel else 0


## A ping in `c`'s command this tick (PN1), from a character in play in a `live` round (never on the range): a PING
## event along its view, recoil and all, from its eyes, saying where that view meets the field within PingConfig.reach
## (or nothing: the sky). The bots' controller makes it a ping (Pings); nothing changes here. One placed on the
## full-screen map (FM1) has value 2 and the point picked as its position; a Go there (ping_move) has value2 1, and the
## controller hands it out as that order.
func _ping(c: Character, commands: Array[PlayerCommand], live: bool, events: SimEvents) -> void:
	var cmd: PlayerCommand = commands[c.id] if c.id >= 0 and c.id < commands.size() else null
	if cmd == null or not cmd.ping or not live:
		return
	if cmd.ping_on_map:
		var on_map := events.add(GameEvent.Kind.PING)
		on_map.actor = c.id
		on_map.value = GameEvent.PING_ON_MAP
		on_map.value2 = 1 if cmd.ping_move else 0
		on_map.position = cmd.ping_target
		return
	var eye := Lean.eye(c, tuning.body, tuning.hits)
	var pitch := clampf(c.pitch + c.armament.recoil, -PI * 0.5, PI * 0.5)
	var flat := cos(pitch)
	var dir := Vector3(-sin(c.yaw) * flat, sin(pitch), -cos(c.yaw) * flat)
	var reach := tuning.pings.reach
	var e := events.add(GameEvent.Kind.PING)
	e.actor = c.id
	e.value2 = 1 if cmd.ping_move else 0
	e.position = eye
	e.direction = dir
	if reach > 0.0 and query.ray(eye, eye + dir * reach, _ping_hit):
		e.value = 1
		e.reach = _ping_hit.fraction * reach


## The magazine hand-off pressed in `c`'s command this tick (MH1): a toss, an ask or a refusal (MagShare.press).
func _mag_hand_off(c: Character, commands: Array[PlayerCommand], sharing: bool, state: GameState) -> void:
	var cmd: PlayerCommand = commands[c.id] if c.id >= 0 and c.id < commands.size() else null
	if cmd != null and cmd.mag_hand_off:
		mag_share.press(c, state, sharing)
