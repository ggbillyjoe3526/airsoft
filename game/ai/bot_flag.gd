class_name BotFlag
## Attack / Defend for bots (the browser game's ai/bot.ts flagRole and wantsFlag, roundPlanner.ts pickRetakers and
## pickRaiser): which side of the pole a bot's team is on, which pole is in play on a map with two (AB1), which defenders
## go to pull its flag down, which attacker raises it while the others guard, and when a bot wants the pole; in
## Elimination, when a bot goes for the overtime flag (OV2). Where it walks there is BotMovement's flag mode.
## Allocates nothing.

enum Role { NONE, ATTACK, DEFEND }


## Whether `b`'s team attacks or defends the pole this round (NONE in Elimination).
static func role(b: Bot, w: BotWorld) -> Role:
	if w.mode != RoundState.Mode.ATTACK_DEFEND or w.attackers < 0:
		return Role.NONE
	return Role.ATTACK if b.character.team == w.attackers else Role.DEFEND


## The pole in play (BotWorld.flag), the attackers' pole: Flag.next_in_play's from the one in play now (a flag going up
## at a pole draws them there, the player's too, but a pole being fought over is kept until the other's flag stands
## higher), else the one the attackers drew for the round (RoundPlanner.attack_flag).
static func in_play(w: BotWorld) -> int:
	var up := Flag.next_in_play(w.flags, w.flag_index)
	if up >= 0:
		return up
	return clampi(w.planner.attack_flag, 0, w.flags.size() - 1) if w.planner != null else 0


## Whether `b` is at the rope of the pole its flag spot was picked by (Bot.flag_pole) while someone works it (raising,
## pulling down or both): it stays on that rope, whatever pole is in play, so a rope that flips between raising and
## contested never sends the bots on it away and back (AB1, critic attempt 2).
static func on_worked_rope(b: Bot, w: BotWorld) -> bool:
	if b.flag_pole < 0 or b.flag_pole >= w.flags.size() or w.overtime_flag.up:
		return false
	var f := w.flags[b.flag_pole]
	return f.status != FlagState.Status.IDLE and Flag.at_pole(b.character, f, w.tuning.flag)


## The pole `b` makes for in flag mode: the one it is on while that rope is worked (on_worked_rope); else a defender's
## the pole it was picked to retake (Bot.retake_pole, pick_retakers), an attacker's the pole in play.
static func pole_of(b: Bot, w: BotWorld) -> int:
	if on_worked_rope(b, w):
		return b.flag_pole
	return b.retake_pole if b.retake_pole >= 0 else w.flag_index


## Where defender `b` holds and searches round (BotBrain): the pole nearest the end of the lane it was dealt, its site.
static func post_of(b: Bot, w: BotWorld) -> Vector3:
	return w.flags[maxi(0, Flag.nearest(w.flags, b.lane_goal))].position


## Holding a post rather than hunting once its lane is walked: a defender (at the point it was dealt) or an anchor.
static func holds_post(b: Bot, w: BotWorld) -> bool:
	return role(b, w) == Role.DEFEND or BotPersonality.anchor_holding(b, w)


## True if `b` should be at the pole now: an attacker that has swept its lane, or a defender picked to retake while the
## flag is off the bottom (the flag on its pole is in plain view). The others hold their posts. In Elimination's
## overtime (OV2), every bot once its reaction to the flag going up is over (Bot.overtime_at), while the round is live:
## the flag comes before chasing noises, as the pole does.
static func wants_flag(b: Bot, w: BotWorld) -> bool:
	match role(b, w):
		Role.ATTACK:
			return b.lane_done
		Role.DEFEND:
			return b.retake and b.retake_pole >= 0 and w.flags[b.retake_pole].progress > 0.0
	return w.overtime_flag.up and w.live and w.time >= b.overtime_at


## Where `b`'s flag mode heads: Elimination's overtime flag while it is up (its foot), else its Attack / Defend pole
## (pole_of).
static func spot(b: Bot, w: BotWorld) -> Vector3:
	return w.overtime_flag.foot if w.overtime_flag.up else w.flags[pole_of(b, w)].position


## Each tick, for the pole in play and then any other whose flag is off the bottom: the defenders already on its worked
## rope (on_worked_rope) stay, and the nearest others in play make them up to `retakers` (Bot.retake_pole), who go to
## pull its flag down once it is off the bottom (wants_flag); the rest hold their posts, so tagging a pole doesn't empty
## every lane. Re-picked every tick, so if one is hit the next nearest takes over. A bot under a squad order isn't
## picked: it does what it was asked. So a flag started at one pole draws defenders there while those fighting at the
## other stay on its rope (AB1).
static func pick_retakers(w: BotWorld) -> void:
	# Those on a worked rope stay on it first, whichever pole is filled first after (critic, attempt 3).
	for b in w.bots:
		b.retake_pole = -1
		if _free_defender(b, w) and on_worked_rope(b, w) and w.flags[b.flag_pole].progress > 0.0:
			b.retake_pole = b.flag_pole
	_pick_for(w, w.flag_index)
	for i in w.flags.size():
		if i != w.flag_index:
			_pick_for(w, i)
	for b in w.bots:
		b.retake = b.retake_pole >= 0


## pick_retakers for pole `i` (another than the one in play only with its flag off the bottom): to those already on its
## worked rope, the nearest free ones one at a time.
static func _pick_for(w: BotWorld, i: int) -> void:
	var f := w.flags[i]
	if i != w.flag_index and f.progress <= 0.0:
		return
	var picked := 0
	for b in w.bots:
		if b.retake_pole == i:
			picked += 1
	while picked < w.cfg.retakers:
		var near: Bot = null
		var best := INF
		for b in w.bots:
			if b.retake_pole >= 0 or not _free_defender(b, w):
				continue
			var d := _to(b.character, f.position)
			if d < best or (d == best and near != null and b.character.id < near.character.id):
				best = d
				near = b
		if near == null:
			return
		near.retake_pole = i
		picked += 1


## A defender in play under no squad order: one pick_retakers may send.
static func _free_defender(b: Bot, w: BotWorld) -> bool:
	return role(b, w) == Role.DEFEND and Elimination.is_in_play(b.character) and b.order == SquadOrder.Kind.NONE


## Each tick: of the attacking bots in play that have swept their lane, one raises the flag and the others guard the pole
## (a second raiser adds nothing: the rope goes up no faster). Bots in flag mode first, then the nearest the pole, the
## current raiser counted raiser_switch_margin nearer; never a bot under a squad order. Nobody raises while an attacker
## who isn't a bot (the player) is at the pole already. A raiser on the worked rope of another pole (_held_elsewhere)
## keeps raising there, and isn't counted for this one.
static func pick_raiser(w: BotWorld) -> void:
	var raiser: Bot = null
	var best_rank := 2
	var best := INF
	for b in w.bots:
		var keep := b.raiser
		b.raiser = false
		if role(b, w) != Role.ATTACK or not Elimination.is_in_play(b.character) or not b.lane_done \
				or b.order != SquadOrder.Kind.NONE:
			continue
		if _held_elsewhere(b, w):
			b.raiser = keep
			continue
		var rank := 0 if b.mode == Bot.Mode.FLAG else 1
		var d := _to_pole(b.character, w) - (w.cfg.raiser_switch_margin if keep else 0.0)
		if rank < best_rank or (rank == best_rank and d < best):
			best_rank = rank
			best = d
			raiser = b
	if raiser == null:
		return
	for c in w.characters:
		if c.team == w.attackers and not _is_bot(c, w) and Flag.at_pole(c, w.flag, w.tuning.flag):
			return
	raiser.raiser = true


## On the worked rope of a pole other than the one in play (on_worked_rope).
static func _held_elsewhere(b: Bot, w: BotWorld) -> bool:
	return b.flag_pole != w.flag_index and on_worked_rope(b, w)


static func _to_pole(c: Character, w: BotWorld) -> float:
	return _to(c, w.flag.position)


static func _to(c: Character, at: Vector3) -> float:
	return Vector2(c.position.x - at.x, c.position.z - at.z).length()


static func _is_bot(c: Character, w: BotWorld) -> bool:
	for b in w.bots:
		if b.character == c:
			return true
	return false
