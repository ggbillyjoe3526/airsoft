extends GutTest
## MB2 (QA): Woodland's road stack lowered to a woodpile's 1.8 m with spruce against its east face. The stand leaves
## the south lane walkable round it, and only the six camp gate screens still stand 2.8 m.

const SIDE := 8
## The stack's centre, the stand's box (x from, x to, z from, z to) and the south lane's points either side of it.
const ROAD_STACK := Vector2(20.5, 42.0)
const STAND := Rect2(21.3, 39.0, 1.7, 6.0)
const LANE_WEST := Vector3(20.6, 0.0, 46.4)
const LANE_EAST := Vector3(24.5, 0.0, 43.8)
## The gate screens stand 2.8 m; every other cordwood stack 1.8 m.
const GATE_SCREENS := 6
const CAMP_X := 70.0

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var map: MapData
var nav: NavGrid


func before_all() -> void:
	map = MapData.load_map("woodland", style, SIDE)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func _stack_height(b: MapData.Block) -> float:
	var top := b.center.y + b.size.y * 0.5
	return top - PropLayout.ground_at(map, b.center.x, b.center.z, top)


func test_only_the_six_camp_gate_screens_stand_taller_than_a_woodpile() -> void:
	var tall := PackedStringArray()
	var count := 0
	for b in map.blocks:
		if b.dress != &"cordwood":
			continue
		if _stack_height(b) < 1.2:
			continue  # a log pile, knee high
		if _stack_height(b) > 2.0:
			count += 1
			if absf(b.center.x) < CAMP_X:
				tall.append(str(b.center))
		else:
			assert_almost_eq(_stack_height(b), 1.8, 0.05, "cordwood at %s" % b.center)
	assert_eq(tall.size(), 0, "a 2.8 m stack outside the camps: %s" % [tall])
	assert_eq(count, GATE_SCREENS, "the gate screens stand 2.8 m")


func test_nothing_but_the_stack_and_the_stand_stands_in_the_culvert_stand_box() -> void:
	var box := STAND.grow(0.4)
	var other := PackedStringArray()
	for b in map.blocks:
		var r := Rect2(b.center.x - b.size.x * 0.5, b.center.z - b.size.z * 0.5, b.size.x, b.size.z)
		if not r.intersects(box):
			continue
		var is_stack := b.dress == &"cordwood" and absf(b.center.x - ROAD_STACK.x) < 0.1
		if not (is_stack or b.kind == &"thicket"):
			other.append("%s %s" % [b.kind, b.center])
	assert_eq(other.size(), 0, "blocks cut by the stand: %s" % [other])
	for p in map.poles:
		assert_false(box.has_point(Vector2(p.x, p.z)), "a flag in the stand")
	for e in map.ends:
		for s in e.spawns:
			assert_false(box.has_point(Vector2(s.position.x, s.position.z)), "a spawn in the stand")


func test_the_south_lane_is_walked_round_the_stand_between_its_two_points() -> void:
	var from := Vector3(LANE_WEST.x, nav.floor_at(Vector3(LANE_WEST.x, 50.0, LANE_WEST.z)), LANE_WEST.z)
	var to := Vector3(LANE_EAST.x, nav.floor_at(Vector3(LANE_EAST.x, 50.0, LANE_EAST.z)), LANE_EAST.z)
	var route := PackedVector3Array()
	assert_true(nav.find_route(from, to, route, true), "a route from the lane's west point to its east point")
	assert_true(nav.find_route(to, from, route, true), "and back")
	var open := PackedStringArray()
	for z: float in [45.4, 45.6, 45.8, 46.0, 46.2]:
		for x: float in [21.0, 22.0, 23.0]:
			if not nav.is_walkable_at(Vector3(x, nav.floor_at(Vector3(x, 50.0, z)) + 0.6, z)):
				open.append("(%.1f, %.1f)" % [x, z])
	assert_eq(open.size(), 0, "the gap south of the stand (1.8 m between the faces) is walkable, blocked at %s" % [open])
