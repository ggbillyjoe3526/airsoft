extends GutTest
## HD1 (the owner's playtest item 5): QA's hunt over the tier bodies, TierSteps' merge and RoundSteps' trunk tiers.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _woodland() -> MapData:
	return MapData.load_map("woodland", play.map_style, tuning.rounds.team_size)


func _trees(m: MapData) -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	for b: MapData.Block in m.blocks:
		if b.rise == MapData.Rise.NONE and play.map_style.round_trunk_tiers.has(play.site_look.props.model_of(b)) \
				and play.site_look.props.lay_of(b) == PropDressConfig.Lay.TREE:
			out.append(b)
	return out


func _meet(rects: Array[Rect2]) -> bool:
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].grow(TierSteps.MEET).intersects(rects[j]):
				return true
	return false


func test_merge_leaves_no_two_rects_meeting_and_covers_every_input() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for round in 40:
		var inputs: Array[Rect2] = []
		for k in rng.randi_range(0, 25):
			inputs.append(Rect2(rng.randf() * 10.0, rng.randf() * 10.0, rng.randf() * 2.0, rng.randf() * 2.0))
		var rects: Array[Rect2] = inputs.duplicate()
		TierSteps._merge(rects)
		assert_false(_meet(rects), "no two output rects meet (round %d)" % round)
		for r: Rect2 in inputs:
			var held := false
			for o: Rect2 in rects:
				held = held or o.grow(0.0001).encloses(r)
			assert_true(held, "an output rect holds each input (round %d)" % round)


func test_merge_of_empty_and_single_inputs_is_unchanged() -> void:
	var none: Array[Rect2] = []
	TierSteps._merge(none)
	assert_eq(none.size(), 0)
	var one: Array[Rect2] = [Rect2(1, 1, 2, 2)]
	TierSteps._merge(one)
	assert_eq(one, [Rect2(1, 1, 2, 2)] as Array[Rect2])


func test_every_woodland_thicket_tier_box_stays_in_its_block_and_is_finite() -> void:
	var m := _woodland()
	var others := TierSteps.tiered_blocks(m, play.map_style, play.site_look.props)
	var out: Array[AABB] = []
	var bad := 0
	var shut := 0
	for b: MapData.Block in others:
		TierSteps.boxes(b, play.map_style, play.site_look.props, others, out)
		if out.is_empty():
			shut += 1
		var box := AABB(b.center - b.size * 0.5, b.size).grow(0.001)
		for t: AABB in out:
			if not box.encloses(t) or t.size.x < 0.0 or t.size.y < 0.0 or t.size.z < 0.0 or not t.position.is_finite():
				bad += 1
	assert_eq(bad, 0, "tier boxes in the block, finite, non-negative")
	assert_lt(shut, others.size(), "not every thicket is shut")


func test_a_single_spruce_and_a_one_metre_deep_thicket_make_tiers_in_their_box() -> void:
	var m := _woodland()
	var others := TierSteps.tiered_blocks(m, play.map_style, play.site_look.props)
	var seen := 0
	var out: Array[AABB] = []
	for b: MapData.Block in others:
		var cell: Vector3 = play.site_look.props.grid_cells.get(play.site_look.props.model_of(b), b.size)
		if minf(b.size.x, b.size.z) > cell.x * 1.5:
			continue
		seen += 1
		TierSteps.boxes(b, play.map_style, play.site_look.props, [] as Array[MapData.Block], out)
		assert_false(out.is_empty(), "a narrow thicket alone at %s has tiers" % b.center)
		var box := AABB(b.center - b.size * 0.5, b.size).grow(0.001)
		for t: AABB in out:
			assert_true(box.encloses(t))
	gut.p("narrow thickets seen: %d" % seen)


func test_trunk_tiers_with_nan_ground_or_ground_above_the_top_stay_in_the_box() -> void:
	var trees := _trees(_woodland())
	assert_gt(trees.size(), 50, "Woodland has trunk-tiered trees")
	var out: Array[AABB] = []
	for b: MapData.Block in trees.slice(0, 60):
		var box := AABB(b.center - b.size * 0.5, b.size).grow(0.001)
		for g: float in [NAN, b.center.y + b.size.y * 5.0, b.center.y - b.size.y * 5.0, b.center.y + b.size.y * 0.5]:
			RoundSteps.boxes(b, play.map_style, play.site_look.props, Vector3.ZERO, out, g)
			assert_false(out.is_empty(), "a tree makes boxes for ground %s" % g)
			for t: AABB in out:
				assert_true(t.position.is_finite() and t.size.is_finite(), "finite for ground %s" % g)
				assert_true(t.size.y >= 0.0 and box.encloses(t), "in the box for ground %s" % g)


func test_trunk_tiers_are_contiguous_up_the_tree_from_its_foot_to_its_top() -> void:
	var b := _trees(_woodland())[0]
	var out: Array[AABB] = []
	RoundSteps.boxes(b, play.map_style, play.site_look.props, Vector3.ZERO, out, b.center.y - b.size.y * 0.5 + 0.4)
	var low := b.center.y - b.size.y * 0.5
	var top := low + b.size.y
	var lo := INF
	var hi := -INF
	for t: AABB in out:
		lo = minf(lo, t.position.y)
		hi = maxf(hi, t.end.y)
	assert_almost_eq(lo, low, 0.001, "the first tier starts at the box's foot")
	assert_almost_eq(hi, top, 0.001, "the last tier reaches the box's top")


func test_a_built_woodland_puts_tier_bodies_in_the_tree_and_reports_their_surface() -> void:
	var m := _woodland()
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	var q := level.query()
	var tiers: Array[Node] = []
	for c: Node in level.get_children():
		if String(c.name).begins_with("Colliders_Tiers_"):
			tiers.append(c)
	assert_gt(tiers.size(), 4, "several chunk bodies")
	for sb: StaticBody3D in tiers:
		assert_true(sb.is_inside_tree())
		assert_lt(sb.get_child_count(), 6000, "shapes owned, not nodes")
	var enumerated := 0
	for rid: RID in q._tier_surfaces:
		enumerated += 1
		assert_between(q._tier_surfaces[rid], 0, RayHit.Surface.size() - 1, "a real surface")
		assert_eq(q._surface_of(rid), q._tier_surfaces[rid] as RayHit.Surface)
	assert_eq(enumerated, tiers.size(), "each body registered once")


func test_tier_bodies_are_freed_with_a_level_freed_whole_rebuilt_or_part_built() -> void:
	var m := _woodland()
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var rids_before := PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS)
	for i in 2:
		var level := MapLevel.new()
		add_child(level)
		level.build(m, play.map_style, tuning.body)
		await wait_physics_frames(2)
		remove_child(level)
		level.free()
	await wait_physics_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no node left over")
	assert_lte(PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS), rids_before, "no body left active")


func test_depot_and_subway_have_no_tier_bodies() -> void:
	for id: String in ["depot", "subway"]:
		var m := MapData.load_map(id, play.map_style, tuning.rounds.team_size)
		var level := MapLevel.new()
		add_child_autofree(level)
		level.build(m, play.map_style, tuning.body)
		for c: Node in level.get_children():
			assert_false(String(c.name).begins_with("Colliders_Tiers_"), "%s has no tier body" % id)
		assert_eq(level.query()._tier_surfaces.size(), 0)


func test_a_tier_key_keeps_its_surface_for_every_chunk_the_field_can_hold() -> void:
	# _tier_body's key is surface + TIER_KEY * (...), _body_rids reads key % TIER_KEY: it holds while the column and
	# row stay inside +-TIER_KEY/2 chunks of 16 m (800 m) and a surface under TIER_KEY.
	assert_lt(RayHit.Surface.size(), MapLevel.TIER_KEY)
	var m := _woodland()
	var reach := 0.0
	for b: MapData.Block in m.blocks:
		reach = maxf(reach, maxf(absf(b.center.x), absf(b.center.z)))
	assert_lt(reach, MapLevel.TIER_KEY / 2 * MapLevel.TIER_CHUNK, "the field fits the key's chunk range")
