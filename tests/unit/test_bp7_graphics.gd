extends GutTest
## BP7, the known-issues pass's graphics: occlusion culling behind a Graphics row (MapOccluders: the tall solid blocks as
## one occluder, off on Low), Depot's dim Lounge in the bake, and Woodland's often-laid props in larger chunks; the
## critic's retry: the doors, poles and props in the baked light near them (BakedLightNear), and no lamp over the Lounge.

var play: PlayTuning = PlayTuning.load_default()
var table: GraphicsTable = null
var _culling: bool = false
var _depot: MapLevel = null


func before_each() -> void:
	table = GraphicsTable.shared()
	_culling = get_tree().root.use_occlusion_culling


func after_each() -> void:
	get_tree().root.use_occlusion_culling = _culling


func after_all() -> void:
	if _depot != null:
		_depot.free()
		_depot = null


## Depot built once, its baked light drawn (greybox: the light is the site's too).
func _baked_depot() -> MapLevel:
	if _depot == null:
		var m := MapData.load_map("depot", play.map_style, 5)
		_depot = MapLevel.new()
		add_child(_depot)
		var sun := LightingConfig.for_map(play.lighting, null, m, LightingConfig.DAY)
		_depot.build(m, play.map_style, SimTuning.load_default().body, play.baked_light, sun)
	_depot.set_baked_light(true)
	return _depot


## Whether `at` lies within `reach` m of the edge of one of `map`'s dim rooms.
func _by_dim_edge(map: MapData, at: Vector3, reach: float) -> bool:
	for r in map.baked_dim_boxes:
		var p := Vector2(at.x, at.z)
		if r.grow(reach).has_point(p) and not r.grow(-reach).has_point(p):
			return true
	return false


func _block(kind: StringName, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.size = size
	b.center = Vector3(0.0, size.y * 0.5, 0.0)
	return b


func test_occlusion_culling_is_off_on_low_and_on_from_medium() -> void:
	assert_false(table.preset(&"low").occlusion_culling, "Low: the processor is the tighter budget")
	for p: StringName in [&"medium", &"high", &"ultra"]:
		assert_true(table.preset(p).occlusion_culling, "%s culls what walls hide" % p)
	var row := table.row(GraphicsQuality.OCCLUSION_CULLING)
	assert_eq(row.cost, 0, "it costs the graphics card nothing")
	assert_eq(row.renderers, GraphicsTable.RENDERERS, "every renderer culls (BP7: Compatibility under Xvfb did)")


func test_the_row_switches_the_root_viewport() -> void:
	var rs := GraphicsApply.Server.new()
	var root := get_tree().root
	GraphicsApply.apply(table.preset(&"high"), root, rs)
	assert_true(root.use_occlusion_culling)
	GraphicsApply.apply(table.preset(&"low"), root, rs)
	assert_false(root.use_occlusion_culling)
	var custom := table.preset(&"low")
	custom.occlusion_culling = true
	assert_eq(GraphicsQuality.choice_of(custom, table), GraphicsQuality.CUSTOM, "Low with it on is Custom")
	assert_eq(GraphicsQuality.overrides(custom, &"low", table), {"occlusion_culling": "on"} as Dictionary[String, Variant])


func test_only_tall_solid_plain_boxes_occlude() -> void:
	var style := play.map_style
	assert_true(MapOccluders.is_occluder(_block(&"plywood", Vector3(2.4, 2.6, 0.1)), style), "a plywood wall")
	assert_true(MapOccluders.is_occluder(_block(&"container", Vector3(6.0, 2.6, 2.4)), style))
	assert_false(MapOccluders.is_occluder(_block(&"plywood", Vector3(2.4, 1.0, 0.1)), style), "too low to hide a bot")
	assert_false(MapOccluders.is_occluder(_block(&"wall", Vector3(0.6, 8.0, 0.6)), style), "a pillar's width")
	assert_false(MapOccluders.is_occluder(_block(&"rack", Vector3(4.0, 3.0, 1.0)), style), "racks are see-through")
	assert_false(MapOccluders.is_occluder(_block(&"net", Vector3(4.0, 2.8, 0.1)), style), "nets are see-through")
	assert_false(MapOccluders.is_occluder(_block(&"glass", Vector3(4.0, 2.8, 0.1)), style), "glass is see-through")
	var dressed := _block(&"crate", Vector3(2.0, 2.4, 2.0))
	dressed.dress = &"crate"
	assert_false(MapOccluders.is_occluder(dressed, style), "a prop's model is not its box")
	var ramp := _block(&"plywood", Vector3(2.0, 2.4, 2.0))
	ramp.rise = MapData.Rise.POS_X
	assert_false(MapOccluders.is_occluder(ramp, style), "a ramp's wedge is not its box")


func test_each_map_s_occluder_is_its_tall_solid_blocks_inset() -> void:
	for id: String in ["depot", "woodland", "street"]:
		var map := MapData.load_map(id, play.map_style, 5)
		var expected := 0
		for b in map.blocks:
			expected += 1 if MapOccluders.is_occluder(b, play.map_style) else 0
		var occ := MapOccluders.build(map, play.map_style)
		assert_not_null(occ, "%s has walls to hide behind" % id)
		if occ == null:
			continue
		assert_eq(occ.boxes, expected, id)
		var shape := occ.occluder as ArrayOccluder3D
		assert_eq(shape.vertices.size(), expected * MapOccluders.CORNERS, "%s: eight corners a box" % id)
		assert_eq(shape.indices.size(), expected * MapOccluders.TRIANGLES.size(), "%s: twelve triangles a box" % id)
		occ.free()


func test_the_occluder_stays_inside_its_block() -> void:
	var map := MapData.parse("""{"name": "Walls", "blocks": [
		{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 21, "y": 0.5, "z": 21}},
		{"kind": "wall", "center": {"x": 0, "y": 2, "z": -10.25}, "size": {"x": 21, "y": 4, "z": 0.5}},
		{"kind": "rack", "center": {"x": 0, "y": 1.5, "z": 5}, "size": {"x": 4, "y": 3, "z": 1}}],
		"spawns": [[{"position": {"x": -5, "y": 0, "z": 0}}], [{"position": {"x": 5, "y": 0, "z": 0}}]],
		"deadZones": [[{"position": {"x": -8, "y": 0, "z": 8}}], [{"position": {"x": 8, "y": 0, "z": 8}}]]}""",
			play.map_style, 1)
	assert_true(map.ok(), "%s" % [map.problems])
	var occ := MapOccluders.build(map, play.map_style)
	assert_eq(occ.boxes, 1, "the wall alone: the floor is low and the rack see-through")
	var box := AABB(map.blocks[1].center - map.blocks[1].size * 0.5, map.blocks[1].size)
	var inset := play.map_style.occluder_inset
	for p in (occ.occluder as ArrayOccluder3D).vertices:
		assert_true(box.grow(-inset + 1e-4).has_point(p), "%s inside the wall, %s m in" % [p, inset])
	occ.free()
	var open := MapData.parse("""{"name": "Open", "blocks": [
		{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 21, "y": 0.5, "z": 21}}],
		"spawns": [[{"position": {"x": -5, "y": 0, "z": 0}}], [{"position": {"x": 5, "y": 0, "z": 0}}]],
		"deadZones": [[{"position": {"x": -8, "y": 0, "z": 8}}], [{"position": {"x": 8, "y": 0, "z": 8}}]]}""",
			play.map_style, 1)
	assert_null(MapOccluders.build(open, play.map_style), "nothing tall: no occluder")


func test_depot_s_lounge_is_dim_in_the_bake() -> void:
	var depot := MapData.load_map("depot", play.map_style, 5)
	assert_eq(depot.warnings, [] as Array[String])
	assert_eq(depot.baked_dim_boxes.size(), 1, "the Lounge")
	var lounge := Rect2(-10, -33, 20, 15)
	assert_eq(depot.baked_dim_boxes[0], lounge, "the Lounge's box, as its area")
	assert_lt(depot.baked_light_at(Vector2(0.0, -25.0)), 0.5, "dim inside")
	assert_eq(depot.baked_light_at(Vector2(30.0, 0.0)), 1.0, "lit outside")
	var bake := BakedLight.load_for(depot)
	assert_not_null(bake)
	if bake == null:
		return
	var t := GreyboxFaces.tile(depot, play.baked_light.cell, play.baked_light.ground_y)
	var cap := roundi(depot.baked_dim_light[0] * BakedLight.FULL) + 1
	var inside := 0
	var over := 0
	var brightest_out := 0
	for v in bake.vertex_count:
		var p := t.positions[v]
		if lounge.grow(-0.01).has_point(Vector2(p.x, p.z)):
			inside += 1
			over += 1 if bake.sky[v] > cap else 0
		else:
			brightest_out = maxi(brightest_out, bake.sky[v])
	assert_gt(inside, 100, "the Lounge's floor and walls are baked")
	assert_eq(over, 0, "no Lounge vertex sees more than the dim share of the sky")
	assert_gt(brightest_out, cap, "the rest of the hall is not dimmed")


func test_a_dim_room_is_part_of_the_bake_s_hash_and_a_bad_one_is_left_out() -> void:
	var depot := MapData.load_map("depot", play.map_style, 5)
	var lighting := LightingConfig.for_map(play.lighting, null, depot, LightingConfig.DAY)
	var with := BakedLight.hash_of(depot, play.map_style, lighting, play.baked_light)
	depot.baked_dim_light[0] = 0.5
	assert_ne(BakedLight.hash_of(depot, play.map_style, lighting, play.baked_light), with, "a dimmer room asks a rebake")
	var m := MapData.new()
	m._read_baked_light({"file": "x", "dim": [{"box": [0, 1, 0, 1], "light": 2.0}, {"box": [0, 1], "light": 0.5},
			{"box": [4, 0, 2, 0], "light": 0.5}]})
	assert_eq(m.warnings.size(), 2, "a light over 1 and a box of two numbers: %s" % [m.warnings])
	assert_eq(m.baked_dim_boxes, [Rect2(0, 0, 4, 2)] as Array[Rect2], "a box given high to low still reads")


func test_woodland_s_often_laid_props_draw_in_larger_chunks_than_the_shelving() -> void:
	var cfg := play.site_look.props
	assert_gt(cfg.many_chunk, cfg.chunk, "fewer draws for the wood's trunks, spruces and cordwood")
	var woodland := MapData.load_map("woodland", play.map_style, 5)
	var dress := PropDress.build(woodland, cfg)
	assert_not_null(dress)
	if dress == null:
		return
	var chunked := 0
	for model: StringName in dress.placed():
		var placed := dress.placed()[model]
		if placed.transforms.size() < cfg.chunk_from or PropDress._tiled(cfg, model):
			continue
		chunked += 1
		var cells: Dictionary[Vector2i, bool] = {}
		for t in placed.transforms:
			cells[Vector2i(floori(t.origin.x / cfg.many_chunk), floori(t.origin.z / cfg.many_chunk))] = true
		assert_eq(dress.views_of(model).size(), cells.size(), "%s: one draw a %d m square" % [model, cfg.many_chunk])
	assert_gt(chunked, 0, "some model is laid often enough to chunk")
	dress.free()


func test_the_light_near_a_point_is_the_mean_of_the_baked_vertices_round_it() -> void:
	var at := PackedVector3Array([Vector3.ZERO, Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0), Vector3(5.0, 0.0, 0.0)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.RIGHT, Vector3.UP])
	var light := PackedColorArray([Color(0.2, 0.2, 0.2), Color(0.4, 0.4, 0.4), Color.WHITE, Color(0.9, 0.9, 0.9)])
	var near := BakedLightNear.new(at, normals, light)
	var p := Vector3(0.0, 0.1, 0.0)
	assert_almost_eq(near.at(p).g, (0.2 + 0.4 + 1.0) / 3.0, 0.001, "every face within reach, the far one left out")
	assert_almost_eq(near.at(p, Vector3.UP).g, 0.3, 0.001, "only the faces facing up")
	assert_eq(near.at(Vector3(20.0, 0.0, 0.0)), Color.WHITE, "nothing near: white")
	assert_eq(near.at(Vector3(20.0, 0.0, 0.0), Vector3.ZERO, Color.RED), Color.RED, "or the fallback asked for")
	assert_almost_eq(near.on_side(p, Vector3.RIGHT).g, 1.0, 0.001, "the face on that side")
	assert_almost_eq(near.on_side(p, Vector3.LEFT).g, 1.0, 0.001, "none facing that way: the other side's")
	assert_eq(near.on_side(Vector3(20.0, 0.0, 0.0), Vector3.RIGHT), Color.WHITE, "neither: white")


func test_depot_s_doors_take_the_light_of_the_wall_on_each_side() -> void:
	var level := _baked_depot()
	var map := level.map
	var doors := DoorView.build(map, play.map_style, 0.4)
	add_child_autofree(doors)
	for j in map.doors.size() * 2:
		assert_eq(doors.light_of(j, true), Color.WHITE, "built in the shared light alone")
	doors.relight(level.baked_lights())
	var lounge := 0
	for i in map.doors.size():
		for k in 2:
			var j := i * 2 + k
			var dark := minf(doors.light_of(j, true).g, doors.light_of(j, false).g)
			var bright := maxf(doors.light_of(j, true).g, doors.light_of(j, false).g)
			if _by_dim_edge(map, map.doors[i].center, 0.5):
				lounge += 1
				assert_lt(dark, 0.5, "door %d: dim on the Lounge's side" % i)
				assert_gt(bright, 0.8, "door %d: lit on the hall's" % i)
			else:
				assert_gt(dark, 0.8, "door %d: as lit as the hall's walls both ways" % i)
			assert_lt(bright, 1.3, "door %d: no brighter than a baked face can be" % i)
	assert_gt(lounge, 2, "the Lounge's doors")
	doors.relight(null)
	assert_eq(doors.light_of(2, true), Color.WHITE, "Baked light off: the shared light alone")
	level.set_baked_light(false)
	assert_null(level.baked_lights(), "nothing near to light by with the bake not drawn")


func test_depot_s_props_and_poles_take_the_bake_near_them() -> void:
	var level := _baked_depot()
	var lights := level.baked_lights()
	var props := PropDress.build(level.map, play.site_look.props)
	add_child_autofree(props)
	props.relight(lights)
	assert_lt(props.light_of(&"sofa", 0).g, 0.5, "the Lounge's sofa is dim")
	var shelves := props.placed()[&"shelf"].transforms.size()
	var sum := 0.0
	for i in shelves:
		sum += props.light_of(&"shelf", i).g
	assert_gt(sum / shelves, 0.6, "the hall's shelving is not")
	props.relight(null)
	assert_eq(props.light_of(&"sofa", 0), Color.WHITE, "Baked light off: its shade alone")
	var teams := TeamColours.resolve(TeamColours.Set.STANDARD, false, null, play.teams).figures
	var pole := FlagView.new()
	add_child_autofree(pole)
	pole.setup(play.flag, teams, level.map.overtime_flag, 3.0)
	assert_eq(pole.materials().size(), 3, "the cloth, ring and the pole's model are prewarmed")
	pole.relight(lights)
	var lit := pole.pole_light()
	assert_true(lit.g > 0.6 and lit.g < 1.3, "the floor's light at its foot: %s" % lit)
	var tint: Color = (pole.materials()[2] as ShaderMaterial).get_shader_parameter(&"tint")
	assert_almost_eq(tint.g, LookMaterials.lit_paint(Color.WHITE, lit).g, 0.001, "the pole drawn in it")
	pole.relight(null)
	tint = (pole.materials()[2] as ShaderMaterial).get_shader_parameter(&"tint")
	assert_almost_eq(tint.g, 1.0, 0.001, "off: its own colours")
	var overtime := OvertimeFlagView.new()
	add_child_autofree(overtime)
	overtime.setup(play.flag, teams, level.map.overtime_flag, 3.0)
	assert_eq(overtime.materials().size(), 3, "the cloth, ring and the pole's model are prewarmed")
	overtime.relight(lights)
	assert_almost_eq(overtime.pole_light().g, lit.g, 0.001, "the same floor, the same light")


func test_no_roof_lamp_hangs_over_a_dim_room() -> void:
	var depot := MapData.load_map("depot", play.map_style, 5)
	assert_gt(depot.roof_lamps.size(), 50, "the hall keeps its lamps")
	for lamp in depot.roof_lamps:
		for r in depot.baked_dim_boxes:
			assert_false(r.has_point(lamp), "no lamp over the Lounge: %s" % lamp)
