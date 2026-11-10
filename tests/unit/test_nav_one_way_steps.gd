extends GutTest
## No shipped map has a one-way step (WL1; BP7 row 46): a step the route search takes one way only (a diagonal past a
## corner from one side). NavGrid.region joins nodes linked either way, so a route to a region joined to the start only
## by such a step would search the whole grid before failing. Rather than a directed region check that costs every
## build time for nothing, this check fails the day a map gains one.

var catalog: MapCatalog
var style: MapStyle
var tuning: SimTuning


func before_all() -> void:
	catalog = MapCatalog.read_file()
	style = PlayTuning.load_default().map_style
	tuning = SimTuning.load_default()


## The steps between walkable nodes of `nav` linked one way only, as "node>node" (at most `most` of them).
static func one_way_steps(nav: NavGrid, most: int = 8) -> PackedStringArray:
	var out := PackedStringArray()
	var d_count := NavGridBuilder.DIRECTIONS
	for k in nav.node_count():
		if nav.walkable[k] == 0:
			continue
		for d in d_count:
			var n := nav.steps[k * d_count + d]
			# each pair once, from its lower node
			if n <= k or nav.walkable[n] == 0:
				continue
			if nav.astar.are_points_connected(k, n, false) != nav.astar.are_points_connected(n, k, false):
				out.append("%d>%d at %s" % [k, n, nav.node_position(k)])
				if out.size() >= most:
					return out
	return out


func test_no_shipped_map_has_a_one_way_step() -> void:
	var checked := 0
	for e in catalog.entries:
		var m := MapData.load_map(e.id, style, 1)
		if not m.ok():
			continue
		var nav := NavGrid.build(m, tuning.nav, tuning.body)
		assert_eq(one_way_steps(nav), PackedStringArray(), "%s has no one-way step" % e.id)
		checked += 1
	assert_eq(checked, catalog.entries.size(), "every shipped map, the range too")
	assert_gt(checked, 2, "Depot, Woodland and the range at least")


func test_the_check_finds_a_one_way_step() -> void:
	var m := MapData.load_map("depot", style, 1)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	assert_eq(one_way_steps(nav).size(), 0)
	# cut one link's way back: the check must see it
	var d_count := NavGridBuilder.DIRECTIONS
	for k in nav.node_count():
		if nav.walkable[k] == 0:
			continue
		var n := nav.steps[k * d_count]
		if n > k and nav.walkable[n] == 1 and nav.astar.are_points_connected(k, n):
			nav.astar.disconnect_points(n, k, false)
			break
	assert_eq(one_way_steps(nav).size(), 1, "one step left one way")
