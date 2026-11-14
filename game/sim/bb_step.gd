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
## them). A body that moved this tick is met where the BB and it were at the same moment of the tick, not where it
## stands at the tick's end (PH1, _first_body). A laser (Dev › Lasers, LZ1) never flies: it is resolved in the tick it
## is fired (_laser).

## A BB_IMPACT's value when the BB stopped in a bush's leaves (0: on the level or a body).
const IN_LEAVES := 1
## A tick's path shorter than this (m) is no path: nothing to test.
const MIN_SEGMENT := 1e-9
## A laser out of a bush's leaves looks for the next bush from this far past the edge (m), not the edge itself.
const LEAF_STEP := 1e-3
## How finely a BB going into a stream through its edge finds where (halvings of its path's last stretch, WS1).
const SIDE_STEPS := 8

## This tick's hit volume of each character, by index in the roster: characters don't move while BBs fly, so each is
## built at most once a tick, and only once a BB's path comes near it (Hitbox.may_touch; _built: 1 once built this
## tick). Grown to the roster's size once, then reused.
static var _volumes: Array[Hitbox.Volume] = []
static var _built: PackedByteArray = PackedByteArray()
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
## out of a bush's edge a BB_LEAVES; one whose path goes under a stream's surface (`query`'s water, WS1) a BB_IMPACT on
## WATER where it went in, never bouncing; one that falls below `kill_y` or outlives its lifetime is BB_LOST. On the practice range a BB also stops on the first of `targets` it reaches, nearer than any
## body or the level, unless in a cease-fire: a TARGET_HIT (a figure goes down, RangeTargets.hit_target), or a
## BB_IMPACT on metal at a plate's post or a swinger's frame (a miss). `rng` (the match's stream) scatters bounces and
## times a pop-up's spell down. `field_air` is the field's own air (GameState.air, PH1); null flies them in the air
## replicas are rated in.
static func step(pool: BBPool, characters: Array[Character], query: WorldQuery, tuning: SimTuning, kill_y: float,
		cease_fire: bool, ends: Array[MapEnd], events: SimEvents, dt: float, wind: Vector3 = Vector3.ZERO,
		rng: RandomNumberGenerator = null, targets: Array[RangeTarget] = [], field_air: AirModel = null) -> void:
	var cfg := tuning.ballistics
	var air := field_air if field_air != null else AirModel.of(cfg)
	var prepared := false
	var foliage := query.foliage
	var leafy := foliage != null and not foliage.is_empty()
	var water := query.water
	var wet := water != null and not water.is_empty()
	for bb: BB in pool.bbs:
		if not bb.active:
			continue
		if bb.laser:
			if not prepared:
				_prepare(characters)
				prepared = true
			_laser(bb, characters, query, tuning, cease_fire, ends, events, rng, targets)
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
			# Under a stream's surface (WS1): the path goes in at the water where it falls through the level, `sink` m
			# along it, and stops there, nearer than the bed or the bank beyond.
			var sink := INF
			if wet and dir.y < 0.0:
				var end := bb.prev_position + dir * minf(wall, length)
				var level := water.level_at(end.x, end.z) if end.y < water.top() - Water.MIN_DEPTH else NAN
				if not is_nan(level) and level - end.y > Water.MIN_DEPTH:
					sink = _went_in(water, bb.prev_position, dir, clampf((level - bb.prev_position.y) / dir.y, 0.0,
							minf(wall, length)), minf(wall, length))
			var reach := minf(minf(wall, length), sink)
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
				_prepare(characters)
				prepared = true
			_first_body(bb, dir, leaf_end if leaf_end >= 0.0 else reach, characters, tuning.hits, length)
			if not targets.is_empty() and not cease_fire \
					and _stop_on_target(bb, dir, targets, tuning, events, rng, length):
				continue
			if _reached >= 0:
				_stop_on_body(bb, dir, characters, tuning.hits, cease_fire, ends, events)
				continue
			if leaf_end >= 0.0:
				_leave_leaves(bb, dir, leaf_end, leaf_stop, cfg, events, rng)
				continue
			if not is_inf(sink):
				_sink(bb, dir, sink, events)
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


## Where a path from `from` along `dir` went into `water` (m along it): at `level` m, where it fell through the
## surface, or, where that lies off the water (a stream's edge with no bank to wall it), the first of it over the water
## before `far`, found to within 1/2^SIDE_STEPS of the way.
static func _went_in(water: Water, from: Vector3, dir: Vector3, level: float, far: float) -> float:
	var at := from + dir * level
	if not is_nan(water.level_at(at.x, at.z)):
		return level
	var lo := level
	var hi := far
	for i in SIDE_STEPS:
		var mid := (lo + hi) * 0.5
		at = from + dir * mid
		if is_nan(water.level_at(at.x, at.z)):
			lo = mid
		else:
			hi = mid
	return hi


## The BB stops `at` m along `dir` where its path went under a stream's surface (WS1): a splash there (a BB_IMPACT on
## WATER), and it sinks, never bouncing.
static func _sink(bb: BB, dir: Vector3, at: float, events: SimEvents) -> void:
	bb.position = bb.prev_position + dir * at
	var impact := events.add(GameEvent.Kind.BB_IMPACT)
	impact.actor = bb.owner_id
	impact.position = bb.position
	impact.value2 = RayHit.Surface.WATER
	impact.direction = bb.velocity
	bb.active = false


## The BB stops on the body _first_body reached (_reached, _reached_at along `dir`), whatever happens to its owner: a
## CHARACTER_HIT that knocks it out, a RICOCHET_TICK for a bounced BB when ricochets don't count, or a BB_IMPACT on a
## body not knocked out (_knocks_out).
static func _stop_on_body(bb: BB, dir: Vector3, characters: Array[Character], hits: HitConfig, cease_fire: bool,
		ends: Array[MapEnd], events: SimEvents) -> void:
	var body := characters[_reached]
	bb.position = bb.prev_position + dir * _reached_at
	bb.active = false
	var ricochet := bb.bounces > 0
	var knocks := _knocks_out(body, bb.owner_id, characters, hits, cease_fire)
	if knocks and ricochet and not hits.ricochets_count:
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


## A laser (Dev › Lasers, LZ1; `bb.laser`, fired this tick from its owner's eyes along its velocity): no flight, no
## gravity, wind, hop-up or bounce. It reaches at once the first of a range target (outside a `cease_fire`), a body
## and the level along a straight line up to LaserConfig.reach, and through bushes as far as a BB pushes through their
## leaves (_laser_leaves), and stops there as a BB would (a body by the same rules, _stop_on_body; a range target; a
## BB_IMPACT in the leaves, or on the level with no speed, so it rings no prop). A LASER event gives its beam. It is
## free again at once.
static func _laser(bb: BB, characters: Array[Character], query: WorldQuery, tuning: SimTuning, cease_fire: bool,
		ends: Array[MapEnd], events: SimEvents, rng: RandomNumberGenerator, targets: Array[RangeTarget]) -> void:
	var from := bb.position
	var speed := bb.velocity.length()
	var dir := bb.velocity / speed if speed > MIN_SEGMENT else Vector3.FORWARD
	var length := tuning.lasers.reach
	bb.prev_position = from
	bb.active = false
	var wall := INF
	if query.bb_ray(from, from + dir * length, _ray_hit):
		wall = _ray_hit.fraction * length
	var reach := minf(wall, length)
	var leaf_end := _laser_leaves(from, dir, reach, query.foliage, tuning)
	_first_body(bb, dir, leaf_end if leaf_end >= 0.0 else reach, characters, tuning.hits)
	bb.position = from + dir * _reached_at
	if targets.is_empty() or cease_fire or not _stop_on_target(bb, dir, targets, tuning, events, rng):
		_laser_stop(bb, dir, not is_inf(wall), leaf_end >= 0.0, characters, tuning, cease_fire, ends, events)
	var beam := events.add(GameEvent.Kind.LASER)
	beam.actor = bb.owner_id
	beam.slot = bb.slot
	beam.position = bb.position
	beam.direction = dir
	beam.reach = from.distance_to(bb.position)


## Where a laser that reached no range target stops (at bb.position): on the body _first_body reached, else in the
## leaves (`in_leaves`), else on the level (`on_level`, _ray_hit), else nowhere, its reach run out in the air.
static func _laser_stop(bb: BB, dir: Vector3, on_level: bool, in_leaves: bool, characters: Array[Character],
		tuning: SimTuning, cease_fire: bool, ends: Array[MapEnd], events: SimEvents) -> void:
	if _reached >= 0:
		_stop_on_body(bb, dir, characters, tuning.hits, cease_fire, ends, events)
	elif in_leaves:
		var stopped := events.add(GameEvent.Kind.BB_IMPACT)
		stopped.actor = bb.owner_id
		stopped.position = bb.position
		stopped.value = IN_LEAVES
		stopped.value2 = RayHit.Surface.LEAVES
		stopped.direction = dir
		stopped.reach = tuning.ballistics.leaf_stop_depth
	elif on_level:
		var impact := events.add(GameEvent.Kind.BB_IMPACT)
		impact.actor = bb.owner_id
		impact.position = bb.position
		impact.value2 = _ray_hit.surface


## How far along `dir` from `from` a laser stops in leaves (`foliage`, null for none): where it has crossed
## leaf_stop_depth of them, over every bush on its line before `reach` (LaserConfig.most_bushes at most); -1 if it
## comes through them all.
static func _laser_leaves(from: Vector3, dir: Vector3, reach: float, foliage: Foliage, tuning: SimTuning) -> float:
	if foliage == null or foliage.is_empty():
		return -1.0
	var start := 0.0
	var left := tuning.ballistics.leaf_stop_depth
	for i in tuning.lasers.most_bushes:
		if not foliage.first_leaves(from + dir * start, dir, reach - start, _crossing):
			return -1.0
		var depth := _crossing.exit - _crossing.enter
		if depth >= left:
			return start + _crossing.enter + left
		left -= depth
		if not _crossing.through:
			return -1.0
		start += _crossing.exit + LEAF_STEP
	return -1.0


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
## `flown` is the segment's whole length (m) for a BB in flight: a target that moved this tick is swept as a body is.
static func _stop_on_target(bb: BB, dir: Vector3, targets: Array[RangeTarget], tuning: SimTuning, events: SimEvents,
		rng: RandomNumberGenerator, flown: float = 0.0) -> bool:
	RangeTargets.first_hit(bb.prev_position, dir, _reached_at, targets, tuning.targets, _target_hit, flown,
			tuning.hits.max_stride)
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


## Readies this tick's hit volumes (see _volumes): none built yet.
static func _prepare(characters: Array[Character]) -> void:
	while _volumes.size() < characters.size():
		_volumes.append(Hitbox.Volume.new())
	if _built.size() < characters.size():
		_built.resize(characters.size())
	_built.fill(0)


## The first body along the BB's segment this tick (from prev_position along `dir`, before `max_t`) into _reached and
## _reached_at, by `hits`' volumes. Every body counts, whatever its status; only the shooter is skipped, until the BB has bounced, and a
## ghost (DevCheats).
## `flown` is the segment's whole length (m) for a BB in flight: a body that stepped this tick (prev_position to
## position, under HitConfig.max_stride: not a respawn or a move to the dead zone) is then tested along the BB's path
## as that body saw it, the BB's travel less the body's step, so each is where it was at the same moment of the tick
## (PH1; before, the body stood at its tick's end for the whole of the BB's travel, up to 11 cm out on a sprinter, and
## the drawn figure and BB, both interpolated over the tick, disagreed with the hit). 0 (a laser): bodies as they stand.
static func _first_body(bb: BB, dir: Vector3, max_t: float, characters: Array[Character], hits: HitConfig,
		flown: float = 0.0) -> void:
	_reached = -1
	var best := max_t
	var stride2 := hits.max_stride * hits.max_stride
	for i in characters.size():
		var c := characters[i]
		if (c.id == bb.owner_id and bb.bounces == 0) or c.ghost:
			continue
		var from := bb.prev_position
		var along := dir
		# Metres of the BB's own path per metre of the path the body saw.
		var per_metre := 1.0
		if flown > MIN_SEGMENT:
			var step_x := c.position.x - c.prev_position.x
			var step_y := c.position.y - c.prev_position.y
			var step_z := c.position.z - c.prev_position.z
			var step2 := step_x * step_x + step_y * step_y + step_z * step_z
			if step2 > 0.0 and step2 < stride2:
				# In the body's frame the BB starts a step further on and ends where it ends.
				from = Vector3(from.x + step_x, from.y + step_y, from.z + step_z)
				along = bb.position - from
				var seen := along.length()
				if seen <= MIN_SEGMENT:
					continue # it flew along with the body: it never gets nearer
				along /= seen
				per_metre = flown / seen
		var reach := best / per_metre
		if not Hitbox.may_touch(c, from, along, reach, hits):
			continue
		if _built[i] == 0:
			Hitbox.build_volume(c, hits, _volumes[i])
			_built[i] = 1
		var d := Hitbox.ray_character(from, along, reach, _volumes[i]) * per_metre
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
