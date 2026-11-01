class_name Grenades
extends RefCounted
## Smoke and flash bombs (SF1; DECISIONS 2026-10-29: basic ones in 0.1 Dev 2, thrown by bots too). A character's
## `PlayerCommand.throw_grenade` is one press: in play, in a live round (or on the range), not vaulting or already
## throwing, with one of that kind left and a slot free in GameState.grenades, the replica goes down (a reload or a draw
## under way stops, as a switch's do) and the pin comes out (GRENADE_PIN); GrenadeConfig.windup later the bomb leaves the
## eyes along the view, lofted, with a share of the thrower's own speed (GRENADE_THROW), and `recover` after that the
## replica is drawn again (a holstered one stays away; a torch that was on comes back on). Meanwhile the command's
## trigger, sights, reload, switch, selector and dial are let go (`throwing_command`). A hit drops the throw: the bomb
## is kept.
## A bomb can also be taken in hand first (MC1: the mouse wheel steps from the replicas onto the bombs left): the
## command's `ready_grenade` puts the replica down as a throw does and holds the bomb (Hand.readied) until a trigger pull
## throws it (`ready_command`), after which the replica comes back up as after any throw. A slot, the holster or a
## reload puts the bomb back and the armament does as asked.
## In the air a bomb falls and bounces off the level (GRENADE_BOUNCE), slides and rolls, and settles. A flash goes bang
## at its fuse (FLASH_BANG) and dazzles everyone in play with a clear line from the eyes to it, by distance and by how
## directly they look (DAZZLED; Character.dazzle_left), the thrower and its team too. A smoke pops at its fuse
## (SMOKE_POP) and smokes where it lies: an upright ellipsoid cloud that grows, holds and thins (`cloud_scale`,
## `cloud_density`), which BBs fly through and eyes don't (`smoke_depth`, BotSenses). Everyone carries
## GrenadeConfig.smoke_carried and flash_carried each round; on the range they come back after every throw.
## Allocates nothing per tick.

## The share of a bomb's radius it is lifted off the ground before the flash's lines to the eyes are cast (so a line
## grazing the floor it lies on is clear).
const BANG_LIFT := 2.0
## Lines and spans shorter than this are nothing.
const EPSILON := 1e-6
## A bomb this close (m) past its radius over the ground is on it, rolling.
const GROUND_PROBE := 0.02


## One character's bombs (Character.grenades): how many it carries and has left, and its throw under way.
class Hand:
	extends RefCounted
	## Carried each round (set by whoever starts the match) and left now.
	var carried_smoke: int = 0
	var carried_flash: int = 0
	var smoke: int = 0
	var flash: int = 0
	## The throw under way (NONE: none): seconds to the release (until it, `released` is false), then to the redraw.
	var throwing: Grenade.Kind = Grenade.Kind.NONE
	var windup_left: float = 0.0
	var recover_left: float = 0.0
	var released: bool = false
	## The replica was holstered, and its torch on, when the throw began: put back as they were after it.
	var was_holstered: bool = false
	var torch_was_on: bool = false
	## The bomb in hand waiting for a trigger pull (MC1; NONE: none), and the replica's holster and torch as they were
	## when it was taken (the throw puts them back so).
	var readied: Grenade.Kind = Grenade.Kind.NONE
	var ready_was_holstered: bool = false
	var ready_torch_was_on: bool = false
	## The trigger last tick while a bomb is in hand: a pull, not a held trigger, throws it.
	var trigger_was_down: bool = false

	## Left of `bomb` now.
	func left(bomb: Grenade.Kind) -> int:
		match bomb:
			Grenade.Kind.SMOKE:
				return smoke
			Grenade.Kind.FLASH:
				return flash
		return 0

	## Carries `smokes` and `flashes` each round from now on, and has them now.
	func carry(smokes: int, flashes: int) -> void:
		carried_smoke = maxi(0, smokes)
		carried_flash = maxi(0, flashes)
		refill()

	## Every carried bomb back, and no throw under way (a respawn; the range after a throw).
	func refill() -> void:
		smoke = carried_smoke
		flash = carried_flash
		stop()

	## No throw under way and no bomb in hand (a hit, a respawn).
	func stop() -> void:
		readied = Grenade.Kind.NONE
		throwing = Grenade.Kind.NONE
		windup_left = 0.0
		recover_left = 0.0
		released = false

	## One of `bomb` fewer.
	func spend(bomb: Grenade.Kind) -> void:
		if bomb == Grenade.Kind.SMOKE:
			smoke = maxi(0, smoke - 1)
		elif bomb == Grenade.Kind.FLASH:
			flash = maxi(0, flash - 1)


var cfg: GrenadeConfig = null
var _tuning: SimTuning = null
var _query: WorldQuery = null
var _hit: RayHit = RayHit.new()


func _init(tuning: SimTuning, world: WorldQuery) -> void:
	_tuning = tuning
	cfg = tuning.grenades
	_query = world


## The pool of bombs, made once with the state (GrenadeConfig.max_grenades).
static func make_pool(count: int) -> Array[Grenade]:
	var out: Array[Grenade] = []
	for i in maxi(0, count):
		out.append(Grenade.new())
	return out


## The command a character follows while it throws: `cmd` with its trigger, sights, reload, switch, holster, selector
## and dial let go, written into `out`.
static func throwing_command(cmd: PlayerCommand, out: PlayerCommand) -> PlayerCommand:
	out.copy_from(cmd)
	out.fire = false
	out.aim = false
	out.reload = false
	out.switch_to = -1
	out.holster = false
	out.cycle_fire_mode = false
	out.hop_up_steps = 0
	return out


## The command `c` (in play) follows for a bomb in hand this tick, before `press` (MC1). `cmd.ready_grenade` takes one
## of that kind in hand when `c` has one left and isn't throwing or vaulting: the replica goes down as for a throw
## (Armament.put_down). With one in hand, a slot, the holster or a reload (or none of that kind left) puts it back and
## `cmd` goes on as it came, for the armament to draw or holster; else a trigger pull throws it (throw_grenade, unless
## the command already throws one) and the trigger and sights are let go, written into `out`.
static func ready_command(c: Character, cmd: PlayerCommand, out: PlayerCommand) -> PlayerCommand:
	var hand := c.grenades
	var want := cmd.ready_grenade
	if want != Grenade.Kind.NONE and want != hand.readied and hand.throwing == Grenade.Kind.NONE \
			and not c.vault.active and hand.left(want) > 0:
		if hand.readied == Grenade.Kind.NONE:
			hand.ready_was_holstered = c.armament.holstered
			hand.ready_torch_was_on = c.torch_on
			c.armament.put_down()
		hand.readied = want
		# a trigger held as the bomb comes into hand doesn't throw it
		hand.trigger_was_down = cmd.fire
	if hand.readied == Grenade.Kind.NONE:
		return cmd
	if cmd.switch_to >= 0 or cmd.holster or cmd.reload or hand.left(hand.readied) <= 0:
		hand.readied = Grenade.Kind.NONE
		return cmd
	out.copy_from(cmd)
	var pull := cmd.fire and not hand.trigger_was_down
	hand.trigger_was_down = cmd.fire
	if pull and out.throw_grenade == Grenade.Kind.NONE:
		out.throw_grenade = hand.readied
	out.fire = false
	out.aim = false
	return out


## The bomb `c` holds in hand waiting for a trigger pull (MC1; NONE: none).
static func in_hand(c: Character) -> Grenade.Kind:
	return c.grenades.readied


## Whether `c` is throwing a bomb (from the pin to the redraw).
static func throwing(c: Character) -> bool:
	return c.grenades.throwing != Grenade.Kind.NONE


## The throw pressed in `cmd` for `c` (in play) this tick: started when `allowed` (a live round, or the range), it isn't
## vaulting or throwing, has one of that kind left and a slot of `pool` is free. True if a throw began.
func press(c: Character, cmd: PlayerCommand, allowed: bool, pool: Array[Grenade], events: SimEvents) -> bool:
	var bomb := cmd.throw_grenade
	var hand := c.grenades
	if bomb == Grenade.Kind.NONE or not allowed or c.vault.active or hand.throwing != Grenade.Kind.NONE \
			or hand.left(bomb) <= 0 or _free(pool) < 0:
		return false
	hand.throwing = bomb
	hand.windup_left = cfg.windup
	hand.recover_left = cfg.recover
	hand.released = false
	# A bomb taken in hand first: the replica was put down then, and comes back as it was then.
	var from_hand := hand.readied != Grenade.Kind.NONE
	hand.was_holstered = hand.ready_was_holstered if from_hand else c.armament.holstered
	hand.torch_was_on = hand.ready_torch_was_on if from_hand else c.torch_on
	hand.readied = Grenade.Kind.NONE
	c.armament.put_down()
	var e := events.add(GameEvent.Kind.GRENADE_PIN)
	e.actor = c.id
	e.value = bomb
	e.position = c.position
	return true


## The throw under way for `c` (in play) this tick, its eyes at `eye`: the release at the windup's end, the redraw at
## the recovery's.
func step_throw(c: Character, eye: Vector3, pool: Array[Grenade], events: SimEvents, dt: float) -> void:
	var hand := c.grenades
	if hand.throwing == Grenade.Kind.NONE:
		return
	if not hand.released:
		hand.windup_left -= dt
		if hand.windup_left > 0.0:
			return
		hand.released = true
		_release(c, eye, pool, events)
		return
	hand.recover_left -= dt
	if hand.recover_left > 0.0:
		return
	hand.stop()
	if not hand.was_holstered:
		c.armament.bring_up(c.id, events, cfg.redraw_scale)
		c.torch_on = hand.torch_was_on and c.armament.light_in_hand() != null


## Every bomb in `state` flies, bounces, pops or goes bang this tick, and every dazzle wears off. A throw by someone
## out of play (hit meanwhile) is dropped, the bomb kept.
func step(state: GameState, dt: float, kill_y: float) -> void:
	for c in state.characters:
		if c.dazzle_left > 0.0:
			c.dazzle_left = maxf(0.0, c.dazzle_left - dt)
		var busy := c.grenades.throwing != Grenade.Kind.NONE or c.grenades.readied != Grenade.Kind.NONE
		if busy and not Elimination.is_in_play(c):
			c.grenades.stop()
	for i in state.grenades.size():
		var g := state.grenades[i]
		if not g.active:
			continue
		g.prev_position = g.position
		g.age += dt
		if not g.resting:
			_fly(g, i, state.events, dt)
		if g.position.y < kill_y or (not g.popped and g.age > cfg.max_flight):
			g.active = false
			continue
		if g.popped:
			g.smoking += dt
			if g.smoking >= cfg.smoke_time:
				g.active = false
			continue
		if g.kind == Grenade.Kind.SMOKE and g.age >= cfg.smoke_fuse:
			g.popped = true
			var e := state.events.add(GameEvent.Kind.SMOKE_POP)
			e.actor = g.owner
			e.target = i
			e.position = g.position
		elif g.kind == Grenade.Kind.FLASH and g.age >= cfg.flash_fuse:
			g.active = false
			_bang(g, state)


## Every bomb gone at once (a new round).
static func clear(pool: Array[Grenade]) -> void:
	for g in pool:
		g.active = false


## How big smoke `g`'s cloud is now, as a share of its full size: growing over smoke_grow from the pop.
static func cloud_scale(g: Grenade, c: GrenadeConfig) -> float:
	if not g.popped or g.kind != Grenade.Kind.SMOKE:
		return 0.0
	return clampf(g.smoking / maxf(c.smoke_grow, EPSILON), 0.0, 1.0)


## How thick smoke `g`'s cloud is now (0..1): whole until its last smoke_fade, then thinning away.
static func cloud_density(g: Grenade, c: GrenadeConfig) -> float:
	if not g.popped or g.kind != Grenade.Kind.SMOKE:
		return 0.0
	return clampf((c.smoke_time - g.smoking) / maxf(c.smoke_fade, EPSILON), 0.0, 1.0)


## The middle of smoke `g`'s cloud now: over the canister, rising as it grows.
static func cloud_middle(g: Grenade, c: GrenadeConfig) -> Vector3:
	return g.position + Vector3(0.0, c.smoke_lift * cloud_scale(g, c), 0.0)


## How much smoke the line from `a` to `b` passes through (m, each cloud's length along the line times its density),
## counting no further once past `most`.
static func smoke_depth(pool: Array[Grenade], c: GrenadeConfig, a: Vector3, b: Vector3, most: float = INF) -> float:
	var d := b - a
	var length := d.length()
	if length < EPSILON:
		return 0.0
	var total := 0.0
	for g in pool:
		if not g.active or not g.popped or g.kind != Grenade.Kind.SMOKE:
			continue
		var size := cloud_scale(g, c)
		var density := cloud_density(g, c)
		var rx := c.smoke_radius * size
		var ry := c.smoke_height * size
		if rx < EPSILON or ry < EPSILON or density <= 0.0:
			continue
		var p := a - cloud_middle(g, c)
		# The line in the cloud's own space, where the cloud is the unit sphere.
		var ps := Vector3(p.x / rx, p.y / ry, p.z / rx)
		var ds := Vector3(d.x / rx, d.y / ry, d.z / rx)
		var qa := ds.dot(ds)
		var qb := 2.0 * ps.dot(ds)
		var qc := ps.dot(ps) - 1.0
		var disc := qb * qb - 4.0 * qa * qc
		if disc <= 0.0:
			continue
		var root := sqrt(disc)
		var t0 := maxf(0.0, (-qb - root) / (2.0 * qa))
		var t1 := minf(1.0, (-qb + root) / (2.0 * qa))
		if t1 <= t0:
			continue
		total += (t1 - t0) * length * density
		if total > most:
			return total
	return total


## How hard a bang at `at` dazzles someone with eyes at `eye` looking along `look` (unit), 0 (not at all) to 1: by
## distance (whole within flash_full, none past flash_reach) and by the view's angle to it (whole within flash_cone_deg,
## behind_share looking straight away). A clear line is the caller's to check.
static func dazzle_strength(eye: Vector3, look: Vector3, at: Vector3, c: GrenadeConfig) -> float:
	var to := at - eye
	var dist := to.length()
	if dist > c.flash_reach:
		return 0.0
	var near := 1.0
	if dist > c.flash_full:
		near = 1.0 - (dist - c.flash_full) / maxf(c.flash_reach - c.flash_full, EPSILON)
	var facing := 1.0
	if dist > EPSILON:
		var cosine := look.dot(to / dist)
		var cone := cos(deg_to_rad(c.flash_cone_deg))
		if cosine < cone:
			facing = lerpf(c.behind_share, 1.0, (cosine + 1.0) / maxf(cone + 1.0, EPSILON))
	return clampf(near * facing, 0.0, 1.0)


## The view pitch (rad) that throws a bomb from `eye`, standing still, to come down at `at` by the release's speed and
## loft: the low arc, or the high one with `high`; NAN where `at` is out of reach (or straight above or below). The
## bounce and roll after are left to the thrower (BotBombs aims short).
static func throw_pitch(eye: Vector3, at: Vector3, c: GrenadeConfig, high: bool = false) -> float:
	var d := Vector2(at.x - eye.x, at.z - eye.z).length()
	if d < EPSILON:
		return NAN
	var v2 := c.throw_speed * c.throw_speed
	var root := v2 * v2 - c.gravity * (c.gravity * d * d + 2.0 * (at.y - eye.y) * v2)
	if root < 0.0:
		return NAN
	var rise := (v2 + sqrt(root)) if high else (v2 - sqrt(root))
	return clampf(atan(rise / (c.gravity * d)) - c.loft, -PI * 0.5, PI * 0.5)


## Where a bomb thrown standing still from `eye` along view `yaw` and `pitch` is `t` s after the release, with no
## bounce yet.
static func arc_point(eye: Vector3, yaw: float, pitch: float, c: GrenadeConfig, t: float) -> Vector3:
	var lofted := clampf(pitch + c.loft, -PI * 0.5, PI * 0.5)
	var flat := cos(lofted) * c.throw_speed * t
	return eye + Vector3(-sin(yaw) * flat, sin(lofted) * c.throw_speed * t - 0.5 * c.gravity * t * t, -cos(yaw) * flat)


## How long a dazzle of `strength` (0..1) lasts (s): none under dazzle_least, else at least dazzle_min.
static func dazzle_time(strength: float, c: GrenadeConfig) -> float:
	if strength <= 0.0 or strength < c.dazzle_least:
		return 0.0
	return maxf(c.dazzle_min, strength * c.dazzle_max)


## The bomb leaves `c`'s hand: into a free slot from its eyes, or kept if every slot is taken meanwhile.
func _release(c: Character, eye: Vector3, pool: Array[Grenade], events: SimEvents) -> void:
	var slot := _free(pool)
	if slot < 0:
		return
	var g := pool[slot]
	var bomb := c.grenades.throwing
	var pitch := clampf(c.pitch + cfg.loft, -PI * 0.5, PI * 0.5)
	var flat := cos(pitch)
	var dir := Vector3(-sin(c.yaw) * flat, sin(pitch), -cos(c.yaw) * flat)
	var speed := dir * cfg.throw_speed + c.velocity * cfg.carry_share
	g.launch(bomb, c.id, eye, speed)
	c.grenades.spend(bomb)
	var e := events.add(GameEvent.Kind.GRENADE_THROW)
	e.actor = c.id
	e.target = slot
	e.value = bomb
	e.position = eye
	e.direction = speed


## One tick of `g`'s flight (slot `index`): falling, and bouncing off, sliding along or rolling on the level where it
## meets it, and settling. The line cast runs a radius past the move; one moved clear probes a radius down for the
## ground, so a bomb rolling on it touches it every tick.
func _fly(g: Grenade, index: int, events: SimEvents, dt: float) -> void:
	g.velocity.y -= cfg.gravity * dt
	var move := g.velocity * dt
	var length := move.length()
	if length < EPSILON:
		return
	var dir := move / length
	var met := _query.ray(g.position, g.position + dir * (length + cfg.radius), _hit)
	if not met:
		g.position += move
		met = g.velocity.y <= 0.0 \
				and _query.ray(g.position, g.position + Vector3.DOWN * (cfg.radius + GROUND_PROBE), _hit)
	if not met:
		return
	g.position = _hit.position + _hit.normal * cfg.radius
	var into := -g.velocity.dot(_hit.normal)
	if into > cfg.bounce_speed:
		_bounce(g, index, into, events)
	else:
		_roll(g, dt)


## `g` bounces off the surface in `_hit`, struck `into` m/s: GRENADE_BOUNCE.
func _bounce(g: Grenade, index: int, into: float, events: SimEvents) -> void:
	var normal_part := _hit.normal * g.velocity.dot(_hit.normal)
	g.velocity = (g.velocity - normal_part) * cfg.friction - normal_part * cfg.restitution
	var e := events.add(GameEvent.Kind.GRENADE_BOUNCE)
	e.actor = g.owner
	e.target = index
	e.value = g.kind
	e.value2 = _hit.surface
	e.position = g.position
	e.reach = into


## `g` slides along the surface in `_hit` (nothing into it): on ground no steeper than rest_slope it rolls, slowing,
## and settles.
func _roll(g: Grenade, dt: float) -> void:
	var n := _hit.normal
	g.velocity -= n * minf(0.0, g.velocity.dot(n))
	if n.y < cfg.rest_slope:
		return
	g.velocity *= exp(-cfg.roll_drag * dt)
	if g.velocity.length() < cfg.rest_speed:
		g.velocity = Vector3.ZERO
		g.resting = true


## Flash `g` goes bang: FLASH_BANG, then everyone in play it dazzles (a clear line from the eyes), each kept at the
## longer of its dazzle and this one.
func _bang(g: Grenade, state: GameState) -> void:
	var at := g.position + Vector3(0.0, cfg.radius * BANG_LIFT, 0.0)
	var bang := state.events.add(GameEvent.Kind.FLASH_BANG)
	bang.actor = g.owner
	bang.position = at
	for c in state.characters:
		if not Elimination.is_in_play(c):
			continue
		var eye := Lean.eye(c, _tuning.body, _tuning.hits)
		if eye.distance_to(at) > cfg.flash_reach or _query.ray(eye, at, _hit):
			continue
		var flat := cos(c.pitch)
		var look := Vector3(-sin(c.yaw) * flat, sin(c.pitch), -cos(c.yaw) * flat)
		var strength := dazzle_strength(eye, look, at, cfg)
		var seconds := dazzle_time(strength, cfg)
		if seconds <= 0.0:
			continue
		# A shorter dazzle than the one running changes nothing, so it makes no event (no second dip in the sound).
		if seconds <= c.dazzle_left:
			continue
		c.dazzle_left = seconds
		c.dazzle_total = seconds
		var e := state.events.add(GameEvent.Kind.DAZZLED)
		e.actor = g.owner
		e.target = c.id
		e.position = at
		e.value = roundi(strength * 100.0)
		e.reach = seconds


## The first free slot of `pool`, or -1.
static func _free(pool: Array[Grenade]) -> int:
	for i in pool.size():
		if not pool[i].active:
			return i
	return -1
