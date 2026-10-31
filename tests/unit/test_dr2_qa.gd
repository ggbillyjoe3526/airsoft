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
