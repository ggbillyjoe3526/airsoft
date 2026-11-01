class_name BBStep
## Moves every BB in flight one tick, drifting in the wind, and stops it at whatever its path crosses first (the browser
## game's sim/bbs.ts stepBBs, without prop noise, which comes with its task): a body, a practice range target, a bush's
## leaves once it has pushed through leaf_stop_depth of them over its flight (FO1), or the level (WorldQuery.bb_ray: a
## railing's bars and rails, not the gaps between them, SR1), where a hard surface
## bounces it off instead (a ricochet, M20). A BB that comes out of a bush having crossed less flies on from where it
## came out, slowed and thrown off its line (Leaves), and the rest of that tick's travel is dropped, as with a bounce.
## Every body on the field stops a BB (M85: it never goes on through someone to whoever is behind); only a body in play
## is knocked out, and not a teammate when friendly fire is off, and nobody once the round is decided. A ricochet knocks
## someone out only when the match counts ricochets (HitConfig.ricochets_count); otherwise it ticks them and stops, and
## they play on. A BB never hits whoever fired it until it has bounced (its first segment starts at their eye, inside
## them).

## A BB_IMPACT's value when the BB stopped in a bush's leaves (0: on the level or a body).
const IN_LEAVES := 1
## A tick's path shorter than this (m) is no path: nothing to test.
const MIN_SEGMENT := 1e-9

## This tick's hit volume of each character, by index in the roster: characters don't move while BBs fly, so they're
## built once a tick, not once a BB. Grown to the roster's size once, then reused.
static var _volumes: Array[Hitbox.Volume] = []
static var _ray_hit: RayHit = RayHit.new()
## The body a BB reached this tick (_first_body): its index in the roster (-1: none), and how far along the segment.
static var _reached: int = -1
static var _reached_at: float = 0.0
## The range target a BB reached this tick (RangeTargets.first_hit).
static var _target_hit: RangeTargets.Hit = RangeTargets.Hit.new()
## Where a BB's path this tick runs through a bush (Foliage.first_leaves).
static var _crossing: Foliage.Crossing = Foliage.Crossing.new()


## One tick of every BB in `pool`: fly, then stop on the nearest of the level (`query`) and the bodies of
## `characters`, in `wind` (m/s). A body knocked out is eliminated (Elimination.eliminate, with `ends` for its dead zone)
## and reported as CHARACTER_HIT (value 1 for a ricochet); a ricochet that doesn't count is a RICOCHET_TICK; a BB
## stopped on a body that isn't knocked out (already hit, a teammate with friendly fire off, anyone in a `cease_fire`)
## or on the level is a BB_IMPACT, and a bounce off the level is one too; one stopped in a bush's leaves (`query`'s
## foliage) is a BB_IMPACT with value IN_LEAVES (direction its unit path, reach the leaves it crossed), and one coming
## out of a bush's edge a BB_LEAVES; one that falls below `kill_y` or outlives its lifetime is BB_LOST. On the practice range a BB also stops on the first of `targets` it reaches, nearer than any
## body or the level, unless in a cease-fire: a TARGET_HIT (a figure goes down, RangeTargets.hit_target), or a
## BB_IMPACT on metal at a plate's post or a swinger's frame (a miss). `rng` (the match's stream) scatters bounces and
## times a pop-up's spell down.
static func step(pool: BBPool, characters: Array[Character], query: WorldQuery, tuning: SimTuning, kill_y: float,
		cease_fire: bool, ends: Array[MapEnd], events: SimEvents, dt: float, wind: Vector3 = Vector3.ZERO,
		rng: RandomNumberGenerator = null, targets: Array[RangeTarget] = []) -> void:
	var cfg := tuning.ballistics
	var air := AirModel.of(cfg)
	var prepared := false
	var foliage := query.foliage
	var leafy := foliage != null and not foliage.is_empty()
	for bb: BB in pool.bbs:
		if not bb.active:
			continue
		bb.prev_position = bb.position
		Ballistics.step_flight(bb, air, dt, wind)
		var segment := bb.position - bb.prev_position
		var length := segment.length()
		if length > MIN_SEGMENT:
			var dir := segment / length
			var wall := INF
			if query.bb_ray(bb.prev_position, bb.position, _ray_hit):
				wall = _ray_hit.fraction * length
			var reach := minf(wall, length)
			# Leaves before the surface: where the BB stops in them, or comes out of them, ends its path here; a path
			# that ends still among them (`in_leaves` m crossed) flies on through them next tick.
			var leaf_end := -1.0
			var leaf_stop := false
			var in_leaves := 0.0
			if leafy and foliage.first_leaves(bb.prev_position, dir, reach, _crossing):
				var left := maxf(0.0, cfg.leaf_stop_depth - bb.leaf)
				leaf_stop = _crossing.exit - _crossing.enter >= left
				if leaf_stop:
					leaf_end = _crossing.enter + left
				elif _crossing.through:
					leaf_end = _crossing.exit
				else:
					in_leaves = _crossing.exit - _crossing.enter
			if not prepared:
				_prepare(characters, tuning.hits)
				prepared = true
			_first_body(bb, dir, leaf_end if leaf_end >= 0.0 else reach, characters)
			if not targets.is_empty() and not cease_fire and _stop_on_target(bb, dir, targets, tuning, events, rng):
				continue
			if _reached >= 0:
				# The BB stops on the body, whatever happens to its owner.
				var body := characters[_reached]
				bb.position = bb.prev_position + dir * _reached_at
				bb.active = false
				var ricochet := bb.bounces > 0
				var knocks := _knocks_out(body, bb.owner_id, characters, tuning.hits, cease_fire)
				if knocks and ricochet and not tuning.hits.ricochets_count:
					var tick := events.add(GameEvent.Kind.RICOCHET_TICK)
					tick.actor = bb.owner_id
					tick.target = body.id
					tick.position = bb.position
					tick.direction = dir
				elif knocks:
					Elimination.eliminate(body, bb.owner_id, characters, ends)
					var hit := events.add(GameEvent.Kind.CHARACTER_HIT)
					hit.actor = bb.owner_id
					hit.target = body.id
					hit.position = bb.position
					hit.direction = dir
					hit.value = 1 if ricochet else 0
				else:
					var knock := events.add(GameEvent.Kind.BB_IMPACT)
					knock.actor = bb.owner_id
					knock.target = body.id
					knock.position = bb.position
				continue
			if leaf_end >= 0.0:
				_leave_leaves(bb, dir, leaf_end, leaf_stop, cfg, events, rng)
				continue
			if not is_inf(wall):
				bb.position = bb.prev_position + dir * wall
				if in_leaves > 0.0:
					# It met the surface still among the leaves: what it crossed counts, and slows it before it lands
					# (not turned: the line it met the surface on is the one already traced).
					bb.leaf += in_leaves
					Leaves.deflect(bb, in_leaves, cfg, null)
				var impact := events.add(GameEvent.Kind.BB_IMPACT)
				impact.actor = bb.owner_id
				impact.position = bb.position
				impact.value2 = _ray_hit.surface
				impact.direction = bb.velocity # how hard it landed, before any bounce turns it (PropNoise.ring)
				# A bounce flies on from the surface next tick: the rest of this tick's travel is dropped, so a ricochet
				# arrives at most a tick late, which nobody can see at these speeds.
				if not Ricochet.bounce(bb, _ray_hit, tuning.ricochet, rng):
					bb.active = false
				continue
			if in_leaves > 0.0:
				# Still among the leaves at the end of its path: it pushes on, slowed and turned by what it crossed.
				bb.leaf += in_leaves
				Leaves.deflect(bb, in_leaves, cfg, rng)
		if bb.age > cfg.max_lifetime or bb.position.y < kill_y:
			bb.active = false
			var lost := events.add(GameEvent.Kind.BB_LOST)
			lost.actor = bb.owner_id
			lost.position = bb.position


## The BB's path this tick ends `leaf_end` m along `dir` in a bush (_crossing): stopped in the leaves (`stop`, a
## BB_IMPACT with value IN_LEAVES, value2 RayHit.Surface.LEAVES, direction its unit path and reach the leaves crossed:
## never fast enough to ring a prop), or out of the bush's edge, slowed and turned (a BB_LEAVES).
static func _leave_leaves(bb: BB, dir: Vector3, leaf_end: float, stop: bool, cfg: BallisticsConfig, events: SimEvents,
		rng: RandomNumberGenerator) -> void:
	bb.position = bb.prev_position + dir * leaf_end
	var crossed := leaf_end - _crossing.enter
	bb.leaf += crossed
	if stop:
		bb.active = false
		var stopped := events.add(GameEvent.Kind.BB_IMPACT)
		stopped.actor = bb.owner_id
		stopped.position = bb.position
		stopped.value = IN_LEAVES
		stopped.value2 = RayHit.Surface.LEAVES
		stopped.direction = dir
		stopped.reach = bb.leaf
		return
	Leaves.deflect(bb, crossed, cfg, rng)
	var brush := events.add(GameEvent.Kind.BB_LEAVES)
	brush.actor = bb.owner_id
	brush.position = bb.position
	brush.direction = dir


## Whether the BB's segment this tick (from prev_position along `dir`) reaches one of `targets` before _reached_at (the
## nearest body, or else the level or the segment's end): it stops there, as a TARGET_HIT, or a BB_IMPACT at a post.
static func _stop_on_target(bb: BB, dir: Vector3, targets: Array[RangeTarget], tuning: SimTuning, events: SimEvents,
		rng: RandomNumberGenerator) -> bool:
	RangeTargets.first_hit(bb.prev_position, dir, _reached_at, targets, tuning.targets, _target_hit)
	if _target_hit.index < 0:
		return false
	bb.position = bb.prev_position + dir * _target_hit.at
	bb.active = false
	if _target_hit.post:
		# A plate's post or a swinger's frame: the BB stops on the steel, as on a wall (a miss where it stopped).
		var impact := events.add(GameEvent.Kind.BB_IMPACT)
		impact.actor = bb.owner_id
		impact.position = bb.position
		impact.value2 = RayHit.Surface.METAL
		return true
	var target := targets[_target_hit.index]
	RangeTargets.hit_target(target, tuning.targets, rng)
	var hit := events.add(GameEvent.Kind.TARGET_HIT)
	hit.actor = bb.owner_id
	hit.target = target.id
	hit.position = bb.position
	hit.direction = dir
	hit.value = target.kind
	hit.value2 = 1 if bb.bounces > 0 else 0
	return true


## Builds this tick's hit volume of every character (see _volumes).
static func _prepare(characters: Array[Character], hits: HitConfig) -> void:
	while _volumes.size() < characters.size():
		_volumes.append(Hitbox.Volume.new())
	for i in characters.size():
		Hitbox.build_volume(characters[i], hits, _volumes[i])


## The first body along the BB's segment this tick (from prev_position along `dir`, before `max_t`) into _reached and
## _reached_at. Every body counts, whatever its status; only the shooter is skipped, until the BB has bounced, and a
## ghost (DevCheats).
static func _first_body(bb: BB, dir: Vector3, max_t: float, characters: Array[Character]) -> void:
	_reached = -1
	var best := max_t
	for i in characters.size():
		if (characters[i].id == bb.owner_id and bb.bounces == 0) or characters[i].ghost:
			continue
		var d := Hitbox.ray_character(bb.prev_position, dir, best, _volumes[i])
		if d <= best:
			best = d
			_reached = i
	_reached_at = best


## Whether a BB from `owner_id` that reaches `body` knocks it out: only a body in play, outside a cease-fire, and not
## on the shooter's team when friendly fire is off.
static func _knocks_out(body: Character, owner_id: int, characters: Array[Character], hits: HitConfig,
		cease_fire: bool) -> bool:
	if cease_fire or not Elimination.is_in_play(body):
		return false
	return hits.friendly_fire or body.team != _team_of(owner_id, characters)


## The team of the character with `id`, or -1 if it isn't in the roster.
static func _team_of(id: int, characters: Array[Character]) -> int:
	for c: Character in characters:
		if c.id == id:
			return c.team
	return -1
