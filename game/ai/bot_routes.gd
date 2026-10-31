class_name BotRoutes
## Walking routes (the browser game's ai/routes.ts): asking for a route and planning it within the tick's search budget
## (plan), following its legs, the last few centimetres onto a lean spot, and the spots a cover search keeps off.
## Allocates nothing once warm but the routes found.

## Teammates' spots for a cover search (teammate_spots), grown once to the most seen, then reused.
static var _taken: PackedVector3Array = PackedVector3Array()


## Asks for a route to `goal`, unless the route it has (or failed to get) already goes about there.
static func want(b: Bot, goal: Vector3, cfg: BotConfig) -> void:
	if b.route_state == Bot.RouteState.WANTED:
		b.route_goal = goal
		return
	var moved := Vector2(goal.x - b.route_goal.x, goal.z - b.route_goal.z).length()
	if (b.route_state == Bot.RouteState.OK or b.route_state == Bot.RouteState.FAILED) and moved < cfg.replan_distance:
		return
	b.route_goal = goal
	b.route_state = Bot.RouteState.WANTED


## Plans the routes of the bots that want one, round-robin from `cursor`, while the tick's search budget lasts
## (NavConfig.search_budget, the browser's planRoutes): a walk-off the simulation step will plan this tick takes the
## tick's first search (Elimination.walk_off_due: not a victim still mid-vault, nor with no grid), and a bot over the
## budget waits for the next tick. A bot out of play,
## or failed lately (BotConfig.route_retry_delay), is passed over. Each wanted route is stamped when first seen
## (Bot.route_asked_at), for its wait. Returns the cursor for the next tick: the bot after the last one served, so no bot
## waits behind another twice.
static func plan(w: BotWorld, characters: Array[Character], cursor: int) -> int:
	var budget := w.tuning.nav.search_budget
	for c in characters:
		if Elimination.walk_off_due(c, w.nav):
			budget -= 1
			break
	for b in w.bots:
		if b.route_state != Bot.RouteState.WANTED:
			b.route_asked_at = -INF
		elif is_inf(b.route_asked_at):
			b.route_asked_at = w.time
	var n := w.bots.size()
	var next := cursor
	for i in n:
		if budget <= 0:
			break
		var k := (cursor + i) % n
		var b := w.bots[k]
		if b.route_state != Bot.RouteState.WANTED or w.time < b.route_retry_at \
				or not Elimination.is_in_play(b.character):
			continue
		next = (k + 1) % n
		budget -= 1
		b.route_asked_at = -INF
		var from := b.character.position
		if w.nav.find_route(from, b.route_goal, b.route, w.time >= b.vaults_off_until):
			b.route_state = Bot.RouteState.OK
			b.route_from = from
			b.route_leg = 0
			b.stuck_for = 0.0
		else:
			b.route.clear()
			b.route_state = Bot.RouteState.FAILED
			b.route_retry_at = w.time + w.cfg.route_retry_delay
	return next


## Drops the route: not "arrived" anywhere (the old route was for another goal).
static func drop(b: Bot) -> void:
	b.route_state = Bot.RouteState.NONE
	b.route.clear()
	b.route_leg = 0


## True if the route walked ended at its goal this tick or before (state NONE, a route kept).
static func arrived(b: Bot) -> bool:
	return b.route_state == Bot.RouteState.NONE and not b.route.is_empty()


## Where `b` will be after walking `distance` m more along its route (level, at its feet' height): round its corners,
## stopping at the route's end; where it stands if it walks no route (none, or in a fight).
static func point_ahead(b: Bot, distance: float) -> Vector3:
	var at := b.character.position
	if b.mode == Bot.Mode.FIGHT or b.route_state != Bot.RouteState.OK:
		return at
	var left := distance
	var leg := b.route_leg
	while leg < b.route.size() and left > 0.0:
		var to := Vector2(b.route[leg].x - at.x, b.route[leg].z - at.z)
		var d := to.length()
		if d >= left:
			to *= left / d
			return Vector3(at.x + to.x, at.y, at.z + to.y)
		at = Vector3(b.route[leg].x, at.y, b.route[leg].z)
		left -= d
		leg += 1
	return at


## Follows the route: writes the way to walk into b.move_dir and returns true, or false with nothing to walk (no route,
## or arrived). `while_planning`: keep walking the old route while a new one is wanted. A bot pushed off its leg (by a
## teammate, a fight) that would take a drop walking straight on asks for a fresh route, once each time it has moved
## off_leg_replan_moved; one walking slower than stuck_speed for stuck_time does too. A leg over a low obstacle (a vault
## link, NavVaults) sets b.vault_leg while the obstacle is still ahead: it is walked straight, its end counts as reached
## once past it wherever the vault set the body down, and held up on it the bot's routes go round for
## vault_retry_delay.
static func follow(b: Bot, w: BotWorld, dt: float, while_planning: bool = false) -> bool:
	var cfg := w.cfg
	var planning := while_planning and b.route_state == Bot.RouteState.WANTED
	if b.route_state != Bot.RouteState.OK and not planning:
		return false
	var p := b.character.position
	while b.route_leg < b.route.size():
		var reached := b.route[b.route_leg]
		if Vector2(reached.x - p.x, reached.z - p.z).length() > cfg.waypoint_reach \
				and not (_leg_share(b.route_from, reached, p, cfg.waypoint_reach) >= 1.0
				and w.nav.is_vault_leg(b.route_from, reached)):
			break
		b.route_from = reached
		b.route_leg += 1
	if b.route_leg >= b.route.size():
		if not planning:
			b.route_state = Bot.RouteState.NONE
			b.stuck_for = 0.0
		return false
	var wp := b.route[b.route_leg]
	var vault := w.nav.is_vault_leg(b.route_from, wp)
	b.vault_leg = vault and _leg_share(b.route_from, wp, p, 0.0) < 0.5
	if not planning and not vault and _off_leg(b.route_from, wp, p) > cfg.route_off_leg \
			and Vector2(p.x - b.off_leg_at.x, p.z - b.off_leg_at.z).length() > cfg.off_leg_replan_moved \
			and w.nav.drop_on_line(p, wp):
		b.off_leg_at = p
		b.route_state = Bot.RouteState.WANTED
		b.stuck_for = 0.0
		return false
	var flat := Vector2(wp.x - p.x, wp.z - p.z)
	var d := flat.length()
	if d < 1e-6:
		return false
	b.move_dir = Vector3(flat.x / d, 0.0, flat.y / d)
	var speed := Vector2(b.character.velocity.x, b.character.velocity.z).length()
	b.stuck_for = b.stuck_for + dt if speed < cfg.stuck_speed else 0.0
	if b.stuck_for > cfg.stuck_time and not planning:
		b.stuck_for = 0.0
		b.route_state = Bot.RouteState.WANTED
		# Held up at a vault (a teammate in the way, a fight that turned it): the next routes go round for a while.
		if vault:
			b.vaults_off_until = w.time + cfg.vault_retry_delay
	return true


## The last bit onto `spot` once its route is done, walking straight at it: a lean spot, where a few centimetres decide
## whether the lean sees round the corner. True while stepping (b.move_dir); false once there, too far off, blocked or
## with a drop on the way.
static func step_onto(b: Bot, w: BotWorld, spot: Vector3, cmd: PlayerCommand, dt: float) -> bool:
	var cfg := w.cfg
	var p := b.character.position
	var flat := Vector2(spot.x - p.x, spot.z - p.z)
	var d := flat.length()
	# A walk coasts a few centimetres once let go: it lets go at half the arrive distance.
	if d <= cfg.lean_spot_arrive * 0.5 or d > cfg.cover_arrive or b.stuck_for > cfg.stuck_time:
		return false
	var speed := Vector2(b.character.velocity.x, b.character.velocity.z).length()
	b.stuck_for = b.stuck_for + dt if speed < cfg.stuck_speed else 0.0
	var ahead := p + Vector3(flat.x, 0.0, flat.y) * (minf(d, cfg.edge_lookahead) / d)
	if w.nav.drop_on_line(p, ahead):
		return false
	b.move_dir = Vector3(flat.x / d, 0.0, flat.y / d)
	cmd.walk = true
	return true


## Where `b`'s teammates stand or are heading for cover, for a cover search to keep off: every teammate in play (the
## player too), and the cover, hold or flag spot each teammate bot is making for. Returns the count; the spots are
## taken().
static func teammate_spots(b: Bot, w: BotWorld) -> int:
	var me := b.character
	var n := 0
	for c in w.characters:
		if c != me and c.team == me.team and Elimination.is_in_play(c):
			n = _add(n, c.position)
	for o in w.bots:
		if o == b or o.character.team != me.team or not Elimination.is_in_play(o.character):
			continue
		if o.mode == Bot.Mode.COVER:
			n = _add(n, o.cover.position)
		elif o.mode == Bot.Mode.ADVANCE and o.hold_cover:
			n = _add(n, o.hold_spot.position)
		elif o.mode == Bot.Mode.FLAG:
			n = _add(n, o.flag_goal)
	return n


static func taken() -> PackedVector3Array:
	return _taken


static func _add(n: int, p: Vector3) -> int:
	if n >= _taken.size():
		_taken.resize(n + 1)
	_taken[n] = p
	return n + 1


## How far along the leg from `a` to `b` the point `p` is, `reach` metres on (0 at `a`, 1 at `b`; 1 for no leg).
static func _leg_share(a: Vector3, b: Vector3, p: Vector3, reach: float) -> float:
	var e := Vector2(b.x - a.x, b.z - a.z)
	var len2 := e.length_squared()
	if len2 <= 0.0:
		return 1.0
	return (Vector2(p.x - a.x, p.z - a.z).dot(e) + reach * sqrt(len2)) / len2


## How far `p` stands off the leg from `a` to `b` on the ground.
static func _off_leg(a: Vector3, b: Vector3, p: Vector3) -> float:
	var e := Vector2(b.x - a.x, b.z - a.z)
	var len2 := e.length_squared()
	var q := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(q.dot(e) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
	return (q - e * t).length()
