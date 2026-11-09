extends GutTest
## DM1: Depot's map models. A plywood wall is laid in modules at the batten pitch, stretched at most a tenth or made up
## with a cut module; a block takes the version of its kind built nearest its height (or the thin or flat one); a
## container's doors face the free end of its row, a cut piece lies along the row it joins and a unit beside another
## keeps its length along its box; every block of a joined row takes the first's paint, carried in the instances'
## custom data so bare steel stays unpainted; a map's doors take the leaf and frame built nearest their size, the
## frame as deep as the thinnest wall at the jamb and casting no shadow.

var play: PlayTuning = PlayTuning.load_default()
var cfg: PropDressConfig = null


func before_each() -> void:
	cfg = play.site_look.props


func _block(kind: StringName, center: Vector3, size: Vector3, piece: int = 0) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	b.piece = piece
	return b


func _boxes() -> Dictionary[StringName, AABB]:
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in cfg.models:
		var mesh := cfg.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	return boxes


func _map(blocks: Array[MapData.Block]) -> MapData:
	var m := MapData.new()
	m.id = "dm1 test"
	var floor_block := _block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(60.0, 0.5, 60.0))
	m.blocks.append(floor_block)
	m.blocks.append_array(blocks)
	return m


## The forward (+x) of a placed model's turn, flattened.
func _facing(t: Transform3D) -> Vector3:
	var x := t.basis.x
	return Vector3(x.x, 0.0, x.z).normalized()


func test_a_plywood_wall_is_laid_at_the_batten_pitch_stretched_under_a_tenth_or_with_a_cut_module() -> void:
	var boxes := _boxes()
	var unit := boxes[&"plywood"].size.x
	# 1.5 m: two modules and 0.28 m over, more than a tenth of them: two at the pitch and a cut one.
	var p: PropLayout.Placed = PropLayout.layout(_map([_block(&"plywood", Vector3(0.0, 1.3, 0.0),
			Vector3(1.5, 2.6, 0.3))]), cfg, boxes)[&"plywood"]
	var widths: Array[float] = []
	for t in p.transforms:
		widths.append(snappedf(t.basis.x.length() * unit, 0.001))
	widths.sort()
	assert_eq(widths, [0.28, 0.61, 0.61] as Array[float], "two whole modules and a cut one")
	# 1.85 m: three and 0.02 m over: three stretched 1 %.
	p = PropLayout.layout(_map([_block(&"plywood", Vector3(0.0, 1.3, 0.0), Vector3(1.85, 2.6, 0.3))]), cfg,
			boxes)[&"plywood"]
	assert_eq(p.transforms.size(), 3)
	for t in p.transforms:
		assert_almost_eq(t.basis.x.length() * unit, 1.85 / 3.0, 1e-4)
	# On all of Depot, no module but a cut one is more than a tenth off the pitch.
	var depot := MapData.load_map("depot", play.map_style, 6)
	var all := PropLayout.layout(depot, cfg, boxes)
	for model: StringName in [&"plywood", &"plywood_mid", &"plywood_low", &"plywood_short"]:
		if not all.has(model):
			continue
		for t in (all[model] as PropLayout.Placed).transforms:
			var w := t.basis.x.length() * boxes[model].size.x
			assert_true(w <= 0.61 * 1.1 + 1e-4, "%s %.3f m: stretched at most a tenth" % [model, w])


func test_a_block_takes_its_kind_s_version_built_nearest_its_height_or_the_thin_or_flat_one() -> void:
	var cases := [
		[&"plywood", Vector3(2.0, 2.6, 0.3), &"plywood"], [&"plywood", Vector3(2.0, 1.7, 0.3), &"plywood_mid"],
		[&"plywood", Vector3(2.0, 1.0, 0.3), &"plywood_low"], [&"plywood", Vector3(2.0, 0.6, 0.3), &"plywood_short"],
		[&"container", Vector3(5.0, 2.6, 2.4), &"container"], [&"container", Vector3(2.0, 1.0, 2.4), &"container_low"],
		[&"container", Vector3(2.0, 0.6, 2.4), &"container_short"],
		[&"container", Vector3(5.0, 2.6, 0.3), &"container_wall"], [&"container", Vector3(12.0, 0.2, 2.5), &"container_roof"],
	]
	for c: Array in cases:
		var b := _block(c[0], Vector3.ZERO, c[1])
		assert_eq(cfg.model_of(b), c[2], "%s %s" % [c[0], c[1]])
	assert_false(cfg.dresses(_block(&"plywood", Vector3.ZERO, Vector3(3.0, 0.2, 0.5))), "a board under 0.3 m stays a box")


func test_a_container_s_doors_face_the_free_end_of_its_row() -> void:
	# Two units end to end along x, the left one's doors away from its neighbour: -x; the right one's +x.
	var left := _block(&"container", Vector3(-2.5, 1.3, 10.0), Vector3(5.0, 2.6, 2.4), 1)
	var right := _block(&"container", Vector3(2.5, 1.3, 10.0), Vector3(5.0, 2.6, 2.4), 1)
	var m := _map([left, right])
	var out := PropLayout.layout(m, cfg, _boxes())
	var p: PropLayout.Placed = out[&"container"]
	assert_eq(p.transforms.size(), 2)
	assert_almost_eq(_facing(p.transforms[0]).x, -1.0, 1e-4, "the left unit's doors at its free (-x) end")
	assert_almost_eq(_facing(p.transforms[1]).x, 1.0, 1e-4, "the right unit's at +x")


func test_a_cut_piece_lies_along_its_row_and_a_unit_beside_another_keeps_its_length() -> void:
	# A 2 x 2.4 piece between two units along x lies along x though its box is longer in z.
	var a := _block(&"container", Vector3(-3.5, 1.3, 0.0), Vector3(5.0, 2.6, 2.4), 2)
	var cut := _block(&"container", Vector3(0.0, 0.5, 0.0), Vector3(2.0, 1.0, 2.4), 2)
	var b := _block(&"container", Vector3(3.5, 1.3, 0.0), Vector3(5.0, 2.6, 2.4), 2)
	var out := PropLayout.layout(_map([a, cut, b]), cfg, _boxes())
	var low: PropLayout.Placed = out[&"container_low"]
	assert_almost_eq(absf(_facing(low.transforms[0]).x), 1.0, 1e-4, "the cut piece along the row (x)")
	# Two units side by side (touching along their long sides) each keep their length along x.
	var c := _block(&"container", Vector3(0.0, 1.3, 20.0), Vector3(5.0, 2.6, 2.4), 3)
	var d := _block(&"container", Vector3(0.0, 1.3, 22.4), Vector3(5.0, 2.6, 2.4), 4)
	var side: PropLayout.Placed = PropLayout.layout(_map([c, d]), cfg, _boxes())[&"container"]
	for t in side.transforms:
		assert_almost_eq(absf(_facing(t).x), 1.0, 1e-4, "a unit beside another is not turned across")
		assert_almost_eq(t.basis.x.length(), 5.0 / _boxes()[&"container"].size.x, 1e-3, "nor squashed")


func test_a_joined_row_takes_its_first_block_s_paint_in_custom_data_and_bare_steel_stays_unpainted() -> void:
	var a := _block(&"container", Vector3(-3.5, 1.3, 0.0), Vector3(5.0, 2.6, 2.4), 5)
	var cut := _block(&"container", Vector3(0.0, 0.5, 0.0), Vector3(2.0, 1.0, 2.4), 6)
	var m := _map([a, cut])
	var paint := func(b: MapData.Block) -> Color: return Color(0.1 * b.piece, 0.2, 0.3)
	var dress := PropDress.build(m, cfg, paint)
	add_child_autofree(dress)
	for model: StringName in [&"container", &"container_low"]:
		# The headless renderer keeps no instance data, so the paint is read from the layout the views are built from.
		assert_true(dress.views_of(model)[0].multimesh.use_custom_data, "%s carries its paint in custom data" % model)
		assert_eq(dress.placed()[model].paints[0], Color(0.5, 0.2, 0.3), "%s takes the row's first paint" % model)
	var mat := dress.materials()[0] as ShaderMaterial
	assert_true(mat.get_shader_parameter(&"paint_by_custom"), "the props' shader paints by custom data")
	# The locking bars and keepers are bare (vertex alpha 0); the paint covers the rest (alpha 1).
	var alphas: Dictionary[float, bool] = {}
	for c in cfg.mesh_of(&"container").surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
		alphas[snappedf(c.a, 0.01)] = true
	assert_eq(alphas.keys().size(), 2, "a container has painted and bare parts")


func test_a_map_s_doors_take_the_leaf_and_frame_built_nearest_their_size() -> void:
	assert_eq(DoorView._nearest(DoorView.LEAF_MODELS, Vector3(0.97, 2.6, 0.0)),
			"res://assets/models/props/door_leaf.glb", "Depot's leaves")
	assert_eq(DoorView._nearest(DoorView.LEAF_MODELS, Vector3(0.77, 2.5, 0.0)),
			"res://assets/models/props/door_leaf_mid.glb", "the huts'")
	assert_eq(DoorView._nearest(DoorView.LEAF_MODELS, Vector3(0.42, 2.1, 0.0)),
			"res://assets/models/props/door_leaf_narrow.glb", "The Street's")
	assert_eq(DoorView._nearest(DoorView.FRAME_MODELS, Vector3(0.9, 2.1, 0.0)),
			"res://assets/models/props/door_frame_narrow.glb", "The Street's frame")
	for path: String in DoorView.LEAF_MODELS:
		assert_not_null(PropDressConfig.load_mesh(path), "%s loads" % path)
	for path: String in DoorView.FRAME_MODELS:
		assert_not_null(PropDressConfig.load_mesh(path), "%s loads" % path)


func test_a_frame_is_as_deep_as_the_thinnest_wall_at_its_jamb_and_casts_no_shadow() -> void:
	# A door in a 0.3 m wall along x whose jamb also meets the end of a 2 m deep block (a corner).
	var m := _map([
		_block(&"plywood", Vector3(1.5, 1.3, 0.0), Vector3(1.0, 2.6, 2.0)),
		_block(&"plywood", Vector3(-4.0, 1.3, 0.0), Vector3(6.0, 2.6, 0.3)),
		_block(&"plywood", Vector3(4.0, 1.3, 0.0), Vector3(6.0, 2.6, 0.3)),
	])
	var d := MapData.Door.new()
	d.center = Vector3(0.0, 1.3, 0.0)
	d.size = Vector3(2.0, 2.6, 0.08)
	m.doors.append(d)
	var view := DoorView.build(m, play.map_style, 0.4)
	add_child_autofree(view)
	var frames := view.get_node("Frames") as MultiMeshInstance3D
	assert_eq(frames.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var t := frames.multimesh.get_instance_transform(0)
	assert_almost_eq(t.basis.z.length(), 0.3 / 0.3, 1e-4, "the frame as deep as the 0.3 m wall, not the 2 m block")
