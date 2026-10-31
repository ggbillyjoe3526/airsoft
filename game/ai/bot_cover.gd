class_name BotCover
## Finding cover from a threat (the browser game's ai/cover.ts): random walkable spots near the bot, the spot right
## behind each low block (crates, barriers: crouch cover you stand up to shoot over) and the lean spots at the corners of
## tall blocks (walls, containers: full cover you lean out of, by the same lean geometry as everyone's). The closest spot
## that hides a crouched player wins, cover you can fight from first, never one that means running at the threat or
## standing where a teammate is. Nothing here allocates except the block lists, built once a match.

## Distances below this (m) count as zero.
const EPSILON := 1e-6


## A block's footprint on the floor: centre and half extents (x, z).
class Block:
	extends RefCounted
	var center: Vector2 = Vector2.ZERO
	var half: Vector2 = Vector2.ZERO


## A cover spot: where (on its floor), whether only crouching hides you there (crouch cover), and which way to lean out
## of full cover to see the threat (-1 left, 1 right, 0 not a lean spot).
class Spot:
	extends RefCounted
	var position: Vector3 = Vector3.ZERO
	var crouch_only: bool = false
	var lean: int = 0


## One search's inputs and best score so far: reused for every search.
class _Search:
	extends RefCounted
	var from: Vector3 = Vector3.ZERO
	var above_floor: float = 0.0
	var threat_eye: Vector3 = Vector3.ZERO
	var radius: float = 0.0
	var threat_dist: float = 0.0
	var peekable: bool = false
	var taken: PackedVector3Array = PackedVector3Array()
	var taken_gap: float = 0.0
	var best: float = INF
	## The night field to keep out of the light of (holding), or null.
	var dark: NightField = null


static var _s: _Search = _Search.new()


## The map's blocks standing on the floor (bottom within low_cover_floor_gap over the floor under them, or sunk at most
## low_cover_floor_sink into it) whose top is between `min_top` and `max_top` above it.
static func floor_blocks(map: MapData, nav: NavGrid, cfg: BotConfig, cell: float, min_top: float,
		max_top: float) -> Array[Block]:
	var out: Array[Block] = []
	for b in map.blocks:
		if b.kind == &"floor" or b.kind == &"ramp":
			continue
		var bottom := b.center.y - b.size.y * 0.5
		var floor_y := _floor_under(nav, b, cell)
		if is_nan(floor_y) or bottom > floor_y + cfg.low_cover_floor_gap or bottom < floor_y - cfg.low_cover_floor_sink:
			continue
		var top := b.center.y + b.size.y * 0.5 - floor_y
		if top <= min_top or top >= max_top:
			continue
		var k := Block.new()
		k.center = Vector2(b.center.x, b.center.z)
		k.half = Vector2(b.size.x, b.size.z) * 0.5
		out.append(k)
	return out


## Low cover: above crouched eyes, below standing ones (crouch cover is exactly 1.2 m; DECISIONS 2026-09-28).
static func low_blocks(map: MapData, nav: NavGrid, cfg: BotConfig, tuning: SimTuning) -> Array[Block]:
	return floor_blocks(map, nav, cfg, tuning.nav.cell, tuning.body.crouch_eye_height, tuning.body.stand_eye_height)


## Full cover: at least as tall as a body.
static func tall_blocks(map: MapData, nav: NavGrid, cfg: BotConfig, tuning: SimTuning) -> Array[Block]:
	return floor_blocks(map, nav, cfg, tuning.nav.cell, tuning.body.height - EPSILON, INF)


## Which way (1 right, -1 left, 0 neither) someone standing at `spot` and facing `threat_eye` can lean to see it: the
## leaned eye has a clear line to the threat and room to lean (no wall within lean_room_margin past it).
static func lean_side_to_see(spot: Vector3, threat_eye: Vector3, w: BotWorld) -> int:
	var body := w.tuning.body
	var yaw := BotAim.look_yaw(spot, threat_eye)
	var upright := spot + Vector3(0.0, body.stand_eye_height, 0.0)
	for i in 2:
		var side := 1 - 2 * i
		var offset := Lean.offset(body.stand_eye_height, side, 0.0, yaw, w.tuning.hits)
		var sideways := Vector2(offset.x, offset.z).length()
		if sideways < EPSILON:
			return 0
		var k := 1.0 + w.cfg.lean_room_margin / sideways
		var reach := upright + Vector3(offset.x * k, offset.y, offset.z * k)
		if BotSenses.line_clear(w.query, upright, reach) and BotSenses.line_clear(w.query, threat_eye, upright + offset):
			return side
	return 0


## True if someone crouched at `spot` (on its floor) is hidden from `threat_eye`.
static func hides_from(spot: Vector3, threat_eye: Vector3, w: BotWorld) -> bool:
	return not BotSenses.line_clear(w.query, threat_eye, spot + Vector3(0.0, w.tuning.body.crouch_eye_height, 0.0))


## Looks for a spot within `radius` of `from` hidden from `threat_eye` (see the class comment), trying `candidates`
## random spots too; `peekable` keeps only spots to fight from. `taken` are spots teammates hold or head for (the first
## `taken_count`). With `keep_dark` (holding), on a field played at night no spot in a light pool counts. Writes the
## best into `out`; false if nothing works.
static func find(from: Vector3, threat_eye: Vector3, w: BotWorld, rng: RandomNumberGenerator, out: Spot, radius: float,
		candidates: int, peekable: bool, taken: PackedVector3Array, taken_count: int, keep_dark: bool = false) -> bool:
	var cfg := w.cfg
	var s := _s
	s.from = from
	var floor_y := w.nav.floor_at(from)
	s.above_floor = 0.0 if is_nan(floor_y) else from.y - floor_y
	s.threat_eye = threat_eye
	s.radius = radius
	s.peekable = peekable
	s.taken = taken
	s.taken_gap = 2.0 * w.tuning.body.radius + cfg.cover_spacing_margin
	s.threat_dist = Vector2(threat_eye.x - from.x, threat_eye.z - from.z).length()
	s.best = INF
	s.dark = w.night if keep_dark else null
	_taken_count = taken_count
	for i in candidates:
		var angle := rng.randf() * TAU
		var r := cfg.cover_min_radius + rng.randf() * (radius - cfg.cover_min_radius)
		_consider(w, out, from.x + cos(angle) * r, from.z + sin(angle) * r)
	var from2 := Vector2(from.x, from.z)
	var threat2 := Vector2(threat_eye.x, threat_eye.z)
	for b in w.low_cover:
		var away := b.center - threat2
		var d := away.length()
		if d < EPSILON or b.center.distance_to(from2) > radius + cfg.low_cover_gap_far + maxf(b.half.x, b.half.y):
			continue
		var u := away / d
		var edge := absf(u.x) * b.half.x + absf(u.y) * b.half.y
		# Hug the block; if that's too tight to stand, a step further back.
		for k in 2:
			var gap := cfg.low_cover_gap if k == 0 else cfg.low_cover_gap_far
			var p := b.center + u * (edge + gap)
			if not w.nav.is_walkable_at(Vector3(p.x, from.y, p.y)):
				continue
			_consider(w, out, p.x, p.y)
			break
	for b in w.tall_cover:
		if b.center.distance_to(from2) > radius + b.half.length():
			continue
		_corner_spots(w, out, b)
	return s.best < INF


## How many of _Search.taken count (set per search).
static var _taken_count: int = 0


## Tests the spot (x, z) and keeps it in `out` if it beats the best so far: walkable, in reach, clear of teammates'
## spots, not towards the threat, out of the light when the search keeps dark, and hiding a crouched player. It
## stands on its cell's floor, as high above it as the searcher stands above its own.
static func _consider(w: BotWorld, out: Spot, x: float, z: float) -> void:
	var cfg := w.cfg
	var s := _s
	var probe := Vector3(x, s.from.y, z)
	if not w.nav.is_walkable_at(probe):
		return
	var r := Vector2(x - s.from.x, z - s.from.z).length()
	if r > s.radius:
		return
	for i in _taken_count:
		var t := s.taken[i]
		if Vector2(t.x - x, t.z - z).length() < s.taken_gap:
			return
	var to_threat := Vector2(s.threat_eye.x - x, s.threat_eye.z - z).length()
	if to_threat < minf(s.threat_dist * cfg.cover_toward_threat_fraction, s.threat_dist - cfg.cover_toward_threat_metres):
		return
	var floor_y := w.nav.floor_at(probe)
	if s.dark != null and s.dark.in_light(Vector3(x, floor_y, z)):
		return
	var spot := Vector3(x, floor_y + s.above_floor, z)
	var body := w.tuning.body
	if BotSenses.line_clear(w.query, s.threat_eye, spot + Vector3(0.0, body.crouch_eye_height, 0.0)):
		return # not cover at all
	var crouch_only := BotSenses.line_clear(w.query, s.threat_eye, spot + Vector3(0.0, body.stand_eye_height, 0.0))
	var lean := 0 if crouch_only else lean_side_to_see(spot, s.threat_eye, w)
	if s.peekable and not crouch_only and lean == 0:
		return
	var score := r - (cfg.crouch_cover_bonus if crouch_only else (cfg.lean_cover_bonus if lean != 0 else 0.0))
	if score < s.best:
		s.best = score
		out.position = spot
		out.crouch_only = crouch_only
		out.lean = lean


## Lean spots at a tall block's two outline corners as the threat sees it.
static func _corner_spots(w: BotWorld, out: Spot, b: Block) -> void:
	var t := Vector2(_s.threat_eye.x, _s.threat_eye.z)
	var c := b.center - t
	if c.length() < EPSILON:
		return
	var min_a := INF
	var max_a := -INF
	var lo := Vector2.ZERO
	var hi := Vector2.ZERO
	for corner in 4:
		var p := b.center + Vector2(b.half.x if (corner & 1) != 0 else -b.half.x,
				b.half.y if (corner & 2) != 0 else -b.half.y)
		var a := c.angle_to(p - t)
		if a < min_a:
			min_a = a
			lo = p
		if a > max_a:
			max_a = a
			hi = p
	_corner_spot(w, out, b, lo)
	_corner_spot(w, out, b, hi)


## The lean spot at `corner` of tall block `b`: on the sight line from the threat past the corner, lean_spot_inset into
## the block's shadow, and far enough along to stand clear of the block.
static func _corner_spot(w: BotWorld, out: Spot, b: Block, corner: Vector2) -> void:
	var cfg := w.cfg
	var clear := cfg.low_cover_gap
	var line := corner - Vector2(_s.threat_eye.x, _s.threat_eye.z)
	var d := line.length()
	if d < EPSILON:
		return
	var u := line / d
	# Into the shadow: across the sight line, towards the block's centre.
	var n := Vector2(-u.y, u.x)
	if n.dot(b.center - corner) < 0.0:
		n = -n
	var p := corner + n * cfg.lean_spot_inset
	var max_along := (b.half * 2.0).length() + clear + cfg.low_cover_gap_far
	var along := clear
	while along <= max_along:
		var q := p + u * along
		along += cfg.lean_spot_step
		if absf(q.x - b.center.x) < b.half.x + clear and absf(q.y - b.center.y) < b.half.y + clear:
			continue
		_consider(w, out, q.x, q.y)
		return


## The floor a block stands on: of the floors under its footprint and a cell round it, the one nearest its bottom (NAN
## if none).
static func _floor_under(nav: NavGrid, b: MapData.Block, step: float) -> float:
	var bottom := b.center.y - b.size.y * 0.5
	var best := NAN
	var lo := b.center - b.size * 0.5
	var hi := b.center + b.size * 0.5
	var x := lo.x - step
	while x <= hi.x + step:
		var z := lo.z - step
		while z <= hi.z + step:
			var f := nav.floor_at(Vector3(x, bottom, z))
			if not is_nan(f) and (is_nan(best) or absf(bottom - f) < absf(bottom - best)):
				best = f
			z += step
		x += step
	return best
