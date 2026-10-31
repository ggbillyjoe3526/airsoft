class_name PracticeSpots
extends RefCounted
## Practice on a field (M94; the browser game's map/practiceSpots.ts and map/practiceLayout.ts, playtest note 11:
## "instead of bots there would be targets"): the range's kinds of target stood where the other team's bots would play,
## read from the map's own data alone, so a new map gets its targets with no extra work, and the timed challenge's START
## plate a little ahead of where you start. In order of how surely a bot stands there (`spots`):
## 1. every lane point (MapData.lanes: a bot advancing on a lane stops at each), facing back down its lane towards your
##    end, the way a bot holding it watches;
## 2. the other end's spawns, facing your start;
## 3. points along the lanes' long legs, where a bot walks between lane points.
## Each is put on the walkable floor under it (or dropped), none near your end's spawns and none crowding another on its
## floor, never facing a wall, and crouched where low cover is right in front of it; then `layout` gives each its kind
## by why a bot is there. Pure: reads the map, its nav grid and its WorldQuery, and RangeConfig's field_ numbers; nothing
## is random, so a map lays out the same targets every time. The browser's Extraction starts and overlooks wait
## for those to be built here.

## Why a bot would be at a spot: a lane point it stops at, its team's start, a point on a lane's leg it walks along.
enum Source { LANE, START, LEG }

## The readout's words for each kind (the range file's labels, translated by HudRangeReadout.label_words).
const STEEL := "Steel"
const SMALL_STEEL := "Small steel"
const SWINGER := "Swinger"
const FIGURE := "Figure"
const CROUCHED := "Crouched figure"
const POPUP := "Pop-up"
const CROUCHED_POPUP := "Crouched pop-up"
const MOVER := "Mover"
const START := "START"
## A standing figure's motions in field_figure_motions.
const MOTION_STILL := "still"
const MOTION_MOVER := "mover"


## A place a target stands, on the floor, facing its way.
class Spot:
	extends RefCounted
	## On the floor (m).
	var position: Vector3 = Vector3.ZERO
	## The way it faces, a unit vector on the floor (x, z): never into a wall.
	var face: Vector2 = Vector2(0.0, 1.0)
	## Cover lower than its shoulders right in front of it: a bot there would crouch behind it.
	var crouched: bool = false
	var source: Source = Source.LANE
	## How far it is from your start across the floor (m).
	var from_start: float = 0.0


## A place a target may stand before it is put on the floor: a point and the way it faces (x, z; any length).
class Candidate:
	extends RefCounted
	var at: Vector3 = Vector3.ZERO
	var face: Vector2 = Vector2.ZERO
	var source: Source = Source.LANE


## Reused by every ray cast here (one layout at a time, on the main thread).
static var _hit: RayHit = RayHit.new()


## Where you start practising on `map`: end 0's first spawn, where Alpha starts round 1; null on a map without one.
static func start_of(map: MapData) -> SpawnPoint:
	if map.ends.is_empty() or map.ends[0].spawns.is_empty():
		return null
	return map.ends[0].spawns[0]


## Practice's targets on `map` (`tuning`'s RangeConfig and body): the range's kinds, each stood at a spot (`spots`) by
## why a bot is there, and the START plate in front of your start where one fits. A spot behind low cover peeks over it
## (a crouched pop-up and a crouched figure in turn); one on a lane's leg walks it (a mover, where its track fits); the
## rest stand, every field_steel_every-th as steel (a plate, a small plate and a swinger in turn, the swinger where its
## frame fits) and the figures among them moving in turn (field_figure_motions).
static func layout(map: MapData, nav: NavGrid, query: WorldQuery, tuning: SimTuning) -> Array[RangeTarget.Spec]:
	var cfg := tuning.targets
	var out: Array[RangeTarget.Spec] = []
	var crouched := 0
	var movers := 0
	var standing := 0
	var steel := 0
	var figures := 0
	var steel_every := maxi(1, cfg.field_steel_every)
	for s in spots(map, nav, query, cfg):
		var yaw := atan2(s.face.x, s.face.y)
		var marked := roundf(s.from_start)
		if s.crouched:
			var popup := crouched % 2 == 0
			crouched += 1
			var c := _spec(RangeTarget.Kind.FIGURE, RangeTarget.Motion.POPUP if popup else RangeTarget.Motion.STILL,
					s.position, yaw, marked, CROUCHED_POPUP if popup else CROUCHED)
			c.crouched = true
			out.append(c)
		elif s.source == Source.LEG and _mover_fits(s, nav, query, cfg):
			out.append(_mover(s, yaw, marked, movers, cfg))
			movers += 1
		else:
			standing += 1
			if standing % steel_every == 0:
				var plate := s.position + Vector3.UP * cfg.plate_height
				var turn := steel % 3
				steel += 1
				var p := _spec(RangeTarget.Kind.STEEL, RangeTarget.Motion.STILL, plate, yaw, marked, STEEL)
				p.radius = cfg.plate_radius
				if turn == 1:
					p.radius = cfg.small_plate_radius
					p.label = SMALL_STEEL
				elif turn == 2 and _swinger_fits(s, nav, query, cfg):
					p.motion = RangeTarget.Motion.SWINGER
					p.label = SWINGER
				out.append(p)
			else:
				var motion := MOTION_STILL
				if not cfg.field_figure_motions.is_empty():
					motion = cfg.field_figure_motions[figures % cfg.field_figure_motions.size()]
				figures += 1
				if motion == MOTION_MOVER and _mover_fits(s, nav, query, cfg):
					out.append(_mover(s, yaw, marked, movers, cfg))
					movers += 1
				elif motion == MOTION_STILL:
					out.append(_spec(RangeTarget.Kind.FIGURE, RangeTarget.Motion.STILL, s.position, yaw, marked, FIGURE))
				else:
					out.append(_spec(RangeTarget.Kind.FIGURE, RangeTarget.Motion.POPUP, s.position, yaw, marked, POPUP))
	var start := start_plate(map, nav, query, tuning)
	if start != null:
		out.append(start)
	return out


## Where targets stand on `map`, sorted near to far from your start (see the class's comment).
static func spots(map: MapData, nav: NavGrid, query: WorldQuery, cfg: RangeConfig) -> Array[Spot]:
	var out: Array[Spot] = []
	var first := start_of(map)
	if first == null or map.ends.size() < 2 or nav == null:
		return out
	var start := first.position
	var candidates: Array[Candidate] = []
	for lane in map.lanes:
		for i in lane.size():
			var back := lane[i - 1] if i > 0 else start
			candidates.append(_candidate(Source.LANE, lane[i], back))
	for s in map.ends[1].spawns:
		candidates.append(_candidate(Source.START, s.position, start))
	for lane in map.lanes:
		for i in range(1, lane.size()):
			var a := lane[i - 1]
			var b := lane[i]
			var steps := floori(Vector2(b.x - a.x, b.z - a.z).length() / cfg.field_leg_step)
			for k in range(1, steps):
				candidates.append(_candidate(Source.LEG, a.lerp(b, float(k) / steps), a))
	for c in candidates:
		if out.size() >= cfg.field_max_targets:
			break
		var spot := _placed(c, map, nav, query, cfg, start)
		if spot != null and not _crowded(spot, out, cfg):
			out.append(spot)
	out.sort_custom(_nearer)
	return out


## The timed challenge's START plate on `map`: a little ahead of your start (the first of field_start_ahead and
## field_start_turns that fits), facing you, on a floor near yours and in plain sight from your eye there; null when no
## place in front of you fits (that map has no challenge).
static func start_plate(map: MapData, nav: NavGrid, query: WorldQuery, tuning: SimTuning) -> RangeTarget.Spec:
	var cfg := tuning.targets
	var s := start_of(map)
	if s == null or nav == null:
		return null
	var p := s.position
	var eye := Vector3(p.x, p.y + tuning.body.rest_gap + tuning.body.stand_eye_height, p.z)
	for ahead in cfg.field_start_ahead:
		for turn in cfg.field_start_turns:
			# A spawn's yaw 0 looks down -z; the plate faces back along the way to it (a target's yaw 0 faces +z).
			var dx := -sin(s.yaw + turn)
			var dz := -cos(s.yaw + turn)
			var x := p.x + dx * ahead
			var z := p.z + dz * ahead
			var ground := _floor_at(x, p.y, z, nav, query, cfg)
			if is_nan(ground) or absf(ground - p.y) > cfg.field_start_climb:
				continue
			var at := Vector3(x, ground + cfg.start_height, z)
			if query.ray(eye, at, _hit):
				continue
			var plate := _spec(RangeTarget.Kind.STEEL, RangeTarget.Motion.STILL, at, atan2(-dx, -dz), ahead, START)
			plate.radius = cfg.plate_radius
			plate.start = true
			return plate
	return null


## The floor's real height at (x, z) (a ramp or the terrain between nav cells' middles), from the nav floor `nav_y`.
static func floor_under(x: float, nav_y: float, z: float, query: WorldQuery, cfg: RangeConfig) -> float:
	var from := Vector3(x, nav_y + cfg.field_floor_up, z)
	if query.ray(from, from + Vector3.DOWN * (cfg.field_floor_up + cfg.field_floor_down), _hit):
		return _hit.position.y
	return nav_y


## Whether something solid is within `reach` of `at` along the floor direction `way` (x, z; unit).
static func blocked(at: Vector3, way: Vector2, reach: float, query: WorldQuery) -> bool:
	return query.ray(at, at + Vector3(way.x, 0.0, way.y) * reach, _hit)


static func _candidate(source: Source, at: Vector3, toward: Vector3) -> Candidate:
	var c := Candidate.new()
	c.at = at
	c.face = Vector2(toward.x - at.x, toward.z - at.z)
	c.source = source
	return c


## A candidate on the walkable floor under it, facing its way, crouched or not; null when it can't stand there.
static func _placed(c: Candidate, map: MapData, nav: NavGrid, query: WorldQuery, cfg: RangeConfig,
		start: Vector3) -> Spot:
	var k := nav.node_at(c.at)
	var x := c.at.x
	var z := c.at.z
	if k < 0 or nav.walkable[k] != 1:
		k = nav.nearest_walkable(c.at, cfg.field_snap_reach)
		if k < 0:
			return null
		var cell := nav.node_cell[k]
		x = nav.cell_x(cell % nav.cols)
		z = nav.cell_z(cell / nav.cols)
	# Not under a tunnel's roof: a spot is stood on (CT1).
	if nav.low[k] != 0:
		return null
	# Not at your start: every spawn of your end keeps its clearing (the spawn yard).
	for s in map.ends[0].spawns:
		if Vector2(s.position.x - x, s.position.z - z).length() < cfg.field_clear_of_start:
			return null
	var ground := floor_under(x, nav.floor_y[k], z, query, cfg)
	var way := _clear_way(Vector3(x, ground + cfg.field_high_ray, z), c.face, Vector2(start.x - x, start.z - z), cfg,
			query)
	if way == Vector2.ZERO:
		return null
	var spot := Spot.new()
	spot.position = Vector3(x, ground, z)
	spot.face = way
	# Its way is open at head height (_clear_way), so cover at waist height in front is cover it can crouch behind.
	spot.crouched = blocked(Vector3(x, ground + cfg.field_low_ray, z), way, cfg.field_cover_reach, query)
	spot.source = c.source
	spot.from_start = Vector2(x - start.x, z - start.z).length()
	return spot


## Whether `spot` stands within field_min_gap of one already kept on its storey.
static func _crowded(spot: Spot, kept: Array[Spot], cfg: RangeConfig) -> bool:
	var p := spot.position
	for o in kept:
		if Vector2(o.position.x - p.x, o.position.z - p.z).length() < cfg.field_min_gap \
				and absf(o.position.y - p.y) < cfg.field_storey_gap:
			return true
	return false


## Near to far from your start; a tie by place, so the order never depends on the sort.
static func _nearer(a: Spot, b: Spot) -> bool:
	if a.from_start != b.from_start:
		return a.from_start < b.from_start
	if a.position.x != b.position.x:
		return a.position.x < b.position.x
	return a.position.z < b.position.z


## The way a target at `at` faces: `face` unless a wall is right in front (a lane's last point in a corner), else
## towards your start (`to_start`), else the open way nearest that of field_turns ways round; Vector2.ZERO when it is
## walled in every way. A plate rings only from its face side, so it never faces a wall.
static func _clear_way(at: Vector3, face: Vector2, to_start: Vector2, cfg: RangeConfig, query: WorldQuery) -> Vector2:
	for w: Vector2 in [face, to_start]:
		if w.length() > 1e-6 and not blocked(at, w.normalized(), cfg.field_cover_reach, query):
			return w.normalized()
	var toward := atan2(to_start.x, to_start.y)
	var turns := maxi(1, cfg.field_turns)
	for k in range(1, turns):
		# 1, -1, 2, -2, ... steps either side of your start's way.
		var step := ceili(k / 2.0) * (1 if k % 2 == 1 else -1)
		var a := toward + step * TAU / turns
		var w := Vector2(sin(a), cos(a))
		if not blocked(at, w, cfg.field_cover_reach, query):
			return w
	return Vector2.ZERO


## A target's spec at `at`, facing `yaw`, marked `marked` m away, called `label`.
static func _spec(kind: RangeTarget.Kind, motion: RangeTarget.Motion, at: Vector3, yaw: float, marked: float,
		label: String) -> RangeTarget.Spec:
	var s := RangeTarget.Spec.new()
	s.kind = kind
	s.motion = motion
	s.position = at
	s.yaw = yaw
	s.distance = marked
	s.label = label
	return s


## The `n`th mover on the map at `spot` (its track's middle, on its trolley), at the next of the movers' speeds and
## phases.
static func _mover(spot: Spot, yaw: float, marked: float, n: int, cfg: RangeConfig) -> RangeTarget.Spec:
	var s := _spec(RangeTarget.Kind.FIGURE, RangeTarget.Motion.MOVER,
			spot.position + Vector3.UP * cfg.mover_trolley_height, yaw, marked, MOVER)
	s.track = cfg.field_mover_track
	var speeds := cfg.field_mover_speeds
	s.speed = speeds[n % speeds.size()] if not speeds.is_empty() else 0.0
	s.phase = n * cfg.field_mover_phase_step
	return s


## Whether a mover's track fits at `s`: level floor under both ends, and nothing across its face along it.
static func _mover_fits(s: Spot, nav: NavGrid, query: WorldQuery, cfg: RangeConfig) -> bool:
	if cfg.field_mover_speeds.is_empty():
		return false
	var p := s.position
	# Its own x across its face: the face turned a quarter to the right.
	var right := Vector2(s.face.y, -s.face.x)
	for side: float in [-1.0, 1.0]:
		var end := _floor_at(p.x + right.x * side * cfg.field_mover_track, p.y,
				p.z + right.y * side * cfg.field_mover_track, nav, query, cfg)
		if is_nan(end) or absf(end - p.y) > cfg.field_mover_flat:
			return false
		for h in cfg.field_mover_rays:
			if blocked(p + Vector3.UP * h, right * side, cfg.field_mover_track + cfg.field_mover_margin, query):
				return false
	return true


## Whether a swinger's frame fits at `s`: level floor under both legs, nothing across its swing, nothing over its pivot.
static func _swinger_fits(s: Spot, nav: NavGrid, query: WorldQuery, cfg: RangeConfig) -> bool:
	var p := s.position
	var right := Vector2(s.face.y, -s.face.x)
	# The legs stand just outside the plate's widest swing.
	var leg := cfg.swinger_arm * sin(cfg.swinger_amplitude) + cfg.plate_radius + cfg.swinger_frame_clearance \
			+ cfg.swinger_frame_width
	var plate := p.y + cfg.plate_height
	var pivot := plate + cfg.swinger_arm
	for side: float in [-1.0, 1.0]:
		var under := _floor_at(p.x + right.x * side * leg, p.y, p.z + right.y * side * leg, nav, query, cfg)
		if is_nan(under) or absf(under - p.y) > cfg.field_swinger_flat:
			return false
		for h: float in [plate, pivot]:
			if blocked(Vector3(p.x, h, p.z), right * side, leg + cfg.field_swinger_margin, query):
				return false
	var from := Vector3(p.x, plate, p.z)
	return not query.ray(from, from + Vector3.UP * (pivot - plate + cfg.field_swinger_headroom), _hit)


## The walkable floor's real height at (x, z) on the storey nearest `y`, or NAN where none is walkable.
static func _floor_at(x: float, y: float, z: float, nav: NavGrid, query: WorldQuery, cfg: RangeConfig) -> float:
	var k := nav.node_at(Vector3(x, y, z))
	if k < 0 or nav.walkable[k] != 1:
		return NAN
	return floor_under(x, nav.floor_y[k], z, query, cfg)
