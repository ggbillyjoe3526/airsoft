class_name NavVaults
## Vault links (the browser game's nav/vaultLinks.ts, M102): where a body can vault a low obstacle (Vault.plan), a link
## from the node it stands on to the node past the obstacle, so a bot's route can go over it. Found from the grid (a
## walkable node beside a blocked one of the same floor) and the level's rays, along the grid's four axes: the maps'
## blocks are all square to them, so a vault straight across is the one a bot walks. Each link costs its length plus
## `price` metres (a vault is slower than its length on foot, the replica is carried, and it is loud), so a route takes
## one only where it saves more than that walking round.
##
## A climb (CL1: a ledge whose top runs on, a platform's edge from the track) is a link up from the node below to the
## node on the top, found where the next cell has no floor a step from this one; each climb also gives a drop link back
## down, walked off the edge (a bot steps off a platform where a player would hop down), so a pit with no steps is
## no trap for either.
##
## In the search each link is a point of its own between the two nodes (AStar3D prices a step by its length times the
## weight of the point stepped onto), one way, weighted so the two halves cost the link's price.

## The four straight steps, as (di, dj).
const DI: Array[int] = [1, -1, 0, 0]
const DJ: Array[int] = [0, 0, 1, -1]
## How far past the vault's clear point the landing node is looked for, in cells (the first walkable one wins).
const LAND_CELLS: Array[int] = [1, 2, 3]


## How many nodes `find` looks at between looks at the clock.
const CLOCK_EVERY := 256


## A search for a grid's vault links under way (`find`, `finish`): the next node to look at, where each node's links
## start in `to`, the landing nodes found so far and the drops back down each climb gives (from the top's node to the
## one below, in the order found).
class Finder:
	var next: int = 0
	var start: PackedInt32Array = PackedInt32Array()
	var to: PackedInt32Array = PackedInt32Array()
	var drop_from: PackedInt32Array = PackedInt32Array()
	var drop_to: PackedInt32Array = PackedInt32Array()
	var plan: VaultState = VaultState.new()


## Finds `g`'s vault links through `query` (a body standing on each node, from a standstill) and adds them to its
## search, enabled. Once per grid: a second call does nothing. Returns how many there are.
static func link(g: NavGrid, query: WorldQuery, vault: VaultConfig, body: BodyConfig, price: float) -> int:
	if g.vault_base >= 0:
		return g.vault_to.size()
	var f := Finder.new()
	find(f, g, query, vault, body, -1)
	return finish(f, g, price)


## Looks for `g`'s vault links from the nodes `f` has not looked at yet, until `until_usec` (Time.get_ticks_usec) has
## passed, read every CLOCK_EVERY nodes (negative: to the end). True once every node is looked at: the links are the
## same however the search is spread (PlaySession spreads it over the loading screen's frames).
static func find(f: Finder, g: NavGrid, query: WorldQuery, vault: VaultConfig, body: BodyConfig,
		until_usec: int) -> bool:
	var nodes := g.node_count()
	if f.start.size() != nodes + 1:
		f.start.resize(nodes + 1)
	var looked := 0
	while f.next < nodes:
		if until_usec >= 0 and looked == CLOCK_EVERY:
			if Time.get_ticks_usec() >= until_usec:
				return false
			looked = 0
		_find_from(f, g, f.next, query, vault, body)
		f.next += 1
		looked += 1
	f.start[nodes] = f.to.size()
	return true


## The links from node `k` into `f`.
static func _find_from(f: Finder, g: NavGrid, k: int, query: WorldQuery, vault: VaultConfig, body: BodyConfig) -> void:
	f.start[k] = f.to.size()
	# A vault starts and lands standing: never from or onto a floor only a crouched body fits over (CT1).
	if g.walkable[k] == 0 or g.low[k] != 0:
		return
	var c := g.node_cell[k]
	var ci := c % g.cols
	var cj := c / g.cols
	for d in DI.size():
		var ni := ci + DI[d]
		var nj := cj + DJ[d]
		if ni < 0 or nj < 0 or ni >= g.cols or nj >= g.rows:
			continue
		# Beside a blocked node of the same floor (a vault, or a climb at a ledge's foot), or with no floor a step
		# away (only a climb: the next cell's floor is the ledge's top).
		var n := g.step_node(k, nj * g.cols + ni)
		if n >= 0 and g.walkable[n] == 1:
			continue
		var feet := g.node_position(k) + Vector3(0.0, body.rest_gap, 0.0)
		var way := Vector2(DI[d], DJ[d])
		if not Vault.plan(feet, way, 0.0, vault, body, query, f.plan) or (n < 0 and not f.plan.climb):
			continue
		for cells: int in LAND_CELLS:
			var s := f.plan.far + cells * g.cell
			var m := g.node_at(Vector3(feet.x + way.x * s, f.plan.top_y, feet.z + way.y * s))
			if m < 0 or g.walkable[m] == 0 or g.low[m] != 0:
				continue
			f.to.append(m)
			if f.plan.climb:
				f.drop_from.append(m)
				f.drop_to.append(k)
			break


## The links `f` found (its `find` done) added to `g`'s search, each costing its length plus `price` metres at its
## take-off node's weight (a wade's dearer, WS1), and the regions they join. Once per grid: on a grid already linked it does nothing. Returns how many links `g` has.
static func finish(f: Finder, g: NavGrid, price: float) -> int:
	if g.vault_base >= 0:
		return g.vault_to.size()
	var nodes := g.node_count()
	var start := f.start
	var to := f.to
	if not f.drop_from.is_empty():
		_merge_drops(f, nodes)
		start = f.start
		to = f.to
	g.vault_start = start
	g.vault_to = to
	g.vault_base = nodes
	for k in nodes:
		for l in range(start[k], start[k + 1]):
			_add_point(g, k, to[l], nodes + l, g.astar.get_point_weight_scale(k), price)
			join(g.vault_region, g.region[k], g.region[to[l]])
	for r: int in g.vault_region:
		g.vault_region[r] = root(g.vault_region, r)
	return to.size()


## Puts the drops `f` found among its links, by their start node (each node's own links first, then its drops in the
## order found), and forgets them: the grid's links are then one list by start node, as `is_vault_leg` reads them.
static func _merge_drops(f: Finder, nodes: int) -> void:
	# The drops by start node: where each node's begin in `drops` (counted, summed, then filled in the order found).
	var at := PackedInt32Array()
	at.resize(nodes + 1)
	at.fill(0)
	for i in f.drop_from.size():
		at[f.drop_from[i] + 1] += 1
	for k in nodes:
		at[k + 1] += at[k]
	var fill := at.duplicate()
	var drops := PackedInt32Array()
	drops.resize(f.drop_from.size())
	for i in f.drop_from.size():
		drops[fill[f.drop_from[i]]] = f.drop_to[i]
		fill[f.drop_from[i]] += 1
	var start := PackedInt32Array()
	start.resize(nodes + 1)
	var to := PackedInt32Array()
	to.resize(f.to.size() + drops.size())
	var n := 0
	for k in nodes:
		start[k] = n
		for l in range(f.start[k], f.start[k + 1]):
			to[n] = f.to[l]
			n += 1
		for l in range(at[k], at[k + 1]):
			to[n] = drops[l]
			n += 1
	start[nodes] = n
	f.start = start
	f.to = to
	f.drop_from.clear()
	f.drop_to.clear()


## The region `r` is joined to, lowest first, in `joins` (a union-find over the few regions vault and lift links
## touch).
static func root(joins: Dictionary[int, int], r: int) -> int:
	var at := r
	while joins.get(at, at) != at:
		at = joins[at]
	return at


## Joins regions `a` and `b`, the lower one the root.
static func join(joins: Dictionary[int, int], a: int, b: int) -> void:
	var ra := root(joins, a)
	var rb := root(joins, b)
	if ra == rb:
		return
	joins[ra] = mini(ra, rb)
	joins[rb] = mini(ra, rb)


## The link from node `k` to node `m` as search point `id`, between them, so the step on and the step off together cost
## (length + price) at `weight` (its take-off node's).
static func _add_point(g: NavGrid, k: int, m: int, id: int, weight: float, price: float) -> void:
	var a := g.node_position(k)
	var b := g.node_position(m)
	var length := maxf(a.distance_to(b), g.cell)
	var half := length * 0.5
	g.astar.add_point(id, (a + b) * 0.5, weight * (half + price) / half)
	g.astar.connect_points(k, id, false)
	g.astar.connect_points(id, m, false)
