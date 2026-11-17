class_name Respawns
## Respawns (RS1, owner 2026-11-17: "matches should let players/bots respawn ... the idea is that matches will last
## long"): a hit character calls its hit and walks off as ever (Elimination), and a delay after the hit comes back into
## the round with full magazines, at its start area or at a forward spawn of its end (MapEnd.forward) that its
## controller picked (PlayerCommand.spawn_pick). A forward spawn with an enemy in play near it is shut, and so are
## forward spawns for the defenders of Attack / Defend and Plant The Bomb, who start by their pole or sites anyway: those
## picks come back at the start area. While anyone has a respawn coming, its team is not wiped out (Round.step). Plant
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


## Whether `c` is out of play with a respawn coming.
static func waiting(c: Character) -> bool:
	return c.respawn_left >= 0.0 and not Elimination.is_in_play(c)


## Whether `team` may come back at its end's forward spawns in `rs`'s round: either team in Elimination; with sides, only
## the attackers (the defenders start by what they defend).
static func forward_allowed(rs: RoundState, team: int) -> bool:
	return not rs.sided() or team == rs.attackers


## The seconds a hit on `team` waits before coming back in `rs`'s round (RoundConfig): the defenders' with sides,
## everyone else's otherwise.
static func delay(rs: RoundState, rounds: RoundConfig, team: int) -> float:
	if rs.sided() and rs.attackers >= 0 and team != rs.attackers:
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
	if k <= 0 or not forward_allowed(rs, c.team) or c.end < 0 or c.end >= ends.size() or ends[c.end] == null:
		return 0
	var forward := ends[c.end].forward
	if k > forward.size() or shut(forward[k - 1], c.team, characters, rounds.forward_block_radius):
		return 0
	return k


## One tick (`dt` s) of the live round's respawns, before Round.step judges wipe-outs: each character out of play takes
## its controller's pick (`commands` by id; none: the start area) and, newly out, starts its wait; a wait run out brings
## it back (a RESPAWNED event). Once respawns are shut (Plant The Bomb's bomb armed), every wait is dropped.
static func step(rs: RoundState, characters: Array[Character], commands: Array[PlayerCommand], ends: Array[MapEnd],
		tuning: SimTuning, events: SimEvents, dt: float) -> void:
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
			continue
		c.respawn_left -= dt
		if c.respawn_left <= 0.0:
			_bring_back(c, rs, ends, characters, tuning, events)


static func _bring_back(c: Character, rs: RoundState, ends: Array[MapEnd], characters: Array[Character],
		tuning: SimTuning, events: SimEvents) -> void:
	var k := resolve(c, rs, ends, characters, tuning.rounds)
	var at := c.spawn_position
	var facing := c.spawn_yaw
	if k > 0:
		var spot := free_spot(ends[c.end].forward[k - 1], characters, tuning.body)
		at = spot.position + Vector3(0.0, tuning.body.rest_gap, 0.0)
		facing = spot.yaw
	c.respawn_at(at, facing)
	var e := events.add(GameEvent.Kind.RESPAWNED)
	e.actor = c.id
	e.value = k
	e.position = at


## The first of `f`'s spots nobody in play stands on (within two body radii, flat), else its first.
static func free_spot(f: ForwardSpawn, characters: Array[Character], body: BodyConfig) -> SpawnPoint:
	var room := body.radius * 2.0
	for s in f.spots:
		var taken := false
		for c in characters:
			if Elimination.is_in_play(c) and Vector2(c.position.x - s.position.x, c.position.z - s.position.z).length() < room:
				taken = true
				break
		if not taken:
			return s
	return f.spots[0]
