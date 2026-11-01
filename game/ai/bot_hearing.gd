class_name BotHearing
## What the bots hear and feel of a tick (the browser game's ai/hearing.ts, without cases): gunfire (as far as the
## shooter's replica is heard: a silencer halves it), a teammate's hit call, running, sprinting, landing and vaulting
## feet (further on loud ground: the event's carry), a rattling magazine, a run into a noisy prop (heard as a step on
## whoever knocked it, out to the prop's reach), a BB ringing off steel (faint: see _hear), enemy BBs landing close, an
## enemy's smoke popping or flash going bang (SF2), and a door an enemy opens or shuts, heard where the door is out to
## its reach through any walls (DO1). Each gives a rough guess of where the enemy is, off by up to hearing_error of the
## distance; walls between muffle a sound to wall_hearing of its range, judged by SoundPath's rays, as the player's
## muffling is. Hearing never counts as sight: a bot still reacts when the enemy then appears. Reads the tick's events
## after the step; writes only the bots' memory. Allocates nothing.

static var _hit: RayHit = RayHit.new()


## After a simulation tick: what the bots hear and feel of the tick's events.
static func observe(state: GameState, w: BotWorld) -> void:
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		match e.kind:
			GameEvent.Kind.SHOT:
				var shooter := _character(w, e.actor)
				if shooter != null:
					var r := shooter.armament.replica()
					var heard := w.cfg.hearing_distance * (r.heard_scale if r != null else 1.0)
					_hear(w, shooter, e.position, shooter.position, heard, null)
			GameEvent.Kind.CHARACTER_HIT:
				_hit_call(e, w)
			GameEvent.Kind.FOOTSTEP:
				var walker := _character(w, e.actor)
				if walker != null and Elimination.is_in_play(walker):
					_hear(w, walker, walker.position, walker.position, _footstep_range(e.value, w.cfg) * e.carry, null)
			GameEvent.Kind.VAULT:
				var vaulter := _character(w, e.actor)
				if vaulter != null and Elimination.is_in_play(vaulter):
					_hear(w, vaulter, vaulter.position, vaulter.position, w.cfg.footstep_hearing_vault, null)
			GameEvent.Kind.BB_IMPACT:
				_near_miss(e, w)
			GameEvent.Kind.PROP_KNOCK:
				var knocker := _character(w, e.actor)
				if knocker != null and Elimination.is_in_play(knocker):
					_hear(w, knocker, e.position, knocker.position, e.reach, null)
			GameEvent.Kind.FLASH_BANG, GameEvent.Kind.SMOKE_POP:
				# An enemy's bomb going off (SF2): news of someone where it went off, a flash's from further; none of a
				# thrower already out (BP2: one hit before the pop sent bots searching for nobody, as a door's never does).
				var thrower := _character(w, e.actor)
				if thrower != null and Elimination.is_in_play(thrower):
					var reach := w.cfg.bang_hearing if e.kind == GameEvent.Kind.FLASH_BANG else w.cfg.pop_hearing
					_hear(w, thrower, e.position, e.position, reach, null, e.position)
			GameEvent.Kind.DOOR:
				var user := _character(w, e.actor)
				if user != null and Elimination.is_in_play(user):
					_hear(w, user, e.position, e.position, e.reach, null, e.position, false, false, false)
			GameEvent.Kind.PROP_RING:
				# Heard where it rang, as a guess there, and faintly.
				var shooter := _character(w, e.actor)
				if shooter != null and Elimination.is_in_play(shooter):
					_hear(w, shooter, e.position, e.position, e.reach, null, e.position, false, true)


static func _footstep_range(kind: int, cfg: BotConfig) -> float:
	match kind:
		GameEvent.Footstep.SPRINT:
			return cfg.footstep_hearing_sprint
		GameEvent.Footstep.LAND:
			return cfg.footstep_hearing_land
		GameEvent.Footstep.RATTLE:
			return cfg.footstep_hearing_rattle
	return cfg.footstep_hearing_run


## A "HIT!" tells the victim's teammates which way the BB came: the guess is back along its path from the victim, as far
## as the shooter stands up to how far gunfire carries (the shot was heard too), then off by hearing_error as any sound.
## Not from a BB fired by someone hit since (they are walking off).
static func _hit_call(e: GameEvent, w: BotWorld) -> void:
	var victim := _character(w, e.target)
	var shooter := _character(w, e.actor)
	if victim == null or shooter == null or not Elimination.is_in_play(shooter) or victim.team == shooter.team:
		return
	var flat := Vector2(e.direction.x, e.direction.z)
	var back := minf(w.cfg.hearing_distance, Vector2(shooter.position.x - victim.position.x,
			shooter.position.z - victim.position.z).length())
	var guess := victim.position
	if flat.length() > 1e-6:
		flat = flat.normalized() * back
		guess -= Vector3(flat.x, 0.0, flat.y)
	_hear(w, shooter, victim.position, victim.position, w.cfg.hearing_distance, null, guess, true)


## An enemy BB landing near a bot puts it under fire and gives away roughly where it came from, however far the shot.
static func _near_miss(e: GameEvent, w: BotWorld) -> void:
	var shooter := _character(w, e.actor)
	for b in w.bots:
		if shooter != null and shooter.team == b.character.team:
			continue
		var chest := BotSenses.body_point(b.character, w.tuning.hits, w.cfg.aim_height_fraction)
		if e.position.distance_to(chest) > w.cfg.suppression_radius:
			continue
		b.suppressed_at = w.time
		b.last_threat_at = w.time
		if shooter != null and Elimination.is_in_play(shooter):
			_hear(w, shooter, b.character.position, shooter.position, INF, b)


## Bots not on `source`'s team within `range_m` of `heard_at` learn roughly where `source` is (or `at` when given: a hit
## call's guess); `only` limits it to one bot. A bot already watching the source learns nothing; one fighting someone
## else keeps it for later. Gunfire from about the same place keeps the same guess. A bot that plays as a team goes to
## trade a teammate's `hit_call`, and tells its teammates where it heard someone. A `faint` sound (a BB ringing off a
## prop) is heard only by a bot with nobody in sight and nothing seen or heard within hearing_contact_time, and is not
## shared: it turns an idle bot's head, never pulls one off a fight. A sound not `muffled` carries its full range
## through walls (a door's, DO1).
static func _hear(w: BotWorld, source: Character, heard_at: Vector3, source_feet: Vector3, range_m: float, only: Bot,
		at: Vector3 = Vector3.INF, hit_call: bool = false, faint: bool = false, muffled: bool = true) -> void:
	var cfg := w.cfg
	var where := source.position if at == Vector3.INF else at
	for b in w.bots:
		if only != null and b != only:
			continue
		var c := b.character
		if c.team == source.team or not Elimination.is_in_play(c) or (b.target_visible and b.target_id == source.id):
			continue
		if faint and (b.target_visible or w.time - maxf(b.last_seen_at(), b.heard_at) < cfg.hearing_contact_time):
			continue
		var heard := Vector2(heard_at.x - c.position.x, heard_at.z - c.position.z).length()
		if heard > range_m:
			continue
		# Within the range a wall leaves, nothing to check; beyond it, cast the rays.
		if muffled and heard > range_m * cfg.wall_hearing:
			var share := SoundPath.blocked_share(w.query, BotSenses.eye_of(c, w.tuning), source_feet,
					cfg.hearing_ray_heights, _hit)
			if heard > range_m * (1.0 - share * (1.0 - cfg.wall_hearing)):
				continue
		var dist := Vector2(where.x - c.position.x, where.z - c.position.z).length()
		if b.target_visible:
			# Busy with someone else: remember this one for later (a flanker), but keep fighting.
			b.heard_other = _guess(w, b, where, dist)
			b.heard_other_at = w.time
			continue
		var margin := dist * cfg.hearing_error + cfg.replan_distance
		var same := b.has_last_known and w.time - b.heard_at < cfg.hearing_contact_time \
				and Vector2(where.x - b.last_known.x, where.z - b.last_known.z).length() <= margin
		if not same:
			b.last_known = _guess(w, b, where, dist)
		b.has_last_known = true
		b.heard_at = w.time
		b.last_threat_at = w.time
		if not b.skill.team_play or faint:
			continue
		if hit_call:
			b.trade_at = w.time
			b.trade_tried = false
		_share_heard(w, b)


## Team play: `b` tells its team-play teammates where it heard someone (the bots' version of the player's minimap). A
## teammate fighting, or with fresher news of its own, keeps its own; nobody trades on hearsay.
static func _share_heard(w: BotWorld, b: Bot) -> void:
	var cfg := w.cfg
	for m in w.bots:
		if m == b or not m.skill.team_play or m.character.team != b.character.team or m.target_visible \
				or not Elimination.is_in_play(m.character):
			continue
		if m.has_last_known and w.time - maxf(m.last_seen_at(), m.heard_at) < cfg.hearing_contact_time:
			continue
		m.last_known = b.last_known
		m.has_last_known = true
		m.heard_at = w.time
		m.last_threat_at = w.time


## A heard guess of `source`, `dist` m from `b`: off by up to hearing_error × dist, on the floor there (the bot's own
## height off the grid).
static func _guess(w: BotWorld, b: Bot, source: Vector3, dist: float) -> Vector3:
	var angle := b.rng.randf() * TAU
	var off := sqrt(b.rng.randf()) * dist * w.cfg.hearing_error
	var out := Vector3(source.x + cos(angle) * off, source.y, source.z + sin(angle) * off)
	var floor_y := w.nav.floor_at(out)
	out.y = b.character.position.y if is_nan(floor_y) else floor_y
	return out


static func _character(w: BotWorld, id: int) -> Character:
	for c in w.characters:
		if c.id == id:
			return c
	return null
