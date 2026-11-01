class_name BotBombs
## When a bot throws its smoke or flash bomb, and its throw (SF2). Pinned in cover (an enemy BB close lately) by someone
## at range, with no cloud between them yet, it smokes the line to them. Searching toward a spot it can't see (round a
## corner), it flashes there, or a point of its route the bang would be seen from, then looks away until the bang and
## pushes. Each is the skill's chance, rolled from the bot's own bomb stream. It throws only along an arc clear of the
## level, aimed short for the bounce and roll; it turns to the throw at its turn rate and stands still to throw. The
## throw itself is the simulation's (Grenades), pressed through the command as the player's G and Y. Allocates nothing.

const EPSILON := 1e-4

static var _hit: RayHit = RayHit.new()


## Whether `b` is busy with a bomb this tick (turning to a throw, throwing, or looking away from its flash), so its aim
## is BotBombs' and not its fight's.
static func busy(b: Bot, w: BotWorld) -> bool:
	return Grenades.throwing(b.character) or b.bomb_kind != Grenade.Kind.NONE or w.time < b.bomb_away_until


## After the rest of the bot's tick (BotBrain.think): a throw it is turning to or making, the look away after a flash,
## or whether to start one now. `target` is who it fights or last fought (null: none).
static func step(b: Bot, w: BotWorld, target: Character, cmd: PlayerCommand, dt: float) -> void:
	var me := b.character
	var cfg := w.cfg
	var hand := me.grenades
	if Grenades.throwing(me):
		_hold_still(cmd)
		_face(b, cmd, b.bomb_yaw, b.bomb_pitch, dt)
		if hand.throwing == Grenade.Kind.FLASH and not hand.released:
			b.bomb_away_until = w.time + hand.windup_left + w.tuning.grenades.flash_fuse + cfg.flash_wait_after
			b.bomb_away_yaw = wrapf(b.bomb_yaw + PI, -PI, PI)
		return
	if b.bomb_kind != Grenade.Kind.NONE:
		_hold_still(cmd)
		if _face(b, cmd, b.bomb_yaw, b.bomb_pitch, dt) <= deg_to_rad(cfg.bomb_aim_within_deg):
			cmd.throw_grenade = b.bomb_kind
			b.bomb_kind = Grenade.Kind.NONE
		elif w.time > b.bomb_aim_until:
			b.bomb_kind = Grenade.Kind.NONE
		return
	if w.time < b.bomb_away_until:
		# Even with someone in sight: facing its own bang would blind it.
		_hold_still(cmd)
		_face(b, cmd, b.bomb_away_yaw, 0.0, dt)
		return
	if not w.live or w.time < b.bomb_roll_at:
		return
	if not _try_smoke(b, w, target):
		_try_flash(b, w)


## Pinned in cover by `target` at range, with no cloud between yet: a roll, and the smoke along the line to them.
static func _try_smoke(b: Bot, w: BotWorld, target: Character) -> bool:
	var me := b.character
	var cfg := w.cfg
	if b.mode != Bot.Mode.COVER or target == null or me.grenades.left(Grenade.Kind.SMOKE) <= 0 \
			or w.time - b.suppressed_at > cfg.smoke_under_fire_for:
		return false
	# Out of sight, the threat is where the bot last knew it to be, as everywhere else in its head.
	if not b.target_visible and not b.has_last_known:
		return false
	var feet := target.position if b.target_visible else b.last_known
	var eye := BotSenses.eye_of(me, w.tuning)
	var threat := BotSenses.eye_of(target, w.tuning) if b.target_visible \
			else b.last_known + Vector3(0.0, w.tuning.body.stand_eye_height, 0.0)
	var dist := _flat(eye, threat)
	if dist < cfg.smoke_min_distance or dist > cfg.smoke_max_distance \
			or Grenades.smoke_depth(w.grenades, w.tuning.grenades, eye, threat) > 0.0:
		return false
	b.bomb_roll_at = w.time + cfg.bomb_roll_gap
	if b.bomb_rng.randf() >= b.skill.smoke_chance:
		return false
	var reach := minf(dist * cfg.smoke_at_share, cfg.smoke_reach) / dist
	var at := Vector3(lerpf(me.position.x, feet.x, reach), me.position.y, lerpf(me.position.z, feet.z, reach))
	return _aim(b, w, eye, at, Grenade.Kind.SMOKE)


## Searching toward a spot out of sight in reach, no teammate near it: a roll, and the flash there or along the route.
static func _try_flash(b: Bot, w: BotWorld) -> bool:
	var me := b.character
	var cfg := w.cfg
	if b.mode != Bot.Mode.SEARCH or not b.has_last_known or b.target_visible \
			or me.grenades.left(Grenade.Kind.FLASH) <= 0:
		return false
	var dist := _flat(me.position, b.last_known)
	if dist < cfg.flash_min_distance or dist > cfg.flash_max_distance:
		return false
	var eye := BotSenses.eye_of(me, w.tuning)
	var spot := b.last_known + Vector3(0.0, cfg.flash_spot_height, 0.0)
	if BotSenses.line_clear(w.query, eye, spot):
		return false
	b.bomb_roll_at = w.time + cfg.bomb_roll_gap
	if b.bomb_rng.randf() >= b.skill.flash_chance:
		return false
	if _flash_at(b, w, eye, b.last_known, spot):
		return true
	for i in range(b.route_leg, mini(b.route.size(), b.route_leg + cfg.flash_route_points)):
		var point := b.route[i]
		if _flat(me.position, point) > cfg.flash_max_distance:
			break
		if _flash_at(b, w, eye, point, spot):
			return true
	return false


## A flash at `at` whose bang `spot` would see and no teammate would (through glass too, as a flash dazzles), thrown
## from `eye` along a clear arc.
static func _flash_at(b: Bot, w: BotWorld, eye: Vector3, at: Vector3, spot: Vector3) -> bool:
	var bang := at + Vector3(0.0, w.cfg.flash_bang_height, 0.0)
	return BotSenses.sight_clear(w.query, bang, spot) and not _mate_sees(b, w, bang) \
			and _aim(b, w, eye, at, Grenade.Kind.FLASH)


## Turns `b` to throw `kind` from `eye` to land at `at`: aimed short for the bounce and roll, along the low arc, or the
## high one where the low meets the level. False (no throw) when neither reaches clear.
static func _aim(b: Bot, w: BotWorld, eye: Vector3, at: Vector3, kind: Grenade.Kind) -> bool:
	var short := w.cfg.bomb_aim_short
	var aim := Vector3(lerpf(eye.x, at.x, short), at.y, lerpf(eye.z, at.z, short))
	if _flat(eye, aim) < EPSILON:
		return false
	var yaw := atan2(-(aim.x - eye.x), -(aim.z - eye.z))
	# A flash lands before its bang, so it never goes off in the air over the thrower's cover.
	var longest := w.tuning.grenades.flash_fuse if kind == Grenade.Kind.FLASH else INF
	var pitch := _clear_pitch(w, eye, yaw, aim, false, longest)
	if is_nan(pitch):
		pitch = _clear_pitch(w, eye, yaw, aim, true, longest)
	if is_nan(pitch):
		return false
	b.bomb_kind = kind
	b.bomb_yaw = yaw
	b.bomb_pitch = pitch
	b.bomb_aim_until = w.time + w.cfg.bomb_aim_time
	return true


## The pitch of the low or `high` arc from `eye` along `yaw` to `aim` if it comes down within `longest` s, clear of the
## level all the way (the last stretch, into the ground, unchecked), else NAN.
static func _clear_pitch(w: BotWorld, eye: Vector3, yaw: float, aim: Vector3, high: bool, longest: float) -> float:
	var g := w.tuning.grenades
	var pitch := Grenades.throw_pitch(eye, aim, g, high)
	if is_nan(pitch):
		return NAN
	var flat_speed := cos(pitch + g.loft) * g.throw_speed
	if flat_speed < EPSILON:
		return NAN
	var flight := _flat(eye, aim) / flat_speed
	if flight > longest:
		return NAN
	var steps := maxi(1, w.cfg.bomb_arc_steps)
	var from := eye
	for i in steps:
		var to := Grenades.arc_point(eye, yaw, pitch, g, flight * float(i + 1) / float(steps + 1))
		if w.query.ray(from, to, _hit):
			return NAN
		from = to
	return pitch


## Whether a teammate of `b` in play would be caught by a bang at `bang`: within flash_mate_clear of it, or within
## flash_mate_sight with a clear line from its eyes (it can't be told to look away).
static func _mate_sees(b: Bot, w: BotWorld, bang: Vector3) -> bool:
	var me := b.character
	for c in w.characters:
		if c == me or c.team != me.team or not Elimination.is_in_play(c):
			continue
		var flat := _flat(c.position, bang)
		if flat < w.cfg.flash_mate_clear or (flat < w.cfg.flash_mate_sight
				and BotSenses.sight_clear(w.query, BotSenses.eye_of(c, w.tuning), bang)):
			return true
	return false


## Turns the bot's view toward `yaw`, `pitch` at its turn rate into `cmd`; returns how far off it still is (rad).
static func _face(b: Bot, cmd: PlayerCommand, yaw: float, pitch: float, dt: float) -> float:
	var d_yaw := wrapf(yaw - b.aim_yaw, -PI, PI)
	var d_pitch := pitch - b.aim_pitch
	var off := Vector2(d_yaw, d_pitch).length()
	var most := b.skill.turn_rate * dt
	var s := most / off if off > most else 1.0
	b.aim_yaw = wrapf(b.aim_yaw + d_yaw * s, -PI, PI)
	b.aim_pitch += d_pitch * s
	cmd.yaw = b.aim_yaw
	cmd.pitch = b.aim_pitch
	return off * (1.0 - s)


## No walking or shooting while it throws or waits on its bang.
static func _hold_still(cmd: PlayerCommand) -> void:
	cmd.fire = false
	cmd.aim = false
	cmd.forward = 0.0
	cmd.right = 0.0
	cmd.sprint = false
	cmd.walk = false
	cmd.jump = false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
