class_name MagShare
extends RefCounted
## The magazine hand-off's rules (MH1; the browser game's sim/magShare.ts and the press of src/magHandoff.ts, MG1):
## asking a teammate for a magazine, and tossing one. A character's `PlayerCommand.mag_hand_off` is one press that does
## what fits now (`press`): a toss to the nearest teammate whose ask to it stands and is in reach, else an ask if it is
## low, else a refusal saying why. The player and every bot press alike; who presses when is the bots' business (MH2)
## and the input's (MH3).
##
## An ask names the nearest teammate in play within MagShareConfig.ask_range with a magazine to spare that fits; it
## stands ask_time unless a magazine lands first or the teammate turns it down (answer: then it goes to the next
## nearest, never back to one that turned it down), and the asker may ask again its gap after it ends. A toss takes its BBs
## out of the thrower's spare at once and puts the magazine in the air (GameState.mag_tosses, made once); after its
## flight they go into the catcher's emptiest spares for the replica it was tossed for, or it is lost: a catcher out of
## play, the round decided meanwhile, or the level met on the way (lost there). Nothing is made out of nothing, and
## nothing random happens.
##
## Events: MAG_ASK, MAG_TOSS, MAG_CATCH, MAG_LOST and MAG_REFUSED (value: a Refusal). Nothing is allocated per tick.

## Why a press did nothing (MAG_REFUSED's value): nobody near has one to spare; you have a full spare; no magazine of
## yours fits the asker's replica; your last ask ended too lately (or your toss is still in the air, or every toss
## slot is); one is already coming to you; the asker is out of reach or sight; you are out, or the round is not live.
enum Refusal { NOBODY, NOT_LOW, NO_SPARE, WAIT, ALREADY, TOO_FAR, NOT_NOW }

## A flight's shortest length in the share of it flown (s).
const EPSILON := 1e-4


## A magazine in the air: one slot of GameState.mag_tosses, made once and reused.
class Toss:
	extends RefCounted
	var active: bool = false
	var from_id: int = -1
	var to_id: int = -1
	## The catcher's loadout slot its BBs go to (the replica in its hand when it was tossed), and the thrower's it came
	## from (its look: a rifle's or a pistol's magazine).
	var slot: int = 0
	var from_slot: int = 0
	var bbs: int = 0
	## Seconds in the air so far, and its whole flight.
	var age: float = 0.0
	var flight: float = 0.0
	## Where it left the thrower's hand. It flies on to the catcher's chest wherever they are now (flight_point); the
	## pieces of that path checked against the level so far (MagShareConfig.path_pieces), and where the last ended, or
	## where it met the level (`at`).
	var from: Vector3 = Vector3.ZERO
	var at: Vector3 = Vector3.ZERO
	var checked: int = 0


## One character's side of the hand-off (Character.mag): its ask, and what is coming to it. Cleared at each respawn but
## for `player`.
class Hand:
	extends RefCounted
	## The teammate asked (-1: no ask standing), and when (s of match time); `taken` once that teammate has set off to
	## bring it (PlayerCommand.MagAnswer.TAKE; a new ask, or one passed on, isn't).
	var asked: int = -1
	var asked_at: float = 0.0
	var taken: bool = false
	## The teammates that turned this ask down (a bit 1 << id each; MagShare.answer): it never goes back to them.
	var turned_down: int = 0
	## Magazines in the air to it, and the thrower of the last.
	var coming: int = 0
	var coming_from: int = -1
	## It may ask again from this time on (s).
	var next_ask: float = -INF
	## The player's ask gap (MagShareConfig.player_ask_gap), not a bot's; set by whoever builds the match.
	var player: bool = false

	func clear() -> void:
		asked = -1
		asked_at = 0.0
		taken = false
		turned_down = 0
		coming = 0
		coming_from = -1
		next_ask = -INF


## The spare a toss would take: the thrower's loadout slot and its index in that pouch, and the BBs that would move.
class SparePick:
	extends RefCounted
	var slot: int = -1
	var index: int = -1
	var bbs: int = 0


var cfg: MagShareConfig = null
var body: BodyConfig = null
var hits: HitConfig = null
var query: WorldQuery = null
## Scratch, one at a time: the spare a check would take, and a line's hit.
var _pick: SparePick = SparePick.new()
var _hit: RayHit = RayHit.new()


func _init(tuning: SimTuning, world: WorldQuery) -> void:
	cfg = tuning.mag_share
	body = tuning.body
	hits = tuning.hits
	query = world


## The pool of magazines in the air, made once with the state (MagShareConfig.max_tosses).
static func make_tosses(count: int) -> Array[Toss]:
	var out: Array[Toss] = []
	for i in maxi(0, count):
		out.append(Toss.new())
	return out


## A magazine of `need`'s class fits `replica`: a rifle's a rifle, a pistol's a pistol (stats.md's Class).
static func fits(replica: ReplicaConfig, need: ReplicaConfig) -> bool:
	return replica != null and need != null and replica.site_class == need.site_class


## Low on BBs: the spares for `slot`'s replica (-1: the one in hand) hold fewer BBs than `mags` full magazines of it.
static func low_on(a: Armament, mags: int, slot: int = -1) -> bool:
	var s := a.active if slot < 0 else slot
	if s >= a.ammo.size():
		return false
	return a.ammo[s].spare_bbs() < a.replicas[s].mag_size * mags


## BBs the emptiest spare for `slot` still has room for (0 with no spare, or every one full).
static func pouch_room(a: Armament, slot: int) -> int:
	if slot < 0 or slot >= a.ammo.size():
		return 0
	var pouch := a.ammo[slot].pouch
	if pouch.is_empty():
		return 0
	var size := a.replicas[slot].mag_size
	var least := size
	for m in pouch:
		least = mini(least, m)
	return size - least


## The spare `giver` would toss for a replica like `need` with `room` to fill, into `out` (true), or false when none
## fits with BBs in it. A spare of a replica it isn't holding goes first (the one in hand is the one it fights with),
## then the fullest; `out.bbs` is what moves, at most `room`.
static func choose_spare(giver: Armament, need: ReplicaConfig, room: int, out: SparePick) -> bool:
	out.slot = -1
	out.index = -1
	out.bbs = 0
	if room <= 0:
		return false
	var best_held := true
	var best := 0
	for s in giver.replicas.size():
		if not fits(giver.replicas[s], need):
			continue
		var pouch := giver.ammo[s].pouch
		var held := s == giver.active
		for i in pouch.size():
			var n := pouch[i]
			if n <= 0:
				continue
			var better := out.slot < 0 or (best_held and not held) or (held == best_held and n > best)
			if not better:
				continue
			out.slot = s
			out.index = i
			best = n
			best_held = held
	if out.slot < 0:
		return false
	out.bbs = mini(best, room)
	return true


## Whether tossing `pick` leaves `giver` with less than `keep` full magazines of the replica in hand: only a spare of
## that one, the one it fights with, counts against it.
static func leaves_low(giver: Armament, pick: SparePick, keep: int) -> bool:
	if pick.slot != giver.active:
		return false
	return giver.ammo[pick.slot].spare_bbs() - pick.bbs < giver.replicas[pick.slot].mag_size * keep


## Puts `bbs` into `slot`'s spares, emptiest first, each up to a full magazine; returns how many went in.
static func fill_spares(a: Armament, slot: int, bbs: int) -> int:
	if slot < 0 or slot >= a.ammo.size():
		return 0
	var pouch := a.ammo[slot].pouch
	var size := a.replicas[slot].mag_size
	var left := bbs
	while left > 0:
		var least := -1
		for i in pouch.size():
			if pouch[i] < size and (least < 0 or pouch[i] < pouch[least]):
				least = i
		if least < 0:
			break
		var add := mini(left, size - pouch[least])
		pouch[least] += add
		left -= add
	return bbs - left


## Whether `c` is low on BBs for the replica in hand (MagShareConfig.low_mags).
func low(c: Character) -> bool:
	return low_on(c.armament, cfg.low_mags)


## Whether `giver` has a magazine to spare for `receiver`'s replica in hand: one that fits, with room for it, keeping
## MagShareConfig.keep_mags full magazines of the replica `giver` fights with.
func has_mag_for(giver: Character, receiver: Character) -> bool:
	var a := receiver.armament
	if a.active >= a.replicas.size():
		return false
	if not choose_spare(giver.armament, a.replicas[a.active], pouch_room(a, a.active), _pick):
		return false
	return not leaves_low(giver.armament, _pick, cfg.keep_mags)


## Where a toss leaves `c`'s hand: a little under its eyes, wherever a lean puts them.
func throw_point(c: Character) -> Vector3:
	return Lean.eye(c, body, hits) - Vector3(0.0, cfg.throw_drop, 0.0)


## Where a toss to `c` is caught: about its chest.
func catch_point(c: Character) -> Vector3:
	return Lean.eye(c, body, hits) - Vector3(0.0, cfg.catch_drop, 0.0)


## How far a toss from `giver` to `receiver` reaches (m): eye to chest.
func toss_distance(giver: Character, receiver: Character) -> float:
	return Lean.eye(giver, body, hits).distance_to(catch_point(receiver))


## Whether `giver` can toss `receiver` a magazine now, with the spare it would take in `out`: teammates both in play,
## the thrower not vaulting, the catcher's replica in hand with room in a spare, a spare that fits, within
## MagShareConfig.toss_range and nothing of the level on the path it would fly (toss_line_clear).
func can_toss_to(giver: Character, receiver: Character, out: SparePick) -> bool:
	if giver == receiver or giver.team != receiver.team or not Elimination.is_in_play(giver) \
			or not Elimination.is_in_play(receiver) or giver.vault.active:
		return false
	var a := receiver.armament
	if a.active >= a.replicas.size():
		return false
	if not choose_spare(giver.armament, a.replicas[a.active], pouch_room(a, a.active), out):
		return false
	if toss_distance(giver, receiver) > cfg.toss_range:
		return false
	return toss_line_clear(giver, receiver)


## Whether nothing of the level is on the path a toss from `giver` to `receiver` would fly: its arc from the giver's
## hand to the receiver's chest, in MagShareConfig.path_pieces straight pieces, the very pieces `step` checks in flight
## (BP7), so a toss allowed with nobody moving is caught. The toss's own test, and the one a bot walking up to toss or
## catch stops by.
func toss_line_clear(giver: Character, receiver: Character) -> bool:
	return not _path_meets(throw_point(giver), catch_point(receiver), 0, cfg.path_pieces)


## Whether pieces `first` to `last` - 1 of the flown path from `from` to `to` (of MagShareConfig.path_pieces) meet the
## level, the first that does leaving where in `_hit`.
func _path_meets(from: Vector3, to: Vector3, first: int, last: int) -> bool:
	var n := maxi(1, cfg.path_pieces)
	var a := flight_point(from, to, float(first) / n, cfg)
	for k in range(first, last):
		var b := flight_point(from, to, float(k + 1) / n, cfg)
		if query.ray(a, b, _hit):
			return true
		a = b
	return false


## `c`'s press of the hand-off this tick (`live`: the round is in play and not practice): a toss to the nearest
## teammate asking it who is in reach, else an ask if it is low, else MAG_REFUSED with the reason.
func press(c: Character, state: GameState, live: bool) -> void:
	var events := state.events
	if not live or not Elimination.is_in_play(c):
		_refuse(c, Refusal.NOT_NOW, -1, events)
		return
	var asker := nearest_asker(c, state.characters, true)
	if asker != null:
		_toss(c, asker, state)
		return
	if low(c):
		if c.mag.asked >= 0:
			_refuse(c, Refusal.ALREADY, c.mag.asked, events)
		elif c.mag.coming > 0:
			_refuse(c, Refusal.ALREADY, c.mag.coming_from, events)
		elif state.time < c.mag.next_ask:
			_refuse(c, Refusal.WAIT, -1, events)
		else:
			_ask(c, state)
		return
	asker = nearest_asker(c, state.characters, false)
	if asker == null:
		_refuse(c, Refusal.NOT_LOW, -1, events)
		return
	var a := asker.armament
	var fit := choose_spare(c.armament, a.replicas[a.active], pouch_room(a, a.active), _pick)
	_refuse(c, Refusal.TOO_FAR if fit else Refusal.NO_SPARE, asker.id, events)


## `c`'s answer to the asks standing with it (PlayerCommand.mag_answer, `to` its mag_answer_to), in a live round with
## `c` in play: TAKE marks `to`'s ask to it taken (it sets off to bring one); TURN_DOWN passes every ask standing with
## it but `to`'s, nothing in the air to them yet, on to the nearest other teammate in reach with one to spare
## (MAG_ASK, a fresh ask's time), or ends it with its gap, refused as NOBODY, when there is none. An ask that can't be
## taken (its giver off to the pole) goes to someone who can at once, rather than standing ask_time unanswered.
func answer(c: Character, reply: PlayerCommand.MagAnswer, to: int, state: GameState, live: bool) -> void:
	if not live or not Elimination.is_in_play(c):
		return
	if reply == PlayerCommand.MagAnswer.TAKE:
		var r := _by_id(state.characters, to)
		if r != null and r.mag.asked == c.id:
			r.mag.taken = true
		return
	for o in state.characters:
		if o == c or o.id == to or o.mag.asked != c.id or o.mag.coming > 0 or not Elimination.is_in_play(o):
			continue
		o.mag.turned_down |= bit(c.id)
		if not _ask_except(o, state, o.mag.turned_down):
			_end_ask(o, state.time)


## One tick after the BBs flew: each magazine in the air lands once its flight is over, in the catcher's spares
## (MAG_CATCH) or, the catcher out of play, on the ground (MAG_LOST); with the round decided (`live` false) every one
## still flying is lost. Then each standing ask that has lapsed, lost its giver or its giver's spare, ends.
func step(state: GameState, live: bool, dt: float) -> void:
	var chars := state.characters
	for t in state.mag_tosses:
		if not t.active:
			continue
		t.age += dt
		var r := _by_id(chars, t.to_id)
		# On its way: it is lost where its path meets the level (BP7; before, it flew through whatever came between),
		# checked a piece at a time as it passes each piece's end, the pieces toss_line_clear allowed it on.
		var met := false
		if live and r != null and Elimination.is_in_play(r):
			var n := maxi(1, cfg.path_pieces)
			var reached := mini(n, floori(clampf(t.age / maxf(t.flight, EPSILON), 0.0, 1.0) * n))
			if reached > t.checked:
				var to := catch_point(r)
				met = _path_meets(t.from, to, t.checked, reached)
				t.at = _hit.position if met else flight_point(t.from, to, float(reached) / n, cfg)
				t.checked = reached
		if live and t.age < t.flight and not met:
			continue
		t.active = false
		if r != null:
			r.mag.coming = maxi(0, r.mag.coming - 1)
			if r.mag.asked >= 0 and r.mag.coming == 0:
				_end_ask(r, state.time)
				if met:
					# Lost to the level on its way (BP7): nothing came of the ask, so the catcher may ask again at once,
					# as when its giver asks (below), rather than wait its gap empty-handed.
					r.mag.next_ask = state.time
		var caught := live and r != null and Elimination.is_in_play(r) and not met
		var e := state.events.add(GameEvent.Kind.MAG_CATCH if caught else GameEvent.Kind.MAG_LOST)
		e.actor = t.from_id
		e.target = t.to_id
		e.slot = t.slot
		e.value2 = t.from_slot
		e.position = t.at if met else (catch_point(r) if r != null else t.from)
		e.value = fill_spares(r.armament, t.slot, t.bbs) if caught else t.bbs
	for c in chars:
		if c.mag.asked >= 0 and c.mag.coming == 0 and live and _giver_asking(c, chars):
			# Its giver asked for one of its own (BP7): it never gives while it asks, so the ask ends with no wait, free
			# to go to someone else.
			_end_ask(c, state.time)
			c.mag.next_ask = state.time
		elif c.mag.asked >= 0 and not _still_asking(c, chars, live, state.time):
			_end_ask(c, state.time)


## Whether `c`'s ask still stands: with a magazine in the air to it, while it is in play and the round live; otherwise
## also not lapsed, its giver in play and still with one to spare.
func _still_asking(c: Character, chars: Array[Character], live: bool, time: float) -> bool:
	if not live or not Elimination.is_in_play(c):
		return false
	if c.mag.coming > 0:
		return true
	if time - c.mag.asked_at > cfg.ask_time:
		return false
	var giver := _by_id(chars, c.mag.asked)
	return giver != null and Elimination.is_in_play(giver) and has_mag_for(giver, c)


## Whether the teammate `c` asked has an ask of its own standing.
static func _giver_asking(c: Character, chars: Array[Character]) -> bool:
	var giver := _by_id(chars, c.mag.asked)
	return giver != null and giver.mag.asked >= 0


func _end_ask(c: Character, time: float) -> void:
	c.mag.asked = -1
	c.mag.taken = false
	c.mag.turned_down = 0
	c.mag.next_ask = time + (cfg.player_ask_gap if c.mag.player else cfg.bot_ask_gap)


## `c` asks the nearest teammate in play within ask_range with one to spare (not one asking itself): MAG_ASK, or
## refused as NOBODY.
func _ask(c: Character, state: GameState) -> void:
	c.mag.turned_down = 0
	_ask_except(c, state, 0)


## _ask, passing over the teammates in `except` (a bit 1 << id each). False when it was refused.
func _ask_except(c: Character, state: GameState, except: int) -> bool:
	var best: Character = null
	var best_d := cfg.ask_range
	for o in state.characters:
		if o == c or except & bit(o.id) != 0 or o.team != c.team or not Elimination.is_in_play(o) \
				or o.mag.asked >= 0:
			continue
		var d := Vector2(o.position.x - c.position.x, o.position.z - c.position.z).length()
		if d > best_d or not has_mag_for(o, c):
			continue
		best = o
		best_d = d
	if best == null:
		_refuse(c, Refusal.NOBODY, -1, state.events)
		return false
	c.mag.asked = best.id
	c.mag.asked_at = state.time
	c.mag.taken = false
	var e := state.events.add(GameEvent.Kind.MAG_ASK)
	e.actor = c.id
	e.target = best.id
	e.slot = c.armament.active
	e.position = c.position
	return true


## `giver` tosses `receiver` a magazine (can_toss_to already allowed it): refused as WAIT while one of its own is still
## in the air or every slot of the pool is. The BBs leave its spare now (MAG_TOSS).
func _toss(giver: Character, receiver: Character, state: GameState) -> void:
	var free: Toss = null
	for t in state.mag_tosses:
		if t.active and t.from_id == giver.id:
			_refuse(giver, Refusal.WAIT, receiver.id, state.events)
			return
		if not t.active and free == null:
			free = t
	if free == null or not can_toss_to(giver, receiver, _pick):
		_refuse(giver, Refusal.WAIT, receiver.id, state.events)
		return
	var d := toss_distance(giver, receiver)
	giver.armament.ammo[_pick.slot].pouch[_pick.index] -= _pick.bbs
	free.active = true
	free.from_id = giver.id
	free.to_id = receiver.id
	free.slot = receiver.armament.active
	free.from_slot = _pick.slot
	free.bbs = _pick.bbs
	free.age = 0.0
	free.flight = cfg.flight_base + cfg.flight_per_metre * d
	free.from = throw_point(giver)
	free.at = free.from
	free.checked = 0
	receiver.mag.coming += 1
	receiver.mag.coming_from = giver.id
	var e := state.events.add(GameEvent.Kind.MAG_TOSS)
	e.actor = giver.id
	e.target = receiver.id
	e.slot = free.slot
	e.value = free.bbs
	e.value2 = free.from_slot
	e.position = free.from
	e.reach = d


## Where a magazine tossed from `from` to `to` is `p` of the way through its flight (0 to 1): along the line, raised by
## its arc (MagShareConfig.arc_per_metre a metre, at most arc_max, at the middle). Presentation draws it there too.
static func flight_point(from: Vector3, to: Vector3, p: float, c: MagShareConfig) -> Vector3:
	var arc := minf(c.arc_per_metre * from.distance_to(to), c.arc_max)
	return from.lerp(to, p) + Vector3.UP * arc * 4.0 * p * (1.0 - p)


## The nearest teammate of `me` in play whose ask to it stands with nothing in the air to it yet: only one `me` can
## toss to now if `in_reach`. Across the ground. The press's own pick, which the HUD's line and wheel read (MH3).
func nearest_asker(me: Character, chars: Array[Character], in_reach: bool) -> Character:
	var best: Character = null
	var best_d := INF
	for o in chars:
		if o == me or o.team != me.team or o.mag.asked != me.id or o.mag.coming > 0 or not Elimination.is_in_play(o):
			continue
		var d := Vector2(o.position.x - me.position.x, o.position.z - me.position.z).length()
		if d >= best_d or (in_reach and not can_toss_to(me, o, _pick)):
			continue
		best = o
		best_d = d
	return best


## Character `id`'s bit in a Hand's turned_down (0 for an id out of its range).
static func bit(id: int) -> int:
	return 1 << id if id >= 0 and id < 63 else 0


static func _refuse(c: Character, reason: Refusal, other: int, events: SimEvents) -> void:
	var e := events.add(GameEvent.Kind.MAG_REFUSED)
	e.actor = c.id
	e.target = other
	e.value = reason


## The character with id `id` (ids are indices; the loop keeps a mismatch harmless), or null.
static func _by_id(chars: Array[Character], id: int) -> Character:
	if id >= 0 and id < chars.size() and chars[id].id == id:
		return chars[id]
	for c in chars:
		if c.id == id:
			return c
	return null
