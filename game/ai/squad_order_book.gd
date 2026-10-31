class_name SquadOrderBook
extends RefCounted
## The squad orders in force (the browser game's BotController order bookkeeping, M22): who gave which, handing one out
## to the giver's bot teammates in play, giving it again (cancel, move a hold, keep from the wheel), Team plan, ending
## it when its giver or a bot is out and at each round start, and Regroup's hand-over to Follow me. BotController feeds
## it the simulation's SQUAD_ORDER events; how each bot carries an order out is SquadOrders'. Allocates nothing.

## What came of the last squad order given (one record, reused), and where the spots held for a giver are (hold_spot).
var order_outcome: SquadOrders.Outcome = SquadOrders.Outcome.new()
var held_middle: Vector3 = Vector3.ZERO
var _world: BotWorld = null
## Per giver (by character id), the squad order in force (one source for the presentation and for giving it again), and
## whether a Hold here in force was given looking at nothing, so each holds where it stood.
var _given: PackedInt32Array = PackedInt32Array()
var _own_spot: PackedByteArray = PackedByteArray()
## The teammates an order goes to, gathered afresh for each order given.
var _order_team: Array[Bot] = []


## The orders of the field in `world` (its characters never change mid-match).
func _init(world: BotWorld) -> void:
	_world = world
	_given.resize(world.characters.size())
	_own_spot.resize(world.characters.size())


## A new round: no order outlasts one (each bot's reset forgets its own).
func clear() -> void:
	_given.fill(SquadOrder.Kind.NONE)
	_own_spot.fill(0)


## An order from `giver_id` the simulation refused (out, or between rounds): the order in force stays, with NOT_NOW.
func refused(giver_id: int) -> void:
	order_outcome.record(giver_id, order_of(giver_id), SquadOrders.Notice.NOT_NOW)


## A squad order `kind` from `giver` to its bot teammates in play (the browser game's BotController.giveOrder, M22),
## written into order_outcome. The order in force given again cancels it, except Hold here aimed somewhere else (at
## least hold_move from the held spot, or at nothing while they hold a spot looked at), which moves it; picked again on
## the order wheel (`from_wheel`) it stays instead. Team plan ends it. A giver out of play (hit in the tick it gave the
## order) gives nothing: its order ends, with NOT_NOW. Returns the order in force afterwards (NONE also when no teammate
## is in play to take it).
func give_order(giver: Character, kind: SquadOrder.Kind, from_wheel: bool = false) -> SquadOrder.Kind:
	if giver == null or giver.id < 0 or giver.id >= _given.size() or kind == SquadOrder.Kind.NONE:
		return SquadOrder.Kind.NONE
	if not Elimination.is_in_play(giver):
		_drop_order(giver)
		order_outcome.record(giver.id, SquadOrder.Kind.NONE, SquadOrders.Notice.NOT_NOW)
		return SquadOrder.Kind.NONE
	var before := order_of(giver.id)
	if kind == SquadOrder.Kind.TEAM_PLAN:
		_drop_order(giver)
		order_outcome.record(giver.id, SquadOrder.Kind.NONE,
				SquadOrders.Notice.CANCELLED if before != SquadOrder.Kind.NONE else SquadOrders.Notice.ON_PLAN)
		return SquadOrder.Kind.NONE
	var now := _hand_out(giver, kind, not from_wheel)
	var notice := SquadOrders.Notice.NONE
	if now == SquadOrder.Kind.NONE:
		notice = SquadOrders.Notice.CANCELLED if before != SquadOrder.Kind.NONE else SquadOrders.Notice.NOBODY
	order_outcome.record(giver.id, now, notice)
	return now


## The squad order in force from the character `giver_id` (NONE: its bot teammates play the team plan).
func order_of(giver_id: int) -> SquadOrder.Kind:
	if giver_id < 0 or giver_id >= _given.size():
		return SquadOrder.Kind.NONE
	return _given[giver_id] as SquadOrder.Kind


## While the bot teammates of `giver_id` hold a spot it looked at, or go to one it pinged (Go there): true, with the middle of the held spots in
## held_middle. False for a hold where each stood (they may be far apart: no one spot to mark), and with no hold.
func hold_spot(giver_id: int) -> bool:
	var kind := order_of(giver_id)
	if (kind != SquadOrder.Kind.HOLD and kind != SquadOrder.Kind.MOVE) or _own_spot[giver_id] == 1:
		return false
	var giver := _character(giver_id)
	if giver == null:
		return false
	held_middle = SquadOrders.held_centre(_world.bots, giver)
	return SquadOrders.is_spot(held_middle)


## Go there (FM1) from `giver` to `spot` (a pinged floor spot; NO_SPOT for a ping at nothing) for its bot teammates in
## play, written into order_outcome: each its own spot side by side across the way from the giver to it, all looking on
## that way once there; once all are there it is a Hold here (move_arrivals). Given again within hold_move of the spot
## in force (Go there's or a looked-at Hold here's) it stays: a ping never cancels. Returns the order in force
## afterwards.
func give_move(giver: Character, spot: Vector3) -> SquadOrder.Kind:
	if giver == null or giver.id < 0 or giver.id >= _given.size():
		return SquadOrder.Kind.NONE
	if not Elimination.is_in_play(giver):
		_drop_order(giver)
		order_outcome.record(giver.id, SquadOrder.Kind.NONE, SquadOrders.Notice.NOT_NOW)
		return SquadOrder.Kind.NONE
	var before := order_of(giver.id)
	if not SquadOrders.is_spot(spot):
		order_outcome.record(giver.id, before, SquadOrders.Notice.NOWHERE)
		return before
	var w := _world
	var team := _order_team
	team.clear()
	for b in w.bots:
		if b.character != giver and b.character.team == giver.team and Elimination.is_in_play(b.character):
			team.append(b)
	if team.is_empty():
		_drop_order(giver)
		order_outcome.record(giver.id, SquadOrder.Kind.NONE,
				SquadOrders.Notice.CANCELLED if before != SquadOrder.Kind.NONE else SquadOrders.Notice.NOBODY)
		return SquadOrder.Kind.NONE
	if hold_spot(giver.id) and Vector2(spot.x - held_middle.x, spot.z - held_middle.z).length() < w.cfg.squad.hold_move:
		order_outcome.record(giver.id, before, SquadOrders.Notice.NONE)
		return before
	var yaw := SquadOrders.yaw_towards(giver.position, spot, giver.yaw)
	_sort_across(team, yaw)
	for b in w.bots:
		if b.order_giver == giver and not team.has(b):
			SquadOrders.end(b, w)
	for slot in team.size():
		SquadOrders.start(team[slot], giver, SquadOrder.Kind.MOVE, slot)
		team[slot].order_yaw = yaw
	SquadOrders.place_across(team, yaw, spot, w)
	_given[giver.id] = SquadOrder.Kind.MOVE
	_own_spot[giver.id] = 0
	order_outcome.record(giver.id, SquadOrder.Kind.MOVE, SquadOrders.Notice.NONE)
	return SquadOrder.Kind.MOVE


## Hands `kind` out to `giver`'s bot teammates in play; `toggle`: the order in force given again cancels it (see
## give_order). Returns the order in force afterwards.
func _hand_out(giver: Character, kind: SquadOrder.Kind, toggle: bool) -> SquadOrder.Kind:
	var w := _world
	var team := _order_team
	team.clear()
	for b in w.bots:
		if b.character != giver and b.character.team == giver.team and Elimination.is_in_play(b.character):
			team.append(b)
	if team.is_empty():
		_drop_order(giver)
		return SquadOrder.Kind.NONE
	var point := SquadOrders.hold_point(giver, w) if kind == SquadOrder.Kind.HOLD else SquadOrders.NO_SPOT
	var looked := SquadOrders.is_spot(point)
	if order_of(giver.id) == kind:
		var same := true
		if kind == SquadOrder.Kind.HOLD:
			var own := _own_spot[giver.id] == 1
			if looked:
				same = not own and hold_spot(giver.id) \
						and Vector2(point.x - held_middle.x, point.z - held_middle.z).length() < w.cfg.squad.hold_move
			else:
				same = own
		if same:
			if not toggle:
				return kind
			_drop_order(giver)
			return SquadOrder.Kind.NONE
	if kind == SquadOrder.Kind.HOLD:
		_sort_across(team, giver.yaw)
	for b in w.bots:
		if b.order_giver == giver and not team.has(b):
			SquadOrders.end(b, w)
	for slot in team.size():
		SquadOrders.start(team[slot], giver, kind, slot)
	if kind == SquadOrder.Kind.HOLD:
		SquadOrders.place_hold(team, giver, point, w)
	_given[giver.id] = kind
	_own_spot[giver.id] = 1 if kind == SquadOrder.Kind.HOLD and not looked else 0
	return kind


## Left to right across a view along `yaw`, so nobody crosses another's path to their spot (an insertion sort: a squad
## is a handful, and it allocates nothing).
static func _sort_across(team: Array[Bot], yaw: float) -> void:
	var right := Vector2(cos(yaw), -sin(yaw))
	for i in range(1, team.size()):
		var b := team[i]
		var key := Vector2(b.character.position.x, b.character.position.z).dot(right)
		var j := i - 1
		while j >= 0 and Vector2(team[j].character.position.x, team[j].character.position.z).dot(right) > key:
			team[j + 1] = team[j]
			j -= 1
		team[j + 1] = b


## Everyone given `giver`'s order goes back to the team plan.
func _drop_order(giver: Character) -> void:
	for b in _world.bots:
		if b.order_giver == giver:
			SquadOrders.end(b, _world)
	_given[giver.id] = SquadOrder.Kind.NONE
	_own_spot[giver.id] = 0


## After each step: an order ends for a bot that is out, and for everyone given it once its giver is out (hit, or the
## round over) or nobody carries it any more.
func update() -> void:
	for b in _world.bots:
		if b.order != SquadOrder.Kind.NONE and not Elimination.is_in_play(b.character):
			SquadOrders.end(b, _world)
	for id in _given.size():
		if _given[id] == SquadOrder.Kind.NONE:
			continue
		var giver := _character(id)
		if giver == null or not Elimination.is_in_play(giver):
			if giver != null:
				_drop_order(giver)
			_given[id] = SquadOrder.Kind.NONE
			_own_spot[id] = 0
			continue
		var carried := false
		for b in _world.bots:
			if b.order_giver == giver:
				carried = true
				break
		if not carried:
			_given[id] = SquadOrder.Kind.NONE
			_own_spot[id] = 0


## Before the bots think (as the browser game's updateOrders): each bot back within regroup_arrive of whoever gave it
## Regroup turns to Follow me, and the order reads Follow me once all have.
func regroup_arrivals() -> void:
	for id in _given.size():
		if _given[id] != SquadOrder.Kind.REGROUP:
			continue
		var regrouping := false
		for b in _world.bots:
			if b.order == SquadOrder.Kind.REGROUP and b.order_giver != null and b.order_giver.id == id \
					and not SquadOrders.regrouped(b, _world):
				regrouping = true
		if not regrouping:
			_given[id] = SquadOrder.Kind.FOLLOW


## Before the bots think, after regroup_arrivals: a Go there whose teammates all stand at their spots turns to Hold
## here (FM1), from the same spots, looking the same way.
func move_arrivals() -> void:
	for id in _given.size():
		if _given[id] != SquadOrder.Kind.MOVE:
			continue
		var moving := false
		for b in _world.bots:
			if b.order == SquadOrder.Kind.MOVE and b.order_giver != null and b.order_giver.id == id \
					and not SquadOrders.moved_in(b):
				moving = true
				break
		if moving:
			continue
		for b in _world.bots:
			if b.order == SquadOrder.Kind.MOVE and b.order_giver != null and b.order_giver.id == id:
				b.order = SquadOrder.Kind.HOLD
		_given[id] = SquadOrder.Kind.HOLD


## The character `id` of the field (a giver of orders), or null.
func _character(id: int) -> Character:
	for c in _world.characters:
		if c.id == id:
			return c
	return null
