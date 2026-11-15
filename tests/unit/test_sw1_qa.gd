extends GutTest
## SW1, QA: Subway's ticket hall stands on the concourse's level, its lifts have two stops, and the spiral stair works
## for a body walking and for the bots' nav grid; every lane lies on a floor and runs from end to end.

const DT := 1.0 / 60.0
const HALL := Vector3(-28.7, 8.9, 6.6)
const PLATFORM := Vector3(-28.7, 0.9, 6.6)

var tuning: SimTuning = SimTuning.load_default()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null


func before_all() -> void:
	map = MapData.load_map("subway", MapStyle.new(), tuning.rounds.team_size)


func before_each() -> void:
	level = MapLevel.new()
	add_child_autofree(level)
	level.build(map, MapStyle.new(), tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


## Walks a character from `from` along the nav route to `goal`, and returns the ticks it took (-1 if it never got
## within a metre horizontally and half a metre vertically).
func _walk_route(from: Vector3, goal: Vector3, limit: int) -> int:
	var route := PackedVector3Array()
	assert_true(nav.find_route(from, goal, route), "a route on foot")
	var mover := level.mover(tuning.body)
	var c := Character.new(0, 0, from, 0.0, ReplicaStats.default_loadout())
	var leg := 0
	var cmd := PlayerCommand.new()
	for t in limit:
		if leg >= route.size():
			break
		var to := route[leg]
		var d := to - c.position
		if Vector2(d.x, d.z).length() < 0.4:
			leg += 1
			continue
		cmd.forward = 1.0
		cmd.yaw = atan2(-d.x, -d.z)
		Movement.step(c, cmd, tuning.movement, tuning.accuracy, DT, mover)
		var flat := Vector2(c.position.x - goal.x, c.position.z - goal.z).length()
		if flat < 1.0 and absf(c.position.y - goal.y) < 0.5:
			return t
	return -1


func test_a_body_walks_down_the_spiral_to_the_south_platform() -> void:
	var ticks := _walk_route(HALL, PLATFORM, 60 * 40)
	assert_gt(ticks, 0, "reaches the platform")
	assert_lt(ticks, 60 * 25, "in a sane time")


func test_a_body_walks_up_the_spiral_to_the_ticket_hall() -> void:
	var ticks := _walk_route(PLATFORM, HALL, 60 * 40)
	assert_gt(ticks, 0, "reaches the hall")
	assert_lt(ticks, 60 * 25, "in a sane time")


func test_the_bots_route_down_the_spiral_is_short() -> void:
	var route := PackedVector3Array()
	assert_true(nav.find_route(HALL, PLATFORM, route))
	var len := 0.0
	var a := HALL
	for p in route:
		len += a.distance_to(p)
		a = p
	assert_lt(len, 40.0, "the stair, not a lift or a detour")
	assert_lt(a.distance_to(PLATFORM), 1.0)


func test_subway_s_lifts_have_exactly_two_stops() -> void:
	assert_gt(map.lifts.size(), 0)
	for spec in map.lifts:
		assert_eq(spec.stops.size(), 2)
		assert_gt(spec.stops[1], spec.stops[0], "ordered platforms then ticket hall")


func test_every_lane_point_stands_on_a_floor() -> void:
	assert_eq(map.lanes.size(), 5)
	for i in map.lanes.size():
		for p in map.lanes[i]:
			var top := map.floor_under(p.x, p.z, p.y + 0.6)
			assert_almost_eq(top, p.y, 0.6, "lane %d point %s is off the floor (floor %s)" % [i, p, top])


func test_every_lane_reaches_both_ends() -> void:
	var route := PackedVector3Array()
	for i in map.lanes.size():
		var lane := map.lanes[i]
		for e in map.ends.size():
			var spawn := map.ends[e].spawns[0].position
			assert_true(nav.find_route(spawn, lane[0], route, true) or nav.find_route(lane[0], spawn, route, true),
					"lane %d start joins end %d" % [i, e])
			assert_true(nav.find_route(spawn, lane[lane.size() - 1], route, true)
					or nav.find_route(lane[lane.size() - 1], spawn, route, true),
					"lane %d finish joins end %d" % [i, e])
