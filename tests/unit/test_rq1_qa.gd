extends GutTest
## The Range's firing point (RQ1), hunted as the player who walks it: the four benches and the chrono table leave a
## way from the spawn to the firing line and along it, no target's line from the line is cut by furniture, the
## furniture stands on the floor inside the walls clear of the other props, the shelter is only a look (no block, high
## over a BB), and a fixtures view of the Range frees everything it built.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var map: MapData = null


func before_all() -> void:
	map = MapData.load_map("range", MapStyle.new(), 1)


func _furniture() -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	for b in map.blocks:
		if b.kind == &"furniture":
			out.append(b)
	return out


func _world() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	for b in map.blocks:
		w.add_box(b.center, b.size, b.surface)
	return w


func _overlap(a: MapData.Block, b: MapData.Block) -> bool:
	return absf(a.center.x - b.center.x) < (a.size.x + b.size.x) * 0.5 \
			and absf(a.center.y - b.center.y) < (a.size.y + b.size.y) * 0.5 \
			and absf(a.center.z - b.center.z) < (a.size.z + b.size.z) * 0.5


func test_the_firing_point_has_four_benches_and_a_chrono_table_clear_of_every_other_block() -> void:
	var f := _furniture()
	assert_eq(f.size(), 5, "four benches and the chrono table")
	for a in f:
		for b in map.blocks:
			if a != b and b.kind != &"floor":
				assert_false(_overlap(a, b), "%s at %s overlaps %s at %s" % [a.dress, a.center, b.kind, b.center])


func test_the_furniture_stands_on_the_floor_inside_the_walls_and_behind_the_firing_line() -> void:
	for a in _furniture():
		assert_almost_eq(a.center.y - a.size.y * 0.5, 0.0, 0.001, "%s on the floor" % a.dress)
		assert_lt(absf(a.center.x) + a.size.x * 0.5, 11.4 - 0.2, "%s inside the side walls" % a.dress)
		assert_lt(a.center.z + a.size.z * 0.5, 6.0, "%s in front of the back wall" % a.dress)
		assert_gt(a.center.z - a.size.z * 0.5, 0.0, "%s behind the firing line" % a.dress)


func test_the_player_walks_from_the_spawn_to_the_firing_line_and_along_it_past_every_bench() -> void:
	var w := _world()
	var mover := w.mover()
	var c := Character.new(0, 0, map.ends[0].spawns[0].position, 0.0, [])
	# straight to the line, then out to each side wall's end and back, nothing holds the body
	for goal: Vector3 in [Vector3(0, 0, 0), Vector3(-10, 0, 0), Vector3(10, 0, 0), Vector3(0, 0, 0)]:
		var steps := 0
		while Vector2(c.position.x - goal.x, c.position.z - goal.z).length() > 0.2 and steps < 60 * 20:
			var d := Vector3(goal.x - c.position.x, 0.0, goal.z - c.position.z)
			var want := d.normalized() * minf(d.length(), 4.0 * DT)
			var before := c.position
			c.position = before + mover.move(c, want)
			steps += 1
			if (c.position - before).length() < 1e-5:
				break
		assert_lt(Vector2(c.position.x - goal.x, c.position.z - goal.z).length(), 0.3, "reached %s" % goal)


func test_a_player_can_stand_in_front_of_each_bench_and_in_each_gap_between_them() -> void:
	var w := _world()
	var mover := w.mover()
	for x: float in [-10.0, -7.5, -5.0, -2.5, 0.0, 2.5, 5.0, 7.5, 10.0]:
		var c := Character.new(0, 0, Vector3(x, 0.0, 0.0), 0.0, [])
		assert_true(mover.room_to_stand(c), "room to stand at x %s on the line" % x)
	# the gap between two benches and the one by the chrono table are wide enough for the body
	var gaps := PackedFloat64Array()
	var f := _furniture()
	f.sort_custom(func(p: MapData.Block, q: MapData.Block) -> bool: return p.center.x < q.center.x)
	var benches: Array[MapData.Block] = []
	for b in f:
		if b.dress == &"shooting_bench":
			benches.append(b)
	for i in benches.size() - 1:
		gaps.append((benches[i + 1].center.x - benches[i + 1].size.x * 0.5) - (benches[i].center.x + benches[i].size.x * 0.5))
	for g in gaps:
		assert_gt(g, tuning.body.radius * 2.0 + 0.3, "a gap between benches passes the body")


func test_no_target_s_line_from_the_firing_line_is_cut_by_the_benches_or_the_chrono_table() -> void:
	var w := _world()
	var hit := RayHit.new()
	var f := _furniture()
	assert_gt(map.targets.size(), 0)
	for t in map.targets:
		var p: Vector3 = t.position
		for x: float in [-10.0, -5.0, 0.0, 5.0, 10.0]:
			var eye := Vector3(x, 1.6, 0.0)
			var goal := Vector3(p.x, 1.0, p.z)
			var struck: bool = false
			if w.sight_ray(eye, goal, hit):
				for b in f:
					if absf(hit.point.x - b.center.x) <= b.size.x * 0.5 + 0.01 \
							and absf(hit.point.z - b.center.z) <= b.size.z * 0.5 + 0.01:
						struck = true
			assert_false(struck, "a bench or table cuts the line from x %s to %s" % [x, p])


func test_the_shelter_and_signs_are_look_only_and_the_shelter_stays_over_head_height() -> void:
	for fx in map.fixtures:
		if not [&"range_canopy", &"range_flag"].has(fx.model):
			continue # a sign hangs on a wall's face by design
		for b in map.blocks:
			if b.kind == &"floor":
				continue
			var inside := absf(fx.position.x - b.center.x) < b.size.x * 0.5 and absf(fx.position.z - b.center.z) < b.size.z * 0.5 \
					and absf(fx.position.y - b.center.y) < b.size.y * 0.5
			assert_false(inside, "%s stands inside a %s block" % [fx.model, b.kind])
	# the canopy is a fixture, never a block, so the world holds nothing above 3.3 m on the firing point
	var w := _world()
	var hit := RayHit.new()
	assert_false(w.bb_ray(Vector3(0, 3.5, 3.0), Vector3(0, 3.5, -30.0), hit), "a BB flying high over the line meets nothing")


func test_leaving_the_range_frees_the_fixtures_view_and_building_it_twice_leaves_nothing_behind() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var v := StationFixtures.build(map, StationFixturesConfig.new())
		assert_not_null(v)
		add_child(v)
		v.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_a_listed_shadow_model_the_map_does_not_place_or_one_missing_from_disk_does_not_break_the_build() -> void:
	var cfg := StationFixturesConfig.new()
	cfg.shadow_models = PackedStringArray(["no_such_model", "range_flag", ""])
	var v := StationFixtures.build(map, cfg)
	assert_not_null(v)
	if v == null:
		return
	add_child_autofree(v)
	for inst in v.views():
		var shadow := String(inst.name).to_snake_case() == "range_flag"
		assert_eq(inst.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, shadow, inst.name)


func test_the_bench_and_chrono_models_fill_their_blocks_exactly() -> void:
	for b in _furniture():
		var mesh := PropDressConfig.load_mesh(PropDressConfig.new().models[StringName(b.dress)])
		assert_not_null(mesh, String(b.dress))
		if mesh == null:
			continue
		var box := mesh.get_aabb()
		assert_almost_eq(box.size.x, b.size.x, 0.01, "%s width" % b.dress)
		assert_almost_eq(box.size.y, b.size.y, 0.01, "%s height" % b.dress)
		assert_almost_eq(box.size.z, b.size.z, 0.01, "%s depth" % b.dress)


func test_the_range_is_one_concrete_floor_again() -> void:
	var floors := 0
	for b in map.blocks:
		if b.kind == &"floor":
			floors += 1
			assert_gt(b.size.y, 0.1, "no thin gravel slab")
	assert_eq(floors, 1)


func test_the_shelter_s_four_lamps_are_cool_white_dark_until_lit_and_freed_with_the_view() -> void:
	var cfg := StationFixturesConfig.new()
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var v := StationFixtures.build(map, cfg)
	add_child(v)
	assert_eq(v.lamps().size(), 4, "four battens' lights, no more")
	for l in v.lamps():
		assert_false(l.visible, "dark until Lamp lights")
		assert_eq(l.light_color, cfg.point_lamp_colour)
		assert_eq(l.omni_range, 8.0)
		assert_eq(l.light_energy, 3.0)
		assert_false(l.shadow_enabled)
		assert_lt(l.global_position.y, 3.6, "under the roof")
		assert_gt(l.global_position.y, 3.0)
	v.set_lamps(true)
	for l in v.lamps():
		assert_true(l.visible)
	v.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "every lamp left with the view")


func test_subway_s_tunnel_lamps_keep_the_lens_colour_range_and_energy() -> void:
	var cfg := StationFixturesConfig.new()
	var sub := MapData.load_map("subway", MapStyle.new(), 1)
	var v := StationFixtures.build(sub, cfg)
	assert_not_null(v)
	if v == null:
		return
	add_child_autofree(v)
	assert_gt(v.lamps().size(), 8)
	for l in v.lamps():
		assert_eq(l.light_color, cfg.lens_colour)
		assert_eq(l.omni_range, 6.5)
		assert_eq(l.light_energy, 1.5)
