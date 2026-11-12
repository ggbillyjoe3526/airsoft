class_name Announcer
extends RefCounted
## Settings › Accessibility's Screen reader messages (the browser game's hit feed was a polite live region): turns the
## tick's events into lines in the HUD's own words for HudAnnounce to hand a screen reader. Each hit feed line ("Rook
## called HIT · Alpha", "You" for the player), your own hit in its place ("You're hit · Rook"), each round's start
## ("Round 3", with the banner's line under it when it has one), each round's end (the stamp, the banner's line and the
## score, your team first), Elimination's overtime flag going up ("Overtime · touch the flag", as its banner), Plant The
## Bomb's pick-up, drop and plant ("Rook picked up the bomb", "Bomb planted at A · Defuse it before it goes off"), the
## match's end (the stamp and the match's score) and each of your team's callouts the feed shows ("Brick: Two, Crate
## yard!") and each notice of the magazine hand-off's line (MH3, HudMagLine: "+1 mag from Brick · 60 BBs", "Nobody near
## has a mag to spare"), and each squad order you give ("Order · Follow Me"), or that waits for the next round (BP6).
## Lines that come inside JOIN_WINDOW of
## the first are joined into one message, so a round's end and the match's end, or a burst of hits, are read as one.
## Your hit and the match's result make the message assertive (read at once); the rest are polite (read when the reader
## is free). Off, nothing is kept. Builds strings only on those events, never per frame.

## Seconds from a message's first line to its going out: later lines inside it join it.
const JOIN_WINDOW := 0.3
## Between joined lines: a full stop, so the reader pauses.
const JOIN := ". "
## Between the parts of one line, as on the HUD's banners.
const PART := " · "
## A squad order's name by SquadOrder.Kind, as the order wheel says it ("" for none).
const ORDER_KEYS: Dictionary[int, String] = {SquadOrder.Kind.FOLLOW: "ORDER_FOLLOW", SquadOrder.Kind.HOLD: "ORDER_HOLD",
		SquadOrder.Kind.REGROUP: "ORDER_REGROUP", SquadOrder.Kind.TEAM_PLAN: "ORDER_TEAM_PLAN",
		SquadOrder.Kind.MAG: "ORDER_MAG", SquadOrder.Kind.MOVE: "ORDER_MOVE", SquadOrder.Kind.WATCH: "ORDER_WATCH"}

## Whether messages are made (Settings.read_out).
var on: bool = true

var _teams: TeamConfig = null
var _you: Character = null
var _half_time_after: int = 0
var _names := PackedStringArray()
## The lines of the message being gathered, whether one of them is assertive, and the seconds left before it goes out
## (negative while nothing is gathered).
var _lines := PackedStringArray()
var _assertive: bool = false
var _left: float = -1.0
## The last message out and whether it was assertive.
var _message: String = ""
var _message_assertive: bool = false


## Lines for `you` (the player, "You" in them), the teams' names from `teams`, half time after round `half_time_after`
## (RoundConfig.half_time_after; 0 for none).
func _init(teams: TeamConfig, you: Character, half_time_after: int) -> void:
	_teams = teams
	_you = you
	_half_time_after = half_time_after


## The names by character id ("" for you, or for a team's name), as the hit feed shows them.
func set_names(names: PackedStringArray) -> void:
	_names = names


## Turns messages on or off; off drops what is being gathered.
func set_on(value: bool) -> void:
	on = value
	if not on:
		_lines.clear()
		_assertive = false
		_left = -1.0


## The tick's events in `state`: hits, and the rounds' and the match's turns (none on the practice range).
func on_tick(state: GameState) -> void:
	if not on:
		return
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		match e.kind:
			GameEvent.Kind.CHARACTER_HIT:
				if e.actor >= 0:
					_hit(state.characters[e.actor], state.characters[e.target])
			GameEvent.Kind.ROUND_START:
				if not state.round_state.practice:
					add(round_start_line(state.round_state, e.value), false)
			GameEvent.Kind.OVERTIME:
				add(overtime_line(), false)
			GameEvent.Kind.ROUND_OVER:
				if not state.round_state.practice:
					add(round_over_line(state.round_state, e.value, e.value2 as GameEvent.RoundEnd), false)
			GameEvent.Kind.MATCH_OVER:
				add(match_over_line(e.value, state.round_state.score), true)
			GameEvent.Kind.PLANT:
				add(bomb_line(state, e), false)
			GameEvent.Kind.SQUAD_ORDER:
				if e.actor == _you.id:
					add(order_line(e.value), false)
			GameEvent.Kind.SQUAD_ORDER_REFUSED:
				if e.actor == _you.id:
					add(tr("HUD_ORDER_NOT_NOW").replace("\n", " "), false)


## Gathers `line` into the message (opening one if none is gathered); `assertive` makes the whole message so.
func add(line: String, assertive: bool) -> void:
	if not on or line.is_empty():
		return
	if _left < 0.0:
		_left = JOIN_WINDOW
	_lines.append(line)
	_assertive = _assertive or assertive


## Moves the clock on `delta` seconds: true when a message has just gone out (message(), assertive()).
func advance(delta: float) -> bool:
	if _left < 0.0:
		return false
	_left -= delta
	if _left > 0.0:
		return false
	_message = JOIN.join(_lines)
	_message_assertive = _assertive
	_lines.clear()
	_assertive = false
	_left = -1.0
	return true


## Whether a message is being gathered (it goes out within JOIN_WINDOW).
func gathering() -> bool:
	return _left >= 0.0


## The last message out.
func message() -> String:
	return _message


## Whether the last message out is assertive (your hit or the match's result in it).
func assertive() -> bool:
	return _message_assertive


## "Rook called HIT · Alpha": `victim` called the hit on `shooter`'s BB.
func hit_line(shooter: Character, victim: Character) -> String:
	return tr("HUD_SR_CALLED_HIT") % [_name(victim), _name(shooter)]


## A teammate's callout as the feed shows it, a polite line: `speaker` said `words`. Builds nothing while off.
func add_call(speaker: Character, words: String) -> void:
	if on:
		add(call_line(speaker, words), false)


## "Brick: Two, Crate yard!".
func call_line(speaker: Character, words: String) -> String:
	return tr("HUD_SR_CALL") % [_name(speaker), words]


## "Order · Follow Me": the squad order `kind` (SquadOrder.Kind) you gave; "" for none.
func order_line(kind: int) -> String:
	var key: String = ORDER_KEYS.get(kind, "")
	return tr("HUD_SR_ORDER") % tr(key) if key != "" else ""


## "You're hit · Rook".
func your_hit_line(shooter: Character) -> String:
	return tr("HUD_SR_YOU_ARE_HIT") % _name(shooter)


## Round `number`'s start as its banner says it: "Round 3", "Round 3 · Attack · Take the flag", "Round 4 · Half time ·
## ends swapped".
func round_start_line(rs: RoundState, number: int) -> String:
	var half := _half_time_after > 0 and number == _half_time_after + 1
	if rs.mode == RoundState.Mode.ATTACK_DEFEND:
		var attacking := _you.team == rs.attackers
		var side := tr(&"HUD_ATTACK" if attacking else &"HUD_DEFEND")
		var job := tr(&"HUD_HALF_TIME") if half else tr(&"HUD_TAKE_FLAG" if attacking else &"HUD_HOLD_POLE")
		return (tr(&"HUD_ROUND_SIDE") % [number, side]) + PART + job
	if rs.mode == RoundState.Mode.PLANT_THE_BOMB:
		var attacking := _you.team == rs.attackers
		var side := tr(&"HUD_ATTACK" if attacking else &"HUD_DEFEND")
		var job := tr(&"HUD_HALF_TIME") if half else _plant_job(rs, attacking)
		return (tr(&"HUD_ROUND_SIDE") % [number, side]) + PART + job
	var title := tr(&"HUD_ROUND") % number
	return title + PART + tr(&"HUD_HALF_TIME") if half else title


## Plant The Bomb's job for a side as its banner says it: "Plant the bomb", or "Hold sites A and B".
func _plant_job(rs: RoundState, attacking: bool) -> String:
	if attacking:
		return tr(&"HUD_PLANT_THE_BOMB")
	if rs.plant.sites.size() < 2:
		return tr(&"HUD_HOLD_SITE") % Plant.LETTERS[0]
	return tr(&"HUD_HOLD_SITES") % [Plant.LETTERS[0], Plant.LETTERS[1]]


## A bomb event of Plant The Bomb as the HUD says it, or "" for none: your team's pick-up and drop when you attack
## ("Rook picked up the bomb"), and the bomb armed as its banner says it ("Bomb planted at A · Defuse it before it goes
## off"). The defuse and the bomb going off are read in the round's end line.
func bomb_line(state: GameState, e: GameEvent) -> String:
	var rs := state.round_state
	if e.value == Plant.Cue.PLANTED:
		var letter: String = Plant.LETTERS[clampi(e.value2, 0, Plant.MOST - 1)]
		var job := tr(&"HUD_BOMB_PLANTED_ATTACK" if _you.team == rs.attackers else &"HUD_BOMB_PLANTED_DEFEND")
		return (tr(&"HUD_BOMB_PLANTED_AT") % letter) + PART + job
	if e.value != Plant.Cue.PICKED_UP and e.value != Plant.Cue.DROPPED:
		return ""
	if e.actor < 0 or e.actor >= state.characters.size():
		return ""
	var actor := state.characters[e.actor]
	var words := HudPlant.feed_words(rs, e, actor, _you)
	return tr(&"HUD_SR_BOMB") % [_name(actor), words] if not words.is_empty() else ""


## Elimination's overtime flag going up, as its banner says it: "Overtime · Touch the flag".
func overtime_line() -> String:
	return tr(&"HUD_OVERTIME") + PART + tr(&"HUD_TOUCH_FLAG")


## A round's end as its banner says it, and the score after it: "Won · Round 3 · Alpha take the round · Alpha 2 – 1
## Beta"; by the flag "Lost · Round 3 · Flag raised · Beta take the round · …" (at the overtime flag "Flag touched");
## "Draw · Round 3 · The round is played again · …". `winner` -1 for a draw. Plant The Bomb's: "Won · Round 3 · Bomb
## went off · Alpha take the round · …", "Bomb defused", or the clock run out "Defended · Time's up · nothing planted".
func round_over_line(rs: RoundState, winner: int, reason: GameEvent.RoundEnd) -> String:
	var parts := PackedStringArray([_stamp(winner), tr(&"HUD_ROUND") % rs.number])
	if winner < 0:
		parts.append(tr(&"HUD_ROUND_DRAW_SUB"))
	else:
		var team := tr(_teams.names[winner])
		if reason == GameEvent.RoundEnd.OVERTIME_FLAG:
			parts.append(tr(&"HUD_FLAG_TOUCHED"))
			parts.append(tr(&"HUD_ROUND_WON") % team)
		elif reason == GameEvent.RoundEnd.SIMULATED:
			parts.append(tr(&"HUD_SIMULATED"))
			parts.append(tr(&"HUD_ROUND_WON") % team)
		elif rs.mode == RoundState.Mode.PLANT_THE_BOMB and reason != GameEvent.RoundEnd.ELIMINATED:
			match reason:
				GameEvent.RoundEnd.WENT_OFF, GameEvent.RoundEnd.DEFUSED:
					var went_off := reason == GameEvent.RoundEnd.WENT_OFF
					parts.append(tr(&"HUD_BOMB_WENT_OFF" if went_off else &"HUD_BOMB_DEFUSED"))
					parts.append(tr(&"HUD_ROUND_WON") % team)
				_:
					parts.append(tr(&"HUD_DEFENDED"))
					parts.append(tr(&"HUD_BOMB_NO_PLANT"))
		elif rs.mode == RoundState.Mode.ATTACK_DEFEND and reason != GameEvent.RoundEnd.ELIMINATED:
			var captured := reason == GameEvent.RoundEnd.CAPTURED
			parts.append(tr(&"HUD_FLAG_RAISED" if captured else &"HUD_DEFENDED"))
			parts.append(tr(&"HUD_ROUND_WON" if captured else &"HUD_HELD_POLE") % team)
		else:
			parts.append(tr(&"HUD_ROUND_WON") % team)
	parts.append(_score(rs.score))
	return PART.join(parts)


## The match's end as its stamp says it: "Won · The match · Alpha 5 – 3 Beta", your team first.
func match_over_line(winner: int, score: PackedInt32Array) -> String:
	var you := _you.team
	return _stamp(winner) + PART + tr(&"SUM_STAMP_SUB") % [tr(_teams.names[you]), score[you], score[1 - you],
			tr(_teams.names[1 - you])]


func _hit(shooter: Character, victim: Character) -> void:
	if victim.id == _you.id:
		add(your_hit_line(shooter), true)
	else:
		add(hit_line(shooter, victim), false)


func _name(c: Character) -> String:
	return HudFeed.name_of(c, _you, _names, _teams)


## Won, Lost or Draw, as the round's and the match's stamps.
func _stamp(winner: int) -> String:
	if winner < 0:
		return tr(&"HUD_ROUND_DRAW")
	return tr(&"HUD_WON" if winner == _you.team else &"HUD_LOST")


## "Alpha 2 – 1 Beta": your team first.
func _score(score: PackedInt32Array) -> String:
	var you := _you.team
	return tr(&"HUD_SR_SCORE") % [tr(_teams.names[you]), score[you], score[1 - you], tr(_teams.names[1 - you])]
