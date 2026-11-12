class_name BotAim
## A bot's view and aim (the browser game's ai/aim.ts): the view turns at the skill's rate, and the aim carries an error
## like a hand still settling: a slow wander, plus a fresh contact's first aim off to one side that the hand walks in.
## The state lives in Bot (aim_* and err_*); these are the rules. Nothing here allocates.


## Yaw and pitch that look from `from` at `to`: yaw 0 down -Z, positive turning left.
static func look_yaw(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))


static func look_pitch(from: Vector3, to: Vector3) -> float:
	return atan2(to.y - from.y, Vector2(to.x - from.x, to.z - from.z).length())


## The way `b` faces holding still: a bot watching the overtime flag from cover (OV2) at the flag from its spot, every
## other the enemy's side.
static func hold_yaw(b: Bot, w: BotWorld) -> float:
	if b.mode == Bot.Mode.FLAG and b.flag_guard and w.overtime_flag.up:
		return look_yaw(b.flag_goal, w.overtime_flag.foot)
	# Plant The Bomb: a defender back at the armed bomb watches it from its cover (whoever guards it is near it).
	if w.plant != null and w.plant.planted() and b.mode == Bot.Mode.FLAG and b.flag_guard \
			and b.character.team != w.attackers:
		return look_yaw(b.flag_goal, w.plant.position)
	return w.enemy_yaw(b.character.team)


## Aim error size (rad) `since` seconds after picking up a target `dist` m away that crosses the view at `sideways` m/s:
## large at first, settling over the skill's settle time; worse while the bot moves or the target does. The starting
## error is never under aim_error_start_metres off the target, so up close the first BBs can miss.
static func error_size(since: float, moving: bool, dist: float, sideways: float, skill: BotSkill) -> float:
	var t := clampf(since / skill.aim_settle_time, 0.0, 1.0)
	var d := maxf(dist, 1e-3)
	var start := maxf(deg_to_rad(skill.aim_error_start_deg), atan2(skill.aim_error_start_metres, d))
	var settled := deg_to_rad(skill.aim_error_settled_deg)
	var tracking := atan2(absf(sideways) * skill.aim_error_tracking, d)
	return start + (settled - start) * t + (deg_to_rad(skill.aim_error_moving_deg) if moving else 0.0) + tracking


## The part of error_size that settles (rad): the start over the settled error, gone after the settle time. It is the
## first aim's, off to one side; the rest wanders.
static func first_error_size(since: float, dist: float, skill: BotSkill) -> float:
	var t := clampf(since / skill.aim_settle_time, 0.0, 1.0)
	var start := maxf(deg_to_rad(skill.aim_error_start_deg), atan2(skill.aim_error_start_metres, maxf(dist, 1e-3)))
	return maxf(0.0, start - deg_to_rad(skill.aim_error_settled_deg)) * (1.0 - t)


## How long a contact's aim has been settling at `time` (s), less the part of its reaction it doesn't settle over.
## Negative while it still reacts.
static func settling(time: float, c: Bot.Contact, cfg: BotConfig) -> float:
	return time - c.acquired_at - (1.0 - cfg.aim_settle_while_reacting) * maxf(0.0, c.react_at - c.first_seen_at)


## Turns `b`'s view towards (yaw, pitch) plus its wandering error of size `error` and the first aim's of size `first`,
## at most the skill's turn rate. Returns the angle (rad) still between the view and the erroneous aim point.
static func step(b: Bot, yaw: float, pitch: float, error: float, first: float, cfg: BotConfig, dt: float) -> float:
	b.wander_left -= dt
	if b.wander_left <= 0.0:
		b.wander_left = 1.0 / cfg.aim_wander_rate
		var angle := b.rng.randf() * TAU
		var r := sqrt(b.rng.randf()) # uniform over the disc
		b.goal_err_yaw = cos(angle) * r
		b.goal_err_pitch = sin(angle) * r
	var k := 1.0 - exp(-cfg.aim_wander_rate * cfg.aim_wander_settle * dt)
	b.err_yaw += (b.goal_err_yaw - b.err_yaw) * k
	b.err_pitch += (b.goal_err_pitch - b.err_pitch) * k
	var goal_yaw := yaw + b.err_yaw * error + b.first_yaw * first
	var goal_pitch := pitch + b.err_pitch * error + b.first_pitch * first
	var d_yaw := wrapf(goal_yaw - b.aim_yaw, -PI, PI)
	var d_pitch := goal_pitch - b.aim_pitch
	var off := Vector2(d_yaw, d_pitch).length()
	var max_turn := b.skill.turn_rate * dt
	var s := max_turn / off if off > max_turn else 1.0
	b.aim_yaw = wrapf(b.aim_yaw + d_yaw * s, -PI, PI)
	b.aim_pitch += d_pitch * s
	return off * (1.0 - s)


## A new aim error on a target: the wander jumps at least aim_first_error_min of the way out. On a fresh contact the
## wander starts from the middle instead and the first aim is what is off, to one side and nearly level, so the first
## BBs whizz past a shoulder and walk onto the target as the bot fires.
static func fresh_error(b: Bot, cfg: BotConfig, fresh: bool) -> void:
	var angle := b.rng.randf() * TAU
	var r := cfg.aim_first_error_min + b.rng.randf() * (1.0 - cfg.aim_first_error_min)
	b.err_yaw = cos(angle) * r
	b.goal_err_yaw = b.err_yaw
	b.err_pitch = sin(angle) * r
	b.goal_err_pitch = b.err_pitch
	b.wander_left = 1.0 / cfg.aim_wander_rate
	if not fresh:
		return
	var tilt := (b.rng.randf() * 2.0 - 1.0) * deg_to_rad(cfg.aim_first_error_tilt_deg)
	var side := 1.0 if b.rng.randf() < 0.5 else -1.0
	var out := cfg.aim_first_error_min + b.rng.randf() * (1.0 - cfg.aim_first_error_min)
	b.first_yaw = side * cos(tilt) * out
	b.first_pitch = sin(tilt) * out
	# The hand starts from the middle and drifts out to the same side, so it never cancels the first aim's miss.
	b.err_yaw = 0.0
	b.err_pitch = 0.0
	b.goal_err_yaw = side * absf(b.goal_err_yaw)
