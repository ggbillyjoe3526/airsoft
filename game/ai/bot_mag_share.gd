class_name BotMagShare
## The bots' side of the magazine hand-off (MH2; the browser game's ai/magShare.ts, MG1). The rules are the
## simulation's (MagShare): one press of PlayerCommand.mag_hand_off asks the nearest teammate with one to spare, or
## tosses one to a teammate asking you who is in reach. Here a bot decides when to press, and where to walk:
##
## - A bot low on BBs for its primary (the replica it fights with; it never asks for its pistol's) presses to ask, at
##   most once a BotConfig.mag_press_gap and only with someone to ask; with nobody, it looks again after the bot's ask
##   gap (MagShareConfig.bot_ask_gap). A bot's unused pistol spare is given freely (the simulation's keep rule).
## - A bot asked (by a bot or by you) and free to bring one (in play, not asking itself, not off to the pole) takes the
##   nearest ask standing to it, sets off sprinting while further than mag_hurry_distance, walks on to within
##   mag_walk_up_to, and presses once the catcher is in reach and in sight (MagShare.can_toss_to). It lets the job go
##   when the ask ends, either of them is out, it has none to spare any more or it wants the pole.
## - A bot answers the asks standing with it through its command (PlayerCommand.mag_answer): it takes the one it sets
##   off for (the asker's line says it is coming only then), and turns down one it can't take, which the simulation
##   passes on to the next teammate with one to spare: every one while it is off to the pole, and, while it brings one
##   to someone else, those another teammate could bring (with nobody else an ask waits its turn).
## - A bot that asked a bot waits where it is while that bot brings it, behind cover from what the giver fights while
##   the giver is held up in a fight (BotBrain); one that asked a player walks up to within mag_walk_up_to of them and
##   waits for their toss.
##
## In a bot's priorities (BotBrain): fights and cover first, then bringing one, then a squad order, the pole, then
## waiting for one. The same at every level and for both teams. Callouts put the asks and answers into words. Allocates
## nothing.

## The loadout slot of a bot's primary, the replica it fights with (BotBrain switches to it).
const PRIMARY := 0

## The spare a toss would take (scratch for can_toss_to; bots think in turn).
static var _pick: MagShare.SparePick = MagShare.SparePick.new()


## Before the bots think (BotController.think; `sharing`: the round live and not practice): each job that ended is let
## go, and each bot free to bring one takes the nearest ask standing to it. With no ask waiting for a magazine anywhere,
## only the jobs are looked at.
static func update(w: BotWorld, sharing: bool) -> void:
	for b in w.bots:
		if b.mag_for != null and not (sharing and _still_giving(b, b.mag_for, w)):
			drop(b)
	if not sharing or not _any_ask_waiting(w):
		return
	for b in w.bots:
		if b.mag_for != null or not _free_to_give(b):
			continue
		var asker := _nearest_asker(b, w)
		if asker != null and not BotFlag.wants_flag(b, w):
			b.mag_for = asker
			b.mag_for_at = w.time
			b.mag_rush = false
			BotRoutes.drop(b)


## `b` stops bringing one.
static func drop(b: Bot) -> void:
	b.mag_for = null
	b.mag_rush = false


## After BotBrain.think wrote `b`'s command: a bot low on BBs for its primary, with no ask standing and nothing coming,
## outside the simulation's gap and its own press gap, presses to ask, if a teammate within reach of an ask has one to
## spare (else it looks again after the bot's ask gap).
static func ask_when_low(b: Bot, w: BotWorld, cmd: PlayerCommand, sharing: bool) -> void:
	var me := b.character
	var a := me.armament
	if not sharing or b.mag_for != null or w.time < b.mag_press_at or a.active != PRIMARY or me.mag.asked >= 0 \
			or me.mag.coming > 0 or w.time < me.mag.next_ask or not Elimination.is_in_play(me):
		return
	var rules := w.mag_share.cfg
	if not MagShare.low_on(a, rules.low_mags, PRIMARY):
		return
	if not _anyone_to_ask(me, w):
		b.mag_press_at = w.time + rules.bot_ask_gap
		return
	b.mag_press_at = w.time + w.cfg.mag_press_gap
	cmd.mag_hand_off = true


## After BotBrain.think wrote `b`'s command: its answer to the asks standing with it (MagShare.answer), one a tick. It
## takes the ask of the teammate it brings one to (update picked it), and turns down any other it can't take: all of
## them while it is off to the pole (BotFlag.wants_flag), else, while it brings one, those another teammate could
## bring.
static func answer(b: Bot, w: BotWorld, cmd: PlayerCommand, sharing: bool) -> void:
	var me := b.character
	if not sharing or not Elimination.is_in_play(me):
		return
	var to := b.mag_for
	if to != null and to.mag.asked == me.id and not to.mag.taken:
		cmd.mag_answer = PlayerCommand.MagAnswer.TAKE
		cmd.mag_answer_to = to.id
		return
	var pole := false
	var looked := false
	for c in w.characters:
		if c == me or c == to or c.mag.asked != me.id or c.mag.coming > 0 or not Elimination.is_in_play(c):
			continue
		if not looked:
			looked = true
			pole = BotFlag.wants_flag(b, w)
		if pole or (to != null and _anyone_else_to_ask(c, me, w)):
			cmd.mag_answer = PlayerCommand.MagAnswer.TURN_DOWN
			cmd.mag_answer_to = to.id if to != null else -1
			return


## Whether `b` waits for a magazine now (BotBrain's mode): one in the air to it, or its ask standing with a player, or
## with a bot that is bringing it.
static func waiting(b: Bot, w: BotWorld) -> bool:
	var me := b.character
	if me.mag.coming > 0:
		return true
	if me.mag.asked < 0:
		return false
	var giver := _character(w, me.mag.asked)
	if giver == null:
		return false
	var gb := bot_of(giver, w)
	return gb == null or gb.mag_for == me


## The bot giver `b` waits on, when that giver is held up fighting or in cover with a threat it knows of
## (Bot.last_known); null otherwise (no bot giver, or one on its way).
static func fighting_giver(b: Bot, w: BotWorld) -> Bot:
	var me := b.character
	if me.mag.coming > 0 or me.mag.asked < 0:
		return null
	var giver := _character(w, me.mag.asked)
	var gb := bot_of(giver, w) if giver != null else null
	if gb == null or not gb.has_last_known or (gb.mode != Bot.Mode.FIGHT and gb.mode != Bot.Mode.COVER):
		return null
	return gb


## The bot driving `c`, or null (the player).
static func bot_of(c: Character, w: BotWorld) -> Bot:
	for b in w.bots:
		if b.character == c:
			return b
	return null


## The MAG mode's move this tick (BotMovement): bringing one, a press once it can toss (it stands there), else the walk
## over, sprinting while far, to within mag_walk_up_to (on, with a wall between); waiting, the walk up to a player it
## asked, or standing. Returns whether it walks.
static func move(b: Bot, w: BotWorld, cmd: PlayerCommand, dt: float) -> bool:
	b.mag_rush = false
	var me := b.character
	var cfg := w.cfg
	var to := b.mag_for
	if to != null:
		if w.mag_share.can_toss_to(me, to, _pick):
			_stand(b)
			if w.time >= b.mag_press_at:
				b.mag_press_at = w.time + cfg.mag_press_gap
				cmd.mag_hand_off = true
			return false
		b.mag_rush = _flat(to.position, me.position) > cfg.mag_hurry_distance
		return _walk_to(b, w, to.position, _up_to(me, to, w), dt)
	var giver := _character(w, me.mag.asked) if me.mag.coming == 0 else null
	if giver == null or bot_of(giver, w) != null:
		_stand(b)
		return false
	return _walk_to(b, w, giver.position, _up_to(giver, me, w), dt)


## Whether `b` still brings `to` one: both in play, `to`'s ask to it standing with nothing in the air yet, one to spare,
## and not off to the pole.
static func _still_giving(b: Bot, to: Character, w: BotWorld) -> bool:
	var me := b.character
	return Elimination.is_in_play(me) and Elimination.is_in_play(to) and to.mag.asked == me.id and to.mag.coming == 0 \
			and not BotFlag.wants_flag(b, w) and w.mag_share.has_mag_for(me, to)


## A bot that may bring one, but for the pole (update asks BotFlag last): in play, not asking itself, nothing coming
## to it.
static func _free_to_give(b: Bot) -> bool:
	var me := b.character
	return me.mag.asked < 0 and me.mag.coming == 0 and Elimination.is_in_play(me)


## Whether any character's ask stands with nothing in the air to it yet: one pass, nothing else looked at.
static func _any_ask_waiting(w: BotWorld) -> bool:
	for c in w.characters:
		if c.mag.asked >= 0 and c.mag.coming == 0:
			return true
	return false


## The nearest teammate in play whose ask to `b` stands with nothing in the air to it yet, and that `b` has one to spare
## for; null if none.
static func _nearest_asker(b: Bot, w: BotWorld) -> Character:
	var me := b.character
	var best: Character = null
	var best_d := INF
	for c in w.characters:
		if c == me or c.team != me.team or c.mag.asked != me.id or c.mag.coming > 0 or not Elimination.is_in_play(c):
			continue
		var d := _flat(c.position, me.position)
		if d >= best_d or not w.mag_share.has_mag_for(me, c):
			continue
		best = c
		best_d = d
	return best


## Whether an ask from `me` would find a giver (the simulation's rule, MagShare._ask): a teammate in play within
## ask_range, not asking itself, with a magazine to spare that fits.
static func _anyone_to_ask(me: Character, w: BotWorld) -> bool:
	var reach := w.mag_share.cfg.ask_range
	for c in w.characters:
		if c == me or c.team != me.team or c.mag.asked >= 0 or not Elimination.is_in_play(c):
			continue
		if _flat(c.position, me.position) <= reach and w.mag_share.has_mag_for(c, me):
			return true
	return false


## Whether `asker`'s ask, turned down by `me`, would find another giver (MagShare.answer's rule): a teammate in play
## within ask_range, not asking itself, that hasn't turned it down, with one to spare that fits.
static func _anyone_else_to_ask(asker: Character, me: Character, w: BotWorld) -> bool:
	var reach := w.mag_share.cfg.ask_range
	for c in w.characters:
		if c == me or c == asker or c.team != asker.team or c.mag.asked >= 0 or not Elimination.is_in_play(c) \
				or asker.mag.turned_down & MagShare.bit(c.id) != 0:
			continue
		if _flat(c.position, asker.position) <= reach and w.mag_share.has_mag_for(c, asker):
			return true
	return false


## How close a walk to the teammate in a hand-off stops (m): mag_walk_up_to while the toss's own line from `thrower` to
## `catcher` is clear (MagShare.toss_line_clear), else right up to them (0), so nothing between stops it where it can't
## toss.
static func _up_to(thrower: Character, catcher: Character, w: BotWorld) -> float:
	return w.cfg.mag_walk_up_to if w.mag_share.toss_line_clear(thrower, catcher) else 0.0


## Walks to `goal` (which may move) until within `arrive`. Returns whether it walks.
static func _walk_to(b: Bot, w: BotWorld, goal: Vector3, arrive: float, dt: float) -> bool:
	if _flat(goal, b.character.position) <= arrive:
		_stand(b)
		return false
	BotRoutes.want(b, goal, w.cfg)
	return BotRoutes.follow(b, w, dt, true)


## Stands where it is (a route still being planned is kept for when it moves again).
static func _stand(b: Bot) -> void:
	if b.route_state != Bot.RouteState.WANTED:
		b.route_state = Bot.RouteState.NONE


static func _character(w: BotWorld, id: int) -> Character:
	for c in w.characters:
		if c.id == id:
			return c
	return null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
