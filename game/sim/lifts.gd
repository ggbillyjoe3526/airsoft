class_name Lifts
extends RefCounted
## Lifts (MT2): a car in a shaft, stopping at each of its stops. A Use press at a landing's door calls the car there;
## inside the car, a press takes the panel's button nearest the view's line (LiftSpec.panel_button), each a stop. The
## car stands at a stop with its doors open; called elsewhere it waits LiftConfig.dwell after opening (panel_dwell once
## its own panel is pressed), shuts its doors (door_time: heard shut_lead before the leaves move), rides to the nearest
## called stop ahead of the way it last went (floor_time a stop), stopping on the way at any stop called meanwhile, and
## chimes and opens them; a stop pressed on its panel while they open shuts them again from where they stand (LS1).
## Its doors never shut on a body in the doorway from outside the car, nor with anyone hit aboard (they walk off), nor
## with more than `capacity` aboard (it buzzes); one aboard but still in the doorway steps in as they start to shut
## (step_in, LS1), and one walking into it from outside before it is sealed opens them again. Its riders rise and fall
## with its floor (carry). A doorway is a solid
## steel leaf to bombs, sight and bodies but while the car stands open at it, and to BBs where its two leaves stand at
## that tick while they shut or open (WorldQuery.set_lift_ajar, bb_ray). Each press, chime, door and ride is a LIFT
## event, heard out to LiftConfig.heard through walls. Each match and each round starts with every car at its start
## stop, open, nothing called. Pure rules on GameState.lifts; the level is told each move through
## WorldQuery.set_lift_car and set_lift_door. Allocates nothing a tick.

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
	lifts.sealed.resize(n)
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
		lifts.sealed[i] = 1
		_query.set_lift_car(i, lifts.y[i])
		_query.set_lift_ajar(i, -1, 0.0)
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
				_shutting(i, state, dt)
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
		# Its leaves as they stand, shutting or opening: a BB's path meets only them in the doorway (bb_ray).
		var ajar := lifts.phase[i] == LiftState.Phase.SHUTTING or lifts.phase[i] == LiftState.Phase.OPENING
		_query.set_lift_ajar(i, lifts.stop[i] if ajar else -1, lifts.doors[i])


## Carries `c` with the car it rides this tick (feet in it as it stood before this tick's rise): up or down by the
## car's rise, never under its floor. Before `c` moves.
func carry(c: Character, lifts: LiftState) -> void:
	c.lift_rise = 0.0
	for i in lifts.count():
		var rise := lifts.rise[i]
		if rise == 0.0 or not _query.lifts[i].holds(c.position, lifts.y[i] - rise, _cfg):
			continue
		var from := c.position.y
		c.position.y = maxf(from + rise, lifts.y[i] + _body.rest_gap)
		c.lift_rise = c.position.y - from
		return


## Eases `c` in, at LiftConfig.step_in_speed, while it stands in a car whose doors have begun to shut with it still in
## their doorway (LS1: a press from just inside the door shuts them at once, never later), until it stands clear of
## them by step_in_gap; the doorway is sealed to bodies once nobody is in it (_shutting). After carry, before `c`
## moves. Allocates nothing.
func step_in(c: Character, lifts: LiftState, dt: float) -> void:
	for i in lifts.count():
		if lifts.phase[i] != LiftState.Phase.SHUTTING or lifts.sealed[i] != 0:
			continue
		var spec := _query.lifts[i]
		if not spec.holds(c.position, lifts.y[i], _cfg):
			continue
		var need := _step_in_need(spec, lifts.stop[i], c.position)
		if need > 0.0:
			c.position -= Vector3(spec.out.x, 0.0, spec.out.y) * minf(need, _cfg.step_in_speed * dt)
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


## Whether anyone's body stands in lift `i`'s doorway at stop `k`, from either side.
func doorway_blocked(i: int, k: int, characters: Array[Character]) -> bool:
	var spec := _query.lifts[i]
	for ch in characters:
		if _in_doorway(spec, k, ch.position):
			return true
	return false


## The id of a body standing in lift `i`'s doorway at stop `k` from outside its car (on the landing, or in the wall's
## depth), whose doors then won't shut, or -1. One in the car is stepping in (step_in), not in the way.
func _blocked_from_outside(i: int, k: int, lifts: LiftState, characters: Array[Character]) -> int:
	var spec := _query.lifts[i]
	for ch in characters:
		if _in_doorway(spec, k, ch.position) and not spec.holds(ch.position, lifts.y[i], _cfg):
			return ch.id
	return -1


## Whether a body with feet at `p` overlaps lift `spec`'s doorway at stop `k` (its leaves' box, the wall's depth).
func _in_doorway(spec: LiftSpec, k: int, p: Vector3) -> bool:
	var c := spec.door_center(k)
	var h := spec.door_size() * 0.5
	if p.y >= c.y + h.y or p.y + _body.height <= c.y - h.y:
		return false
	var r := _body.radius
	var dx := p.x - clampf(p.x, c.x - h.x, c.x + h.x)
	var dz := p.z - clampf(p.z, c.z - h.z, c.z + h.z)
	return dx * dx + dz * dz < r * r


## How far (m) a body with feet at `p`, inside lift `spec`'s car, has to step in, away from the door's face, to stand
## step_in_gap clear of its doorway at stop `k`; 0 when it already stands clear.
func _step_in_need(spec: LiftSpec, k: int, p: Vector3) -> float:
	if not _in_doorway(spec, k, p):
		return 0.0
	var r := _body.radius
	var along := p.x if spec.along_x() else p.z
	var side := along - clampf(along, spec.door_from, spec.door_to)
	# How far in from the face the body is (positive in the car), and how far it must be for its edge to miss the box.
	var depth := (spec.face_at() - (p.z if spec.along_x() else p.x)) * (spec.out.y if spec.along_x() else spec.out.x)
	var clear := sqrt(maxf(0.0, r * r - side * side)) + _cfg.step_in_gap
	return maxf(0.0, clear - depth)


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
		# From inside, standing open: the doors shut now (LiftConfig.panel_dwell), not after the wait for walkers-out.
		if inside and lifts.phase[i] == LiftState.Phase.OPEN:
			lifts.left[i] = minf(lifts.left[i], _cfg.panel_dwell)
		# From inside, opening: they shut again from where they stand, heard on the press, as a press standing open
		# shuts them at once (docs/records/LS1.md). Not with anyone hit aboard, too many or anyone in the doorway from
		# outside: those keep it open anyway.
		elif inside and lifts.phase[i] == LiftState.Phase.OPENING and not _hit_aboard(i, lifts, state.characters) \
				and aboard(i, lifts, state.characters) <= _cfg.capacity \
				and _blocked_from_outside(i, lifts.stop[i], lifts, state.characters) < 0:
			_start_shut(i, state, _cfg.shut_lead + _cfg.shut_time() * lifts.doors[i])
		return
	match lifts.phase[i]:
		LiftState.Phase.OPEN:
			lifts.left[i] = maxf(lifts.left[i], _cfg.dwell)
		LiftState.Phase.SHUTTING:
			_reopen(i, k, state, c.id)


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
	if _blocked_from_outside(i, k, lifts, chars) >= 0 or _hit_aboard(i, lifts, chars):
		return
	var spec := _query.lifts[i]
	if aboard(i, lifts, chars) > _cfg.capacity:
		lifts.buzz_left[i] -= dt
		if lifts.buzz_left[i] <= 0.0:
			lifts.buzz_left[i] = _cfg.buzz_every
			_event(state, Cue.BUZZ, i, k, spec.door_center(k), lifts.caller[i], _cfg.heard, _through(spec))
		return
	lifts.buzz_left[i] = 0.0
	_start_shut(i, state, _cfg.door_time)


## Lift `i`'s doors start to shut at its stop, `left` seconds from shut (door_time from open; less from ajar), heard
## now: the leaves stand through the lead, then meet (_shutting). Its doorway is sealed at once if nobody is in it.
func _start_shut(i: int, state: GameState, left: float) -> void:
	var lifts := state.lifts
	var k := lifts.stop[i]
	var spec := _query.lifts[i]
	lifts.phase[i] = LiftState.Phase.SHUTTING
	lifts.left[i] = left
	lifts.sealed[i] = 0
	_event(state, Cue.SHUTTING, i, k, spec.door_center(k), lifts.caller[i], _cfg.heard, _through(spec))
	_seal(i, state)


## Lift `i` shutting a tick: its doorway sealed once nobody is in it (_seal); the leaves stand open through the
## sound's lead (LiftConfig.shut_lead), and past it while someone aboard is still stepping in, then meet in shut_time;
## shut, it sets off.
func _shutting(i: int, state: GameState, dt: float) -> void:
	var lifts := state.lifts
	if lifts.sealed[i] == 0 and not _seal(i, state):
		return
	var span := _cfg.shut_time()
	# While someone aboard still stands in the doorway the leaves hold where they stand, ready to meet from there (a shut
	# begun from ajar would otherwise wait out the whole shut_time with its leaves still: BP13).
	var least := 0.0 if lifts.sealed[i] != 0 else span * lifts.doors[i]
	lifts.left[i] = maxf(least, lifts.left[i] - dt)
	# Never further open than they stood: a shut begun from ajar keeps its leaves still through the lead.
	lifts.doors[i] = minf(lifts.doors[i], lifts.left[i] / span) if span > 0.0 else 0.0
	if lifts.left[i] <= 0.0:
		_depart(i, state)


## Lift `i`, shutting with its doorway open to bodies: a body in the doorway from outside the car opens the doors
## again (false: they open); nobody in it seals it, from then on solid to bodies as before (true: the shut goes on).
func _seal(i: int, state: GameState) -> bool:
	var lifts := state.lifts
	var k := lifts.stop[i]
	var outside := _blocked_from_outside(i, k, lifts, state.characters)
	if outside >= 0:
		_reopen(i, k, state, outside)
		return false
	if not doorway_blocked(i, k, state.characters):
		lifts.sealed[i] = 1
		_query.set_lift_door(i, k, true)
	return true


## Lift `i`'s doors, shutting at stop `k`, opened again from as far as they had shut (heard), its calls kept for after.
func _reopen(i: int, k: int, state: GameState, actor: int) -> void:
	var lifts := state.lifts
	var spec := _query.lifts[i]
	lifts.phase[i] = LiftState.Phase.OPENING
	lifts.left[i] = _cfg.door_time * (1.0 - lifts.doors[i])
	lifts.sealed[i] = 1
	_event(state, Cue.OPENING, i, k, spec.door_center(k), actor, _cfg.heard, _through(spec))


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
		_event(state, Cue.OPENING, i, lifts.stop[i], spec.door_center(lifts.stop[i]), lifts.caller[i], _cfg.heard,
				_through(spec))
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
	_event(state, Cue.ARRIVE, i, k, spec.door_center(k), lifts.caller[i], _cfg.heard, _through(spec))
	# Its doors are heard opening as they open, with the chime (they slid open silently before UL3).
	_event(state, Cue.OPENING, i, k, spec.door_center(k), lifts.caller[i], _cfg.heard, _through(spec))


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


## A doorway's cue `through` its depth: its middle to its face, so the sound plays from the face on the hearer's side
## and its own leaves never muffle it (SimAudio); none for a button's or the car's.
func _event(state: GameState, cue: Cue, i: int, k: int, at: Vector3, actor: int, reach: float,
		through: Vector3 = Vector3.ZERO) -> void:
	var e := state.events.add(GameEvent.Kind.LIFT)
	e.direction = through
	e.actor = actor
	e.target = i
	e.value = cue
	e.value2 = k
	e.position = at
	e.reach = reach


## From the middle of lift `spec`'s doorway to its face on the landing's side (half its depth, out).
static func _through(spec: LiftSpec) -> Vector3:
	return Vector3(spec.out.x, 0.0, spec.out.y) * (spec.door_depth * 0.5)
