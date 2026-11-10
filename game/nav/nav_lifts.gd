class_name NavLifts
## Lift links (MT2): a link from each stop's landing node to every other stop's of the same lift, so a bot's route can
## ride a car (BotLifts walks it: call, board, press, ride, walk out). Each link costs the ride's time on foot: the
## doors shutting and opening (LiftConfig.door_time each), floor_time a stop on the way and `wait` for the car to come,
## at `speed` m/s (a running bot's pace), so a route takes a lift only where the stairs and escalators are longer still.
## The landing node is the walkable node nearest LiftSpec.landing_point on the stop's floor.
##
## In the search each link is a point of its own between the two nodes (as NavVaults'), one way, weighted so the two
## halves cost the link's price, its ids from lift_base = the grid's nodes + ID_OFFSET (clear of the vault links' ids,
## found before or after). A walk-off never rides (find_route without `vaults`).

## Lift links' search ids start this far past the grid's nodes: past any vault link's.
const ID_OFFSET := 1 << 24
## A landing node is looked for this far round its landing point (m).
const LANDING_SNAP := 0.6


## Adds `query`'s lifts' links to `g`'s search, enabled, each costing its ride as above, and joins the regions they
## link. Once per grid: a second call does nothing. Returns how many links `g` has.
static func link(g: NavGrid, query: WorldQuery, cfg: LiftConfig, speed: float, wait: float) -> int:
	if g.lift_base >= 0 or g.node_count() == 0:
		return g.lift_to.size()
	g.lift_base = g.node_count() + ID_OFFSET
	for i in query.lift_count():
		var spec := query.lifts[i]
		var landing := PackedInt32Array()
		for k in spec.stop_count():
			var n := g.nearest_walkable(spec.landing_point(k, cfg), LANDING_SNAP)
			# A landing on another floor than the stop's isn't its landing.
			landing.append(n if n >= 0 and absf(g.floor_y[n] - spec.stops[k]) <= g.max_step else -1)
		g.lift_wells.append(spec.well)
		g.lift_stop_y.append(spec.stops)
		g.lift_landing.append(landing)
		for a in spec.stop_count():
			for b in spec.stop_count():
				if a == b or landing[a] < 0 or landing[b] < 0:
					continue
				var seconds := cfg.door_time * 2.0 + cfg.floor_time * absi(b - a) + wait
				var l := g.lift_to.size()
				g.lift_from.append(landing[a])
				g.lift_to.append(landing[b])
				g.lift_of.append(i)
				g.lift_stop_from.append(a)
				g.lift_stop_to.append(b)
				_add_point(g, landing[a], landing[b], g.lift_base + l, g.astar.get_point_weight_scale(landing[a]),
						seconds * speed)
				NavVaults.join(g.vault_region, g.region[landing[a]], g.region[landing[b]])
	for r: int in g.vault_region:
		g.vault_region[r] = NavVaults.root(g.vault_region, r)
	return g.lift_to.size()


## The link from node `k` to node `m` as search point `id`, between them, so the step on and the step off together cost
## `price` metres at the grid's `weight`.
static func _add_point(g: NavGrid, k: int, m: int, id: int, weight: float, price: float) -> void:
	var a := g.node_position(k)
	var b := g.node_position(m)
	var half := maxf(a.distance_to(b), g.cell) * 0.5
	g.astar.add_point(id, (a + b) * 0.5, weight * price * 0.5 / half)
	g.astar.connect_points(k, id, false)
	g.astar.connect_points(id, m, false)
