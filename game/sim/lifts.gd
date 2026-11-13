class_name Lifts
extends RefCounted
## Lifts (MT2): a car in a shaft, stopping at each of its stops. A Use press at a landing's door calls the car there;
## inside the car, a press takes the panel's button nearest the view's line (LiftSpec.panel_button), each a stop. The
## car stands at a stop with its doors open; called elsewhere it waits LiftConfig.dwell after opening, shuts its doors
## (door_time), rides to the nearest called stop ahead of the way it last went (floor_time a stop), stopping on the way
## at any stop called meanwhile, and opens them. Its doors never shut on a body in the doorway, nor with anyone hit
## aboard (they walk off), nor with more than `capacity` aboard (it buzzes). Its riders rise and fall with its floor
## (carry). A doorway is a solid steel leaf to BBs, bombs, sight and bodies but while the car stands open at it. Each
## press, chime, door and ride is a LIFT event, heard out to LiftConfig.heard through walls. Each match and each round
## starts with every car at its start stop, open, nothing called. Pure rules on GameState.lifts; the level is told each
## move through WorldQuery.set_lift_car and set_lift_door. Allocates nothing a tick.

## What a LIFT event says (its value).
enum Cue { BUTTON, OPENING, SHUTTING, DEPART, ARRIVE, BUZZ }

## No lift button: pick's answer for none.
const NONE := Vector2i(-1, -1)
## A car this close (m) to a stop's height stands at it.
const AT_STOP := 1e-4

var _cfg: LiftConfig = null
var _body: BodyConfig = null
var _hits: HitConfig = null
var _query: WorldQuery = null


func _init(tuning: SimTuning, world: WorldQuery) -> void:
	_cfg = tuning.lifts
	_body = tuning.body
	_hits = tuning.hits
	_query = world


## How many lifts the level has.
func count() -> int:
	return _query.lift_count()


## Every car at its start stop, doors open, nothing called, the level told; sizes `lifts` to the level's.
func reset(lifts: LiftState) -> void:
	var n := _query.lift_count()
	lifts.y.resize(n)
	lifts.prev_y.resize(n)
	lifts.rise.resize(n)
	lifts.stop.resize(n)
	lifts.to.resize(n)
	lifts.phase.resize(n)
	lifts.left.resize(n)
	lifts.doors.resize(n)
	lifts.calls.resize(n)
	lifts.heading.resize(n)
	lifts.buzz_left.resize(n)
	lifts.caller.resize(n)
	for i in n:
		var spec := _query.lifts[i]
		var k := clampi(spec.start, 0, spec.stop_count() - 1)
		lifts.y[i] = spec.stops[k]
		lifts.prev_y[i] = spec.stops[k]
		lifts.rise[i] = 0.0
		lifts.stop[i] = k
		lifts.to[i] = -1
		lifts.phase[i] = LiftState.Phase.OPEN
		lifts.left[i] = 0.0
		lifts.doors[i] = 1.0
		lifts.calls[i] = 0
		lifts.heading[i] = 0
		lifts.buzz_left[i] = 0.0
		lifts.caller[i] = -1
		_query.set_lift_car(i, lifts.y[i])
		for s in spec.stop_count():
			_query.set_lift_door(i, s, s != k)


## A tick of every car, before anyone moves: doors, rides and arrivals, each car's `rise` for its riders (carry).
func step(state: GameState, dt: float) -> void:
	var lifts := state.lifts
	for i in lifts.count():
		lifts.prev_y[i] = lifts.y[i]
		lifts.rise[i] = 0.0
		match lifts.phase[i]:
			LiftState.Phase.OPEN:
				_wait_open(i, state, dt)
			LiftState.Phase.SHUTTING:
				lifts.left[i] = maxf(0.0, lifts.left[i] - dt)
				lifts.doors[i] = lifts.left[i] / _cfg.door_time
				if lifts.left[i] <= 0.0:
					_depart(i, state)
			LiftState.Phase.MOVING:
				_ride(i, state, dt)
			LiftState.Phase.OPENING:
				lifts.left[i] = maxf(0.0, lifts.left[i] - dt)
				lifts.doors[i] = 1.0 - lifts.left[i] / _cfg.door_time
				if lifts.left[i] <= 0.0:
					lifts.phase[i] = LiftState.Phase.OPEN
					lifts.doors[i] = 1.0
					lifts.left[i] = _cfg.dwell
					_query.set_lift_door(i, lifts.stop[i], false)


## Carries `c` with the car it rides this tick (feet in it as it stood before this tick's rise): up or down by the
## car's rise, never under its floor. Before `c` moves.
func carry(c: Character, lifts: LiftState) -> void:
	for i in lifts.count():
		var rise := lifts.rise[i]
		if rise == 0.0 or not _query.lifts[i].holds(c.position, lifts.y[i] - rise, _cfg):
			continue
		c.position.y = maxf(c.position.y + rise, lifts.y[i] + _body.rest_gap)
		return


## `c`'s Use press: the button its controller picked (`cmd.lift_to_use`, `cmd.lift_stop`) if it can press it, else the
## one its view picks (pick). Whether it pressed a lift's button (the press is then nobody's door's).
func press(c: Character, cmd: PlayerCommand, state: GameState) -> bool:
	var lifts := state.lifts
	var at := Vector2i(cmd.lift_to_use, cmd.lift_stop)
	if not can_press(_query, _cfg, lifts, c.position, at):
		at = pick(_query, _cfg, lifts, c.position, Lean.eye(c, _body, _hits), c.yaw, c.pitch)
	if at == NONE:
		return false
	_press_button(at.x, at.y, c, state)
	return true


## The lift button a body with feet at `feet` and eyes at `eye`, looking along `yaw` and `pitch`, would press: in a car,
## the panel's button nearest the view's line; on a landing, the call button of the doorway in reach (LiftConfig.reach
## level, reach_up of its floor, outside it) nearest the view's line. (lift, stop), or NONE.
static func pick(query: WorldQuery, cfg: LiftConfig, lifts: LiftState, feet: Vector3, eye: Vector3, yaw: float,
		pitch: float) -> Vector2i:
	if lifts.count() != query.lift_count():
		return NONE
	var flat := cos(pitch)
	var look := Vector3(-sin(yaw) * flat, sin(pitch), -cos(yaw) * flat)
	var i := riding(query, cfg, lifts, feet)
	if i >= 0:
		var spec := query.lifts[i]
		var best := 0
		var best_dot := -INF
		for k in spec.stop_count():
			var to := spec.panel_button(k, lifts.y[i], cfg) - eye
			var dot := look.dot(to.normalized()) if to.length_squared() > 0.0 else 1.0
			if dot > best_dot:
				best = k
				best_dot = dot
		return Vector2i(i, best)
	var found := NONE
	var found_dot := -INF
	var level := Vector2(look.x, look.z)
	for l in query.lift_count():
		var spec := query.lifts[l]
		for k in spec.stop_count():
			var to := _to_doorway(spec, cfg, feet, k)
			if to == Vector2.INF:
				continue
			var d := to.length()
			var dot := level.normalized().dot(to / d) if d > 1e-4 and level.length_squared() > 0.0 else 1.0
			if dot > found_dot:
				found = Vector2i(l, k)
				found_dot = dot
	return found


## Whether feet at `feet` can press button `at` (lift, stop): its panel from inside its car, its call button from that
## stop's landing in reach.
static func can_press(query: WorldQuery, cfg: LiftConfig, lifts: LiftState, feet: Vector3, at: Vector2i) -> bool:
	if at.x < 0 or at.x >= query.lift_count() or at.x >= lifts.count() or at.y < 0 \
			or at.y >= query.lifts[at.x].stop_count():
		return false
	var spec := query.lifts[at.x]
	if spec.holds(feet, lifts.y[at.x], cfg):
		return true
	return riding(query, cfg, lifts, feet) < 0 and _to_doorway(spec, cfg, feet, at.y) != Vector2.INF


## The lift whose car feet at `feet` stand in, or -1.
static func riding(query: WorldQuery, cfg: LiftConfig, lifts: LiftState, feet: Vector3) -> int:
	for i in mini(query.lift_count(), lifts.count()):
		if query.lifts[i].holds(feet, lifts.y[i], cfg):
			return i
	return -1


## Plant The Bomb (PB1): keeps a carried bomb's resting place (PlantState.rest) off the cars. While its carrier `c`
## stands in a car, a hit would leave the bomb on the landing of the stop the car stands at or last stood at, never in
## the car or the shaft. Each tick before the round's rules, with `c` null when nobody carries it.
func bomb_rest(ps: PlantState, c: Character, lifts: LiftState) -> void:
	ps.on_lift = false
	if c == null:
		return
	var i := riding(_query, _cfg, lifts, c.position)
	if i < 0:
		return
	ps.on_lift = true
	ps.rest = _query.lifts[i].landing_point(lifts.stop[i], _cfg)


## Whether `c` stands in a car whose doors aren't open (shutting, riding or opening): nobody walks out of it yet.
func shut_in(c: Character, lifts: LiftState) -> bool:
	var i := riding(_query, _cfg, lifts, c.position)
	return i >= 0 and lifts.phase[i] != LiftState.Phase.OPEN


## How many stand in lift `i`'s car (in play or not).
func aboard(i: int, lifts: LiftState, characters: Array[Character]) -> int:
	var spec := _query.lifts[i]
	var n := 0
	for c in characters:
		if spec.holds(c.position, lifts.y[i], _cfg):
			n += 1
	return n


## Whether anyone's body stands in lift `i`'s doorway at stop `k`: its doors won't shut.
func doorway_blocked(i: int, k: int, characters: Array[Character]) -> bool:
	var spec := _query.lifts[i]
	var c := spec.door_center(k)
	var h := spec.door_size() * 0.5
	var r := _body.radius
	for ch in characters:
		var p := ch.position
		if p.y >= c.y + h.y or p.y + _body.height <= c.y - h.y:
			continue
		var dx := p.x - clampf(p.x, c.x - h.x, c.x + h.x)
		var dz := p.z - clampf(p.z, c.z - h.z, c.z + h.z)
		if dx * dx + dz * dz < r * r:
			return true
	return false


## From feet at `feet` to the middle of lift `spec`'s doorway at stop `k` on its landing side, level; Vector2.INF out of
## reach (LiftConfig.reach level, reach_up of the stop's floor) or not on the landing's side of the door's face.
static func _to_doorway(spec: LiftSpec, cfg: LiftConfig, feet: Vector3, k: int) -> Vector2:
	if absf(feet.y - spec.stops[k]) > cfg.reach_up:
		return Vector2.INF
	var mid := spec.on_face((spec.door_from + spec.door_to) * 0.5, spec.door_depth, spec.stops[k])
	var to := Vector2(mid.x - feet.x, mid.z - feet.z)
	# Outside the shaft: the door's face lies ahead of the feet looking in (to against out).
	if to.dot(spec.out) > 0.0 or to.length() > cfg.reach:
		return Vector2.INF
	return to


## Button `k` of lift `i` pressed by `c`: its stop called, or the doors held or opened again where the car stands.
func _press_button(i: int, k: int, c: Character, state: GameState) -> void:
	var lifts := state.lifts
	var spec := _query.lifts[i]
	lifts.caller[i] = c.id
	var inside := spec.holds(c.position, lifts.y[i], _cfg)
	_event(state, Cue.BUTTON, i, k, spec.panel_button(k, lifts.y[i], _cfg) if inside else spec.call_button(k, _cfg),
			c.id, _cfg.button_heard)
	var here := lifts.stop[i] == k and lifts.phase[i] != LiftState.Phase.MOVING
	if not here:
		lifts.calls[i] |= 1 << k
		return
	match lifts.phase[i]:
		LiftState.Phase.OPEN:
			lifts.left[i] = maxf(lifts.left[i], _cfg.dwell)
		LiftState.Phase.SHUTTING:
			# Opened again from as far as they had shut, the stop's call kept for after.
			lifts.phase[i] = LiftState.Phase.OPENING
			lifts.left[i] = _cfg.door_time * (1.0 - lifts.doors[i])
			_event(state, Cue.OPENING, i, k, spec.door_center(k), c.id, _cfg.heard)


## Lift `i` standing open: once its wait is over, with a stop called elsewhere, it shuts its doors, unless a body
## stands in its doorway, anyone hit is aboard (they walk off first) or it is too full (it buzzes).
func _wait_open(i: int, state: GameState, dt: float) -> void:
	var lifts := state.lifts
	var k := lifts.stop[i]
	lifts.calls[i] &= ~(1 << k)
	lifts.left[i] = maxf(0.0, lifts.left[i] - dt)
	if lifts.calls[i] == 0 or lifts.left[i] > 0.0:
		lifts.buzz_left[i] = 0.0
		return
	var chars := state.characters
	if doorway_blocked(i, k, chars) or _hit_aboard(i, lifts, chars):
		return
	var spec := _query.lifts[i]
	if aboard(i, lifts, chars) > _cfg.capacity:
		lifts.buzz_left[i] -= dt
		if lifts.buzz_left[i] <= 0.0:
			lifts.buzz_left[i] = _cfg.buzz_every
			_event(state, Cue.BUZZ, i, k, spec.door_center(k), lifts.caller[i], _cfg.heard)
		return
	lifts.buzz_left[i] = 0.0
	lifts.phase[i] = LiftState.Phase.SHUTTING
	lifts.left[i] = _cfg.door_time
	_query.set_lift_door(i, k, true)
	_event(state, Cue.SHUTTING, i, k, spec.door_center(k), lifts.caller[i], _cfg.heard)


## Whether anyone out of play stands in lift `i`'s car.
func _hit_aboard(i: int, lifts: LiftState, characters: Array[Character]) -> bool:
	var spec := _query.lifts[i]
	for c in characters:
		if not Elimination.is_in_play(c) and spec.holds(c.position, lifts.y[i], _cfg):
			return true
	return false


## Lift `i`'s doors shut: it rides to the stop called next, or opens again with none.
func _depart(i: int, state: GameState) -> void:
	var lifts := state.lifts
	lifts.doors[i] = 0.0
	var spec := _query.lifts[i]
	var t := _next_stop(i, lifts)
	if t < 0:
		lifts.phase[i] = LiftState.Phase.OPENING
		lifts.left[i] = _cfg.door_time
		_event(state, Cue.OPENING, i, lifts.stop[i], spec.door_center(lifts.stop[i]), lifts.caller[i], _cfg.heard)
		return
	lifts.phase[i] = LiftState.Phase.MOVING
	lifts.to[i] = t
	lifts.heading[i] = 1 if spec.stops[t] > lifts.y[i] else -1
	_event(state, Cue.DEPART, i, lifts.stop[i], spec.car_point(lifts.y[i]), lifts.caller[i], _cfg.heard)


## Lift `i` riding a tick towards its stop (or one called meanwhile on the way), at its stretch's pace: floor_time
## from one stop to the next. At the stop it chimes and opens.
func _ride(i: int, state: GameState, dt: float) -> void:
	var lifts := state.lifts
	var spec := _query.lifts[i]
	var t := _next_stop(i, lifts)
	if t >= 0:
		lifts.to[i] = t
	var goal := spec.stops[lifts.to[i]]
	var y := lifts.y[i]
	var moved := move_toward(y, goal, _pace(spec, y, lifts.heading[i]) * dt)
	if absf(moved - goal) < AT_STOP:
		moved = goal
	lifts.y[i] = moved
	lifts.rise[i] = moved - y
	_query.set_lift_car(i, moved)
	if moved != goal:
		return
	var k := lifts.to[i]
	lifts.stop[i] = k
	lifts.to[i] = -1
	lifts.calls[i] &= ~(1 << k)
	lifts.phase[i] = LiftState.Phase.OPENING
	lifts.left[i] = _cfg.door_time
	_event(state, Cue.ARRIVE, i, k, spec.door_center(k), lifts.caller[i], _cfg.heard)


## The speed (m/s) of a car at `y` heading `heading` (1 up, -1 down): its stretch between two stops in floor_time.
func _pace(spec: LiftSpec, y: float, heading: int) -> float:
	var n := spec.stop_count()
	for k in n - 1:
		var lo := spec.stops[k]
		var hi := spec.stops[k + 1]
		# The stretch the car is in, or about to enter from a stop at its end the way it heads.
		if (y > lo and y < hi) or (heading > 0 and y == lo) or (heading < 0 and y == hi):
			return (hi - lo) / _cfg.floor_time
	return absf(spec.stops[n - 1] - spec.stops[0]) / maxf(1.0, n - 1.0) / _cfg.floor_time


## The called stop lift `i` makes for next: the nearest ahead of the way it heads, else the nearest either way; -1 with
## none called. A stop it stands at (or has just left) is never next.
func _next_stop(i: int, lifts: LiftState) -> int:
	var calls := lifts.calls[i]
	if calls == 0:
		return -1
	var spec := _query.lifts[i]
	var y := lifts.y[i]
	var h := lifts.heading[i]
	var best := -1
	var best_d := INF
	var any := -1
	var any_d := INF
	for k in spec.stop_count():
		if (calls >> k) & 1 == 0:
			continue
		var d := spec.stops[k] - y
		if absf(d) < AT_STOP:
			continue
		if absf(d) < any_d:
			any = k
			any_d = absf(d)
		if h != 0 and d * h > 0.0 and absf(d) < best_d:
			best = k
			best_d = absf(d)
	return best if best >= 0 else any


func _event(state: GameState, cue: Cue, i: int, k: int, at: Vector3, actor: int, reach: float) -> void:
	var e := state.events.add(GameEvent.Kind.LIFT)
	e.actor = actor
	e.target = i
	e.value = cue
	e.value2 = k
	e.position = at
	e.reach = reach
