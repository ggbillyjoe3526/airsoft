class_name BotLifts
## A bot riding a lift (MT2): its route's lift leg (NavLifts) from one landing to another, walked as a player would. On
## the landing it waits for the car, calling it (the call button, once: Lifts keeps the call) or opening its shutting
## doors again; with the car open there and room aboard it walks in, to its own spot in the car; aboard, it presses
## its stop's button (once) and stands while the car rides; open at its stop, it walks out to the landing, where the
## leg ends. One too many aboard (the buzzer), the highest ids step back out and wait. Waiting on the landing longer
## than BotConfig.lift_patience it gives up: a fresh route on foot (no links for vault_retry_delay). Aboard a car on a
## leg on foot (a route planned again inside it), it waits for the doors before walking out. Writes b.move_dir (zero:
## stand) and b.lift_press; never stuck while it waits. Allocates nothing.

## Bots aboard stand this far (m) from the car's middle, each at its own angle by id, so they don't crowd one spot.
const SPREAD := 0.45
## Close enough (m, level) to a spot to stand still on it.
const ON_SPOT := 0.2
## The turn (radians) from one id's spot to the next: the golden angle, so any few ids stand well apart.
const SPOT_TURN := 2.399963


## Walks `b`'s lift leg (link `link` of the grid's): writes b.move_dir and b.lift_press. True while on its route;
## false once it gives up (its route wanted again).
static func ride(b: Bot, w: BotWorld, link: int, dt: float) -> bool:
	var nav := w.nav
	var i := nav.lift_of[link]
	var from := nav.lift_stop_from[link]
	var to := nav.lift_stop_to[link]
	var spec := w.query.lifts[i]
	var lifts := w.lifts
	var cfg := w.tuning.lifts
	var me := b.character
	var p := me.position
	b.lift_press = Lifts.NONE
	b.stuck_for = 0.0
	if spec.holds(p, lifts.y[i], cfg):
		b.lift_wait = 0.0
		if lifts.open_at(i, to):
			_walk_to(b, spec.landing_point(to, cfg))
			return true
		if lifts.open_at(i, from) and _over(w, i, spec, me):
			_walk_to(b, spec.landing_point(from, cfg))
			return true
		if not lifts.called(i, to) and not (lifts.stop[i] == to and lifts.phase[i] != LiftState.Phase.MOVING):
			b.lift_press = Vector2i(i, to)
		_walk_to(b, _spot(b, spec, lifts.y[i]))
		return true
	# Out on the far landing: the leg's end is a step away.
	if absf(p.y - spec.stops[to]) < cfg.reach_up:
		_walk_to(b, spec.landing_point(to, cfg))
		return true
	b.lift_wait += dt
	if b.lift_wait > w.cfg.lift_patience:
		b.lift_wait = 0.0
		b.vaults_off_until = w.time + w.cfg.vault_retry_delay
		b.route_state = Bot.RouteState.WANTED
		return false
	var at := Vector2i(i, from)
	if lifts.open_at(i, from) and _room_aboard(w, i, spec):
		_walk_to(b, _spot(b, spec, lifts.y[i]))
		return true
	var reopen := lifts.stop[i] == from and lifts.phase[i] == LiftState.Phase.SHUTTING
	var coming := lifts.called(i, from) or (lifts.stop[i] == from and lifts.phase[i] == LiftState.Phase.OPENING)
	if (reopen or not coming) and Lifts.can_press(w.query, cfg, lifts, p, at):
		b.lift_press = at
	_walk_to(b, spec.landing_point(from, cfg))
	return true


## Aboard a car on a leg on foot: false (walk on) once the car stands open; else true, standing (b.move_dir zero).
static func hold_aboard(b: Bot, w: BotWorld) -> bool:
	if w.lifts == null:
		return false
	var i := Lifts.riding(w.query, w.tuning.lifts, w.lifts, b.character.position)
	if i < 0 or w.lifts.phase[i] == LiftState.Phase.OPEN:
		return false
	b.move_dir = Vector3.ZERO
	b.stuck_for = 0.0
	return true


## Whether lift `i`'s car has room for one more (LiftConfig.capacity).
static func _room_aboard(w: BotWorld, i: int, spec: LiftSpec) -> bool:
	var n := 0
	for c in w.characters:
		if spec.holds(c.position, w.lifts.y[i], w.tuning.lifts):
			n += 1
	return n < w.tuning.lifts.capacity


## Whether `me` is one too many aboard lift `i`'s car (over LiftConfig.capacity, so it buzzes and won't go): the
## highest ids aboard step out, as many as are over, so the rest can ride.
static func _over(w: BotWorld, i: int, spec: LiftSpec, me: Character) -> bool:
	var n := 0
	var above := 0
	for c in w.characters:
		if spec.holds(c.position, w.lifts.y[i], w.tuning.lifts):
			n += 1
			if c.id > me.id:
				above += 1
	return above < n - w.tuning.lifts.capacity


## `b`'s own spot in the car with its floor at `y`: SPREAD from the middle at an angle of its id's.
static func _spot(b: Bot, spec: LiftSpec, y: float) -> Vector3:
	var angle := b.character.id * SPOT_TURN
	return spec.car_point(y) + Vector3(cos(angle), 0.0, sin(angle)) * SPREAD


## Straight at `at` (level), or stand once on it.
static func _walk_to(b: Bot, at: Vector3) -> void:
	var p := b.character.position
	var flat := Vector2(at.x - p.x, at.z - p.z)
	var d := flat.length()
	b.move_dir = Vector3(flat.x / d, 0.0, flat.y / d) if d > ON_SPOT else Vector3.ZERO
