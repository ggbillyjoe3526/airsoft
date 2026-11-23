extends GutTest
## DG1 QA: BBs and sight meet the props a map draws as drawn (DrawnRays). Edge cases: maps with and without props, the
## staged build, rebuilds and frees, doors, rays of no length or ending on a card, the leaf tries running out, a
## sheared prop's faces.

const MAPS: Array[String] = ["range", "depot", "subway", "woodland"]
## A stop this near (m) to a place agrees with it.
const NEAR := 0.05
const RAYS := 300

var _runners: Dictionary[String, MatchRunner] = {}
var _hit := RayHit.new()


func before_all() -> void:
	for id in MAPS:
		_runners[id] = MatchRunner.new(self, id)


func after_all() -> void:
	for id in _runners:
		_runners[id].free_level()


func _rays(id: String) -> DrawnRays:
	return _runners[id].level.drawn_rays()


func _query(id: String) -> JoltQuery:
	return _runners[id].level.query()


func test_every_map_builds_its_drawn_rays_and_a_map_with_none_drawn_stands_on_its_boxes() -> void:
	for id in MAPS:
		var rays := _rays(id)
		assert_not_null(rays, "%s: the level made its drawn rays" % id)
		assert_eq(rays.body_count() > 0, rays.prop_count() > 0, "%s: bodies where props stand, none where none" % id)
		assert_lte(rays.body_count(), rays.prop_count() * 2, "%s: no body a prop more than needed" % id)
		for body: RID in rays.surfaces:
			assert_true(body.is_valid(), "%s: a body is a real RID" % id)


func test_a_block_no_prop_stands_in_for_still_stops_a_bb_on_every_map() -> void:
	# Through the middle of each plain wall or crate's box, in from one side: something stops it.
	for id in MAPS:
		var m := _runners[id].map
		var rays := _rays(id)
		var q := _query(id)
		var tried := 0
		var through: Array[String] = []
		for i in m.blocks.size():
			var b := m.blocks[i]
			if rays.draws(i) or b.rise != MapData.Rise.NONE or b.dress != &"" or b.size.x < 0.4 or b.size.z < 0.4 \
					or b.size.y < 0.6 or b.kind == &"floor":
				continue
			if b.kind == &"railing" or b.kind == &"glass" or String(b.kind).contains("rail") \
					or String(b.kind).contains("glass") or String(b.kind).contains("window"):
				continue
			var a := Vector3(b.center.x - b.size.x * 0.5 - 0.5, b.center.y, b.center.z)
			var c := Vector3(b.center.x, b.center.y, b.center.z)
			tried += 1
			if not q.bb_ray(a, c, _hit):
				through.append("%s %s at %s" % [id, b.kind, b.center])
			if tried >= 60:
				break
		assert_lt(through.size(), 3, "%s: a BB aimed into a plain block's face stops (%s)" % [id, through.slice(0, 4)])


func test_rays_of_no_length_or_none_are_no_hit_and_do_not_hang() -> void:
	for id in MAPS:
		var q := _query(id)
		var p := Vector3(0.0, 1.0, 0.0)
		assert_false(q.sight_ray(p, p, _hit), "%s: sight, zero length" % id)
		assert_false(q.bb_ray(p, p, _hit), "%s: bb, zero length" % id)
		assert_false(q.ray(p, p, _hit), "%s: level ray, zero length" % id)


func test_a_ray_that_starts_on_a_leaf_card_or_ends_on_one_comes_back_sane() -> void:
	var m := _runners["woodland"].map
	var props := PropDressConfig.new()
	var q := _query("woodland")
	var placed := _placed(m, props)
	var mesh := props.drawn_mesh_of(&"spruce")
	var spruces: PropLayout.Placed = placed[&"spruce"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var tested := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for k in range(0, index.size() - 2, 3):
			if uv[index[k]].x < LeafTrim.BARK_BELOW or tested >= 60:
				continue
			var xf := spruces.transforms[rng.randi() % spruces.transforms.size()]
			var at := xf * ((verts[index[k]] + verts[index[k + 1]] + verts[index[k + 2]]) / 3.0)
			var out := (xf.basis * (verts[index[k + 1]] - verts[index[k]]).cross(verts[index[k + 2]] - verts[index[k]])
					).normalized()
			if not out.is_finite():
				continue
			tested += 1
			# starting on the card, fired away from it, and into it from outside, ending exactly on it
			for pair: Array in [[at, at + out * 5.0], [at, at - out * 5.0], [at + out * 2.0, at], [at - out * 2.0, at]]:
				var met := q.bb_ray(pair[0], pair[1], _hit)
				if met:
					assert_true(_hit.position.is_finite(), "a finite stop")
					assert_between(_hit.fraction, 0.0, 1.0, "a fraction along the line")
					assert_true(_hit.normal.is_finite(), "a finite normal")
	assert_gt(tested, 20, "cards tried")


func test_every_stop_lies_on_its_own_line_through_the_woods() -> void:
	var m := _runners["woodland"].map
	var q := _query("woodland")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var wrong := 0
	var met := 0
	for i in RAYS:
		var a := Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0))
		a.y = m.terrain.height_clamped(a.x, a.z) + rng.randf_range(0.3, 2.0)
		var b := a + Vector3(rng.randf_range(-30.0, 30.0), rng.randf_range(-3.0, 3.0), rng.randf_range(-30.0, 30.0))
		for sight: bool in [false, true]:
			var found := q.sight_ray(a, b, _hit) if sight else q.bb_ray(a, b, _hit)
			if not found:
				continue
			met += 1
			var on := a + (b - a) * _hit.fraction
			if on.distance_to(_hit.position) > NEAR or _hit.fraction < 0.0 or _hit.fraction > 1.0:
				wrong += 1
	assert_gt(met, 50, "lines meet something")
	assert_eq(wrong, 0, "a stop's fraction and position agree on the line, past cut-out cards too")


func test_a_ray_through_a_trunk_gets_its_blocks_surface_and_a_card_leaves() -> void:
	var m := _runners["woodland"].map
	var rays := _rays("woodland")
	var q := _query("woodland")
	var props := PropDressConfig.new()
	var placed := _placed(m, props)
	var p: PropLayout.Placed = placed[&"pine_grown"]
	var checked := 0
	for i in mini(p.transforms.size(), 30):
		var b := m.blocks[p.blocks[i]]
		if not rays.draws(p.blocks[i]):
			continue
		var xf := p.transforms[i]
		var y := m.terrain.height_clamped(xf.origin.x, xf.origin.z) + 1.0
		var mid := Vector3(xf.origin.x, y, xf.origin.z)
		if q.bb_ray(mid - Vector3(1.5, 0, 0), mid + Vector3(1.5, 0, 0), _hit):
			checked += 1
			assert_true(_hit.surface == b.surface or _hit.surface == RayHit.Surface.LEAVES,
					"a drawn trunk is made of its block's stuff (or its limbs' leaves), not %d" % _hit.surface)
	assert_gt(checked, 3, "trunks met")


func test_the_staged_build_makes_the_same_drawn_rays_as_the_whole_one() -> void:
	var whole := _runners["subway"].level
	var staged := MapLevel.new()
	var world := SubViewport.new()
	world.own_world_3d = true
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(world)
	world.add_child(staged)
	var play := PlayTuning.load_default()
	staged.begin(_runners["subway"].map, play.map_style, _runners["subway"].tuning.body, null, null, false, null,
			_runners["subway"].tuning.lifts)
	var calls := 0
	while not staged.build_some(1):
		calls += 1
		assert_lt(calls, 400, "the build finishes")
		if calls >= 400:
			break
	assert_eq(staged.drawn_rays().prop_count(), whole.drawn_rays().prop_count(), "the same props stand")
	assert_eq(staged.drawn_rays().body_count(), whole.drawn_rays().body_count(), "on the same number of bodies")
	for i in _runners["subway"].map.blocks.size():
		assert_eq(staged.drawn_rays().draws(i), whole.drawn_rays().draws(i), "block %d" % i)
	var rays := staged.drawn_rays()
	staged.free()
	assert_eq(rays.body_count(), 0, "the staged level's bodies went with it")


func test_a_level_left_part_built_frees_without_drawn_bodies_or_errors() -> void:
	var staged := MapLevel.new()
	var world := SubViewport.new()
	world.own_world_3d = true
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(world)
	world.add_child(staged)
	var play := PlayTuning.load_default()
	staged.begin(_runners["depot"].map, play.map_style, _runners["depot"].tuning.body, null, null, false, null,
			_runners["depot"].tuning.lifts)
	# stop on the piece before the drawn rays are built, and just after
	for n in 12:
		staged.build_some(1)
		if staged.drawn_rays() != null:
			break
	var rays := staged.drawn_rays()
	staged.free()
	if rays != null:
		assert_eq(rays.body_count(), 0, "freed with the level")
	assert_true(true, "no error on freeing a part built level")


func test_building_and_freeing_levels_again_and_again_leaves_nothing_behind() -> void:
	var map := _runners["subway"].map
	var play := PlayTuning.load_default()
	var tuning := _runners["subway"].tuning
	var world := SubViewport.new()
	world.own_world_3d = true
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(world)
	var nodes := -1
	var orphans := -1
	var bodies := PackedInt32Array()
	for turn in 3:
		var level := MapLevel.new()
		world.add_child(level)
		level.build(map, play.map_style, tuning.body, null, null, false, null, tuning.lifts)
		bodies.append(level.drawn_rays().body_count())
		level.free()
		if turn == 0:
			nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), nodes, "no node left over")
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans, "no orphan left over")
	assert_eq(bodies[0], bodies[2], "a rebuild makes the same bodies")


func test_a_shut_door_stops_a_bb_and_sight_and_an_open_one_does_not_on_every_map() -> void:
	var tested := 0
	for id in MAPS:
		var q := _query(id)
		for i in q.door_count():
			var c := q.door_centers[i]
			var h := q.door_halves[i]
			var along_x := h.x > h.z
			var dir := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
			var a := c - dir * 1.0
			var b := c + dir * 1.0
			q.set_door_shut(i, true)
			tested += 1
			assert_true(q.bb_ray(a, b, _hit), "%s door %d shut stops a BB" % [id, i])
			assert_true(q.sight_ray(a, b, _hit), "%s door %d shut stops sight" % [id, i])
			q.set_door_shut(i, false)
			var box := AABB(c - h, h * 2.0).grow(0.02)
			var stopped := q.bb_ray(a, b, _hit) and box.has_point(_hit.position)
			assert_false(stopped, "%s door %d open lets a BB through its leaf" % [id, i])
			q.set_door_shut(i, q.door_starts_shut[i] == 1)
	assert_gt(tested, 0, "doors tried")


func test_a_prop_whose_axes_are_not_square_is_sheared_and_a_turned_scaled_one_is_not() -> void:
	var turned := Basis(Vector3.UP, 0.7) * Basis.from_scale(Vector3(2.0, 0.5, 3.0))
	assert_false(DrawnRays._sheared(turned), "a turn and a scale along its axes")
	var bent := Basis(Vector3(1, 0, 0), Vector3(0.4, 1, 0), Vector3(0, 0, 1))
	assert_true(DrawnRays._sheared(bent), "an axis leaning on another")


func test_a_map_with_no_blocks_makes_no_rays_and_a_double_free_is_safe() -> void:
	var map := MapData.new()
	var space := _runners["subway"].level.get_world_3d().space
	var rays := DrawnRays.build(map, PropDressConfig.new(), space, DrawnRayConfig.new())
	assert_eq(rays.body_count(), 0)
	assert_eq(rays.prop_count(), 0)
	assert_false(rays.draws(0), "no block drawn, and an index past the end is not")
	rays.free_bodies()
	rays.free_bodies()
	assert_eq(rays.body_count(), 0)


func test_opaque_answers_solid_for_a_card_it_cannot_place() -> void:
	var rays := _rays("woodland")
	assert_true(rays.opaque(RID(), 0, 0, Vector3.ZERO), "an unknown body")
	for body: RID in rays.surfaces:
		if rays.is_leaf(body):
			assert_true(rays.opaque(body, 0, -1, Vector3.ZERO), "a face not told")
			assert_true(rays.opaque(body, -1, 0, Vector3.ZERO), "a shape not told")
			assert_true(rays.opaque(body, 100000, 0, Vector3.ZERO), "a shape past the end")
			assert_true(rays.opaque(body, 0, 100000000, Vector3.ZERO), "a face past the end")
			return
	fail_test("Woodland has leaf bodies")


func test_a_ray_with_one_try_stops_on_the_first_card_whether_cut_away_or_not() -> void:
	var rays := _rays("woodland")
	var cfg := rays.config()
	var q := _query("woodland")
	var m := _runners["woodland"].map
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var kept := cfg.leaf_tries
	var lines := 0
	var through_many := 0
	var through_one := 0
	for i in 400:
		var a := Vector3(rng.randf_range(-50.0, 50.0), 0.0, rng.randf_range(-50.0, 50.0))
		a.y = m.terrain.height_clamped(a.x, a.z) + 6.0
		var b := a + Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(-6.0, 0.0), rng.randf_range(-20.0, 20.0))
		cfg.leaf_tries = kept
		var many := q.sight_ray(a, b, _hit)
		cfg.leaf_tries = 1
		var one := q.sight_ray(a, b, _hit)
		lines += 1
		through_many += 0 if many else 1
		through_one += 0 if one else 1
	cfg.leaf_tries = kept
	assert_gt(lines, 0)
	assert_lte(through_one, through_many, "fewer tries never lets more lines through (%d vs %d)" % [
			through_one, through_many])


func test_a_ray_with_no_tries_set_still_stops_on_a_wall() -> void:
	var rays := _rays("subway")
	var cfg := rays.config()
	var kept := cfg.leaf_tries
	var q := _query("subway")
	var b := _wall_of("subway")
	var a := Vector3(b.center.x - b.size.x * 0.5 - 1.0, b.center.y, b.center.z)
	var c := Vector3(b.center.x, b.center.y, b.center.z)
	cfg.leaf_tries = 0
	var found := q.sight_ray(a, c, _hit)
	cfg.leaf_tries = kept
	assert_true(found, "a wall still stops sight with leaf_tries 0 (at least one cast)")


func test_a_long_line_through_the_woods_allocates_nothing_in_the_cast() -> void:
	var m := _runners["woodland"].map
	var q := _query("woodland")
	var a := Vector3(-50.0, 0.0, -50.0)
	a.y = m.terrain.height_clamped(a.x, a.z) + 4.0
	var b := Vector3(50.0, a.y, 50.0)
	q.sight_ray(a, b, _hit)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 100:
		q.sight_ray(a, b, _hit)
		q.bb_ray(b, a, _hit)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "no object made")


func _wall_of(id: String) -> MapData.Block:
	var rays := _rays(id)
	var m := _runners[id].map
	for i in m.blocks.size():
		var b := m.blocks[i]
		if b.kind == &"wall" and not rays.draws(i) and b.size.x > 1.0 and b.size.y > 1.0 and b.rise == MapData.Rise.NONE:
			return b
	return m.blocks[0]


func _placed(m: MapData, props: PropDressConfig) -> Dictionary[StringName, PropLayout.Placed]:
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in PropDress.models_used(m, props):
		if props.mesh_of(model) != null:
			boxes[model] = props.mesh_of(model).get_aabb()
	return PropLayout.layout(m, props, boxes)


func _begun(id: String, world: SubViewport) -> DrawnRays:
	var play := PlayTuning.load_default()
	return DrawnRays.begin(_runners[id].map, _runners[id].level._ray_props(), world.find_world_3d().space,
			play.map_style.drawn_rays)


func _own_world() -> SubViewport:
	var world := SubViewport.new()
	world.own_world_3d = true
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(world)
	return world


func test_build_step_returns_true_once_at_the_end_and_is_safe_after() -> void:
	var world := _own_world()
	var rays := _begun("subway", world)
	assert_false(rays.done(), "begun, not done")
	var trues := 0
	var calls := 0
	while not rays.done() and calls < 5000:
		calls += 1
		if rays.build_step():
			trues += 1
			assert_true(rays.done(), "true means every body is made")
	assert_eq(trues, 1, "true exactly once, on the last step")
	var bodies := rays.body_count()
	assert_true(rays.build_step(), "a step after the end says done")
	assert_true(rays.build_step(), "and again")
	assert_eq(rays.body_count(), bodies, "and makes nothing more")
	rays.free_bodies()


func test_build_step_on_a_map_with_no_props_finishes_at_once() -> void:
	var world := _own_world()
	var rays := DrawnRays.begin(MapData.new(), PropDressConfig.new(), world.find_world_3d().space, DrawnRayConfig.new())
	var calls := 0
	while not rays.build_step() and calls < 10:
		calls += 1
	assert_lt(calls, 10, "ends")
	assert_true(rays.done(), "done")
	assert_eq(rays.body_count(), 0, "no body")
	rays.free_bodies()


func test_freeing_the_bodies_mid_build_leaves_none() -> void:
	var world := _own_world()
	var rays := _begun("woodland", world)
	for n in 3:
		rays.build_step()
	rays.free_bodies()
	assert_eq(rays.body_count(), 0, "freed mid-build")
	# Freeing ends the build: a step after it does nothing, and no shape goes into a freed body.
	assert_true(rays.build_step(), "a step after the free is done")
	assert_true(rays.done(), "done")
	assert_eq(rays.body_count(), 0, "still none")


func test_a_body_key_has_room_for_every_surface_layer_and_square_the_maps_use() -> void:
	assert_lt(RayHit.Surface.WATER, DrawnRays.KEY_SLOTS, "every surface fits its slot")
	for layer: int in [DrawnRays.BOX_LAYER, DrawnRays.DRAWN_LAYER, DrawnRays.LEAF_LAYER]:
		assert_lt(layer, DrawnRays.KEY_SLOTS, "layer %d fits its slot" % layer)
	var chunk := DrawnRayConfig.new().chunk
	for id in MAPS:
		for b in _runners[id].map.blocks:
			assert_lt(absf(b.center.x) / chunk, DrawnRays.KEY_CELLS, "%s: column in range" % id)
			assert_lt(absf(b.center.z) / chunk, DrawnRays.KEY_CELLS, "%s: row in range" % id)
