extends GutTest
## DR2: Depot's CC0 props. Every prop stands inside a block of the kind it dresses, so what you see is what stops a BB
## and a body; the drums stand four on a pallet, the barrels two a block, the sofa faces the field and the tall racks
## are lined with shelving over a backing while the rack's shelf boards stay boards; a box drawn as props draws none
## of its own faces (or only its backing) and leaves the baked shadow caster; no prop colour reads as a team; the
## layout is seeded; a missing model leaves its kind a box; the props are in the prewarm. WR3: Woodland's blocks
## name their props (trees, spruces, logs, cordwood, crates, tyres, a truck) with no site dress, each inside its
## block; a grid lays a cell's prop a cell; a dressed block draws no box, a thicket only its dark core; a ramp keeps
## its box.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var look: SiteLook = null


func before_each() -> void:
	look = play.site_look


func _map(id: String) -> MapData:
	var m := MapData.load_map(id, play.map_style, 1 if id == "range" else tuning.rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func _level(m: MapData, site: SiteLook) -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, m,
			LightingConfig.DAY), false, site)
	return level


func _box(b: MapData.Block, grow: float) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size).grow(grow)


func _dress(m: MapData) -> PropDress:
	var dress := PropDress.build(m, look.props)
	if dress != null:
		add_child_autofree(dress)
	return dress


func _count(m: MapData, kind: StringName, tall_from: float = 0.0) -> int:
	var n := 0
	for b in m.blocks:
		if b.kind == kind and b.size.y >= tall_from:
			n += 1
	return n


## Each prop that reaches past the box of the block it stands in, as "model index".
func _outside(m: MapData, dress: PropDress) -> Array[String]:
	var boxes: Array[AABB] = []
	for b in m.blocks:
		if look.props.dresses(b):
			boxes.append(_box(b, 1e-3))
	var outside: Array[String] = []
	var placed := dress.placed()
	for model: StringName in placed:
		var mesh := dress.mesh_of(model)
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var middle := mesh.get_aabb().get_center()
		for i in placed[model].transforms.size():
			var t := placed[model].transforms[i]
			var home := -1
			for k in boxes.size():
				if boxes[k].has_point(t * middle):
					home = k
					break
			for v in verts:
				if home < 0 or not boxes[home].has_point(t * v):
					outside.append("%s %d" % [model, i])
					break
	return outside


func test_every_prop_stands_inside_a_block_it_dresses() -> void:
	var m := _map("depot")
	var dress := _dress(m)
	assert_not_null(dress, "Depot is dressed with props")
	assert_eq(_outside(m, dress), [] as Array[String], "no prop reaches past its block's box")


func test_drums_stand_four_on_a_pallet_barrels_two_a_block_one_sofa_and_shelving_on_tall_racks() -> void:
	var m := _map("depot")
	var dress := _dress(m)
	assert_eq(dress.count(&"drum"), 4 * _count(m, &"drum"), "four drums a cluster")
	assert_eq(dress.count(&"pallet"), _count(m, &"drum"), "a pallet under each cluster")
	assert_eq(dress.count(&"barrel"), 2 * _count(m, &"barrel"), "two barrels a block")
	assert_eq(dress.count(&"sofa"), 1)
	assert_gt(dress.count(&"shelf"), _count(m, &"rack", 2.0), "racking lined with shelving")
	for b in m.blocks:
		if b.kind == &"rack" and b.size.y < 2.0:
			assert_false(look.props.dresses(b), "a rack's shelf board stays a board")
			assert_false(SiteSurface.as_props(look, b))


func test_the_sofa_faces_the_field_s_middle() -> void:
	var m := _map("depot")
	var t := _dress(m).placed()[&"sofa"].transforms[0]
	var front := (t.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var sofa: MapData.Block = null
	for b in m.blocks:
		if b.kind == &"sofa":
			sofa = b
	var to := PropLayout.field_middle(m) - sofa.center
	assert_gt(front.dot(Vector3(to.x, 0.0, to.z).normalized()), 0.0, "its seat faces the field")
	assert_almost_eq(absf(front.y), 0.0, 1e-4, "upright")


func test_a_propped_box_draws_no_faces_and_leaves_the_baked_shadow_caster() -> void:
	var m := _map("depot")
	var level := _level(m, look)
	var hidden := 0
	var drawn := 0
	for b in m.blocks:
		if SiteSurface.hidden(look, b):
			hidden += 1
			var core := SiteSurface.core_of(look, b, m)
			assert_eq(core * (b.center + b.size * 0.5), b.center, "a drum's or barrel's box folds to its middle")
		drawn += GreyboxFaces.faces_of(b).size() if not SiteSurface.hidden(look, b) else 0
	assert_eq(hidden, _count(m, &"drum") + _count(m, &"barrel") + _count(m, &"sofa"))
	var caster := MapLevel._greybox_mesh(m, play.map_style, look)
	var full := MapLevel._greybox_mesh(m, play.map_style)
	assert_lt(caster.surface_get_array_len(0), full.surface_get_array_len(0), "the caster leaves them out")
	level.set_baked_light(true)
	assert_true(level.baked_light_drawn(), "the bake still fits: the tiles are all there, folded")


func test_tall_racks_draw_a_backing_half_a_row_inside_each_lined_face_and_flush_with_the_rest() -> void:
	var m := _map("depot")
	var checked := 0
	var flush := 0
	for b in m.blocks:
		if not look.props.backs(b):
			continue
		assert_eq(look.finish_of(b), &"backing")
		var line := PropLayout.lining(m, look.props, b)
		var core := SiteSurface.core_of(look, b, m)
		var lo := core * (b.center - b.size * 0.5)
		var hi := core * (b.center + b.size * 0.5)
		var box_lo := b.center - b.size * 0.5
		var box_hi := b.center + b.size * 0.5
		for axis: int in [0, 2]:
			assert_almost_eq(lo[axis], box_lo[axis] + line.low[axis] * 0.5, 1e-4, "half a row in, or flush")
			assert_almost_eq(hi[axis], box_hi[axis] - line.high[axis] * 0.5, 1e-4, "half a row in, or flush")
			flush += int(line.low[axis] == 0.0) + int(line.high[axis] == 0.0)
		assert_almost_eq(lo.y, box_lo.y, 1e-4, "on the floor")
		assert_gt(line.low.length() + line.high.length(), 0.0, "some face is lined")
		checked += 1
	assert_eq(checked, _count(m, &"rack", 2.0))
	assert_gt(flush, 0, "some face is against a wall or another rack")


## Seen from outside, every point of a tall rack's sides is props or backing: no slot along an unlined face, no open
## corner where a row stops (the critic's check, DR2 attempt 1).
func test_every_point_just_inside_a_rack_s_sides_is_shelving_or_backing() -> void:
	var m := _map("depot")
	var dress := _dress(m)
	var cell := dress.mesh_of(&"shelf").get_aabb()
	var shelves: Array[AABB] = []
	for t in dress.placed()[&"shelf"].transforms:
		shelves.append((t * cell).grow(1e-3))
	var gaps: Array[String] = []
	for b in m.blocks:
		if not look.props.backs(b):
			continue
		var core := SiteSurface.core_of(look, b, m)
		var lo := core * (b.center - b.size * 0.5)
		var backing := AABB(lo, core * (b.center + b.size * 0.5) - lo).grow(1e-3)
		var box_lo := b.center - b.size * 0.5
		for edge: Vector3 in [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0),
				Vector3(1.0, 0.0, 1.0)]:
			for along: int in [0, 2]:
				var steps := maxi(2, ceili(b.size[along] / 0.2))
				for i in steps + 1:
					var at := box_lo + b.size * edge
					at[along] = box_lo[along] + b.size[along] * i / steps
					var across := 2 - along
					at[across] += 0.01 if edge[across] == 0.0 else -0.01
					at[along] = clampf(at[along], box_lo[along] + 0.01, box_lo[along] + b.size[along] - 0.01)
					at.y = box_lo.y + b.size.y * 0.5
					if backing.has_point(at):
						continue
					var hit := false
					for s in shelves:
						if s.has_point(at):
							hit = true
							break
					if not hit:
						gaps.append("rack at %s: %s" % [b.center, at])
						break
	assert_eq(gaps, [] as Array[String], "a rack's footprint is all shelving or backing")


func test_no_prop_colour_reads_as_a_team() -> void:
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(play.teams.colours)
	var near: Array[String] = []
	for model: StringName in look.props.models:
		var mesh := PropDressConfig.load_mesh(look.props.models[model])
		assert_not_null(mesh, "%s loads" % model)
		var seen: Dictionary[Color, bool] = {}
		for linear in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
			var c := linear.linear_to_srgb()
			if seen.has(c):
				continue
			seen[c] = true
			if FieldChecks.reads_as_team(c, teams):
				near.append("%s %s" % [model, c.to_html(false)])
	assert_eq(near, [] as Array[String], "no prop within 20 degrees of a team's hue unless dull")
	assert_eq(look.props.metallic, 0.0)


func test_the_layout_is_seeded() -> void:
	var m := _map("depot")
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in look.props.models:
		boxes[model] = PropDressConfig.load_mesh(look.props.models[model]).get_aabb()
	var a := PropLayout.layout(m, look.props, boxes)
	var b := PropLayout.layout(m, look.props, boxes)
	for model: StringName in a:
		assert_eq(a[model].transforms, b[model].transforms, "%s the same both times" % model)
		assert_eq(a[model].shades, b[model].shades)


func test_a_missing_model_leaves_its_kind_a_box() -> void:
	var m := _map("depot")
	var cfg := PropDressConfig.new()
	cfg.models[&"drum"] = "res://assets/models/props/no_such_drum.glb"
	var drum: MapData.Block = null
	for b in m.blocks:
		if b.kind == &"drum":
			drum = b
	assert_false(cfg.dresses(drum), "no model, no props")
	var other := SiteLook.new()
	other.props = cfg
	assert_false(SiteSurface.as_props(other, drum))
	assert_eq(SiteSurface.core_of(other, drum, m), Transform3D.IDENTITY, "its box is drawn")
	var dress := PropDress.build(m, cfg)
	add_child_autofree(dress)
	assert_eq(dress.count(&"drum"), 0, "and no drums")
	assert_gt(dress.count(&"barrel"), 0, "the rest as before")


func test_the_props_are_in_the_site_dress_and_its_prewarm() -> void:
	var m := _map("depot")
	var level := _level(m, look)
	var site := SiteDress.build(m, look, level.site_material())
	add_child_autofree(site)
	assert_not_null(site.props())
	for mat in site.props().materials():
		assert_true(site.materials().has(mat), "warmed before play")
	for view in site.props().all_views():
		assert_eq(view.material_override, site.props().materials()[0], "one material for every prop")


func test_woodland_is_dressed_without_a_site_each_prop_inside_the_block_that_names_it() -> void:
	var m := _map("woodland")
	assert_null(SiteDress.build(m, look, ShaderMaterial.new()), "no site dress")
	var dress := _dress(m)
	assert_not_null(dress, "but CC0 props all the same")
	if dress == null:
		return
	var named: Dictionary[StringName, int] = {}
	for b in m.blocks:
		if b.dress != &"":
			assert_true(look.props.dresses(b), "%s's %s has its model" % [b.kind, b.dress])
			named[b.dress] = named.get(b.dress, 0) + 1
	for model: StringName in [&"trunk", &"pine", &"log", &"logstack", &"crate", &"tyre", &"truck"]:
		assert_gt(named.get(model, 0), 0, "a block names %s" % model)
		assert_gt(dress.count(model), 0, "%s placed" % model)
	assert_eq(dress.count(&"trunk"), named[&"trunk"], "one trunk a tree")
	assert_eq(dress.count(&"truck"), 1)
	assert_eq(_outside(m, dress), [] as Array[String], "no prop reaches past its block's box")


func test_a_grid_lays_a_block_s_props_in_cells_and_a_round_count_a_side() -> void:
	var m := _map("woodland")
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in look.props.models:
		boxes[model] = PropDressConfig.load_mesh(look.props.models[model]).get_aabb()
	var placed := PropLayout.layout(m, look.props, boxes)
	var want := 0
	for b in m.blocks:
		if b.dress != &"crate":
			continue
		var cell: Vector3 = look.props.grid_cells[&"crate"]
		var across := maxf(b.size.x, b.size.z)
		var deep := minf(b.size.x, b.size.z)
		want += maxi(1, roundi(across / cell.x)) * maxi(1, roundi(b.size.y / cell.y)) * maxi(1, roundi(deep / cell.z))
	assert_eq(look.props.lay_of(m.blocks.filter(func(b: MapData.Block) -> bool: return b.dress == &"crate")[0]),
			PropDressConfig.Lay.GRID)
	assert_eq(placed[&"crate"].transforms.size(), want, "a crate a cell")


func test_a_dressed_block_draws_no_box_and_a_thicket_only_its_core() -> void:
	var m := _map("woodland")
	var plain := MapLevel._greybox_mesh(m, play.map_style)
	var dressed := MapLevel._greybox_mesh(m, play.map_style, null, look.props)
	var thicket: MapData.Block = null
	var hidden := 0
	for b in m.blocks:
		if b.dress == &"pine" and thicket == null:
			thicket = b
		elif b.dress != &"":
			hidden += 1
	var verts := func(mesh: ArrayMesh) -> int: return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			as PackedVector3Array).size()
	assert_lt(verts.call(dressed), verts.call(plain), "the dressed blocks' boxes are left out")
	assert_eq(look.props.core_of(thicket), look.props.model_cores[&"pine"])
	var inset: Vector2 = look.props.model_cores[&"pine"]
	var cored: Array[MapData.Block] = []
	for b in m.blocks:
		if b.dress == &"pine":
			cored.append(b)
	var lone := MapLevel.core_box(thicket, inset, [] as Array[MapData.Block])
	var lo := thicket.center - thicket.size * 0.5
	var hi := thicket.center + thicket.size * 0.5
	var step := Vector3(minf(inset.x, thicket.size.x * MapLevel.CORE_SHARE), 0.0,
			minf(inset.x, thicket.size.z * MapLevel.CORE_SHARE))
	assert_almost_eq(lone * lo, lo + step, Vector3.ONE * 1e-4, "a lone thicket's core is inset at the foot")
	assert_almost_eq((lone * hi).y, lo.y + thicket.size.y * inset.y, 1e-4, "cut down to its share")
	# Touching thickets' cores meet: each side another thicket touches runs to the face.
	var gaps: Array[String] = []
	for t in cored:
		var core := MapLevel.core_box(t, inset, cored)
		var t_lo := t.center - t.size * 0.5
		var t_hi := t.center + t.size * 0.5
		var c_lo := core * t_lo
		var c_hi := core * t_hi
		for o in cored:
			if o == t:
				continue
			var o_box := AABB(o.center - o.size * 0.5, o.size)
			for axis: int in [0, 2]:
				var probe_lo := t_lo
				var probe_size := t.size
				probe_lo[axis] = t_hi[axis]
				probe_size[axis] = 0.01
				if o_box.intersects(AABB(probe_lo, probe_size)) and absf(c_hi[axis] - t_hi[axis]) > 1e-3:
					gaps.append("%s→%s" % [t.center, o.center])
				probe_lo[axis] = t_lo[axis] - 0.01
				if o_box.intersects(AABB(probe_lo, probe_size)) and absf(c_lo[axis] - t_lo[axis]) > 1e-3:
					gaps.append("%s←%s" % [t.center, o.center])
	assert_eq(gaps, [] as Array[String], "no gap between touching thickets' cores")
	assert_gt(hidden, 0)


func test_drums_barrels_and_the_sofa_cast_shadows_and_shelving_leaves_it_to_its_rack() -> void:
	var dress := _dress(_map("depot"))
	for model: StringName in [&"drum", &"barrel", &"pallet", &"sofa"]:
		for view in dress.views_of(model):
			assert_ne(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts" % model)
	for view in dress.views_of(&"shelf"):
		assert_eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the rack's box casts it")


## The shelving is drawn in chunks no wider than PropDressConfig.chunk, so the camera culls what it can't see and far
## chunks take the simpler mesh the import generated (the Mesh detail step's threshold); the rest one view a model;
## every prop is drawn once.
func test_shelving_is_drawn_in_chunks_that_cull_and_take_a_simpler_mesh_far_off() -> void:
	var m := _map("depot")
	var dress := _dress(m)
	var placed := dress.placed()
	for model: StringName in placed:
		var views := dress.views_of(model)
		assert_eq(dress.count(model), placed[model].transforms.size(), "%s: each drawn once" % model)
		if model != &"shelf":
			assert_eq(views.size(), 1, "%s: one view" % model)
			continue
		var cells: Dictionary[Vector2i, bool] = {}
		for t in placed[model].transforms:
			cells[Vector2i(floori(t.origin.x / look.props.chunk), floori(t.origin.z / look.props.chunk))] = true
		assert_eq(views.size(), cells.size(), "shelving: a view a chunk")
	assert_gt(dress.views_of(&"shelf").size(), 10, "the shelving is many chunks, not one hall-wide draw")
	var lods: Array = RenderingServer.mesh_get_surface(dress.mesh_of(&"shelf").get_rid(), 0).get("lods", [])
	assert_gt(lods.size(), 0, "the shelf has a simpler mesh for far chunks")


func test_shelving_lines_only_faces_nobody_is_against() -> void:
	var m := _map("depot")
	var hidden := 0
	for b in m.blocks:
		if look.props.backs(b) and b.center.z > 30.0 and b.size.x > 100.0:
			assert_true(PropLayout.face_hidden(m, b, Vector3(0.0, 0.0, 1.0)), "the south rack's back is against the wall")
			assert_false(PropLayout.face_hidden(m, b, Vector3(0.0, 0.0, -1.0)), "its front faces the hall")
			hidden += 1
	assert_eq(hidden, 1)


func test_a_ramp_that_names_a_prop_keeps_its_box() -> void:
	var m := _map("woodland")
	var b: MapData.Block = null
	for o in m.blocks:
		if o.dress == &"crate":
			b = o
			break
	assert_true(look.props.dresses(b), "a crate block is drawn as crates")
	b.rise = MapData.Rise.POS_X
	assert_false(look.props.dresses(b), "but not as a ramp: it keeps its box")
	assert_eq(look.props.core_of(b), Vector2.ZERO)
	b.rise = MapData.Rise.NONE
