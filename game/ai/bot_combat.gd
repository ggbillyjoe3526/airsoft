class_name BotCombat
## A bot's aim, trigger and reloads (the browser game's ai/botCombat.ts): it turns to the part of its target it sees,
## leading it by part of the BB's flight, with an aim error that settles; it fires bursts only once it has reacted and is
## on aim, never into a wall close in front, never with a teammate (or someone already out) in the line of fire, a miss's
## flight past the target included. With nobody in sight it looks where it walks, where a threat was, or across the enemy
## side. Allocates nothing.

static var _hit: RayHit = RayHit.new()
static var _volume: Hitbox.Volume = Hitbox.Volume.new()
## The point aim() last aimed at (with lead): shoot() reads it the same tick.
static var _aim_point: Vector3 = Vector3.ZERO
## Whether the last line-of-fire check found the level itself (a wall, glass, leaves) on the line to the aim point.
static var _level_in_line: bool = false
## Where aim() looks with nobody in sight, set by the branch that decides it (and by _held_angle_look).
static var _look_yaw: float = 0.0
static var _look_pitch: float = 0.0


## Turns `b`'s view from `eye`: at its target (lead and aim error), else per its mode (`walking`: along b.move_dir).
## Aim is worse while it moves or sidesteps. Returns how far the view still is from the erroneous aim point (rad), or
## INF with no target in sight.
static func aim(b: Bot, w: BotWorld, target: Character, eye: Vector3, walking: bool, cmd: PlayerCommand,
		dt: float) -> float:
	var cfg := w.cfg
	if b.target_visible and target != null and b.contact != null:
		var point := BotSenses.body_point(target, w.tuning.hits, b.target_part)
		var dist := eye.distance_to(point)
		var flight := flight_time(b, w, dist)
		point.x += target.velocity.x * flight * b.skill.lead_factor
		point.z += target.velocity.z * flight * b.skill.lead_factor
		_aim_point = point
		var v := target.velocity
		var across := Vector2(point.x - eye.x, point.z - eye.z)
		var sideways := (v.x * across.y - v.z * across.x) / maxf(across.length(), 1e-3)
		var since := BotAim.settling(w.time, b.contact, cfg)
		var first := BotAim.first_error_size(since, dist, b.skill)
		var error := BotAim.error_size(since, walking or cmd.right != 0.0, dist, sideways, b.skill)
		return BotAim.step(b, BotAim.look_yaw(eye, point), BotAim.look_pitch(eye, point), error - first, first, cfg, dt)
	_look_yaw = b.aim_yaw
	_look_pitch = 0.0
	var walk_yaw := atan2(-b.move_dir.x, -b.move_dir.z)
	var enemy := w.enemy_yaw(b.character.team)
	if walking and b.vault_leg:
		# At a low obstacle on its route: face the way over it, as nobody vaults without looking.
		_look_yaw = walk_yaw
	elif b.mode == Bot.Mode.SEARCH and b.search_look_left > 0.0:
		# At the end of a search: look round, one way then the other, from the way it arrived.
		var t := 1.0 - b.search_look_left / b.search_look_time
		_look_yaw = b.search_look_yaw + sin(TAU * t) * deg_to_rad(cfg.search_look_deg)
	elif walking and b.careful and b.mode == Bot.Mode.SEARCH and b.has_last_known \
			and _slice_towards_last_known(b, w, eye, cmd):
		# Slicing towards someone heard or lost: while the spot is round a corner, aim at that corner and lean out.
		pass
	elif b.has_last_known and (b.mode == Bot.Mode.SEARCH or b.mode == Bot.Mode.COVER or not walking):
		# Watch where the threat was, even on the way there; slicing corners, at head height there.
		var y := b.last_known.y + w.tuning.body.stand_eye_height if b.skill.slices_corners else eye.y
		var spot := Vector3(b.last_known.x, y, b.last_known.z)
		_look_yaw = BotAim.look_yaw(eye, spot)
		_look_pitch = BotAim.look_pitch(eye, spot)
	elif b.mode == Bot.Mode.ORDER and (not walking or (b.order == SquadOrder.Kind.FOLLOW and not b.order_rush)):
		# A squad order: at its spot, look the way the order says; keeping up behind its giver, keep covering their back
		# on the move too (only hurrying, it looks where it runs).
		_look_yaw = b.order_yaw
	elif walking and b.careful and b.mode == Bot.Mode.ADVANCE \
			and _slice(b, w, _held_angle_look(b, w, eye, walk_yaw, false, INF), cmd):
		# Slicing: walking near the enemy, aim at the corner ahead someone could step out of, not where it walks, and
		# lean out past a near one to see round it a slice at a time.
		pass
	elif walking and not (b.mode == Bot.Mode.ADVANCE and not b.hunting and cos(walk_yaw - enemy) < 0.0):
		_look_yaw = walk_yaw
	elif not (b.holding and b.skill.holds_angles and _held_angle_look(b, w, eye, BotAim.hold_yaw(b, w), false, INF)
			!= null):
		# Holding, or walking back along its lane: face the enemy side (watching the overtime flag, the flag), sweeping
		# slowly across it while holding. Hard aims at the corners someone would come round instead of sweeping.
		_look_yaw = BotAim.hold_yaw(b, w)
		if b.holding:
			_look_yaw += sin(TAU * b.team_wait / cfg.hold_sweep_period) * deg_to_rad(cfg.hold_sweep_deg)
	BotAim.step(b, _look_yaw, _look_pitch, 0.0, 0.0, cfg, dt)
	return INF


## Slicing: leans out past `a`, the corner aimed at, once within slice_lean_distance of it (towards its open side).
## False if there is no corner to slice.
static func _slice(b: Bot, w: BotWorld, a: BotAngles.HeldAngle, cmd: PlayerCommand) -> bool:
	if a == null:
		return false
	var p := b.character.position
	if Vector2(a.point.x - p.x, a.point.z - p.z).length() <= w.cfg.slice_lean_distance:
		cmd.lean = a.side
	return true


## Closing in on where someone was heard or last seen: while that spot, at head height, is out of view round a corner,
## slices the corner nearest its bearing. False once the spot is in plain view (then it watches the spot itself).
static func _slice_towards_last_known(b: Bot, w: BotWorld, eye: Vector3, cmd: PlayerCommand) -> bool:
	var head := b.last_known + Vector3(0.0, w.tuning.body.stand_eye_height, 0.0)
	if BotSenses.line_clear(w.query, eye, head):
		return false
	# Only a corner short of the spot can be the one it is behind (not the far end of a long wall).
	var to_spot := Vector2(head.x - eye.x, head.z - eye.z).length()
	return _slice(b, w, _held_angle_look(b, w, eye, BotAim.look_yaw(eye, head), true, to_spot), cmd)


## Holding with held angles, or slicing on the move: finds the corners in view of where it stands, facing about
## `facing_yaw` (again every angle_refresh, or once it has moved angle_move_refresh), then looks at one of them: if
## `nearest`, the one nearest `facing_yaw` among those within `within` m, else switching every angle_switch_time.
## Returns it, or null if it found none.
static func _held_angle_look(b: Bot, w: BotWorld, eye: Vector3, facing_yaw: float, nearest: bool,
		within: float) -> BotAngles.HeldAngle:
	var cfg := w.cfg
	var p := b.character.position
	var from := b.held_angles_from
	if w.time - b.held_angles_at > cfg.angle_refresh \
			or Vector2(p.x - from.x, p.z - from.z).length() > cfg.angle_move_refresh:
		b.held_angles_at = w.time
		b.held_angles_from = p
		# The fan runs at standing eye height (over low cover), whatever the bot's own crouch; heads are at the same.
		var head := p.y + w.tuning.body.stand_eye_height
		b.held_angle_count = BotAngles.find(w.query, Vector3(p.x, head, p.z), head, facing_yaw, cfg, b.held_angles)
	if b.held_angle_count == 0:
		return null
	var a: BotAngles.HeldAngle = b.held_angles[floori(b.team_wait / cfg.angle_switch_time) % b.held_angle_count]
	if nearest:
		a = null
		for i in b.held_angle_count:
			var o := b.held_angles[i]
			if Vector2(o.point.x - p.x, o.point.z - p.z).length() > within:
				continue
			if a == null or absf(wrapf(o.yaw - facing_yaw, -PI, PI)) < absf(wrapf(a.yaw - facing_yaw, -PI, PI)):
				a = o
		if a == null:
			return null
	_look_yaw = BotAim.look_yaw(eye, a.point)
	_look_pitch = BotAim.look_pitch(eye, a.point)
	return a


## Bursts at the target once reacted and on aim (within fire_cone_deg), never with cover, a close wall, a teammate or
## a body in the way. On semi the trigger is squeezed every other tick, as a player taps.
static func shoot(b: Bot, w: BotWorld, target: Character, eye: Vector3, off_aim: float, cmd: PlayerCommand,
		dt: float) -> void:
	var cfg := w.cfg
	var was_bursting := b.bursting
	b.bursting = false
	if target == null or not b.target_visible:
		b.no_shot_for = 0.0
	elif b.no_shot_for > 0.0 and BotSenses.line_clear(w.query, eye, _aim_point) \
			and not leaves_in_line(w, eye, _aim_point):
		# The way clear again (it went round, or the glass is behind it): a shot, whether or not it can take it this tick.
		b.no_shot_for = 0.0
	var ready := w.live and BotSenses.has_reacted(b, w) and not cmd.sprint and b.mode != Bot.Mode.COVER
	if not ready or target == null or off_aim >= deg_to_rad(cfg.fire_cone_deg):
		b.pause_left = maxf(0.0, b.pause_left - dt)
		return
	var dir := Vector3(-sin(b.aim_yaw) * cos(b.aim_pitch), sin(b.aim_pitch), -cos(b.aim_yaw) * cos(b.aim_pitch))
	var dist := eye.distance_to(_aim_point)
	if _line_of_fire_blocked(b, w, eye, dir, dist):
		# Seen through glass or leaves it can't shoot through (BQ1): counted, so it goes round in time.
		b.no_shot_for = b.no_shot_for + dt if _level_in_line else 0.0
		return
	b.no_shot_for = 0.0
	var begun := b.burst_left <= 0.0 and b.pause_left <= 0.0
	if begun:
		b.burst_left = b.pick(b.skill.burst)
	if b.burst_left > 0.0:
		if begun or not was_bursting:
			# A burst begun (on whoever it now aims at), or picked up again after a tick it couldn't fire in: is the
			# knee's shot clear?
			b.knee_clear = b.skill.kneels_to_fire and _knee_has_shot(b, w)
		b.bursting = true
		var a := b.character.armament
		cmd.fire = a.fire_mode() != ReplicaConfig.FireMode.SEMI or not a.trigger_was_down
		b.burst_left -= dt
		if b.burst_left <= 0.0:
			b.pause_left = b.pick(b.skill.burst_pause)
	else:
		b.pause_left -= dt


## Whether `b`'s eye, kneeling where it stands and upright, would have the shot at _aim_point (BQ3: one ray as a burst
## begins or resumes).
static func _knee_has_shot(b: Bot, w: BotWorld) -> bool:
	var c := b.character
	var knee := c.position + Vector3(0.0, Character.eye_height(1.0, w.tuning.body), 0.0)
	return BotSenses.line_clear(w.query, knee, _aim_point) and not leaves_in_line(w, knee, _aim_point)


## Reloads when empty, or swaps a low magazine for a fuller spare when nobody is in sight.
static func reload_when_due(b: Bot, w: BotWorld, cmd: PlayerCommand) -> void:
	var a := b.character.armament
	if a.replicas.is_empty() or a.ammo[a.active].next_spare() < 0:
		return
	if a.mag() == 0:
		cmd.reload = true
	elif not b.target_visible and low_on_bbs(b, w.cfg.tactical_reload_fraction):
		# With a threat in mind a corner-slicer tops up only once in cover (BotBrain: it heads there to reload).
		if b.skill.slices_corners and b.threat_in_mind(w.time, w.cfg) and _heading_for_cover(b, w):
			return
		cmd.reload = true


## True if the loaded magazine holds less than `share` of a full one and a spare can top it up.
static func low_on_bbs(b: Bot, share: float) -> bool:
	var a := b.character.armament
	if a.replicas.is_empty() or a.ammo[a.active].next_spare() < 0:
		return false
	return a.mag() < a.replica().mag_size * share


## In cover mode and not there yet.
static func _heading_for_cover(b: Bot, w: BotWorld) -> bool:
	var p := b.character.position
	return b.mode == Bot.Mode.COVER and Vector2(b.cover.position.x - p.x, b.cover.position.z - p.z).length() \
			>= w.cfg.cover_arrive


## Seconds `b`'s BB takes to fly `dist` m: the replica in its hands, with the BBs it loads.
static func flight_time(b: Bot, w: BotWorld, dist: float) -> float:
	var a := b.character.armament
	var r := a.replica()
	if r == null:
		return 0.0
	var grams := a.bb_weights[a.active]
	var t := Ballistics.flight_time_estimate(dist, Ballistics.muzzle_velocity(r, w.tuning.replica_rules, grams),
			Ballistics.bb_mass(r, grams), w.tuning.ballistics)
	return t if t < INF else 0.0


## True if `b` must hold fire along `dir` from `eye` at a target `dist` m away (_level_in_line says whether the level
## itself, glass or leaves, stood on the line to the aim point): cover on the line to the aim point, more
## leaves in the way than it shoots through (leaves_in_line), a wall close in front along the aim, or a body in the line
## of fire (_body_in_line) up to where a miss would stop.
static func _line_of_fire_blocked(b: Bot, w: BotWorld, eye: Vector3, dir: Vector3, dist: float) -> bool:
	var cfg := w.cfg
	_level_in_line = not BotSenses.line_clear(w.query, eye, _aim_point) or leaves_in_line(w, eye, _aim_point)
	if _level_in_line:
		return true
	var reach := miss_reach(cfg, dist)
	var wall := -1.0
	if w.query.ray(eye, eye + dir * reach, _hit):
		wall = _hit.fraction * reach
	# The BB flies along the aim, not the line to the target: no shooting the wall beside you.
	if wall >= 0.0 and wall < dist * cfg.aim_wall_fraction:
		return true
	var stray := _stray_per_metre(b, cfg)
	return _body_in_line(b, w, eye, dir, _friendly_reach(w, eye, dir, dist, wall, stray), dist, stray)


## True if the line from `eye` to `aim_point` runs through more bush than a bot shoots through (FO1): more than
## foliage_fire_through of leaves. A bot can notice someone in a bush close by (close_awareness) and still have no shot
## at them.
static func leaves_in_line(w: BotWorld, eye: Vector3, aim_point: Vector3) -> bool:
	var leaves := w.query.foliage
	if leaves == null or leaves.is_empty():
		return false
	var most := w.cfg.foliage_fire_through
	return leaves.depth(eye, aim_point, most) > most


## How far `b`'s BBs may stray off its aim line (m per m flown): friendly_spread_sigmas of the spread it shoots with now.
static func _stray_per_metre(b: Bot, cfg: BotConfig) -> float:
	var me := b.character
	var r := me.armament.replica()
	if r == null:
		return 0.0
	return tan(deg_to_rad(cfg.friendly_spread_sigmas * r.spread_deg * me.spread_scale))


## How far a miss at a target `dist` m off flies on, a wall aside (m from the shooter): friendly_beyond_target past the
## target, and friendly_carry at least.
static func miss_reach(cfg: BotConfig, dist: float) -> float:
	return maxf(dist + cfg.friendly_beyond_target, cfg.friendly_carry)


## How far along `dir` a miss can still hit someone: miss_reach, or friendly_past_wall past a wall in the way (`wall`
## m, or -1). Only a wall: it must also stand friendly_wall_clearance higher there and as far to either side as the BBs
## stray, or they go over or round it.
static func _friendly_reach(w: BotWorld, eye: Vector3, dir: Vector3, dist: float, wall: float, stray: float) -> float:
	var cfg := w.cfg
	var reach := miss_reach(cfg, dist)
	if wall < 0.0:
		return reach
	var back := minf(wall, cfg.friendly_wall_probe)
	var raised := eye + dir * (wall - back) + Vector3(0.0, cfg.friendly_wall_clearance, 0.0)
	var probe := back + cfg.friendly_wall_probe
	if not w.query.ray(raised, raised + dir * probe, _hit):
		return reach
	var flat := Vector2(dir.x, dir.z).length()
	var off := stray * wall / flat if flat > 0.0 else 0.0
	for i in 2:
		var side := 1.0 - 2.0 * i
		var p := raised + Vector3(dir.z * off * side, -cfg.friendly_wall_clearance, -dir.x * off * side)
		if not w.query.ray(p, p + dir * probe, _hit):
			return reach
	return minf(reach, wall + cfg.friendly_past_wall)


## True if a teammate stands in (or near) the line of fire within `dist` m, where it is now or could be as the BBs pass,
## or anyone already hit stands in it before the target (`to_target` m): every body stops a BB. Each teammate counts
## friendly_margin wider, and `stray` m wider per m away. Where a teammate in play could be (WL10): anywhere a run
## (friendly_mate_speed) takes it during the flight, since it may strafe either way, break for cover or turn to a fight
## at any moment; faster than that (a sprint) also straight on, and for a bot round its route's corners. Anyone already
## hit, straight on at their pace.
static func _body_in_line(b: Bot, w: BotWorld, from: Vector3, dir: Vector3, dist: float, to_target: float,
		stray: float) -> bool:
	var me := b.character
	var cfg := w.cfg
	var hits := w.tuning.hits
	for mate in w.characters:
		if mate == me:
			continue
		if mate.team != me.team:
			# An opponent already out, between you and the target, would take the BBs.
			if Elimination.is_in_play(mate):
				continue
			Hitbox.build_volume(mate, hits, _volume)
			if Hitbox.ray_character(from, dir, to_target, _volume) < INF:
				return true
			continue
		var along := (mate.position - from).dot(dir)
		var reach := clampf(along, 0.0, dist)
		var flight := flight_time(b, w, reach)
		var in_play := Elimination.is_in_play(mate)
		# Past the target only a teammate a BB could knock out matters; before it every body stops the BBs.
		var harmed := dist if in_play and hits.friendly_fire else to_target
		var margin := cfg.friendly_margin + reach * stray
		Hitbox.build_volume(mate, hits, _volume)
		_inflate(_volume, margin + (cfg.friendly_mate_speed * flight if in_play else 0.0))
		if Hitbox.ray_character(from, dir, harmed, _volume) < INF:
			return true
		var speed := Vector2(mate.velocity.x, mate.velocity.z).length()
		if speed <= 0.0 or (in_play and speed <= cfg.friendly_mate_speed):
			continue
		_shift(_volume, mate.velocity.x * flight, mate.velocity.z * flight)
		if Hitbox.ray_character(from, dir, harmed, _volume) < INF:
			return true
		var walker := w.bot_of(mate) if in_play else null
		if walker != null and walker.route_state == Bot.RouteState.OK \
				and _ahead_in_line(walker, hits, from, dir, harmed, margin, speed * flight):
			return true
	return false


## True if bot `walker`'s hit volume, `margin` m wider, stands in the line of fire (`harmed` m along `dir` from `from`)
## once it has walked `distance` m more along its route.
static func _ahead_in_line(walker: Bot, hits: HitConfig, from: Vector3, dir: Vector3, harmed: float, margin: float,
		distance: float) -> bool:
	var mate := walker.character
	var ahead := BotRoutes.point_ahead(walker, distance)
	Hitbox.build_volume(mate, hits, _volume)
	_inflate(_volume, margin)
	_shift(_volume, ahead.x - mate.position.x, ahead.z - mate.position.z)
	return Hitbox.ray_character(from, dir, harmed, _volume) < INF


static func _inflate(v: Hitbox.Volume, margin: float) -> void:
	v.head.r += margin
	v.bound.r += margin
	for c in v.parts:
		c.r += margin


static func _shift(v: Hitbox.Volume, dx: float, dz: float) -> void:
	var d := Vector3(dx, 0.0, dz)
	v.head.a += d
	v.head.b += d
	v.bound.a += d
	v.bound.b += d
	for c in v.parts:
		c.a += d
		c.b += d
