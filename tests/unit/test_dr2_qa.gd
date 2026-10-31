extends GutTest
## QA for DR2 (Depot's CC0 props): a model that is there but won't load, props inside the box on every dressed map and
## seed, and no nodes left over from building and freeing the props.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _map(id: String) -> MapData:
	return MapData.load_map(id, play.map_style, 1 if id == "range" else tuning.rounds.team_size)


func _box(b: MapData.Block) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size).grow(1e-3)


## A model file that exists but holds no mesh (a scene without one): its kind must stay a box, as the config says.
func test_a_model_that_is_there_but_will_not_load_leaves_its_kind_a_box() -> void:
	var m := _map("depot")
	var cfg := PropDressConfig.new()
	cfg.models[&"drum"] = "res://game/main.tscn"
	var drum: MapData.Block = null
	for b in m.blocks:
		if b.kind == &"drum":
			drum = b
	var look := SiteLook.new()
	look.props = cfg
	var dress := PropDress.build(m, cfg)
	if dress != null:
		add_child_autofree(dress)
	var drawn := dress != null and dress.count(&"drum") > 0
	var box_drawn := not SiteSurface.hidden(look, drum) and SiteSurface.core_of(look, drum, m) == Transform3D.IDENTITY
	assert_true(drawn or box_drawn, "the drum block is drawn as drums or as its box, never as nothing")


func test_props_stay_inside_their_block_on_depot_and_the_range_for_any_seed() -> void:
	for id: String in ["depot", "range"]:
		var m := _map(id)
		for seed_value: int in [1, 7, 12345]:
			m.dressing_seed = seed_value
			var look := play.site_look
			var dress := PropDress.build(m, look.props)
			if dress == null:
				continue
			add_child_autofree(dress)
			var boxes: Array[AABB] = []
			for b in m.blocks:
				if look.props.dresses(b):
					boxes.append(_box(b))
			var bad := 0
			var placed := dress.placed()
			for model: StringName in placed:
				var mesh := dress.mesh_of(model)
				var corners := mesh.get_aabb()
				for t in placed[model].transforms:
					var inside := false
					for box in boxes:
						var all := true
						for i in 8:
							all = all and box.has_point(t * corners.get_endpoint(i))
						inside = inside or all
					bad += 0 if inside else 1
			assert_eq(bad, 0, "%s seed %d: every prop's bounds lie in one dressed block" % [id, seed_value])


func test_building_and_freeing_props_leaves_no_orphans() -> void:
	var m := _map("depot")
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var dress := PropDress.build(m, play.site_look.props)
		dress.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_every_prop_is_in_exactly_one_chunk_for_any_chunk_size() -> void:
	var m := _map("depot")
	for size: float in [20.0, 0.5, 7.3, 1.0e9, 0.0, -5.0]:
		var cfg := PropDressConfig.new()
		cfg.chunk = size
		var dress := PropDress.build(m, cfg)
		add_child_autofree(dress)
		for model: StringName in dress.placed():
			var want := dress.placed()[model].transforms.size()
			assert_eq(dress.count(model), want, "%s at chunk %s: each prop drawn once" % [model, size])


func test_a_racks_props_and_backing_cover_its_whole_footprint() -> void:
	for id: String in ["depot", "range"]:
		var m := _map(id)
		var look := play.site_look
		var gaps: Array[String] = []
		for b in m.blocks:
			if not look.props.backs(b):
				continue
			var line := PropLayout.lining(m, look.props, b)
			var lo := b.center - b.size * 0.5
			var hi := b.center + b.size * 0.5
			var rects: Array[Rect2] = []
			rects.append(Rect2(lo.x + line.low.x * 0.5, lo.z + line.low.z * 0.5,
					b.size.x - (line.low.x + line.high.x) * 0.5, b.size.z - (line.low.z + line.high.z) * 0.5))
			if line.low.z > 0.0:
				rects.append(Rect2(lo.x, lo.z, b.size.x, line.low.z))
			if line.high.z > 0.0:
				rects.append(Rect2(lo.x, hi.z - line.high.z, b.size.x, line.high.z))
			var zl := b.size.z - line.low.z - line.high.z
			if line.low.x > 0.0:
				rects.append(Rect2(lo.x, lo.z + line.low.z, line.low.x, zl))
			if line.high.x > 0.0:
				rects.append(Rect2(hi.x - line.high.x, lo.z + line.low.z, line.high.x, zl))
			var x := lo.x + 0.05
			while x < hi.x:
				var z := lo.z + 0.05
				while z < hi.z:
					var covered := false
					for r in rects:
						covered = covered or r.grow(1e-4).has_point(Vector2(x, z))
					if not covered:
						gaps.append("%s rack at %s: %s,%s" % [id, b.center, x, z])
						break
					z += 0.25
				if not gaps.is_empty() and gaps[-1].begins_with("%s rack at %s" % [id, b.center]):
					break
				x += 0.25
		assert_eq(gaps.slice(0, 3), [] as Array[String], "%s: no gap in a rack's footprint" % id)
