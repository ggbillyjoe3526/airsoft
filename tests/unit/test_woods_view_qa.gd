extends GutTest
## WL4's wood, hunted for what its own tests leave open: a collider anywhere in the physics world (the match test keeps
## the shared fixture in the tree for both runs and only sees what reaches a bot), odd `dressing` data, a wood on a
## map with no sloping ground, the view built and freed again and again, and its parts across every preset.

const FLAT := """{"name": "Yard", "blocks": [
	{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 20, "y": 0.5, "z": 20}},
	{"kind": "tree", "center": {"x": 2, "y": 3, "z": 2}, "size": {"x": 0.5, "y": 6, "z": 0.5}}],
	"spawns": [[{"position": {"x": -5, "y": 0, "z": 0}}], [{"position": {"x": 5, "y": 0, "z": 0}}]],
	"deadZones": [[{"position": {"x": -6, "y": 0, "z": 6}}], [{"position": {"x": 6, "y": 0, "z": 6}}]],
	"dressing": {"seed": 5, "woods": {"leaves": 0.5, "fallen": 0.5}, "moss": {"colour": 4820770, "share": 0.5},
		"puddles": [{"x": 0, "z": 0, "width": 3, "depth": 3}], "fireflies": {"count": 20},
		"grass": {"height": 0.3}, "motes": {"tint": 16777215}, "forest": {"trees": 50}}}"""
## A yard whose dressing is of the wrong types altogether.
const WRONG := ["5", "[]", "null", "\"x\"", "{\"puddles\": \"x\", \"woods\": 3, \"moss\": null, \"motes\": 5}",
		"{\"puddles\": [null, 4, [], {\"x\": 1}], \"fireflies\": [], \"forest\": \"many\", \"grass\": null}",
		"{\"puddles\": [{\"x\": 0, \"z\": 0, \"width\": 1e30, \"depth\": 1}], \"grass\": {\"height\": -1}}"]

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.load_default()
var woodland: MapData = null
var night: LightingConfig = null
var view: WoodsView = null


func before_all() -> void:
	woodland = MapData.load_map("woodland", play.map_style, 1)
	night = LightingConfig.for_map(play.lighting, play.night_lighting, woodland, LightingConfig.NIGHT)


func _yard(dressing: String) -> MapData:
	var text := FLAT
	var from := text.find("\"dressing\"")
	return MapData.parse(text.substr(0, from) + "\"dressing\": %s}" % dressing, play.map_style, 1)


## What a sweep of rays through the whole physics world meets: straight down over a grid of the field from far above,
## and across it along the x axis at the crowns' and the forest's heights.
func _sweep() -> PackedVector3Array:
	var space := get_viewport().world_3d.direct_space_state
	var field := WoodsShapes.field_rect(woodland)
	var out := PackedVector3Array()
	var n := 40
	for j in n:
		for i in n:
			var x := field.position.x + field.size.x * (i + 0.5) / n
			var z := field.position.y + field.size.y * (j + 0.5) / n
			out.append(_cast(space, Vector3(x, 80.0, z), Vector3(x, -30.0, z)))
	for h: float in [0.6, 1.5, 2.5, 4.0, 7.0, 12.0]:
		for j in n:
			var z := field.position.y + field.size.y * (j + 0.5) / n
			out.append(_cast(space, Vector3(field.position.x - 60.0, h, z), Vector3(field.end.x + 60.0, h, z)))
	return out


func _cast(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(q)
	return Vector3(hit["position"]) if not hit.is_empty() else Vector3(INF, INF, INF)


func test_the_wood_in_the_tree_changes_no_ray_through_the_physics_world() -> void:
	var run := MatchRunner.new(self, "woodland", tuning)
	await wait_physics_frames(3)
	var bare := _sweep()
	var dressed := WoodsView.build(run.map, play.woods, play.skyline, night, play.map_style)
	add_child(dressed)
	dressed.set_quality(GraphicsQuality.MeshDetail.ULTRA, 1.0)
	await wait_physics_frames(3)
	var with_it := _sweep()
	dressed.free()
	run.free_level()
	assert_gt(bare.size(), 1000, "a real sweep")
	assert_true(bare == with_it, "every ray meets what it met without the wood")


func test_the_sweep_would_see_a_collider_on_a_crown() -> void:
	# the guard above is worth something only if it fails for a leak: a body on the first crown, found by a ray
	var run := MatchRunner.new(self, "woodland", tuning)
	var dressed := WoodsView.build(run.map, play.woods, play.skyline, night, play.map_style)
	add_child(dressed)
	await wait_physics_frames(3)
	var before := _sweep()
	var x := WoodsShapes.crowns(run.map, play.woods).xforms[0]
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = x.basis.y.length() * 0.5
	shape.shape = sphere
	body.add_child(shape)
	body.position = x.origin + Vector3(0.0, sphere.radius, 0.0)
	dressed.add_child(body)
	await wait_physics_frames(3)
	var after := _sweep()
	dressed.free()
	run.free_level()
	assert_false(before == after, "a leaked collider on a crown shows in the sweep")


func test_wrong_typed_dressing_warns_and_builds_without_error() -> void:
	for dressing: String in WRONG:
		var m := _yard(dressing)
		assert_true(m.ok(), "the yard loads with dressing %s: %s" % [dressing, m.problems])
		var built := WoodsView.build(m, play.woods, play.skyline, night, play.map_style)
		if built != null:
			built.set_quality(GraphicsQuality.MeshDetail.ULTRA, 1.0)
			built.free()
	assert_true(true, "no script error stopped it")


func test_a_flat_map_with_a_wood_builds_what_needs_no_slope() -> void:
	var m := _yard(FLAT.substr(FLAT.find("\"dressing\"") + 12, FLAT.length()).trim_suffix("}"))
	assert_eq(m.warnings, [] as Array[String], "no warning")
	assert_null(m.terrain, "a flat yard")
	var v := WoodsView.build(m, play.woods, play.skyline, night, play.map_style)
	assert_not_null(v, "the tree's crown and the forest and the air")
	assert_not_null(v.crowns())
	assert_null(v.puddles(), "no puddles without sloping ground")
	assert_eq(v.tufts().size(), 0, "no grass without sloping ground")
	for step: int in GraphicsQuality.MeshDetail.values():
		v.set_quality(step, 1.0)
	v.free()


func test_no_dressing_builds_no_view() -> void:
	for id: String in ["depot", "range"]:
		var m := MapData.load_map(id, play.map_style, 1)
		if not m.ok():
			continue
		var has_tree := m.blocks.any(func(b: MapData.Block) -> bool: return b.kind == WoodsShapes.TREE)
		var v := WoodsView.build(m, play.woods, play.skyline, play.lighting, play.map_style)
		# Depot's and the range's puddles are read but lie on no sloping ground: nothing is drawn
		assert_eq(v != null, has_tree or m.forest_trees > 0 or m.fireflies > 0 or m.moss_share > 0.0
				or (m.terrain != null and (not m.puddles.is_empty() or m.leaf_drifts > 0.0 or m.fallen > 0.0)),
				"%s builds a view only for a wood" % id)
		if v != null:
			v.free()


func test_building_and_freeing_the_wood_over_and_over_leaves_nothing_behind() -> void:
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 4:
		var v := WoodsView.build(woodland, play.woods, play.skyline, night, play.map_style)
		add_child(v)
		for step: int in GraphicsQuality.MeshDetail.values():
			v.set_quality(step, 0.5 * (i % 3))
			v.set_motion(MotionScale.of(i % 2 == 0))
		remove_child(v)
		v.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node left")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no orphan")


func test_changing_the_preset_adds_and_removes_no_node() -> void:
	var v := WoodsView.build(woodland, play.woods, play.skyline, night, play.map_style)
	add_child(v)
	var count := 0
	var pending: Array[Node] = [v]
	while not pending.is_empty():
		var n: Node = pending.pop_back()
		count += 1
		pending.append_array(n.get_children())
	for step: int in [3, 0, 2, 1, 3, 0]:
		v.set_quality(step, 1.0)
	var after := 0
	pending = [v]
	while not pending.is_empty():
		var n: Node = pending.pop_back()
		after += 1
		pending.append_array(n.get_children())
	v.free()
	assert_eq(after, count, "the same nodes on every preset: parts hide, none come or go")


func test_the_air_is_drawn_by_night_only_on_every_map() -> void:
	for id: String in ["depot", "range", "woodland"]:
		var m := MapData.load_map(id, play.map_style, 1)
		var day := WoodsView.build(m, play.woods, play.skyline, play.lighting, play.map_style)
		if day != null:
			assert_null(day.air(), "%s by day" % id)
			day.free()


func _bodies_in(root: Node) -> int:
	var n := 0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var c: Node = pending.pop_back()
		pending.append_array(c.get_children())
		n += 1 if c is CollisionObject3D else 0
	return n


func test_a_woodland_match_wires_the_wood_to_the_presets_and_frees_it_with_the_session() -> void:
	var table := GraphicsTable.shared()
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var counts: Array[int] = []
	for round_no in 2:
		var session := PlaySession.new()
		session.map_id = "woodland"
		session.lighting_pick = LightingConfig.NIGHT # its second preset since WR1: fireflies fly by night
		session.autopilot = true
		add_child(session)
		await wait_physics_frames(2)
		var woods: WoodsView = session._woods
		assert_not_null(woods, "the session builds the wood")
		assert_eq(session.get_children().filter(func(c: Node) -> bool: return c is WoodsView).size(), 1, "once")
		assert_not_null(woods.air(), "Woodland by night: fireflies")
		var shape_bodies := _bodies_in(woods)
		assert_eq(shape_bodies, 0, "no body under the wood")
		for preset: StringName in [&"low", &"medium", &"high", &"ultra", &"low"]:
			session._apply_graphics(table.preset(preset))
			assert_true(woods.crowns().visible, "crowns on %s" % preset)
			assert_eq(woods.puddles().visible, preset != &"low", "puddles on %s" % preset)
			assert_eq(woods.forest().visible, preset != &"low", "forest on %s" % preset)
		counts.append(woods.get_child_count())
		await wait_physics_frames(30)
		remove_child(session)
		session.free()
		await wait_process_frames(2)
	assert_eq(counts[0], counts[1], "a second match builds the same wood, not more")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node left behind")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no orphan")
