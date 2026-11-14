class_name PropNoise
extends RefCounted
## Noisy props (the browser game's sim/propNoise.ts, NP1): someone who runs into one, or a BB that lands hard on one
## that rings, makes a noise there, a PROP_KNOCK or PROP_RING event that bots hear and you hear. Pure rules on plain
## data: which of the level's boxes (WorldQuery.block_kinds) are noisy, and how far each carries, is NoiseConfig. A prop
## makes at most one noise per NoiseConfig.quiet, kept in GameState.prop_quiet. Nothing is random. Made once per
## Simulation; a tick allocates nothing.

var cfg: NoiseConfig = null
## The noisy props, in the level's order: each one's block index in the WorldQuery, box, Sound and reaches.
var block: PackedInt32Array = PackedInt32Array()
var center: PackedVector3Array = PackedVector3Array()
var half: PackedVector3Array = PackedVector3Array()
var sound: PackedInt32Array = PackedInt32Array()
var surface: PackedInt32Array = PackedInt32Array()
var knock_reach: PackedFloat32Array = PackedFloat32Array()
var ring_reach: PackedFloat32Array = PackedFloat32Array()
## Whether any of them rings, so a level with none skips the BB impacts, and the indexes of those that do.
var rings: bool = false
var ringing: PackedInt32Array = PackedInt32Array()


## The noisy props among `query`'s boxes (those whose kind `noise` lists, or that name their own sound,
## WorldQuery.block_noises).
func _init(noise: NoiseConfig, query: WorldQuery) -> void:
	cfg = noise
	if query == null:
		return
	for i in query.block_kinds.size():
		var own := query.block_noises[i]
		var s: int = NoiseConfig.SOUND_NAMES.find(String(own)) if own != &"" \
				else noise.props.get(query.block_kinds[i], -1)
		if s < 0:
			continue
		block.append(i)
		center.append(query.block_centers[i])
		half.append(query.block_halves[i])
		sound.append(s)
		surface.append(query.block_surfaces[i])
		knock_reach.append(noise.knock_reach_of(s))
		ring_reach.append(noise.ring_reach_of(s))
		if noise.ring_reach_of(s) > 0.0:
			ringing.append(block.size() - 1)
	rings = not ringing.is_empty()


## How many noisy props the level has.
func count() -> int:
	return block.size()


## Grows `state`'s quiet times to one per prop, each ready to sound (allocates only the first time on a state).
func prepare(state: GameState) -> void:
	var n := state.prop_quiet.size()
	if n >= block.size():
		return
	state.prop_quiet.resize(block.size())
	for i in range(n, block.size()):
		state.prop_quiet[i] = -INF


## After `c`'s move this tick (Character.wanted_move and made_move, over `dt` seconds): a run into a noisy prop knocks
## it. The move counts as one when it lost at least knock_blocked_min against something, the wanted move's speed into
## that (along the way it was stopped) was knock_speed or more, and the nearest noisy prop whose face is within
## knock_touch of the body (`body`'s radius round, its height tall), and not underfoot, lies that way (knock_facing).
## The noise comes from that face, noise_height above the feet.
func knock(c: Character, body: BodyConfig, dt: float, state: GameState) -> void:
	var bx := c.wanted_move.x - c.made_move.x
	var bz := c.wanted_move.z - c.made_move.z
	var blocked := sqrt(bx * bx + bz * bz)
	if blocked < cfg.knock_blocked_min:
		return
	var nx := bx / blocked
	var nz := bz / blocked
	if (c.wanted_move.x * nx + c.wanted_move.z * nz) / dt < cfg.knock_speed:
		return
	var p := c.position
	var best := -1
	var best_d := body.radius + cfg.knock_touch
	var best_x := 0.0
	var best_z := 0.0
	for i in block.size():
		var ce := center[i]
		var h := half[i]
		# Out of reach along either axis, or underfoot, or overhead: the cheap tests first.
		if absf(p.x - ce.x) > h.x + best_d or absf(p.z - ce.z) > h.z + best_d \
				or ce.y + h.y <= p.y + cfg.underfoot or ce.y - h.y >= p.y + body.height:
			continue
		var qx := clampf(p.x, ce.x - h.x, ce.x + h.x)
		var qz := clampf(p.z, ce.z - h.z, ce.z + h.z)
		var dx := qx - p.x
		var dz := qz - p.z
		var d := sqrt(dx * dx + dz * dz)
		if d > best_d or (d > 1e-6 and (dx * nx + dz * nz) / d < cfg.knock_facing):
			continue
		best = i
		best_d = d
		best_x = qx
		best_z = qz
	if best < 0:
		return
	var y := clampf(p.y + cfg.noise_height, center[best].y - half[best].y, center[best].y + half[best].y)
	var e := _sound(best, GameEvent.Kind.PROP_KNOCK, c.id, knock_reach[best], state)
	if e != null:
		e.position = Vector3(best_x, y, best_z)
		e.value2 = surface[best]


## After the tick's BBs flew: each BB that landed on the level from `first` on in the tick's events (a BB_IMPACT with
## no body, its direction the BB's velocity) at ring_min_speed or faster, on a prop that rings, rings it there.
func ring(state: GameState, first: int) -> void:
	if not rings:
		return
	var events := state.events
	var last := events.count
	var m := cfg.ring_margin
	var min_sq := cfg.ring_min_speed * cfg.ring_min_speed
	for k in range(first, last):
		var impact := events.items[k]
		if impact.kind != GameEvent.Kind.BB_IMPACT or impact.target >= 0 \
				or impact.direction.length_squared() < min_sq:
			continue
		var at := impact.position
		for i in ringing:
			var ce := center[i]
			var h := half[i]
			if absf(at.x - ce.x) > h.x + m or absf(at.y - ce.y) > h.y + m or absf(at.z - ce.z) > h.z + m:
				continue
			var e := _sound(i, GameEvent.Kind.PROP_RING, impact.actor, ring_reach[i], state)
			if e != null:
				e.position = at
			break


## Prop `i` makes its noise of `kind`, set off by `actor`, unless it made one less than `quiet` ago: the event, or null.
## A quiet time further off than `quiet` is from an earlier match's clock, so it no longer holds.
func _sound(i: int, kind: GameEvent.Kind, actor: int, reach_m: float, state: GameState) -> GameEvent:
	var until := state.prop_quiet[i]
	if state.time < until and until - state.time <= cfg.quiet:
		return null
	state.prop_quiet[i] = state.time + cfg.quiet
	var e := state.events.add(kind)
	e.actor = actor
	e.target = block[i]
	e.value = sound[i]
	e.reach = reach_m
	return e
