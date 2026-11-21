class_name Respawns
## Respawns (RS1, owner 2026-11-17: "matches should let players/bots respawn ... the idea is that matches will last
## long"): a hit character calls its hit and walks off as ever (Elimination), and a delay after the hit comes back into
## the round with full magazines, at its start area or at a forward spawn of its end (MapEnd.forward) that its
## controller picked (PlayerCommand.spawn_pick). A forward spawn with an enemy in play near it is shut, and so are the
## defenders' where RoundConfig.defender_forward_spawns is off: those picks come back at the start area. With respawns
## an untended flag slips back down (slip_time). While anyone has a respawn coming, its team is not wiped out (Round.step). Plant
## The Bomb's respawns end as the bomb is armed: whoever is out then stays out. Pure; allocates nothing.


## Whether `rounds` brings hit characters back in `mode`'s matches (RoundConfig.respawns): by mode, in Attack / Defend
## and Plant The Bomb but not Elimination; or always, or never (the Custom rule).
static func on_in(rounds: RoundConfig, mode: RoundState.Mode) -> bool:
	match rounds.respawns:
		RoundConfig.RespawnRule.ALWAYS:
			return true
		RoundConfig.RespawnRule.NEVER:
			return false
	return mode != RoundState.Mode.ELIMINATION


## Whether a hit in `rs`'s round still comes back now: the match has respawns (never on the range), and in Plant The
## Bomb the bomb isn't armed.
static func open(rs: RoundState) -> bool:
	return rs.respawns and not rs.practice and not (rs.mode == RoundState.Mode.PLANT_THE_BOMB and rs.plant.planted())


## The seconds an untended flag takes to slip from the top to the bottom in `rs`'s round (FlagConfig): with respawns,
## else 0 (it stays).
static func slip_time(rs: RoundState, flag: FlagConfig) -> float:
	return maxf(0.0, flag.respawn_slip_time) if rs.respawns and not rs.practice else 0.0


## Whether `c` is out of play with a respawn coming.
static func waiting(c: Character) -> bool:
	return c.respawn_left >= 0.0 and not Elimination.is_in_play(c)


## Whether `team` may come back at its end's forward spawns in `rs`'s round: either team in Elimination; with sides, the
## attackers, and the defenders too where `rounds` lets them (RoundConfig.defender_forward_spawns).
static func forward_allowed(rs: RoundState, team: int, rounds: RoundConfig) -> bool:
	return forward_for(rs.sided(), rs.attackers, team, rounds)


## forward_allowed from its parts, for a controller that keeps the mode and the attackers on its own (BotRespawn).
static func forward_for(sided: bool, attackers: int, team: int, rounds: RoundConfig) -> bool:
	return not sided or team == attackers or rounds.defender_forward_spawns


## The seconds a hit on `team` waits before coming back in `rs`'s round (RoundConfig): the defenders' in Attack /
## Defend (a field's own) and in Plant The Bomb, everyone else's otherwise.
static func delay(rs: RoundState, rounds: RoundConfig, team: int) -> float:
	if rs.sided() and rs.attackers >= 0 and team != rs.attackers:
		if rs.mode == RoundState.Mode.PLANT_THE_BOMB:
			return maxf(0.0, rounds.plant_defender_respawn_delay)
		return maxf(0.0, rounds.defender_respawn_delay)
	return maxf(0.0, rounds.respawn_delay)


## Whether forward spawn `f` is shut to `team`: someone of the other team in play within `radius` of its middle.
static func shut(f: ForwardSpawn, team: int, characters: Array[Character], radius: float) -> bool:
	var reach := radius * radius
	for c in characters:
		if c.team != team and Elimination.is_in_play(c) and c.position.distance_squared_to(f.centre) <= reach:
			return true
	return false


## Where `c` comes back if it does now, from its pick: the forward spawn picked (k, its end's forward spawn k - 1) when
## its team may use them, there is one and it isn't shut; else 0, the start area.
static func resolve(c: Character, rs: RoundState, ends: Array[MapEnd], characters: Array[Character],
		rounds: RoundConfig) -> int:
	var k := c.spawn_pick
	if k <= 0 or not forward_allowed(rs, c.team, rounds) or c.end < 0 or c.end >= ends.size() or ends[c.end] == null:
		return 0
	var forward := ends[c.end].forward
	if k > forward.size() or shut(forward[k - 1], c.team, characters, rounds.forward_block_radius):
		return 0
	return k


## One tick (`dt` s) of the live round's respawns, before Round.step judges wipe-outs: each character out of play takes
## its controller's pick (`commands` by id; none: the start area) and, newly out, starts its wait; one still walking
## off leaves the field as its wait's last HitConfig.vanish_time starts once nobody in play sees it (seen, through
## `query` with `hit` for its rays and the round's `grenades` for their smoke; none given, nobody does) or it has
## walked HitConfig.seen_most past it, and a wait run out brings it back (a RESPAWNED event) once it is out (still
## calling its hit, it calls, walks off and leaves first). Once respawns are shut (Plant The Bomb's bomb armed), every wait is dropped.
static func step(rs: RoundState, characters: Array[Character], commands: Array[PlayerCommand], ends: Array[MapEnd],
		tuning: SimTuning, events: SimEvents, dt: float, query: WorldQuery = null, hit: RayHit = null,
		grenades: Array[Grenade] = []) -> void:
	if not rs.is_live():
		return
	var is_open := open(rs)
	for c in characters:
		if Elimination.is_in_play(c):
			continue
		if not is_open:
			c.respawn_left = -1.0
			continue
		var cmd: PlayerCommand = commands[c.id] if c.id >= 0 and c.id < commands.size() else null
		c.spawn_pick = cmd.spawn_pick if cmd != null else 0
		if c.respawn_left < 0.0:
			c.respawn_left = delay(rs, tuning.rounds, c.team)
			c.respawn_seen = 0.0
			continue
		# Never under 0 while it waits to be out of sight: a wait run out still counts as coming (waiting).
		c.respawn_left = maxf(c.respawn_left - dt, 0.0)
		# Walking off as the wait runs out, it leaves the field (Elimination's fade) on its last vanish_time, so it is
		# out of sight as it comes back, never drawn at its spawn in a blink (the owner's playtest of 0.1 Beta 2, item
		# 6); seen, it walks on (at most seen_most) so nobody watches it fade where it stands; once out, it comes back.
		if c.status == Character.Status.WALKING_OFF and c.respawn_left <= tuning.hits.vanish_time:
			if c.respawn_seen < tuning.hits.seen_most and seen(c, characters, tuning, query, hit, grenades):
				c.respawn_seen += dt
			else:
				Elimination.leave(c)
		if c.respawn_left <= 0.0 and c.status == Character.Status.OUT:
			_bring_back(c, rs, ends, characters, tuning, events)


## Whether anyone in play sees `c` (HitConfig.seen_range, seen_angle): faces it, near enough, with a clear sight line
## (`query`'s sight_ray, into `hit`) from their eye to its chest, through no more than seen_leaves of bush (`query`'s
## foliage) and seen_smoke of `grenades`' smoke. False with no `query`.
static func seen(c: Character, characters: Array[Character], tuning: SimTuning, query: WorldQuery,
		hit: RayHit, grenades: Array[Grenade] = []) -> bool:
	if query == null or hit == null:
		return false
	var hits := tuning.hits
	var chest := c.position + Vector3(0.0, (hits.torso_bottom + hits.torso_top) * 0.5, 0.0)
	var reach := hits.seen_range * hits.seen_range
	var cone := cos(deg_to_rad(hits.seen_angle))
	for o in characters:
		if o == c or not Elimination.is_in_play(o):
			continue
		var eye := o.eye(tuning.body)
		var to := chest - eye
		if to.length_squared() > reach:
			continue
		var flat := Vector2(to.x, to.z)
		var ahead := Vector2(-sin(o.yaw), -cos(o.yaw))
		if flat.length_squared() > 1e-6 and flat.normalized().dot(ahead) < cone:
			continue
		if query.sight_ray(eye, chest, hit):
			continue
		if query.foliage != null and query.foliage.depth(eye, chest, hits.seen_leaves) > hits.seen_leaves:
			continue
		if not grenades.is_empty() \
				and Grenades.smoke_depth(grenades, tuning.grenades, eye, chest, hits.seen_smoke) > hits.seen_smoke:
			continue
		return true
	return false


static func _bring_back(c: Character, rs: RoundState, ends: Array[MapEnd], characters: Array[Character],
		tuning: SimTuning, events: SimEvents) -> void:
	var k := resolve(c, rs, ends, characters, tuning.rounds)
	var at := c.spawn_position
	var facing := c.spawn_yaw
	var spot: SpawnPoint = free_spot(ends[c.end].forward[k - 1], characters, tuning.body) if k > 0 else null
	if spot == null:
		k = 0
	else:
		at = spot.position + Vector3(0.0, tuning.body.rest_gap, 0.0)
		facing = spot.yaw
	c.respawn_at(at, facing)
	var e := events.add(GameEvent.Kind.RESPAWNED)
	e.actor = c.id
	e.value = k
	e.position = at


## The first of `f`'s spots nobody in play stands on (within two body radii, flat, and within a body's height of it, so
## someone on the floor above or below a spot doesn't take it), else null: at 7v7 and 8v8 a fifth coming back to a
## forward spawn's four spots at once comes back at its start, as at a shut one, never inside a teammate (BP11).
static func free_spot(f: ForwardSpawn, characters: Array[Character], body: BodyConfig) -> SpawnPoint:
	var room := body.radius * 2.0
	for s in f.spots:
		var taken := false
		for c in characters:
			if Elimination.is_in_play(c) and absf(c.position.y - s.position.y) < body.height \
					and Vector2(c.position.x - s.position.x, c.position.z - s.position.z).length() < room:
				taken = true
				break
		if not taken:
			return s
	return null
