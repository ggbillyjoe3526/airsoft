class_name BotBrain
## One bot's decisions each tick (the browser game's ai/botBrain.ts): look (ten times a second), pick a mode, move, aim,
## fire and reload, all written into the PlayerCommand its body follows, as the player's input is. The modes: walk its
## lane, then hunt (advance); fight someone in sight; get into cover and peek from it (over crouch cover, or leaning out
## round a corner); go to where someone was seen or heard (search); in Attack / Defend, work or guard the pole (flag);
## carry out a teammate's squad order (order); bring a teammate a magazine or wait for one (mag). Its smoke and flash
## bombs are BotBombs'. Allocates nothing.

## The vault check's answer for a bot on a vault leg (one at a time: bots think in turn).
static var _vault_check: VaultState = VaultState.new()


## One tick of decisions for `b`, written into `cmd`. Characters out of play follow the hit-calling routine instead, so
## this only keeps the view in step for them.
static func think(b: Bot, w: BotWorld, cmd: PlayerCommand, dt: float) -> void:
	var me := b.character
	var cfg := w.cfg
	cmd.reset(me.yaw, me.pitch)
	# Bots fight with their primary and fire from the hip (DECISIONS: bots fire from the hip).
	if me.armament.active != 0:
		cmd.switch_to = 0
	if not Elimination.is_in_play(me):
		b.mode = Bot.Mode.ADVANCE
		b.aim_yaw = me.yaw
		b.aim_pitch = me.pitch
		return
	# Dazzled by a flash (SF1): it sees nothing (BotSenses), so it ducks where it stands until it can see again.
	if me.dazzle_left > 0.0:
		b.target_visible = false
		b.aim_yaw = me.yaw
		b.aim_pitch = me.pitch
		cmd.crouch = true
		return
	b.think_left -= dt
	if b.think_left <= 0.0:
		b.think_left += cfg.think_interval
		if w.live:
			BotSenses.perceive(b, w)
		else:
			b.target_visible = false
	var target := BotSenses.current_target(b, w)
	if target == null:
		b.target_visible = false
	b.cover_cooldown -= dt
	BotMovement.glance(b, w)
	_choose_mode(b, w, target, dt)
	# With a threat in mind, or walking its lane in the enemy's half (skill.slices_corners): walk and slice each corner
	# ahead. Hunting with nothing heard, it hurries.
	var near := b.skill.slices_corners and (b.threat_in_mind(w.time, cfg)
			or (not b.hunting and w.planner.in_enemy_half(b)))
	var trading := w.trading(b)
	var pusher := BotPersonality.pushes_in(b)
	b.careful = near and not trading and not pusher and (b.mode == Bot.Mode.ADVANCE or b.mode == Bot.Mode.SEARCH) \
			and not w.pushing_late(b)
	# A route's vault leg is the walk's own (BotRoutes.follow).
	b.vault_leg = false
	var moving := BotMovement.keep_apart(b, w, BotMovement.move(b, w, cmd, dt, target), cmd)
	# Holding a lane point: crouch once settled, where crouched eyes still see the enemy side.
	if b.holding and b.hold_crouch and b.team_wait >= cfg.hold_crouch_delay:
		cmd.crouch = true
	# Round a corner of full cover: lean out to look and fight, back in to hide.
	if _leaning_out(b):
		cmd.lean = b.cover.lean
	var eye := BotSenses.eye_of(me, w.tuning)
	# Busy with a bomb, its view is the throw's (BotBombs), not the fight's.
	var bombing := BotBombs.busy(b, w)
	var off_aim := PI if bombing else BotCombat.aim(b, w, target, eye, moving, cmd, dt)
	cmd.yaw = b.aim_yaw
	cmd.pitch = b.aim_pitch
	if moving:
		# The walk's world direction as the command's axes, relative to the view this tick's turn left it at.
		var d := b.move_dir
		cmd.forward = -sin(b.aim_yaw) * d.x - cos(b.aim_yaw) * d.z
		cmd.right = cos(b.aim_yaw) * d.x - sin(b.aim_yaw) * d.z
		var calm := w.time - b.last_threat_at > cfg.sprint_when_calm_for
		# A bot that pushes in runs at where someone was, footsteps and all.
		var going := b.mode == Bot.Mode.ADVANCE or b.mode == Bot.Mode.FLAG or (pusher and b.mode == Bot.Mode.SEARCH)
		# Hurrying to a squad order (regrouping, catching up) or with a magazine sprints even with a fight just over, and
		# through the small turns of following someone (a looser forward gate), so it doesn't flick between run and
		# sprint at each one.
		if (b.mode == Bot.Mode.ORDER and b.order_rush) or (b.mode == Bot.Mode.MAG and b.mag_rush):
			cmd.sprint = cmd.forward > cfg.squad.sprint_forward
		else:
			cmd.sprint = going and (calm or pusher) and cmd.forward > cfg.sprint_forward
		# Closing in on where someone was: walk, so its feet don't give it away (not while trading or pushing in).
		if b.mode == Bot.Mode.SEARCH and not trading and not pusher \
				and Vector2(b.last_known.x - me.position.x, b.last_known.z - me.position.z).length() \
				< b.skill.search_walk_distance:
			cmd.walk = true
		if b.careful:
			cmd.walk = true
			cmd.sprint = false
		# A low obstacle on its route: Jump once the vault is there, as the player's would be (the same rule).
		if b.vault_leg:
			cmd.jump = Vault.find_along(me, Vault.way(cmd, w.tuning), w.tuning, w.query, _vault_check)
		# A shut door in its way: it opens it, as the player would, noise and all (DO1).
		if w.doors != null:
			cmd.door_to_use = Doors.shut_ahead(w.query, w.tuning.doors, w.doors, me.position,
					Vector2(b.move_dir.x, b.move_dir.z))
			cmd.use_door = cmd.door_to_use >= 0
	# A personality that aims from cover raises its sight standing still to fight, to look over its cover or to hold;
	# never to draw a holstered replica (BotHolster decides that). Every other bot fires from the hip.
	if b.style.aims_from_cover and not moving and cmd.forward == 0.0 and cmd.right == 0.0 \
			and not me.armament.holstered and (b.mode == Bot.Mode.FIGHT or b.holding
			or (b.mode == Bot.Mode.COVER and b.cover_phase == Bot.CoverPhase.PEEK)):
		cmd.aim = true
	BotCombat.shoot(b, w, target, eye, off_aim, cmd, dt)
	BotCombat.reload_when_due(b, w, cmd)
	BotHolster.step(b, w, cmd, dt)
	BotBombs.step(b, w, target, cmd, dt)


## Picks the mode for this tick from what `b` knows and how it is doing.
static func _choose_mode(b: Bot, w: BotWorld, target: Character, dt: float) -> void:
	var me := b.character
	var cfg := w.cfg
	var seeing := b.target_visible and target != null
	var a := me.armament
	var reloading := a.reloading()
	var spare := not a.replicas.is_empty() and a.ammo[a.active].next_spare() >= 0
	var out_of_bbs := a.mag() == 0 and not spare
	var empty := a.mag() == 0 and spare
	var suppressed := w.time - b.suppressed_at < cfg.suppression_time
	# A lean spot works only right on it: a few centimetres decide whether the lean sees round the corner.
	var arrive := cfg.lean_spot_arrive if b.cover.lean != 0 else cfg.cover_arrive
	var at_cover := _flat(b.cover.position, me.position) < arrive
	var cover_over := w.time - b.cover_since > cfg.cover_episode_max or out_of_bbs

	# Fighting over crouch cover (or round a corner): duck back when shot at, reloading, empty, out of sight or after a
	# short fight. With the target gone there is nothing to duck from: move on.
	if b.mode == Bot.Mode.FIGHT and b.from_cover:
		b.peek_fight_left -= dt
		var duck := not seeing or suppressed or reloading or empty or b.peek_fight_left <= 0.0
		if at_cover and duck and target != null and not cover_over and _duck_back(b, w, target, seeing):
			return
		if not at_cover or duck or cover_over:
			b.from_cover = false
	if seeing and (suppressed or reloading or empty) and b.mode != Bot.Mode.COVER and b.cover_cooldown <= 0.0:
		b.cover_cooldown = cfg.cover_cooldown
		if _take_cover(b, w, BotSenses.eye_of(target, w.tuning), b.pick(cfg.cover_time), cfg.cover_radius,
				cfg.cover_candidates, false):
			return
	if b.mode == Bot.Mode.COVER:
		if not _stay_in_cover(b, w, seeing, reloading, at_cover, cover_over, dt):
			return
		b.route_state = Bot.RouteState.NONE
	# A defender (Attack / Defend) goes only after what is near its pole, an anchor holding short of the middle only after
	# what is near its post, on that floor; anything else they watch from their post until it is old news.
	var fresh := b.threat_in_mind(w.time, cfg)
	var defending := BotFlag.role(b, w) == BotFlag.Role.DEFEND
	var holds_post := defending or BotPersonality.anchor_holding(b, w)
	var post := BotFlag.post_of(b, w) if defending else b.lane_goal
	var leash := cfg.defend_search_radius if defending else cfg.anchor_search_radius
	var watch_from_post := fresh and holds_post and (_flat(b.last_known, post) > leash \
			or absf(b.last_known.y - post.y) > cfg.anchor_search_rise)
	if seeing:
		# Back in sight: any watch for them is over.
		b.watch_until = -INF
		# A fresh contact at range while on the move: behind close crouch cover first, then peek.
		# A personality that pushes in fights where it is.
		if (b.mode == Bot.Mode.ADVANCE or b.mode == Bot.Mode.SEARCH or b.mode == Bot.Mode.ORDER) \
				and b.cover_cooldown <= 0.0 and not BotPersonality.pushes_in(b):
			if _flat(target.position, me.position) >= b.skill.contact_cover_min_distance \
					and _take_cover(b, w, BotSenses.eye_of(target, w.tuning), 0.0, cfg.contact_cover_radius, 0, true):
				b.cover_cooldown = cfg.cover_cooldown
				return
		b.mode = Bot.Mode.FIGHT
	elif b.mag_for != null:
		# Bringing a teammate a magazine (MH2, BotMagShare) comes before a squad order: it is over in moments.
		_enter_mag(b, fresh)
	elif b.order != SquadOrder.Kind.NONE:
		# A squad order comes before the team plan: the pole, chasing noises and the lane. A noise still turns its head
		# (BotCombat.aim watches last_known) until it is old news.
		if b.mode != Bot.Mode.ORDER:
			b.mode = Bot.Mode.ORDER
			BotRoutes.drop(b)
		if not fresh:
			b.has_last_known = false
	elif BotFlag.wants_flag(b, w):
		# Attack / Defend: the pole comes before chasing noises.
		if b.mode != Bot.Mode.FLAG:
			BotMovement.enter_flag(b, w)
	elif BotMagShare.waiting(b, w):
		# Low on BBs, it asked a teammate for a magazine: it waits for it, or goes over to the player it asked.
		_enter_mag(b, fresh)
	elif fresh and (_trade_hit(b, w) or _reload_from_cover(b, w)):
		return
	elif fresh and not watch_from_post:
		if b.mode != Bot.Mode.SEARCH:
			# Lost sight of someone in a fight: a bot with peek_watch_time first watches where they ducked out; one
			# that pushes in goes straight after them.
			if b.mode == Bot.Mode.FIGHT and b.contact != null and b.skill.peek_watch_time.y > 0.0 \
					and not BotPersonality.pushes_in(b):
				b.watch_until = w.time + b.pick(b.skill.peek_watch_time)
			b.route_state = Bot.RouteState.NONE
			b.mode = Bot.Mode.SEARCH
			BotMovement.start_search(b, w)
	elif b.mode != Bot.Mode.ADVANCE:
		# Back to the lane, still watching that way if holding its post.
		b.has_last_known = watch_from_post
		b.mode = Bot.Mode.ADVANCE
		BotRoutes.drop(b)
		b.wait_for_team = false
		b.hold_left = 0.0
		b.hold_cover = false
		# Back to the lane point it left.
		if not b.hunting and b.lane_index >= 0:
			b.lane_index -= b.lane_dir
	elif holds_post and not fresh:
		# Holding its post: stop watching where a noise was once it is old news.
		b.has_last_known = false
	if b.mode == Bot.Mode.ADVANCE and not b.hunting and w.pushing_late(b):
		# Behind on players late in the round (team play): stop holding the lane and go looking for them.
		b.hunting = true
		BotRoutes.drop(b)
		b.hold_left = 0.0
		b.wait_for_team = false
		b.hold_cover = false


## One tick in cover: settling in, ducked, peeking. Returns true when the episode is over (exposed, given up, out of
## time or looks) and the bot picks another mode; false while it stays (it may have gone to fight from the spot).
static func _stay_in_cover(b: Bot, w: BotWorld, seeing: bool, reloading: bool, at_cover: bool, cover_over: bool,
		dt: float) -> bool:
	var cfg := w.cfg
	if at_cover:
		b.cover_held += dt
	else:
		b.cover_give_up -= dt # only getting there can take too long
	if at_cover and b.cover_phase == Bot.CoverPhase.DOWN:
		b.cover_left -= dt
	# Settled in cover but still in sight of an enemy (flanked, or the spot doesn't hide it): fight back.
	var exposed := b.cover_phase == Bot.CoverPhase.DOWN and b.cover_held >= cfg.cover_settle and seeing and not reloading
	var done := exposed or cover_over or b.cover_give_up <= 0.0 or b.route_state == Bot.RouteState.FAILED
	if not done and at_cover and b.cover_phase == Bot.CoverPhase.DOWN and b.cover_left <= 0.0 and not reloading:
		# Time to look again: over crouch cover by standing, round a corner by leaning out, else by moving on.
		if (b.cover.crouch_only or _leans_out_here(b, w)) and b.peeks_left > 0:
			b.cover_phase = Bot.CoverPhase.PEEK
			b.peek_left = b.pick(cfg.peek_look)
			b.peeks_left -= 1
		else:
			done = true
	elif not done and b.cover_phase == Bot.CoverPhase.PEEK:
		if seeing:
			b.mode = Bot.Mode.FIGHT
			b.from_cover = true
			b.peek_fight_left = b.pick(cfg.peek_fight)
			return false
		b.peek_left -= dt
		if b.peek_left <= 0.0:
			if b.peeks_left > 0:
				b.cover_phase = Bot.CoverPhase.DOWN
				b.cover_left = b.pick(cfg.peek_down)
				b.cover_held = 0.0
			else:
				done = true
	return done


## Into the magazine hand-off's mode (BotMagShare); a noise still turns its head (BotCombat.aim watches last_known)
## until it is old news.
static func _enter_mag(b: Bot, fresh: bool) -> void:
	if b.mode != Bot.Mode.MAG:
		b.mode = Bot.Mode.MAG
		BotRoutes.drop(b)
	if not fresh:
		b.has_last_known = false


## Looks for cover from a threat whose eyes are at `threat_eye` and heads there (`radius`, `candidates` and `peekable`
## narrow the search, BotCover.find); false if no spot nearby hides the bot. Ducks `down` seconds once there.
static func _take_cover(b: Bot, w: BotWorld, threat_eye: Vector3, down: float, radius: float, candidates: int,
		peekable: bool) -> bool:
	var cfg := w.cfg
	var taken := BotRoutes.teammate_spots(b, w)
	if not BotCover.find(b.character.position, threat_eye, w, b.rng, b.cover, radius, candidates, peekable,
			BotRoutes.taken(), taken):
		return false
	b.mode = Bot.Mode.COVER
	b.cover_phase = Bot.CoverPhase.DOWN
	b.cover_left = down
	b.cover_give_up = cfg.cover_max_time
	b.cover_held = 0.0
	b.cover_since = w.time
	b.peeks_left = floori(b.pick(cfg.peek_count))
	b.from_cover = false
	b.route_state = Bot.RouteState.NONE
	BotRoutes.want(b, b.cover.position, cfg)
	return true


## Team play: a teammate's hit call heard within trade_time: once, to cover within trade_cover_radius to peek where
## the shot came from; with none there it goes straight there (search). False if it isn't trading now.
static func _trade_hit(b: Bot, w: BotWorld) -> bool:
	var cfg := w.cfg
	if not b.skill.team_play or b.trade_tried or w.time - b.trade_at > cfg.trade_time or b.cover_cooldown > 0.0:
		return false
	b.trade_tried = true
	if not _take_cover(b, w, _known_threat_eye(b, w), 0.0, cfg.trade_cover_radius, 0, true):
		return false
	b.cover_cooldown = cfg.cover_cooldown
	return true


## A low magazine with a threat in mind (skill.slices_corners): to cover from where the threat is known to be, to top
## up there (BotCombat.reload_when_due waits for the spot). False if it needn't or no spot hides it.
static func _reload_from_cover(b: Bot, w: BotWorld) -> bool:
	var cfg := w.cfg
	if not b.skill.slices_corners or b.cover_cooldown > 0.0 \
			or not BotCombat.low_on_bbs(b, cfg.tactical_reload_fraction):
		return false
	# Cooled down whether or not a spot is found, as for ducking under fire: no search every tick while none is near.
	b.cover_cooldown = cfg.cover_cooldown
	return _take_cover(b, w, _known_threat_eye(b, w), b.pick(cfg.cover_time), cfg.cover_radius, cfg.cover_candidates,
			false)


## Ducks back behind the cover it fights from (or leans back in), unless the spot no longer hides it from the threat
## (flanked). Ducking with the enemy still in sight renews its looks.
static func _duck_back(b: Bot, w: BotWorld, target: Character, seeing: bool) -> bool:
	var cfg := w.cfg
	var threat := BotSenses.eye_of(target, w.tuning) if seeing else _known_threat_eye(b, w)
	if not BotCover.hides_from(b.cover.position, threat, w):
		return false
	b.mode = Bot.Mode.COVER
	b.cover_phase = Bot.CoverPhase.DOWN
	b.cover_left = b.pick(cfg.peek_down)
	b.cover_held = 0.0
	if seeing:
		b.peeks_left = maxi(b.peeks_left, floori(b.pick(cfg.peek_count)))
	b.from_cover = false
	return true


## At a lean spot: which way a lean shows where the threat was, from where the bot actually stands. False if neither.
static func _leans_out_here(b: Bot, w: BotWorld) -> bool:
	if b.cover.lean == 0:
		return false
	var side := BotCover.lean_side_to_see(b.character.position, _known_threat_eye(b, w), w)
	if side != 0:
		b.cover.lean = side
	return side != 0


## Leaning out of full cover at a corner: peeking, or fighting from the spot.
static func _leaning_out(b: Bot) -> bool:
	return b.cover.lean != 0 and ((b.mode == Bot.Mode.COVER and b.cover_phase == Bot.CoverPhase.PEEK)
			or (b.mode == Bot.Mode.FIGHT and b.from_cover))


## Where the bot knows the threat to be (last seen or heard), at standing eye height.
static func _known_threat_eye(b: Bot, w: BotWorld) -> Vector3:
	return b.last_known + Vector3(0.0, w.tuning.body.stand_eye_height, 0.0)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
