class_name NavSmoke
extends RefCounted
## Smoke clouds priced on the nav grid (AUD2, the owner: "make them route around"): while a smoke bomb's cloud stands
## (Grenade.popped, until the simulation ends it, smoke_time on), every walkable node whose eyes would be in its full
## cloud costs NavConfig.smoke_cost times as much to step onto, so a route goes round a cloud where it can and through
## it only where it must (a cost, not a wall: a route from inside one, or with no way round, still goes). Put on the
## tick a cloud pops and taken off the tick its bomb is gone (a new round's clear too); one riding a lift's car moves
## its price with it. Overlapping clouds count per node, and smoke_cost is a power of two, so taking a price off gives
## back the node's own weight exactly. Lives on its grid (NavGrid.smoke), so whoever routes on it next (the next match's
## bots) starts from what is priced; `release` takes every price off. Nothing is allocated per tick: the per-node counts
## once per grid, the per-bomb places once per pool size.

## Per node: how many clouds price it.
var _count: PackedByteArray = PackedByteArray()
## Per bomb slot of the pool priced: 1 while its cloud is priced, and the cloud's middle and the eye height it was
## priced at.
var _priced: PackedByteArray = PackedByteArray()
var _at: PackedVector3Array = PackedVector3Array()
## Clouds priced now, and the full cloud's size and the eye height they were priced with (for depth).
var _live: int = 0
var _radius: float = 0.0
var _up: float = 0.0
var eye: float = 0.0


## Brings the prices on `g` in line with `pool`'s clouds (`cfg` the bombs', `nav` the grid's tuning, `eye` a standing
## body's eye height over its floor): each cloud that popped is priced, each priced one gone is taken off.
func step(g: NavGrid, pool: Array[Grenade], cfg: GrenadeConfig, nav: NavConfig, eye_height: float) -> void:
	eye = eye_height
	_radius = cfg.smoke_radius
	_up = cfg.smoke_height
	if _priced.size() < pool.size():
		_priced.resize(pool.size())
		_at.resize(pool.size())
	for i in _priced.size():
		var smoking := i < pool.size() and _smoking(pool[i])
		if _priced[i] == 1:
			if smoking and _at[i].distance_squared_to(_full_middle(pool[i], cfg)) < g.cell * g.cell * 0.25:
				continue
			_price(g, _at[i], cfg, nav, eye, false)
			_priced[i] = 0
			_live -= 1
		if smoking:
			_at[i] = _full_middle(pool[i], cfg)
			_price(g, _at[i], cfg, nav, eye, true)
			_priced[i] = 1
			_live += 1


## Takes every price off `g` (a new match's bots, or none left to route).
func release(g: NavGrid, cfg: GrenadeConfig, nav: NavConfig, eye_height: float) -> void:
	for i in _priced.size():
		if _priced[i] == 1:
			_price(g, _at[i], cfg, nav, eye_height, false)
			_priced[i] = 0
	_live = 0


## Whether any cloud is priced now.
func live() -> bool:
	return _live > 0


## Whether node `k` of `g` is priced by a cloud now.
func priced(k: int) -> bool:
	return k >= 0 and k < _count.size() and _count[k] > 0


## How far the line from `a` to `b` runs through the priced clouds (m, summed), counting no further once past `most`:
## the string-pulling's check (NavRoute), so a leg doesn't cut back through a cloud its route went round.
func depth(a: Vector3, b: Vector3, most: float = INF) -> float:
	var d := b - a
	var length := d.length()
	if _live == 0 or length < 1e-6:
		return 0.0
	var total := 0.0
	for i in _priced.size():
		if _priced[i] == 0:
			continue
		var m := _at[i]
		var p := Vector3((a.x - m.x) / _radius, (a.y - m.y) / _up, (a.z - m.z) / _radius)
		var q := Vector3(d.x / _radius, d.y / _up, d.z / _radius)
		var qq := q.dot(q)
		var pq := p.dot(q)
		var disc := pq * pq - qq * (p.dot(p) - 1.0)
		if disc <= 0.0:
			continue
		var root := sqrt(disc)
		var t0 := maxf(0.0, (-pq - root) / qq)
		var t1 := minf(1.0, (-pq + root) / qq)
		if t1 > t0:
			total += (t1 - t0) * length
			if total > most:
				return total
	return total


func _smoking(b: Grenade) -> bool:
	return b.active and b.popped and b.kind == Grenade.Kind.SMOKE


## The middle of `b`'s full cloud (its canister, smoke_lift up): where it stands once grown.
static func _full_middle(b: Grenade, cfg: GrenadeConfig) -> Vector3:
	return b.position + Vector3(0.0, cfg.smoke_lift, 0.0)


## Puts on (`on`) or takes off the price of a full cloud round `middle`: every walkable node whose point `eye_height`
## over its floor is inside the cloud's ellipsoid.
func _price(g: NavGrid, middle: Vector3, cfg: GrenadeConfig, nav: NavConfig, eye_height: float, on: bool) -> void:
	if _count.size() < g.node_count():
		_count.resize(g.node_count())
	var r := cfg.smoke_radius
	var up := cfg.smoke_height
	if g.astar == null or not (r > 0.0) or not (up > 0.0):
		return
	var i0 := maxi(0, ceili((middle.x - r - g.min_x) / g.cell - 0.5))
	var i1 := mini(g.cols - 1, floori((middle.x + r - g.min_x) / g.cell - 0.5))
	var j0 := maxi(0, ceili((middle.z - r - g.min_z) / g.cell - 0.5))
	var j1 := mini(g.rows - 1, floori((middle.z + r - g.min_z) / g.cell - 0.5))
	for j in range(j0, j1 + 1):
		var dz := (g.cell_z(j) - middle.z) / r
		for ci in range(i0, i1 + 1):
			var dx := (g.cell_x(ci) - middle.x) / r
			if dx * dx + dz * dz > 1.0:
				continue
			var c := j * g.cols + ci
			for k in range(g.cell_start[c], g.cell_start[c + 1]):
				if g.walkable[k] == 0:
					continue
				var dy := (g.floor_y[k] + eye_height - middle.y) / up
				if dx * dx + dy * dy + dz * dz > 1.0:
					continue
				if on:
					_count[k] += 1
					if _count[k] == 1:
						g.astar.set_point_weight_scale(k, g.astar.get_point_weight_scale(k) * nav.smoke_cost)
				elif _count[k] > 0:
					_count[k] -= 1
					if _count[k] == 0:
						g.astar.set_point_weight_scale(k, g.astar.get_point_weight_scale(k) / nav.smoke_cost)
