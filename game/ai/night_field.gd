class_name NightField
extends RefCounted
## What bots know about the dark on a field played at night (the browser game's map/nightSight.ts, M33g and M34e; WL6):
## the map's light pools, where the trees close overhead (the canopy grid) and the floors and roofs over each cell, all
## worked out from the map's data once as a match loads, never from scene nodes or lights. `sight_range` says how far
## away someone standing at a point can be made out: lit, under the trees, indoors in the dark or in the moonlit open
## (BotConfig's night sight). By day there is no field (`build` gives null) and sight is as it always was. Pure data;
## the queries allocate nothing.
##
## The weapon torches' light (WL7, the browser's map/torchLight.ts) is worked out here too, once per bot perception
## interval (`update_torches`, BotTorch.refresh): anyone a lit beam's spill falls on, within its reach (across the
## ground) and with no wall between, is made out from `lit`; so is anyone whose own lit torch points within
## torch_seen_from of the viewer (`torch_range`). Allocation-free once its table is as long as the highest id.

## Lit, moonlit-open, under-trees and indoor sight ranges (m), and the pool and roof bands (BotConfig.night_*).
var lit: float = 40.0
var open: float = 25.0
var canopy_range: float = 10.0
var indoor: float = 15.0
var pool_below: float = 0.5
var pool_above: float = 2.0
var roof_from: float = 1.9
var roof_to: float = 9.5
## The light pools (MapData.lights): where each light hangs, its radius squared, and the floor it lights (NAN where
## there is none under it, and then it lights every height). On a map with terrain the ground under the feet is every
## pool's floor instead, so a pool lights the whole of a slope.
var light_at: PackedVector3Array = PackedVector3Array()
var light_radius_sq: PackedFloat64Array = PackedFloat64Array()
var light_floor: PackedFloat64Array = PackedFloat64Array()
var terrain: TerrainGrid = null
## The grid over the blocks' footprint, from (min_x, min_z) in `cell` m cells, cols x rows, row by row along z.
var min_x: float = 0.0
var min_z: float = 0.0
var cell: float = 1.0
var cols: int = 0
var rows: int = 0
## 1 where the cell's middle is under the trees.
var canopy: PackedByteArray = PackedByteArray()
## The undersides of every block but trees over each cell's middle, lowest first: roofs[roof_start[c] ..
## roof_start[c + 1]) for cell c.
var roof_start: PackedInt32Array = PackedInt32Array([0])
var roofs: PackedFloat64Array = PackedFloat64Array()
## Lit by someone else's torch, by character id (1: lit), as of perception interval `torch_stamp` (-1: never), and the
## cosine of BotConfig.night_torch_seen_from_deg.
var torch_lit: PackedByteArray = PackedByteArray()
var torch_stamp: int = -1
var torch_seen_cos: float = 0.5
## How long the build took (µs), for the record.
var build_usec: int = 0

## The torch light's line of sight check (one at a time: the bots think in turn).
static var _torch_hit: RayHit = RayHit.new()


## The night field of `map` with `cfg`'s night sight, or null when the match is played by day (`night`: the playing
## lighting preset's flag, LightingConfig.night). Trunks are the blocks of kind tree.
static func build(map: MapData, cfg: BotConfig, night: bool) -> NightField:
	if not night or map == null:
		return null
	var started := Time.get_ticks_usec()
	var f := NightField.new()
	f.lit = cfg.night_lit
	f.open = cfg.night_open
	f.canopy_range = cfg.night_canopy
	f.indoor = cfg.night_indoor
	f.pool_below = cfg.night_pool_below
	f.pool_above = cfg.night_pool_above
	f.roof_from = cfg.night_roof_from
	f.roof_to = cfg.night_roof_to
	f.torch_seen_cos = cos(deg_to_rad(cfg.night_torch_seen_from_deg))
	f.terrain = map.terrain
	f.cell = cfg.night_canopy_cell
	for l in map.lights:
		f.light_at.append(l.position)
		f.light_radius_sq.append(l.radius * l.radius)
		f.light_floor.append(ground_under(map, l.position.x, l.position.z, l.position.y))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for b in map.blocks:
		lo = lo.min(Vector2(b.center.x - b.size.x * 0.5, b.center.z - b.size.z * 0.5))
		hi = hi.max(Vector2(b.center.x + b.size.x * 0.5, b.center.z + b.size.z * 0.5))
	if is_finite(lo.x):
		f.min_x = lo.x
		f.min_z = lo.y
		f.cols = maxi(1, ceili((hi.x - lo.x) / f.cell))
		f.rows = maxi(1, ceili((hi.y - lo.y) / f.cell))
		f._build_canopy(map, cfg.night_canopy_trees, cfg.night_canopy_radius)
		f._build_roofs(map)
	f.build_usec = Time.get_ticks_usec() - started
	return f


## The walkable ground's height at (x, z) for a light hanging at `below` (m): the terrain's (past its edge, the edge's),
## or the highest floor or ramp top under the light; NAN where there is none.
static func ground_under(map: MapData, x: float, z: float, below: float) -> float:
	if map.terrain != null:
		return map.terrain.height_clamped(x, z)
	var best := NAN
	for b in map.blocks:
		if b.kind != &"floor" and b.kind != &"ramp":
			continue
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		if x < lo.x or x > hi.x or z < lo.z or z > hi.z:
			continue
		var top := MapData.ramp_top(b, x, z) if b.rise != MapData.Rise.NONE else hi.y
		if top <= below and (is_nan(best) or top > best):
			best = top
	return best


## How far away (m) someone with feet at `p` can be made out: lit, under the trees, indoors in the dark, or in the open.
func sight_range(p: Vector3) -> float:
	if in_light(p):
		return lit
	if under_canopy(p):
		return canopy_range
	return indoor if under_roof(p) else open


## Whether feet at `p` stand in a light pool: within its radius across and on the floor it lights (from pool_below under
## that floor to pool_above over it), not on a floor above or below.
func in_light(p: Vector3) -> bool:
	for k in light_at.size():
		var l := light_at[k]
		var dx := p.x - l.x
		var dz := p.z - l.z
		if dx * dx + dz * dz > light_radius_sq[k]:
			continue
		var floor_y := terrain.height_clamped(p.x, p.z) if terrain != null else light_floor[k]
		if is_nan(floor_y) or (p.y >= floor_y - pool_below and p.y <= floor_y + pool_above):
			return true
	return false


## Whether `p` is under the trees (outside the grid: no).
func under_canopy(p: Vector3) -> bool:
	var c := _cell_of(p)
	return c >= 0 and canopy[c] == 1


## Whether feet at `p` stand under a floor or roof: a block's underside between roof_from and roof_to over them.
func under_roof(p: Vector3) -> bool:
	var c := _cell_of(p)
	if c < 0:
		return false
	var lo := p.y + roof_from
	var hi := p.y + roof_to
	for k in range(roof_start[c], roof_start[c + 1]):
		var h := roofs[k]
		if h > hi:
			return false
		if h >= lo:
			return true
	return false


## Works out who the lit torches shine on, once per `stamp` (the bots' perception interval; the same stamp again does
## nothing): for each lit torch (Torch.lit) everyone else in play inside its spill cone from its holder's leaned eye, a
## `height` share up their hit volume (the bots' chest aim), within its reach across the ground and with no level surface
## between. The cone is tested first; only those inside it are ray cast.
func update_torches(characters: Array[Character], query: WorldQuery, tuning: SimTuning, height: float,
		stamp: int) -> void:
	if stamp == torch_stamp:
		return
	torch_stamp = stamp
	var top := -1
	for c in characters:
		top = maxi(top, c.id)
	if torch_lit.size() <= top:
		torch_lit.resize(top + 1)
	torch_lit.fill(0)
	for h in characters:
		if not Torch.lit(h):
			continue
		var light := Torch.in_hand(h)
		var cos_half := cos(deg_to_rad(light.spill_deg * 0.5))
		var eye := Lean.eye(h, tuning.body, tuning.hits)
		var aim := h.view_direction()
		var reach_sq := light.reach * light.reach
		for t in characters:
			if t == h or torch_lit[t.id] == 1 or not Elimination.is_in_play(t):
				continue
			var point := t.position + Vector3(0.0, Hitbox.hit_top(t.crouch_amount, tuning.hits) * height, 0.0)
			var ray := point - eye
			if ray.x * ray.x + ray.z * ray.z > reach_sq:
				continue
			var d := ray.length()
			if d < 1e-6 or ray.dot(aim) < cos_half * d:
				continue
			# A beam lights through glass (BQ1).
			if not query.sight_ray(eye, point, _torch_hit):
				torch_lit[t.id] = 1


## How far `viewer` makes `target` out by torchlight (m): `lit` while a beam shines on the target, or while the
## target's own lit torch points within torch_seen_from of the viewer across the ground (its lens gives it away); else 0.
func torch_range(viewer: Character, target: Character) -> float:
	if target.id < torch_lit.size() and torch_lit[target.id] == 1:
		return lit
	if not Torch.lit(target):
		return 0.0
	var dx := viewer.position.x - target.position.x
	var dz := viewer.position.z - target.position.z
	var flat := sqrt(dx * dx + dz * dz)
	if flat < 1e-6:
		return lit
	var aim := target.view_direction()
	var along := sqrt(aim.x * aim.x + aim.z * aim.z)
	if along < 1e-6:
		return 0.0
	return lit if (aim.x * dx + aim.z * dz) / (along * flat) >= torch_seen_cos else 0.0


## How far `viewer` makes `target` out at night: by the light round the target, or by torchlight if that is further.
func range_between(viewer: Character, target: Character) -> float:
	return maxf(sight_range(target.position), torch_range(viewer, target))


## The cell holding (p.x, p.z), or -1 outside the grid.
func _cell_of(p: Vector3) -> int:
	var i := floori((p.x - min_x) / cell)
	var j := floori((p.z - min_z) / cell)
	if i < 0 or j < 0 or i >= cols or j >= rows:
		return -1
	return j * cols + i


## The canopy grid: each trunk counted into the cells whose middle it stands within `radius` of (the browser's per-cell
## count over every trunk, the same cells, from the trunks' side: a few dozen cells a trunk, not every trunk a cell).
func _build_canopy(map: MapData, trees: int, radius: float) -> void:
	var count := PackedInt32Array()
	count.resize(cols * rows)
	var r2 := radius * radius
	for b in map.blocks:
		if b.kind != &"tree":
			continue
		var i0 := maxi(0, floori((b.center.x - radius - min_x) / cell) - 1)
		var i1 := mini(cols - 1, floori((b.center.x + radius - min_x) / cell) + 1)
		var j0 := maxi(0, floori((b.center.z - radius - min_z) / cell) - 1)
		var j1 := mini(rows - 1, floori((b.center.z + radius - min_z) / cell) + 1)
		for j in range(j0, j1 + 1):
			var dz := b.center.z - (min_z + (j + 0.5) * cell)
			for i in range(i0, i1 + 1):
				var dx := b.center.x - (min_x + (i + 0.5) * cell)
				if dx * dx + dz * dz <= r2:
					count[j * cols + i] += 1
	canopy.resize(cols * rows)
	for c in count.size():
		canopy[c] = 1 if count[c] >= trees else 0


## The undersides over each cell's middle (roof_start, roofs): every block but trees whose footprint holds the middle,
## counted, then filed, then each cell's sorted lowest first.
func _build_roofs(map: MapData) -> void:
	var n := cols * rows
	roof_start.resize(n + 1)
	roof_start.fill(0)
	for pass_index in 2:
		var fill := PackedInt32Array()
		if pass_index == 1:
			# Counts to starts; `fill` walks each cell's slice as it is filed.
			var total := 0
			for c in n:
				var here := roof_start[c]
				roof_start[c] = total
				total += here
			roof_start[n] = total
			roofs.resize(total)
			fill = roof_start.duplicate()
		for b in map.blocks:
			if b.kind == &"tree":
				continue
			var half := b.size * 0.5
			var i0 := maxi(0, floori((b.center.x - half.x - min_x) / cell) - 1)
			var i1 := mini(cols - 1, floori((b.center.x + half.x - min_x) / cell) + 1)
			var j0 := maxi(0, floori((b.center.z - half.z - min_z) / cell) - 1)
			var j1 := mini(rows - 1, floori((b.center.z + half.z - min_z) / cell) + 1)
			var bottom := b.center.y - half.y
			for j in range(j0, j1 + 1):
				if absf(min_z + (j + 0.5) * cell - b.center.z) > half.z:
					continue
				for i in range(i0, i1 + 1):
					if absf(min_x + (i + 0.5) * cell - b.center.x) > half.x:
						continue
					var c := j * cols + i
					if pass_index == 0:
						roof_start[c] += 1
					else:
						roofs[fill[c]] = bottom
						fill[c] += 1
	for c in n:
		_sort_slice(roof_start[c], roof_start[c + 1])


## Insertion sort of roofs[from .. to) (a cell holds a handful at most).
func _sort_slice(from: int, to: int) -> void:
	for k in range(from + 1, to):
		var v := roofs[k]
		var m := k - 1
		while m >= from and roofs[m] > v:
			roofs[m + 1] = roofs[m]
			m -= 1
		roofs[m + 1] = v
