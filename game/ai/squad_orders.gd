class_name SquadOrders
## How bot teammates carry out a squad order (the browser game's ai/squadOrders.ts, M22): BotController hands an order
## out (start, end); each tick BotBrain puts an ordered bot in ORDER mode between fights and `move` walks it there.
## Follow me: a spot behind the giver's heading, kept at the giver's pace, covering their back. Hold here: the spot the
## giver looks at, the teammates side by side across their view, all looking their way. Regroup: sprint back to the
## giver, then follow (`regrouped`). Go there (FM1): a pinged spot, the teammates side by side across the way there,
## looking on that way; once all are there it is a Hold here (SquadOrderBook.move_arrivals). Tuning is BotConfig.squad
## (SquadConfig). Allocates nothing.

## What came of the last order given, for the presentation: CANCELLED, back to the team plan (the order given again, Team
## plan, or no teammate left to take it); ON_PLAN, Team plan with no order in force; NOBODY, no teammate in play to
## take it; NOT_NOW, given while out or between rounds; NOWHERE, Go there pinged at nothing (the sky, too far).
enum Notice { NONE, CANCELLED, ON_PLAN, NOBODY, NOT_NOW, NOWHERE }

## No spot: hold_point looking at nothing, held_centre with nobody holding.
const NO_SPOT := Vector3(NAN, NAN, NAN)
## A follower's pace, from the giver's: a walk, a run or a sprint (one faster or slower to catch up or drop back).
const WALK := 0
const RUN := 1
const SPRINT := 2

static var _hit: RayHit = RayHit.new()


## The last order given (SquadOrderBook.order_outcome, one record reused): by whom, the order in force afterwards (NONE:
## the team plan), and its notice (NONE when an order was taken). `serial` counts every outcome, so a reader sees a new
## one even when it reads the same.
class Outcome:
	extends RefCounted
	var giver: int = -1
	var order: SquadOrder.Kind = SquadOrder.Kind.NONE
	var notice: SquadOrders.Notice = SquadOrders.Notice.NONE
	var serial: int = 0

	func record(giver_id: int, in_force: SquadOrder.Kind, what: SquadOrders.Notice) -> void:
		giver = giver_id
		order = in_force
		notice = what
		serial += 1


## True unless `p` is NO_SPOT.
static func is_spot(p: Vector3) -> bool:
	return not is_nan(p.x)


## `b` carries out `kind` for `giver` as the `slot`th of the teammates given it, from the next tick. A route to an
## earlier order's spot is dropped; any other is the brain's to drop once it turns to the order (a bot on its way to
## cover gets there first).
static func start(b: Bot, giver: Character, kind: SquadOrder.Kind, slot: int) -> void:
	b.order = kind
	b.order_giver = giver
	b.order_slot = slot
	b.order_yaw = giver.yaw
	b.order_heading = giver.yaw
	b.order_rush = false
	b.order_settled = false
	b.order_catching_up = false
	b.order_dropping_back = false
	if b.mode == Bot.Mode.ORDER:
		BotRoutes.drop(b)


## Back to the team plan: in Elimination the bot hunts from where it stands (its lane is behind it by now); in Attack /
## Defend it takes up its post or the pole again.
static func end(b: Bot, w: BotWorld) -> void:
	if b.order == SquadOrder.Kind.NONE:
		return
	b.order = SquadOrder.Kind.NONE
	b.order_giver = null
	b.order_rush = false
	if BotFlag.role(b, w) == BotFlag.Role.NONE:
		b.hunting = true


## Hold here: the spot `giver` looks at, on walkable ground hold_wall_gap short of what the view meets, stepped back
## towards them until the ground is walkable; NO_SPOT if they look at nothing within hold_range or no walkable ground
## is on that line.
static func hold_point(giver: Character, w: BotWorld) -> Vector3:
	var cfg := w.cfg.squad
	var eye := BotSenses.eye_of(giver, w.tuning)
	var view := giver.view_direction()
	if not w.query.ray(eye, eye + view * cfg.hold_range, _hit):
		return NO_SPOT
	var flat := Vector2(view.x, view.z).length()
	if flat < 1e-3:
		return NO_SPOT
	# How far along the ground the line of sight goes before it meets something.
	var reach := _hit.fraction * cfg.hold_range * flat - cfg.hold_wall_gap
	var nav := w.nav
	var back := 0.0
	while back <= reach:
		var d := reach - back
		back += nav.cell
		# The floor the line of sight passes over there: the street below when the giver looks down off a balcony, the
		# floor upstairs when they look up at it from below, the hall when they look up under its ceiling. A rising line
		# takes the highest floor under it (never lower than the eye's own reach); a falling one keeps node_at's reach.
		var line_y := eye.y + view.y / flat * d
		var at := Vector3(giver.position.x + view.x / flat * d, minf(line_y, maxf(eye.y, line_y - nav.pick_above)),
				giver.position.z + view.z / flat * d)
		if nav.is_walkable_at(at):
			return Vector3(at.x, nav.floor_at(at), at.z)
	return NO_SPOT


## Hold here for the teammates `bots` (by their place across `giver`'s view, left to right): each its own spot across the
## line of sight from `point`, hold_spacing apart (the point itself where that isn't walkable or isn't in a straight
## walkable line from it), or with no point (NO_SPOT), the spot it stands on.
static func place_hold(bots: Array[Bot], giver: Character, point: Vector3, w: BotWorld) -> void:
	place_across(bots, giver.yaw, point, w)


## Go there's and Hold here's spots for `bots` (left to right across `yaw`): as place_hold, across the line along `yaw`.
static func place_across(bots: Array[Bot], yaw: float, point: Vector3, w: BotWorld) -> void:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var n := bots.size()
	for k in n:
		var b := bots[k]
		if not is_spot(point):
			b.order_goal = b.character.position
			continue
		var spot := point + right * ((k - (n - 1) * 0.5) * w.cfg.squad.hold_spacing)
		# A side spot must be walkable and in a straight walkable line from the point (M-05: not on the far side of a
		# thin wall, which would send the bot round by the next doorway). The line checks every step's height, so a spot
		# along a ramp passes and one on another level fails.
		if w.nav.is_walkable_at(spot) and w.nav.clear_line(point, spot):
			b.order_goal = Vector3(spot.x, w.nav.floor_at(spot), spot.z)
		else:
			b.order_goal = point


## The middle of the spots held (or gone to: Go there) for `giver` among `bots`, or NO_SPOT if nobody holds one for them.
static func held_centre(bots: Array[Bot], giver: Character) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for b in bots:
		if (b.order == SquadOrder.Kind.HOLD or b.order == SquadOrder.Kind.MOVE) and b.order_giver == giver:
			sum += b.order_goal
			n += 1
	return sum / n if n > 0 else NO_SPOT


## Regroup: true once `b` is back within regroup_arrive of its giver, when it turns to Follow me (SquadOrderBook's,
## before the bots think), its spots behind the way the giver faces.
static func regrouped(b: Bot, w: BotWorld) -> bool:
	var giver := b.order_giver
	if b.order != SquadOrder.Kind.REGROUP or giver == null \
			or _flat(giver.position, b.character.position) > w.cfg.squad.regroup_arrive:
		return false
	b.order = SquadOrder.Kind.FOLLOW
	b.order_heading = giver.yaw
	return true


## Go there: true once `b` stands at its spot (or got as near as a route goes), when it holds it (order_settled).
static func moved_in(b: Bot) -> bool:
	return b.order == SquadOrder.Kind.MOVE and b.order_settled


## The yaw (the game's: 0 looks down -z, positive turns left) looking from `from` towards `to` along the ground; `fallback`
## when they stand on the same spot.
static func yaw_towards(from: Vector3, to: Vector3, fallback: float) -> float:
	var d := Vector2(to.x - from.x, to.z - from.z)
	return atan2(-d.x, -d.y) if d.length() > 1e-3 else fallback


## Follow me: the spot behind `giver`'s `heading` for follower `slot`: followers pair up either side of straight behind,
## each further pair a row back. Where that spot isn't walkable (a corridor wall, a drop) or can't be walked to in a
## straight line from the giver (the far side of a thin wall, M-05), straight behind at the same distance, then
## follow_fallback_step closer; only if none is, the giver's own position (never inside the giver while there is room
## behind).
static func follow_spot(giver: Character, heading: float, slot: int, w: BotWorld) -> Vector3:
	var cfg := w.cfg.squad
	var nav := w.nav
	var side := 1.0 if slot % 2 == 0 else -1.0
	var dist := cfg.follow_distance + floorf(slot * 0.5) * cfg.follow_row_gap
	var p := giver.position
	# Spots are measured from where the giver stands or, inside the margin the nav grid keeps from walls and edges (a
	# body touching a wall stands in it), from the nearest walkable cell: on the giver's side of that wall.
	var anchor := p
	if not nav.is_walkable_at(p):
		var k := nav.nearest_walkable(p, cfg.follow_line_snap)
		if k >= 0:
			anchor = nav.node_position(k)
		# A giver standing at a platform's lip can be nearest a cell on the ground below: measured from there, the spots
		# would be down a level with no way up nearby, so stay on the giver instead. A cell along a ramp is fine however
		# much higher or lower, as long as no drop lies between (in the air, the floor below is the level that counts).
		var anchor_floor := anchor.y if k >= 0 else nav.floor_at(p)
		if giver.grounded and absf(anchor_floor - p.y) > nav.max_step:
			var own_level := absf(nav.floor_at(p) - p.y) <= nav.max_step
			if not own_level or nav.drop_on_line(p, anchor):
				return p
	var behind := heading + PI
	var spot := _try_follow_spot(anchor, behind + side * deg_to_rad(cfg.follow_spread_deg), dist, nav)
	if is_spot(spot):
		return spot
	spot = _try_follow_spot(anchor, behind, dist, nav)
	if is_spot(spot):
		return spot
	spot = _try_follow_spot(anchor, behind, dist - cfg.follow_fallback_step, nav)
	return spot if is_spot(spot) else p


## The spot `dist` from `from` along `angle` if it is walkable and in a straight walkable line from `from`, else
## NO_SPOT. The line checks the height of every step, so a spot down a ramp counts and one past a drop or a step up
## doesn't: from an anchor on the giver's level (follow_spot sees to that), another level fails.
static func _try_follow_spot(from: Vector3, angle: float, dist: float, nav: NavGrid) -> Vector3:
	var spot := Vector3(from.x - sin(angle) * dist, from.y, from.z - cos(angle) * dist)
	if not nav.is_walkable_at(spot) or not nav.clear_line(from, spot):
		return NO_SPOT
	return Vector3(spot.x, nav.floor_at(spot), spot.z)


## Moves an ordered bot this tick (BotMovement's ORDER mode). Returns whether it walks (direction in b.move_dir); sets
## b.order_rush (sprint) and, following, cmd.walk.
static func move(b: Bot, w: BotWorld, cmd: PlayerCommand, dt: float) -> bool:
	var cfg := w.cfg.squad
	var was_rushing := b.order_rush
	b.order_rush = false
	var giver := b.order_giver
	if giver == null:
		return false
	match b.order:
		SquadOrder.Kind.HOLD, SquadOrder.Kind.MOVE:
			# No way there: it holds where it got to.
			if b.route_state == Bot.RouteState.FAILED:
				b.order_goal = b.character.position
				b.route_state = Bot.RouteState.NONE
			var walking := _walk_to(b, w, b.order_goal, cfg.hold_arrive, dt)
			# There (not merely waiting for a route): Go there turns to Hold here once all are.
			b.order_settled = not walking and (_flat(b.order_goal, b.character.position) <= cfg.hold_arrive
					or _arrived_for(b, b.order_goal, w))
			return walking
		SquadOrder.Kind.REGROUP:
			# Sprint back; once close the controller turns it into Follow me.
			b.order_rush = _flat(giver.position, b.character.position) > cfg.regroup_arrive
			b.order_goal = giver.position
			b.order_yaw = giver.yaw
			return _walk_to(b, w, b.order_goal, cfg.regroup_arrive, dt)
		SquadOrder.Kind.FOLLOW:
			# Keep a spot behind the way the giver moves, and cover their back once there.
			var v := giver.velocity
			if Vector2(v.x, v.z).length() >= cfg.heading_speed:
				# Eased, so the spots swing round behind a giver who turns rather than jump to the other side.
				var turn := wrapf(atan2(-v.x, -v.z) - b.order_heading, -PI, PI)
				var most := cfg.heading_turn_rate * dt
				b.order_heading = wrapf(b.order_heading + clampf(turn, -most, most), -PI, PI)
			b.order_goal = follow_spot(giver, b.order_heading, b.order_slot, w)
			var watch := cfg.follow_watch_deg
			var turned := deg_to_rad(watch[b.order_slot % watch.size()]) if not watch.is_empty() else PI
			b.order_yaw = b.order_heading + turned
			return _follow_move(b, w, giver, was_rushing, cmd, dt)
	return false


## Follow me's moving (the spot is in b.order_goal): settle at the spot while the giver stands still; otherwise make for
## it, straight there when the ground in between is clear (no route needed, so no stop at each replan) and round walls
## by the giver's way, at the giver's own pace: walking with a giver who walks or crouches, sprinting with one who
## sprints, a pace faster while catching up on the spot and one slower ahead of it, sprinting beyond catch_up.
static func _follow_move(b: Bot, w: BotWorld, giver: Character, was_rushing: bool, cmd: PlayerCommand,
		dt: float) -> bool:
	var cfg := w.cfg.squad
	var p := b.character.position
	var g := b.order_goal
	var gap := Vector2(g.x - p.x, g.z - p.z)
	var d := gap.length()
	var v := Vector2(giver.velocity.x, giver.velocity.z)
	var speed := v.length()
	var moving := speed >= cfg.heading_speed
	b.order_settled = not moving and (d <= cfg.follow_arrive
			or (b.order_settled and d <= cfg.follow_arrive + cfg.follow_settle))
	# How far the spot is ahead of the bot along the giver's way (negative: the bot is ahead of it).
	var behind := gap.dot(v) / speed if moving else 0.0
	b.order_catching_up = behind > cfg.catch_up_gap or (b.order_catching_up and behind > 0.0)
	b.order_dropping_back = behind < -cfg.catch_up_gap or (b.order_dropping_back and behind < 0.0)
	if b.order_settled:
		_stand(b)
		return false
	# The giver's pace; making for the spot with the giver still, a run, and a walk the last stretch.
	var pace := WALK
	if moving:
		pace = SPRINT if giver.sprinting \
				else WALK if giver.walking or giver.crouch_amount > cfg.crouched_pace else RUN
	elif d > cfg.follow_run_from:
		pace = RUN
	if b.order_catching_up and moving:
		pace = mini(SPRINT, pace + 1)
	elif b.order_dropping_back:
		# Ahead of the spot: a pace slower, so it drops back into place (from a walk, it waits for the spot to come by).
		pace -= 1
	if pace < WALK:
		_stand(b)
		return false
	if _flat(giver.position, p) > cfg.catch_up - (cfg.rush_ease if was_rushing else 0.0):
		pace = SPRINT
	b.order_rush = pace == SPRINT
	cmd.walk = pace == WALK
	if w.nav.clear_line(p, g):
		BotRoutes.drop(b)
		# Straight at the spot while the giver stands; with the giver on the move, go their way and close on the spot
		# (pursuit: their velocity plus a pull towards the spot), so the direction stays steady as the spot slides
		# along.
		var dir := v + gap * cfg.follow_pull if moving else gap
		var length := dir.length()
		# That blend is not the line checked above (M-08): where it would step off a drop just ahead, go straight at the
		# spot along the checked line instead. Walls only stop the bot (it slides along them), and checking for them too
		# flipped the way back and forth beside every wall.
		if moving and length >= 1e-6:
			var look := w.cfg.edge_lookahead / length
			if w.nav.drop_on_line(p, Vector3(p.x + dir.x * look, p.y, p.z + dir.y * look)):
				dir = gap
				length = d
		if length < 1e-6:
			return false
		b.move_dir = Vector3(dir.x / length, 0.0, dir.y / length)
		return true
	# No straight way to the spot. With the giver on the move, go the giver's own way round (G11): the spot is picked to
	# be walkable from the giver, not from here, and as it swings round behind a turning giver it can slide to the far
	# side of a container from the follower, whose route then flips round the other end and back. The way to the giver
	# can't flip; once the spot is in a straight line again, the bot makes for it as above.
	return _walk_to(b, w, giver.position if moving else g, 0.0, dt, false)


## Stands where it is (a route still being planned is kept for when it moves again).
static func _stand(b: Bot) -> void:
	if b.route_state != Bot.RouteState.WANTED:
		b.route_state = Bot.RouteState.NONE


## Walks to `goal` until within `arrive`, or (`settle`: a goal that stays put) until at the end of a route planned for
## about there. Returns whether it walks; a giver on the move shifts the goal every few metres, so it keeps walking the
## old route until the new one comes rather than stopping at each replan.
static func _walk_to(b: Bot, w: BotWorld, goal: Vector3, arrive: float, dt: float, settle: bool = true) -> bool:
	var p := b.character.position
	if Vector2(goal.x - p.x, goal.z - p.z).length() <= arrive or (settle and _arrived_for(b, goal, w)):
		_stand(b)
		return false
	BotRoutes.want(b, goal, w.cfg)
	return BotRoutes.follow(b, w, dt, true)


## True if `b` got to the end of a route planned for about `goal` and stands there (nothing to replan).
static func _arrived_for(b: Bot, goal: Vector3, w: BotWorld) -> bool:
	return BotRoutes.arrived(b) and Vector2(goal.x - b.route_goal.x, goal.z - b.route_goal.z).length() \
			< w.cfg.replan_distance


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
