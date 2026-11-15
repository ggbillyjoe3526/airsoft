class_name Spots
extends RefCounted
## Spotted (CW1, owner 2026-11-15, after Battlefield's spotting): a tap of the order wheel's key (or letting it go on
## the wheel's middle) marks the enemy under your view for your team. The simulation raises a PING event with value2
## PING_SPOT; BotController.observe hands it here. The enemy is the one a ping would mark, a little more forgivingly
## (PingConfig.spot_cone_deg), and only one the bots' sight rules let you see; nobody under the view, nothing happens.
## They stay marked PingConfig.spot_time (seconds of match time; spotted again, the time starts over), until they are
## out, or until the round ends; the HUD draws an arrow over their head meanwhile, through walls (HudSpotArrows). While
## they are marked, the spotter's bot teammates within spot_share_radius of them hear where they are now, at once and
## every spot_share_gap after (share): as a teammate's call heard there, so each goes after them or watches them from
## its post as its own play decides (BotBrain); one further off, out, fighting or already seeing someone carries on.
## The book is made once a match and refilled; it allocates nothing.

## Spots placed this match (the serial the next one gets) and the id of the character who placed the last one: the
## sound hears a new one of yours by them (SimAudio.on_spot).
var placed: int = 0
var last_spotter: int = -1
## By character id: until when (s of match time) they are marked (-INF: not), and the team that marked them.
var _until := PackedFloat64Array()
var _by := PackedInt32Array()
## When the marked are next told to the spotters' teammates (s of match time).
var _next_share: float = -INF
var _cfg: PingConfig = null


## A book for every character in `characters`, with `cfg`'s numbers.
func _init(characters: Array[Character], cfg: PingConfig) -> void:
	_cfg = cfg
	var most := -1
	for c in characters:
		most = maxi(most, c.id)
	_until.resize(most + 1)
	_by.resize(most + 1)
	clear()


## Whether the character `id` is marked at `now` (s of match time).
func is_spotted(id: int, now: float) -> bool:
	return id >= 0 and id < _until.size() and now < _until[id]


## The team that marked the character `id` (-1: nobody, or an id the book doesn't hold).
func spotted_by(id: int) -> int:
	return _by[id] if id >= 0 and id < _by.size() else -1


## How long (s) the character `id` stays marked after `now` (0: not marked).
func time_left(id: int, now: float) -> float:
	return maxf(0.0, _until[id] - now) if is_spotted(id, now) else 0.0


## A new round: nobody marked.
func clear() -> void:
	_until.fill(-INF)
	_by.fill(-1)
	_next_share = -INF


## A PING event `e` with value2 PING_SPOT (Simulation) at `now`: the enemy under its pinger's view (Pings
## .enemy_under_view, spot_cone_deg) is marked for the pinger's team and told to their bot teammates near them at once.
## Returns them, or null when nobody is under the view or the pinger is out.
func place(e: GameEvent, now: float, w: BotWorld, pings: Pings) -> Character:
	var spotter := _character(w, e.actor)
	if spotter == null or not Elimination.is_in_play(spotter) or e.value == Pings.ON_MAP:
		return null
	var reach := e.reach if e.value == 1 else _cfg.reach
	var enemy := pings.enemy_under_view(spotter, e.position, e.direction, reach, _cfg.spot_cone_deg, w)
	if enemy == null or enemy.id >= _until.size():
		return null
	_until[enemy.id] = now + _cfg.spot_time
	_by[enemy.id] = spotter.team
	placed += 1
	last_spotter = spotter.id
	share(w, enemy, spotter.team, _cfg.spot_share_radius)
	return enemy


## Before the bots think: a marked enemy who is out is marked no longer, and every spot_share_gap each one still marked
## is told again where they are now.
func step(w: BotWorld) -> void:
	var tell := w.time >= _next_share
	if tell:
		_next_share = w.time + _cfg.spot_share_gap
	for c in w.characters:
		if not is_spotted(c.id, w.time):
			continue
		if not Elimination.is_in_play(c):
			_until[c.id] = -INF
			_by[c.id] = -1
		elif tell and w.live:
			share(w, c, _by[c.id], _cfg.spot_share_radius)


## `enemy`'s position now, told to `team`'s bots in play within `radius` m of them (flat) that are neither fighting
## nor seeing someone: their last-known spot, as a teammate's call heard there (BotRadio.tell's), a threat.
static func share(w: BotWorld, enemy: Character, team: int, radius: float) -> void:
	var reach_sq := radius * radius
	var at := enemy.position
	for m in w.bots:
		if m.character.team != team or m.target_visible or m.mode == Bot.Mode.FIGHT \
				or not Elimination.is_in_play(m.character):
			continue
		var p := m.character.position
		if Vector2(at.x - p.x, at.z - p.z).length_squared() > reach_sq:
			continue
		m.last_known = at
		m.has_last_known = true
		m.heard_at = w.time
		m.last_threat_at = w.time


static func _character(w: BotWorld, id: int) -> Character:
	for c in w.characters:
		if c.id == id:
			return c
	return null
