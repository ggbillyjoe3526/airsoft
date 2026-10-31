class_name Pings
extends RefCounted
## Pings (PN1; the browser game's ai/pings.ts, PG1): a player marks where they look for their team, and their bot
## teammates take the spot as somewhere worth a look, each as its own play takes a noise heard there. The simulation
## raises a PING event for the press (where the view met the field, or nothing); BotController.observe hands it here,
## where it becomes a spot or a contact in the ping book, one ping per character, kept PingConfig.lifetime and cleared
## each round. A teammate's Contact call may also mark its enemy here (Callouts, data/callouts.md › Marks): a mark only
## shows, no bot takes it. The book is made once a match and refilled; the HUD reads it (PN2). Allocates nothing per
## ping.

## What a ping marks: a spot on the field, or an enemy seen there.
enum Kind { SPOT, CONTACT }

## A PING event's value for a ping placed on the full-screen map at its position (FM1); 1 is one along the view that met
## the field, 0 one at nothing.
const ON_MAP := GameEvent.PING_ON_MAP


## One character's ping: who placed it and their team, what it marks, where the marker goes (the point the view met, or
## the enemy's chest), the floor spot the bots go to or watch (the nearest walkable one to the point, or the enemy's
## feet), the enemy marked (character id, -1 for a spot), when (s of match time; -INF: none) and whether it is a
## teammate's mark from a call rather than a press.
class Ping:
	extends RefCounted
	var owner: int = -1
	var team: int = -1
	var kind: Kind = Kind.SPOT
	var point: Vector3 = Vector3.ZERO
	var spot: Vector3 = Vector3.ZERO
	var enemy_id: int = -1
	var at: float = -INF
	var marked: bool = false


## Pings placed this match, marks included (the serial the next one gets): the HUD hears a new one by it.
var placed: int = 0
## Each character's ping, by character id (made once, refilled).
var _book: Array[Ping] = []
var _cfg: PingConfig = null


## A book for every character in `characters`, with `cfg`'s numbers.
func _init(characters: Array[Character], cfg: PingConfig) -> void:
	_cfg = cfg
	var most := -1
	for c in characters:
		most = maxi(most, c.id)
	for i in most + 1:
		_book.append(Ping.new())


## Character `id`'s ping (whether placed or not: `is_up`), or null for an id the book doesn't hold.
func of(id: int) -> Ping:
	return _book[id] if id >= 0 and id < _book.size() else null


## How many characters the book holds (ids 0 to size - 1).
func size() -> int:
	return _book.size()


## Whether `p` shows at `now`: placed this round, less than PingConfig.lifetime ago.
func is_up(p: Ping, now: float) -> bool:
	return p != null and p.at > -INF and now - p.at < _cfg.lifetime


## A new round: every ping gone.
func clear() -> void:
	for p in _book:
		p.at = -INF
		p.marked = false


## A PING event `e` (Simulation): where its pinger's view points becomes their ping, at `now` (s of match time), and
## the ping is returned; null when nothing is pinged (the sky, nothing within PingConfig.reach), the pinger is out, or
## their last ping is less than PingConfig.min_gap old (a double click is one ping). An enemy in play under the view,
## nearer than what it meets behind them and seen by the bots' sight rules from the pinger's eyes (BotSenses
## .visible_part, as far as a ping reaches: so never one hidden in a bush, in the dark or behind a body), makes it a
## contact; otherwise it marks the floor in front of what the view met. One placed on the full-screen map (FM1: value
## 2) marks the floor there (map_spot), never an enemy: the map shows only what your side heard.
func place(e: GameEvent, now: float, w: BotWorld) -> Ping:
	var leader := _character(w, e.actor)
	var p := of(e.actor)
	if leader == null or p == null or not Elimination.is_in_play(leader) or now - p.at < _cfg.min_gap:
		return null
	if e.value == ON_MAP:
		var at := map_spot(e.position, w)
		if not SquadOrders.is_spot(at):
			return null
		p.kind = Kind.SPOT
		p.enemy_id = -1
		p.point = at
		p.spot = at
		_placed(p, leader, now, false)
		return p
	var met := e.value == 1
	var eye := e.position
	var dir := e.direction
	var enemy := _enemy_under_view(leader, eye, dir, e.reach if met else _cfg.reach, w)
	if enemy != null:
		p.kind = Kind.CONTACT
		p.enemy_id = enemy.id
		p.point = BotSenses.body_point(enemy, w.tuning.hits, w.cfg.aim_height_fraction)
		p.spot = enemy.position
	elif met:
		p.kind = Kind.SPOT
		p.enemy_id = -1
		p.point = eye + dir * e.reach
		p.spot = _floor_spot(p.point, dir, e.reach, w)
	else:
		return null
	_placed(p, leader, now, false)
	return p


## Where a Go there ping `e` (FM1, PlayerCommand.ping_move) sends the pinger's teammates: the floor in front of what
## the view met (as a spot ping's), or for one on the map, map_spot; NO_SPOT (SquadOrders) for a view that met nothing.
func move_spot(e: GameEvent, w: BotWorld) -> Vector3:
	if e.value == ON_MAP:
		return map_spot(e.position, w)
	if e.value != 1:
		return SquadOrders.NO_SPOT
	return _floor_spot(e.position + e.direction * e.reach, e.direction, e.reach, w)


## The floor spot for a ping on the full-screen map at `at` (x and z picked, y the floor of the storey shown): the
## nearest walkable one within PingConfig.map_snap, judged map_lift above that floor; NO_SPOT with none (inside a
## building's walls, off the field).
func map_spot(at: Vector3, w: BotWorld) -> Vector3:
	if w.nav == null:
		return SquadOrders.NO_SPOT
	var k := w.nav.nearest_walkable(at + Vector3.UP * _cfg.map_lift, _cfg.map_snap)
	return w.nav.node_position(k) if k >= 0 else SquadOrders.NO_SPOT


## A teammate's sighting call marks `enemy` for its team (Callouts, data/callouts.md › Marks): `caller`'s ping, a
## contact over `enemy` now (`now`, s of match time), in the book only: no bot takes it.
func mark(caller: Character, enemy: Character, now: float, w: BotWorld) -> void:
	var p := of(caller.id)
	if p == null:
		return
	p.kind = Kind.CONTACT
	p.enemy_id = enemy.id
	p.point = BotSenses.body_point(enemy, w.tuning.hits, w.cfg.aim_height_fraction)
	p.spot = enemy.position
	_placed(p, caller, now, true)


## Bot `b` hears a teammate's ping (the browser game's takePing): its spot becomes the bot's last-known one, as a noise
## heard there exactly and kept in mind BotConfig.ping_memory (Bot.ping_in_mind), and the bot's own play decides what it
## does (BotBrain): a search the way its personality searches; a defender or an anchor holding watches it from its post
## when it is far; under a squad order it keeps the order and watches it. A contact also counts as a threat, a spot
## doesn't. A new ping starts a search under way afresh. A bot out of play, fighting, in cover or with a target in view
## ignores it: false.
static func take(b: Bot, p: Ping, w: BotWorld) -> bool:
	if not Elimination.is_in_play(b.character) or b.target_visible or b.mode == Bot.Mode.FIGHT \
			or b.mode == Bot.Mode.COVER:
		return false
	b.last_known = p.spot
	b.ping_spot = p.spot
	b.has_last_known = true
	b.heard_at = w.time
	b.ping_at = w.time
	if p.kind == Kind.CONTACT:
		b.last_threat_at = w.time
	b.watch_until = -INF
	if b.mode == Bot.Mode.SEARCH:
		b.route_state = Bot.RouteState.NONE
		BotMovement.start_search(b, w)
	return true


func _placed(p: Ping, owner: Character, now: float, marked: bool) -> void:
	p.owner = owner.id
	p.team = owner.team
	p.at = now
	p.marked = marked
	placed += 1


## The floor spot for a ping whose view (along `dir`) met the field at `point`, `hit` m from the eyes: the nearest
## walkable floor within PingConfig.spot_snap of a point back_off (at most `hit`) back towards the pinger, so in front
## of a wall or a crate's side, on the level the view reached. It must be in sight of that point (sight_lift over its
## floor): a floor beyond a thin wall is never the spot; then it is looked for again spot_snap further back, as far as
## the eyes. The point itself if no floor is near.
func _floor_spot(point: Vector3, dir: Vector3, hit: float, w: BotWorld) -> Vector3:
	if w.nav == null:
		return point
	var first := minf(_cfg.back_off, hit)
	var step := _cfg.spot_snap
	var tries := ceili((hit - first) / step) + 1 if step > 0.0 else 1
	for t in tries:
		var from := point - dir * minf(first + step * t, hit)
		var k := w.nav.nearest_walkable(from, step)
		if k >= 0:
			var spot := w.nav.node_position(k)
			if w.query == null or BotSenses.line_clear(w.query, from, spot + Vector3.UP * _cfg.sight_lift):
				return spot
	return point


## The enemy of `leader` in play nearest the line of its view (`dir` from `eye`) within `reach` m: one whose chest or
## head the line passes within enemy_cone_deg of (or enemy_reach m, up close) and whom the bots' sight rules let the
## leader see. Null if none.
func _enemy_under_view(leader: Character, eye: Vector3, dir: Vector3, reach: float, w: BotWorld) -> Character:
	var cone := tan(deg_to_rad(_cfg.enemy_cone_deg))
	var hits := w.tuning.hits
	var best: Character = null
	var best_off := INF
	for c in w.characters:
		if c.team == leader.team or not Elimination.is_in_play(c):
			continue
		# How far off the line the nearer of their chest and head is, as a slope (across / along).
		var off := INF
		for part in 2:
			var fraction := w.cfg.aim_height_fraction if part == 0 else w.cfg.head_height_fraction
			var to := BotSenses.body_point(c, hits, fraction) - eye
			var along := to.dot(dir)
			if along <= 0.0 or along > reach:
				continue
			var across := (to - dir * along).length()
			if across <= maxf(_cfg.enemy_reach, along * cone):
				off = minf(off, across / along)
		if off >= best_off or BotSenses.visible_part(leader, c, w, _cfg.reach) == 0.0:
			continue
		best = c
		best_off = off
	return best


static func _character(w: BotWorld, id: int) -> Character:
	for c in w.characters:
		if c.id == id:
			return c
	return null
