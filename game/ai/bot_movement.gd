class_name BotMovement
## Where a bot walks (the browser game's ai/botMovement.ts): its lane point by point with a pause at each (crouched
## where that still sees ahead, or from crouch cover close by), waiting for a team that falls behind, then hunting the
## stalest spot its team hasn't checked (in Attack / Defend, a defender holds its last point and an attacker makes for
## the pole); at the pole, raising or pulling down the flag, or guarding it from cover; to where someone was seen or
## heard (round by a flank first, sometimes) and a look round there; into cover and onto a lean spot; sidestepping in a
## fight without stepping off a floor, into a wall or out of sight of its target; and keeping apart from everyone else.
## Writes the way to walk into Bot.move_dir. Allocates nothing.

## The two steps of an R2 sequence: a bot's glances spread evenly over its view, with no dice.
const GLANCE_ACROSS := 0.7548776662466927
const GLANCE_OUT := 0.5698402909980532


## Moves per mode. Returns whether the bot walks (direction in b.move_dir). `target`: whom it fights.
static func move(b: Bot, w: BotWorld, cmd: PlayerCommand, dt: float, target: Character) -> bool:
	b.holding = false
	# Any tick not spent settled at its post (_advance sets it again) ends the hold there: the next is a fresh one.
	var at_post := b.at_post
	b.at_post = false
	match b.mode:
		Bot.Mode.ADVANCE:
			return _advance(b, w, dt, at_post)
		Bot.Mode.SEARCH:
			return _search(b, w, cmd, dt)
		Bot.Mode.COVER:
			# Get there, then keep low, standing only to look over crouch cover. At a lean spot, stand right on it.
			if BotRoutes.follow(b, w, dt):
				return true
			if b.cover.lean == 0:
				cmd.crouch = b.route_state == Bot.RouteState.NONE and b.cover_phase == Bot.CoverPhase.DOWN
				return false
			return b.route_state == Bot.RouteState.NONE and BotRoutes.step_onto(b, w, b.cover.position, cmd, dt)
		Bot.Mode.FLAG:
			return _flag(b, w, cmd, dt)
		Bot.Mode.ORDER:
			return SquadOrders.move(b, w, cmd, dt)
		Bot.Mode.MAG:
			return BotMagShare.move(b, w, cmd, dt)
		Bot.Mode.FIGHT:
			# Fighting from cover, or at the pole raising the flag: it stays put.
			var rope := w.flags[BotFlag.pole_of(b, w)]
			if b.from_cover or (b.raiser and Flag.at_pole(b.character, rope, w.tuning.flag)):
				return false
			_strafe(b, w, cmd, dt, target)
	return false


## Into flag mode (BotFlag.wants_flag): picks its spot by the pole and heads there.
static func enter_flag(b: Bot, w: BotWorld) -> void:
	b.mode = Bot.Mode.FLAG
	_pick_flag_spot(b, w)


## Flag mode: whether `b` guards the pole from cover rather than going to it (an attacker that isn't raising); in
## Elimination's overtime, whether it watches the flag first (BotPersonality.overtime_watching).
static func _guards_flag(b: Bot, w: BotWorld) -> bool:
	if w.overtime_flag.up:
		return BotPersonality.overtime_watching(b, w)
	return BotFlag.role(b, w) == BotFlag.Role.ATTACK and not b.raiser


## The raiser (and a defender pulling the flag down) stands at a random spot within flag_stand of the pole; a guard
## takes crouch cover within flag_guard_radius of it, hidden from where an enemy was last known (or from a point
## flag_guard_threat_distance towards the defenders' side), or failing that a random spot that far out. In
## Elimination's overtime (OV2) a bot heads for the flag's very foot (a touch wins), round the side first if its flank
## roll came up, and one watching the flag first guards it as an attacker guards the pole.
static func _pick_flag_spot(b: Bot, w: BotWorld) -> void:
	var cfg := w.cfg
	b.flag_pole = BotFlag.pole_of(b, w)
	var pole := BotFlag.spot(b, w)
	b.flag_guard = _guards_flag(b, w)
	b.team_wait = 0.0
	b.flanking = false
	BotRoutes.drop(b)
	if not b.flag_guard and w.overtime_flag.up:
		b.flag_goal = pole
		if b.overtime_flank:
			b.overtime_flank = false
			_overtime_flank_point(b, w, pole)
		return
	if not b.flag_guard:
		b.flag_goal = _jitter(b, w, pole, cfg.flag_stand)
		return
	var threat := Vector3.ZERO
	if b.has_last_known:
		threat = Vector3(b.last_known.x, 0.0, b.last_known.z)
	else:
		var yaw := w.enemy_yaw(b.character.team)
		threat = Vector3(pole.x - sin(yaw) * cfg.flag_guard_threat_distance, 0.0,
				pole.z - cos(yaw) * cfg.flag_guard_threat_distance)
	threat.y = pole.y + w.tuning.body.stand_eye_height
	var taken := BotRoutes.teammate_spots(b, w)
	if BotCover.find(pole, threat, w, b.rng, b.hold_spot, cfg.flag_guard_radius, 0, true, BotRoutes.taken(), taken,
			true):
		b.flag_goal = b.hold_spot.position
	else:
		b.flag_goal = _jitter(b, w, pole, cfg.flag_guard_radius)
	b.hold_crouch = _crouched_view_clear(b, w, b.flag_goal)


## Overtime (OV2): the way to the flag at `flag` goes round by a point overtime_flank_offset to one side of the straight
## way and overtime_flank_back short of the flag (walkable, on the flag's floor; where a pillar or a hut's clearance
## covers that point, the nearest walkable spot within the nav's snap), so it comes at it from the side; none from
## closer than overtime_flank_min_distance, or where neither side has floor near.
static func _overtime_flank_point(b: Bot, w: BotWorld, flag: Vector3) -> void:
	var cfg := w.cfg
	var p := b.character.position
	var flat := Vector2(flag.x - p.x, flag.z - p.z)
	var d := flat.length()
	if d < cfg.overtime_flank_min_distance:
		return
	var u := flat / d
	var first := 1.0 if b.rng.randf() < 0.5 else -1.0
	for i in 2:
		var side := first if i == 0 else -first
		var x := flag.x - u.x * cfg.overtime_flank_back - u.y * cfg.overtime_flank_offset * side
		var z := flag.z - u.y * cfg.overtime_flank_back + u.x * cfg.overtime_flank_offset * side
		var goal := Vector3(x, flag.y, z)
		if _on_same_floor(w, flag, x, z):
			goal.y = w.nav.floor_at(goal)
		else:
			var k := w.nav.nearest_walkable(goal, w.tuning.nav.snap)
			if k < 0:
				continue
			goal = w.nav.node_position(k)
			if absf(goal.y - flag.y) > w.tuning.body.max_step:
				continue
		b.flank_goal = goal
		b.flanking = true
		return


## Flag mode: to the spot by the pole (or the guard spot) and stay there, crouched working the rope, or holding guard.
## In overtime, round the side first when flanking (_overtime_flank_point).
static func _flag(b: Bot, w: BotWorld, cmd: PlayerCommand, dt: float) -> bool:
	var cfg := w.cfg
	# The raiser changed (hit, or the player took the rope), or an overtime watch is over: raise, or guard, instead. The
	# pole it makes for changed (a flag went up at the other while it isn't on a worked rope, AB1): to that one.
	if b.flag_guard != _guards_flag(b, w) or b.flag_pole != BotFlag.pole_of(b, w):
		_pick_flag_spot(b, w)
	if b.flanking:
		BotRoutes.want(b, b.flank_goal, cfg)
		if BotRoutes.follow(b, w, dt):
			return true
		if b.route_state == Bot.RouteState.WANTED:
			return false
		# Round the side (or no way round): now straight on for the flag.
		b.flanking = false
		BotRoutes.drop(b)
	var p := b.character.position
	var arrive := cfg.cover_arrive if b.flag_guard else cfg.flag_arrive
	if Vector2(b.flag_goal.x - p.x, b.flag_goal.z - p.z).length() <= arrive:
		BotRoutes.drop(b)
		b.holding = b.flag_guard
		if b.flag_guard:
			b.team_wait += dt
		else:
			cmd.crouch = true
		return false
	var pole := BotFlag.spot(b, w)
	if b.route_state == Bot.RouteState.FAILED:
		if not b.flag_guard and (b.flag_goal.x != pole.x or b.flag_goal.z != pole.z):
			# No way to that spot: try the foot of the pole itself.
			b.flag_goal = pole
			b.route_state = Bot.RouteState.NONE
		elif w.time >= b.route_retry_at:
			# No way there either: try again every route_retry_delay rather than stand there for good.
			b.route_state = Bot.RouteState.NONE
	BotRoutes.want(b, b.flag_goal, cfg)
	return BotRoutes.follow(b, w, dt)


## A search begins: with the skill's flank_chance, and a far enough spot, go round by a point to one side first.
static func start_search(b: Bot, w: BotWorld) -> void:
	var cfg := w.cfg
	b.search_look_left = 0.0
	b.flanking = false
	var p := b.character.position
	var k := b.last_known
	var flat := Vector2(k.x - p.x, k.z - p.z)
	var d := flat.length()
	if d < cfg.flank_min_distance or b.rng.randf() >= b.skill.flank_chance:
		return
	var u := flat / d
	var first := 1.0 if b.rng.randf() < 0.5 else -1.0
	for i in 2:
		var side := first if i == 0 else -first
		var x := k.x - u.x * cfg.flank_back - u.y * cfg.flank_offset * side
		var z := k.z - u.y * cfg.flank_back + u.x * cfg.flank_offset * side
		if not _on_same_floor(w, k, x, z):
			continue
		b.flank_goal = Vector3(x, w.nav.floor_at(Vector3(x, k.y, z)), z)
		b.flanking = true
		return


## One glance a tick at a spot in its view, for the team's hunt memory: a spot seen empty isn't walked to.
static func glance(b: Bot, w: BotWorld) -> void:
	var range_m := w.cfg.hunt_clear_range
	if range_m <= 0.0 or not w.live:
		return
	var me := b.character
	b.glances += 1
	var across := fmod(b.glances * GLANCE_ACROSS, 1.0)
	var out := fmod(b.glances * GLANCE_OUT, 1.0)
	var yaw := me.yaw + (across - 0.5) * deg_to_rad(w.cfg.fov_deg)
	var near := minf(range_m, w.cfg.hunt_sector_size)
	# Even over the area of the view's slice, not bunched up close.
	var d := near + (range_m - near) * sqrt(out)
	var spot := Vector3(me.position.x - sin(yaw) * d, me.position.y, me.position.z - cos(yaw) * d)
	if not w.nav.is_walkable_at(spot):
		return
	spot.y = w.nav.floor_at(spot)
	if BotSenses.sees_spot(me, spot, range_m, w):
		w.mark_visited(me.team, spot)


## Steers `b` off anyone in play close by (bodies pass through each other in the physics), harder the closer. Walking,
## the push bends the walk; standing with nothing else to do, it walks out of the way, never off a floor. Returns
## whether it walks now.
static func keep_apart(b: Bot, w: BotWorld, moving: bool, cmd: PlayerCommand) -> bool:
	var me := b.character
	var reach := w.cfg.separation_distance
	var push := Vector2.ZERO
	for o in w.characters:
		if o == me or not Elimination.is_in_play(o) or absf(o.position.y - me.position.y) > w.tuning.body.height:
			continue
		var away := Vector2(me.position.x - o.position.x, me.position.z - o.position.z)
		var d := away.length()
		if d >= reach:
			continue
		var k := (reach - d) / reach
		if d > 1e-4:
			push += away / d * k
		else:
			push.x += k if me.id < o.id else -k
	if push == Vector2.ZERO:
		return moving
	if moving:
		var bent := Vector2(b.move_dir.x, b.move_dir.z) + push
		var size := bent.length()
		if size < 1e-6:
			return moving
		bent *= 1.0 / size if size > 1.0 else 1.0 # no faster than the walk, slower where the push is against it
		b.move_dir = Vector3(bent.x, 0.0, bent.y)
		return true
	if cmd.forward != 0.0 or cmd.right != 0.0:
		# Sidestepping already: to the side the push points, unless that side is blocked.
		var side := push.x * cos(b.aim_yaw) - push.y * sin(b.aim_yaw)
		var right := 1.0 if side > 0.0 else -1.0
		if absf(side) > 1e-6 and cmd.right != right and not _step_off_ground(b, w, right, cmd.forward):
			cmd.right = right
		return false
	var dir := push.normalized()
	# Never pushed off a floor: along the edge instead, either way round, or stand.
	if _drop_ahead(b, w, dir):
		dir = Vector2(-dir.y, dir.x)
		if _drop_ahead(b, w, dir):
			dir = -dir
			if _drop_ahead(b, w, dir):
				return moving
	b.move_dir = Vector3(dir.x, 0.0, dir.y)
	cmd.walk = true
	return true


## Advance: lane points with a pause (and maybe crouch cover) at each, waiting for the team where it got ahead, then
## hunting; an anchor holds its last point instead until its time (`at_post`: it was settled there last tick).
static func _advance(b: Bot, w: BotWorld, dt: float, at_post: bool = false) -> bool:
	var cfg := w.cfg
	if b.hold_left > 0.0:
		b.hold_left -= dt
		b.team_wait += dt
		b.holding = true
		return false
	# At a lane point well ahead of the team: wait for them to catch up. Moving in pairs (team play): also while a lane
	# partner nearby is on the move (for up to bound_wait_max), so one covers while the other moves. A personality that
	# never waits for the team goes on.
	var waiting := b.style.waits_for_team and ((b.team_wait < cfg.team_wait_max and w.planner.ahead_of_team(b, w))
			or (b.skill.team_play and b.team_wait < cfg.bound_wait_max and _partner_moving(b, w)))
	if b.wait_for_team and waiting:
		b.team_wait += dt
		b.holding = true
		return false
	b.wait_for_team = false
	if b.hold_cover:
		# Stepping into cover by the lane point just reached: hold from there once there, then on to the next point.
		if BotRoutes.follow(b, w, dt):
			return true
		if b.route_state == Bot.RouteState.WANTED:
			return false
		b.hold_cover = false
		if BotFlag.holds_post(b, w) and _at_last_point(b, w):
			# A defender's or an anchor's post is the cover by its last lane point: it holds there (_next_goal gives it no
			# goal).
			BotRoutes.drop(b)
			return false
		_start_hold(b, w)
		b.route_state = Bot.RouteState.NONE
		BotRoutes.want(b, b.lane_goal, cfg)
		return false
	# Hunting, its goal checked meanwhile by its team or by its own eyes: off to the next, walking on as it comes.
	if b.hunting and b.route_state == Bot.RouteState.OK and _hunt_goal_done(b, w) and _pick_hunt(b, w):
		BotRoutes.want(b, b.hunt_goal, cfg)
		return BotRoutes.follow(b, w, dt, true)
	if b.route_state == Bot.RouteState.NONE or b.route_state == Bot.RouteState.FAILED:
		if b.route_state == Bot.RouteState.FAILED:
			# No way to the last goal: a moment before the next ask; a hunt spot it can't reach counts as checked.
			if w.time < b.route_retry_at:
				return false
			if b.hunting:
				w.mark_visited(b.character.team, b.route_goal)
		var reached := BotRoutes.arrived(b)
		if not _next_goal(b, w):
			if BotFlag.holds_post(b, w):
				_hold_post(b, w, dt, reached, at_post)
			return false
		if reached and not b.hunting:
			if _pick_hold_cover(b, w):
				b.hold_cover = true
				b.route_state = Bot.RouteState.NONE
				BotRoutes.want(b, b.hold_spot.position, cfg)
				return false
			# Pause at the point just reached, looking ahead, then wait for the team if need be.
			_start_hold(b, w)
		b.route_state = Bot.RouteState.NONE
		BotRoutes.want(b, b.hunt_goal if b.hunting else b.lane_goal, cfg)
	return BotRoutes.follow(b, w, dt)


## The next place to go while advancing, into lane_goal (the next lane point, moved a little at random) or, the lane
## swept, hunt_goal. False if there is none: an anchor holding, or in Attack / Defend a defender at its post or an
## attacker off to the pole (lane_done).
static func _next_goal(b: Bot, w: BotWorld) -> bool:
	if not b.hunting and b.lane >= 0 and b.lane < w.lanes.size():
		var lane := w.lanes[b.lane]
		var next := (0 if b.lane_dir > 0 else lane.size() - 1) if b.lane_index < 0 else b.lane_index + b.lane_dir
		var walked := next if b.lane_dir > 0 else lane.size() - 1 - next
		if next >= 0 and next < lane.size() and walked < b.lane_points:
			b.lane_index = next
			b.lane_goal = _jitter(b, w, lane[next], w.cfg.lane_jitter)
			_stagger_hold(b, w)
			# At night it holds out of the light pools (BotWorld.out_of_light).
			b.lane_goal = w.out_of_light(b.lane_goal)
			return true
	# Attack / Defend: a defender holds its last point; an attacker goes for the pole (BotFlag.wants_flag).
	match BotFlag.role(b, w):
		BotFlag.Role.DEFEND:
			return false
		BotFlag.Role.ATTACK:
			b.lane_done = true
			return false
	# An anchor holds its last point, short of the middle, until late in the round; then it hunts.
	if BotPersonality.anchor_holding(b, w):
		return false
	b.hunting = true
	return _pick_hunt(b, w)


## Defenders sharing a lane (Attack / Defend): with a teammate holding at (or heading to hold at) about b.lane_goal, the
## goal moves lane_hold_offset to one side, across the way to the enemy (a random side first, onto its own floor), so
## the two hold side by side, not one inside the other. A defender that plays as a team sets a crossfire instead, if it
## can. (The browser game staggers every bot's lane points; here only defenders', who stop on them.)
static func _stagger_hold(b: Bot, w: BotWorld) -> void:
	if BotFlag.role(b, w) != BotFlag.Role.DEFEND:
		return
	var cfg := w.cfg
	var g := b.lane_goal
	var mate := Vector3.INF
	for o in w.bots:
		if o == b or o.character.team != b.character.team or not Elimination.is_in_play(o.character):
			continue
		var p := o.character.position
		if Vector2(p.x - g.x, p.z - g.z).length() < cfg.lane_hold_spacing:
			mate = p
			break
		var heading := o.mode == Bot.Mode.ADVANCE and not o.hunting and o.lane == b.lane
		if heading and Vector2(o.lane_goal.x - g.x, o.lane_goal.z - g.z).length() < cfg.lane_hold_spacing:
			mate = o.lane_goal
			break
	if mate == Vector3.INF:
		return
	if b.skill.team_play and _crossfire_spot(b, w, mate):
		return
	var yaw := w.enemy_yaw(b.character.team)
	# The view's right on the ground is (cos yaw, 0, -sin yaw).
	var side := 1.0 if b.rng.randf() < 0.5 else -1.0
	for k in 2:
		var x := g.x + cos(yaw) * cfg.lane_hold_offset * side
		var z := g.z - sin(yaw) * cfg.lane_hold_offset * side
		if _on_same_floor(w, g, x, z):
			b.lane_goal = Vector3(x, g.y, z)
			return
		side = -side


## Crossfire: moves b.lane_goal round the lane's next point (the choke towards the attackers) by crossfire_turn_deg, at
## the same distance from it, to the first spot on its floor that sees the choke at head height from an angle at least
## crossfire_min_deg away from `mate`'s. False (goal unchanged) if the lane has no next point or no spot will do.
static func _crossfire_spot(b: Bot, w: BotWorld, mate: Vector3) -> bool:
	var cfg := w.cfg
	if b.lane < 0 or b.lane >= w.lanes.size():
		return false
	var lane := w.lanes[b.lane]
	var at := b.lane_index + b.lane_dir
	if at < 0 or at >= lane.size():
		return false
	var choke := lane[at]
	var g := b.lane_goal
	var dx := g.x - choke.x
	var dz := g.z - choke.z
	if Vector2(dx, dz).length() < 1e-6:
		return false
	var eye_up := w.tuning.body.stand_eye_height
	var choke_eye := Vector3(choke.x, choke.y + eye_up, choke.z)
	var mate_yaw := atan2(mate.x - choke.x, mate.z - choke.z)
	var least := cfg.crossfire_turn_deg.x
	var most := cfg.crossfire_turn_deg.y
	for k in 3:
		var turn := deg_to_rad(least + (most - least) * k / 2.0)
		for j in 2:
			var side := 1.0 if j == 0 else -1.0
			var c := cos(turn * side)
			var s := sin(turn * side)
			var x := choke.x + dx * c + dz * s
			var z := choke.z - dx * s + dz * c
			if not _on_same_floor(w, g, x, z):
				continue
			if absf(angle_difference(mate_yaw, atan2(x - choke.x, z - choke.z))) < deg_to_rad(cfg.crossfire_min_deg):
				continue
			var floor_y := w.nav.floor_at(Vector3(x, g.y, z))
			if not BotSenses.line_clear(w.query, Vector3(x, floor_y + eye_up, z), choke_eye):
				continue
			b.lane_goal = Vector3(x, floor_y, z)
			return true
	return false


## True if a teammate bot in play walks or holds `b`'s lane too (not hunting).
static func _lane_shared(b: Bot, w: BotWorld) -> bool:
	for o in w.bots:
		if o != b and o.character.team == b.character.team and o.lane == b.lane and o.mode == Bot.Mode.ADVANCE \
				and not o.hunting and Elimination.is_in_play(o.character):
			return true
	return false


## True if the lane point `b` last reached is the last it walks (b.lane_points).
static func _at_last_point(b: Bot, w: BotWorld) -> bool:
	if b.hunting or b.lane < 0 or b.lane >= w.lanes.size() or b.lane_index < 0:
		return false
	var walked := b.lane_index if b.lane_dir > 0 else w.lanes[b.lane].size() - 1 - b.lane_index
	return walked + 1 >= b.lane_points


static func _pick_hunt(b: Bot, w: BotWorld) -> bool:
	if not w.planner.hunt_point(b, w):
		return false
	b.hunt_picked_at = w.time
	return true


## Whether `b`'s hunt goal needs no visit: its team checked that sector since the bot picked it, or it sees the spot
## empty from here. At most once a think after a pick.
static func _hunt_goal_done(b: Bot, w: BotWorld) -> bool:
	if w.time - b.hunt_picked_at < w.cfg.think_interval:
		return false
	var p := b.character.position
	var team := b.character.team
	if w.sector_of(b.hunt_goal) != w.sector_of(p) and w.visited_at(team, b.hunt_goal) > b.hunt_picked_at:
		return true
	var d := Vector2(b.hunt_goal.x - p.x, b.hunt_goal.z - p.z).length()
	if d <= w.cfg.cover_arrive or not BotSenses.sees_spot(b.character, b.hunt_goal, w.cfg.hunt_clear_range, w):
		return false
	w.mark_visited(team, b.hunt_goal)
	return true


## `point` moved up to `radius` at random onto walkable ground on its own floor (unmoved if no spot turns up).
static func _jitter(b: Bot, w: BotWorld, point: Vector3, radius: float) -> Vector3:
	for i in w.cfg.lane_jitter_tries:
		var angle := b.rng.randf() * TAU
		var r := sqrt(b.rng.randf()) * radius
		var x := point.x + cos(angle) * r
		var z := point.z + sin(angle) * r
		if _on_same_floor(w, point, x, z):
			return Vector3(x, w.nav.floor_at(Vector3(x, point.y, z)), z)
	return point


## True if (x, z) is walkable and on the floor `point` stands on (within a step of its height).
static func _on_same_floor(w: BotWorld, point: Vector3, x: float, z: float) -> bool:
	var at := Vector3(x, point.y, z)
	return w.nav.is_walkable_at(at) and absf(w.nav.floor_at(at) - point.y) <= w.tuning.body.max_step


## A defender or an anchor at its last lane point: just come to it, it may step into crouch cover by it (as at any lane
## point) and hold from there; else it holds where it stands, crouched if crouched eyes still see the enemy side (chosen
## once, on arrival: `at_post`, it was here last tick too).
static func _hold_post(b: Bot, w: BotWorld, dt: float, arrived: bool, at_post: bool) -> void:
	if arrived:
		# The route walked is done with, so it isn't "arrived" again next tick: one look per arrival.
		BotRoutes.drop(b)
		if _pick_hold_cover(b, w):
			b.hold_cover = true
			BotRoutes.want(b, b.hold_spot.position, w.cfg)
			return
	if not at_post:
		b.hold_crouch = _crouched_view_clear(b, w, b.character.position)
	b.at_post = true
	b.holding = true
	b.team_wait += dt


## The pause at the lane point just reached: how long, whether to wait for the team, whether to crouch.
static func _start_hold(b: Bot, w: BotWorld) -> void:
	b.hold_left = b.pick(b.skill.hold_time)
	b.team_wait = 0.0
	b.wait_for_team = true
	b.hold_crouch = _crouched_view_clear(b, w, b.character.position)


## True if crouched eyes at `at` see hold_look_distance towards the enemy: worth crouching to hold there. Behind crouch
## cover they don't, so it holds standing and looks over it.
static func _crouched_view_clear(b: Bot, w: BotWorld, at: Vector3) -> bool:
	var yaw := BotAim.hold_yaw(b, w)
	var floor_y := w.nav.floor_at(at)
	var eye := Vector3(at.x, (at.y if is_nan(floor_y) else floor_y) + w.tuning.body.crouch_eye_height, at.z)
	var look := eye + Vector3(-sin(yaw), 0.0, -cos(yaw)) * w.cfg.hold_look_distance
	return BotSenses.line_clear(w.query, eye, look)


## At a lane point, maybe (the skill's hold_cover_chance) crouch cover close by to hold from: hidden from a point
## hold_cover_threat_distance towards the enemy, off teammates' spots. False to hold where it stands (always, for a
## defender that plays as a team on a shared lane: it holds its crossfire point).
static func _pick_hold_cover(b: Bot, w: BotWorld) -> bool:
	# Two defenders that play as a team sharing a lane hold their crossfire points, not cover beside them.
	if b.skill.team_play and BotFlag.role(b, w) == BotFlag.Role.DEFEND and _lane_shared(b, w):
		return false
	if b.rng.randf() >= b.skill.hold_cover_chance:
		return false
	var cfg := w.cfg
	var p := b.character.position
	var yaw := w.enemy_yaw(b.character.team)
	var threat := p + Vector3(-sin(yaw) * cfg.hold_cover_threat_distance, w.tuning.body.stand_eye_height,
			-cos(yaw) * cfg.hold_cover_threat_distance)
	var taken := BotRoutes.teammate_spots(b, w)
	return BotCover.find(p, threat, w, b.rng, b.hold_spot, cfg.hold_cover_radius, 0, true, BotRoutes.taken(), taken,
			true) and b.hold_spot.crouch_only


## True if a bot teammate on the same lane, within bound_distance, is walking it now (team play: one moves, one covers).
static func _partner_moving(b: Bot, w: BotWorld) -> bool:
	var p := b.character.position
	for o in w.bots:
		if o == b or o.character.team != b.character.team or o.lane != b.lane or not Elimination.is_in_play(o.character):
			continue
		# Set off this tick (its route still wanted) counts: bots think in turn, and two at their points must not both go.
		# One handed a squad order is no partner, even before it turns to the order.
		if o.mode != Bot.Mode.ADVANCE or o.hunting or o.holding or o.order != SquadOrder.Kind.NONE \
				or (o.route_state != Bot.RouteState.OK and o.route_state != Bot.RouteState.WANTED):
			continue
		if Vector2(o.character.position.x - p.x, o.character.position.z - p.z).length() <= w.cfg.bound_distance:
			return true
	return false


## Search: to the spot (round by a flank point first, if flanking), then crouch and look round.
static func _search(b: Bot, w: BotWorld, cmd: PlayerCommand, dt: float) -> bool:
	# Watching where someone ducked out of sight (skill.peek_watch_time) before going after them: they may peek again.
	if w.time < b.watch_until:
		return false
	if b.search_look_left > 0.0:
		b.search_look_left -= dt
		cmd.crouch = true
		if b.search_look_left <= 0.0:
			_forget_search(b, w)
		return false
	BotRoutes.want(b, b.flank_goal if b.flanking else b.last_known, w.cfg)
	if BotRoutes.follow(b, w, dt):
		return true
	if b.flanking and b.route_state != Bot.RouteState.WANTED:
		# Round the side (or no way round): now for the spot itself.
		b.flanking = false
		b.route_state = Bot.RouteState.NONE
		return false
	if b.route_state == Bot.RouteState.NONE:
		b.search_look_time = b.pick(w.cfg.search_look)
		b.search_look_left = b.search_look_time
		b.search_look_yaw = b.aim_yaw
		cmd.crouch = true
	elif b.route_state == Bot.RouteState.FAILED:
		_forget_search(b, w)
	return false


## A search over with nobody found: forget the spot (or turn to another enemy heard meanwhile).
static func _forget_search(b: Bot, w: BotWorld) -> void:
	b.search_look_left = 0.0
	b.has_last_known = false
	b.heard_at = -INF
	if b.recall_heard_other(w.time, w.cfg):
		b.route_state = Bot.RouteState.NONE


## Sidestepping while shooting: never off a floor, into a wall or out of sight of the target; the other way, or
## forward or back if both sides are blocked, or it stands.
static func _strafe(b: Bot, w: BotWorld, cmd: PlayerCommand, dt: float, target: Character) -> void:
	var cfg := w.cfg
	b.strafe_left -= dt
	var new_step := b.strafe_left <= 0.0
	if new_step:
		b.strafe_left = b.pick(cfg.strafe_time)
		b.strafe_dir = -1 if b.rng.randf() < 0.5 else 1
	# Pushing in (a personality's habit): whether a step forward keeps the target in sight is looked at once a sidestep
	# or for a new target; whether the ground ahead is there, every tick.
	var pusher := target != null and BotPersonality.pushes_in(b)
	if pusher and (new_step or b.push_look_for != target.id):
		b.push_in_sight = not _step_blocked(b, w, 0.0, 1.0, target)
		b.push_look_for = target.id
	if _step_blocked(b, w, b.strafe_dir, 0.0, target):
		b.strafe_dir = -b.strafe_dir
	# It closes in as it sidesteps, until push_distance from its target.
	if pusher and b.push_in_sight and Vector2(target.position.x - b.character.position.x,
			target.position.z - b.character.position.z).length() > cfg.push_distance \
			and not _step_off_ground(b, w, 0.0, 1.0):
		cmd.forward = cfg.strafe_input
	if not _step_blocked(b, w, b.strafe_dir, 0.0, target):
		cmd.right = b.strafe_dir * cfg.strafe_input
	elif not _step_blocked(b, w, 0.0, b.strafe_dir, target):
		cmd.forward = b.strafe_dir * cfg.strafe_input
	elif not _step_blocked(b, w, 0.0, -b.strafe_dir, target):
		cmd.forward = -b.strafe_dir * cfg.strafe_input


## A step to the view's right (`right` 1) or left (-1), or forward or back, would soon leave a floor or meet a wall, or
## lose sight of `target` from eyes moved that way.
static func _step_blocked(b: Bot, w: BotWorld, right: float, forward: float, target: Character) -> bool:
	if _step_off_ground(b, w, right, forward):
		return true
	if target == null or not b.target_visible:
		return false
	var eye := BotSenses.eye_of(b.character, w.tuning) + _step_dir(b, right, forward) * w.cfg.strafe_sight_offset
	return not BotSenses.line_clear(w.query, eye, BotSenses.body_point(target, w.tuning.hits, b.target_part))


## The view's right on the ground is (cos yaw, 0, -sin yaw), its forward (-sin yaw, 0, -cos yaw).
static func _step_dir(b: Bot, right: float, forward: float) -> Vector3:
	return Vector3(cos(b.aim_yaw) * right - sin(b.aim_yaw) * forward, 0.0,
			-sin(b.aim_yaw) * right - cos(b.aim_yaw) * forward)


static func _step_off_ground(b: Bot, w: BotWorld, right: float, forward: float) -> bool:
	var p := b.character.position
	var ahead := p + _step_dir(b, right, forward) * w.cfg.edge_lookahead
	return w.nav.drop_on_line(p, ahead) or not w.nav.is_walkable_at(ahead)


static func _drop_ahead(b: Bot, w: BotWorld, dir: Vector2) -> bool:
	var p := b.character.position
	return w.nav.drop_on_line(p, p + Vector3(dir.x, 0.0, dir.y) * w.cfg.edge_lookahead)
