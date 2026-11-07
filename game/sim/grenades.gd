class_name Grenades
extends RefCounted
## Smoke and flash bombs (SF1; DECISIONS 2026-10-29: basic ones in 0.1 Dev 2, thrown by bots too). A character's
## `PlayerCommand.throw_grenade` is one press: in play, in a live round (or on the range), not vaulting or already
## throwing, with one of that kind left and a slot free in GameState.grenades, the replica goes down (a reload or a draw
## under way stops, as a switch's do) and the pin comes out (GRENADE_PIN); GrenadeConfig.windup later the bomb leaves the
## throwing hand (GrenadeConfig.release_offset, never from inside a wall) along the view, lofted, with a share of the thrower's own speed (GRENADE_THROW), and `recover` after that the
## replica is drawn again (a holstered one stays away; a torch that was on comes back on). Meanwhile the command's
## trigger, sights, reload, switch, selector and dial are let go (`throwing_command`). A hit drops the throw: the bomb
## is kept.
## A bomb can also be taken in hand first (MC1: the mouse wheel steps from the replicas onto the bombs left): the
## command's `ready_grenade` puts the replica down as a throw does and holds the bomb (Hand.readied) until a trigger pull
## throws it (`ready_command`), after which the replica comes back up as after any throw. A slot, the holster or a
## reload puts the bomb back and the armament does as asked.
## In the air a bomb falls and bounces off the level and off the bodies of those in play (GRENADE_BOUNCE; a body's
## surface is NONE; it hits nobody and never rests on one), slides and rolls, and settles. A flash goes bang
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
	## The trigger pull that threw a bomb in hand, or put it back, is still held (BP5): the replica that comes back up
	## doesn't fire until the trigger is let go (`trigger_command`).
	var trigger_held_off: bool = false
	## The torch was on before the throw or the bomb in hand, and the replica is back up this tick: Torch.step puts it
	## back on (BP5: a bomb put back by a slot, the holster or a reload left it off).
	var torch_back: bool = false

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

	## Every carried bomb back, and no throw under way (a respawn).
	func refill() -> void:
		restock()
		stop()

	## Every carried bomb back, leaving a bomb in hand where it is (the range, every tick there's no throw under way:
	## refill's stop dropped a bomb taken in hand on the tick it was taken, BP2).
	func restock() -> void:
		smoke = carried_smoke
		flash = carried_flash

	## No throw under way and no bomb in hand (a hit, a respawn): nothing held off and no torch to take back either.
	func stop() -> void:
		end_throw()
		trigger_held_off = false
		torch_back = false

	## No throw under way and no bomb in hand, the pull that threw it still let go (a throw's end).
	func end_throw() -> void:
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
## A character's collision body, widened by the bomb's radius (`_body_hit`; used only within one call).
var _body: Hitbox.Capsule = Hitbox.Capsule.new()


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
	out.zoom_steps = 0
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
		# the trigger is let go from here while it stays held (trigger_command)
		hand.trigger_held_off = true
		hand.torch_back = hand.ready_torch_was_on
		return cmd
	out.copy_from(cmd)
	var pull := cmd.fire and not hand.trigger_was_down
	hand.trigger_was_down = cmd.fire
	if pull and out.throw_grenade == Grenade.Kind.NONE:
		out.throw_grenade = hand.readied
	if out.throw_grenade != Grenade.Kind.NONE:
		hand.trigger_held_off = true
	out.fire = false
	out.aim = false
	return out


## The command `c` follows after ready_command and the bomb's press: while it throws, throwing_command's; once a bomb
## in hand is thrown or put back, while the pull that did it is still held, `cmd` with the trigger let go (BP5), so a
## replica on full auto doesn't fire on its own the moment it is back up, nor a semi read the held pull as a fresh one.
## `pulled` is the trigger as the controller pulls it (before a vault holds it): letting go ends it, during the throw
## too. Written into `out`.
static func trigger_command(c: Character, cmd: PlayerCommand, pulled: bool, out: PlayerCommand) -> PlayerCommand:
	var hand := c.grenades
	if not pulled:
		hand.trigger_held_off = false
	if throwing(c):
		return throwing_command(cmd, out)
	if not hand.trigger_held_off or hand.readied != Grenade.Kind.NONE:
		return cmd
	if out != cmd:
		out.copy_from(cmd)
	out.fire = false
	return out


## Whether `c`'s torch goes back on this tick (after a throw or a bomb put back), once: Torch.step lights it.
static func take_torch_back(c: Character) -> bool:
	var back := c.grenades.torch_back
	c.grenades.torch_back = false
	return back


## The bomb `c` holds in hand waiting for a trigger pull (MC1; NONE: none). The bomb drawn in hand, the pin pull's too,
## is `held`.
static func in_hand(c: Character) -> Grenade.Kind:
	return c.grenades.readied


## The bomb shown in `c`'s hand (NONE: none, or `c` null): while its pin comes out, or while it waits in hand for a
## trigger pull (MC1) in play. Your arms hold it then (GrenadeView), and the replica's let go (ReplicaView).
static func held(c: Character) -> Grenade.Kind:
	var hand := c.grenades if c != null else null
	if hand == null:
		return Grenade.Kind.NONE
	if hand.throwing != Grenade.Kind.NONE and not hand.released:
		return hand.throwing
	if hand.readied != Grenade.Kind.NONE and Elimination.is_in_play(c):
		return hand.readied
	return Grenade.Kind.NONE


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
	# the pull that threw it may still be held: it stays let go after the throw too (trigger_command)
	hand.end_throw()
	if not hand.was_holstered:
		c.armament.bring_up(c.id, events, cfg.redraw_scale)
		hand.torch_back = hand.torch_was_on


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
			_fly(g, i, state.characters, state.events, dt)
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


## Where the throwing hand of someone with eyes at `eye` looking along `yaw` lets a bomb go: release_offset right, up
## and ahead of the eyes on the level (whatever the pitch, so a bot can aim from it before it picks one).
static func hand_point(eye: Vector3, yaw: float, c: GrenadeConfig) -> Vector3:
	var o := c.release_offset
	var s := sin(yaw)
	var co := cos(yaw)
	return eye + Vector3(co * o.x - s * o.z, o.y, -s * o.x - co * o.z)


## hand_point, or with the level (through `query`, into `hit`) between the eyes and there, a bomb's radius short of it
## along that line, so a bomb never starts inside a wall.
static func release_from(eye: Vector3, yaw: float, c: GrenadeConfig, query: WorldQuery, hit: RayHit) -> Vector3:
	var hand := hand_point(eye, yaw, c)
	if query == null or not query.ray(eye, hand, hit):
		return hand
	var reach := eye.distance_to(hand)
	return eye.lerp(hand, maxf(0.0, hit.fraction * reach - c.radius) / maxf(reach, EPSILON))


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
	var hand := release_from(eye, c.yaw, cfg, _query, _hit)
	g.launch(bomb, c.id, hand, speed)
	c.grenades.spend(bomb)
	var e := events.add(GameEvent.Kind.GRENADE_THROW)
	e.actor = c.id
	e.target = slot
	e.value = bomb
	e.position = hand
	e.direction = speed


## One tick of `g`'s flight (slot `index`): falling, and bouncing off, sliding along or rolling on the level where it
## meets it, and settling; bouncing off or sliding along the body of anyone in play in `characters` it meets first. The
## line cast runs a radius past the move; one moved clear probes a radius down for the ground, so a bomb rolling on it
## touches it every tick.
func _fly(g: Grenade, index: int, characters: Array[Character], events: SimEvents, dt: float) -> void:
	g.velocity.y -= cfg.gravity * dt
	var move := g.velocity * dt
	var length := move.length()
	if length < EPSILON:
		return
	var dir := move / length
	var reach := length + cfg.radius
	var met := _query.ray(g.position, g.position + dir * reach, _hit)
	var on_body := _body_hit(g, dir, (_hit.fraction * reach - cfg.radius) if met else length, characters)
	met = met or on_body
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
	elif on_body:
		g.velocity -= _hit.normal * minf(0.0, g.velocity.dot(_hit.normal)) # slides off: never rests on a body
	else:
		_roll(g, dt)


## Whether bomb `g` moving along the unit `dir` meets the body (BodyConfig's capsule, its height now) of someone in
## play in `characters` within `most` m; if so `_hit` holds the nearest, its surface NONE. A body the bomb is already
## inside (the thrower's, at the throw) is passed through, and so is the thrower's team for team_pass_time after it.
func _body_hit(g: Grenade, dir: Vector3, most: float, characters: Array[Character]) -> bool:
	if most <= 0.0:
		return false
	var from := g.position
	var body := _tuning.body
	var r := body.radius + cfg.radius
	var best := INF
	var best_axis := Vector3.ZERO
	var passing := -1
	if g.age < cfg.team_pass_time:
		for c in characters:
			if c.id == g.owner:
				passing = c.team
	for c in characters:
		if not Elimination.is_in_play(c) or c.team == passing:
			continue
		var dx := c.position.x - from.x
		var dz := c.position.z - from.z
		if dx * dx + dz * dz > (most + r) * (most + r):
			continue
		_body.a = c.position + Vector3(0.0, body.radius, 0.0)
		_body.b = c.position + Vector3(0.0, maxf(body.radius, c.body_height(body) - body.radius), 0.0)
		_body.r = r
		var t := Hitbox.ray_vertical_capsule(from, dir, minf(most, best), _body)
		if t > 0.0 and t < best:
			best = t
			best_axis = _body.a
			best_axis.y = clampf(from.y + dir.y * t, _body.a.y, _body.b.y)
	if is_inf(best):
		return false
	var centre := from + dir * best
	_hit.normal = (centre - best_axis).normalized() if not centre.is_equal_approx(best_axis) else -dir
	_hit.position = centre - _hit.normal * cfg.radius
	_hit.fraction = best / maxf(most, EPSILON)
	_hit.surface = RayHit.Surface.NONE
	return true


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
		# A flash dazzles through glass as light goes through it (BQ1).
		if eye.distance_to(at) > cfg.flash_reach or _query.sight_ray(eye, at, _hit):
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
