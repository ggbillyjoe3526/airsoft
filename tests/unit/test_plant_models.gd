extends GutTest
## Plant The Bomb's models in PlantView (PB2): the bomb drawn from its model with its lamp tinted, its front turned to
## whoever keys it in, and the wire cutters at its red wire, shown and snipping only while it is being made safe.

var cfg := PlantViewConfig.new()
var ps: PlantState
var view: PlantView


func before_each() -> void:
	ps = PlantState.new()
	ps.set_sites(PackedVector3Array([Vector3(20.0, 0.0, -10.0), Vector3(20.0, 0.0, 10.0)]),
			PackedFloat32Array([0.0, 0.0]), 4.5)
	ps.start = Vector3(-20.0, 0.0, 0.0)
	ps.reset()
	view = PlantView.new()
	add_child_autofree(view)
	view.setup(cfg, TeamConfig.new(), ps)


func _bomb() -> Node3D:
	return view.prop().get_child(0) as Node3D


func _cutters() -> Node3D:
	return view.prop().find_child("Cutters", true, false) as Node3D


func test_the_bomb_is_drawn_from_its_model_turned_to_face_plus_z() -> void:
	assert_eq(view.prop().get_child_count(), 1, "the model alone, no stand-in boxes")
	assert_not_null(_bomb().find_child(PlantView.LAMP_NODE, true, false), "its lamp")
	assert_almost_eq(_bomb().rotation.y, PI, 0.001, "its wires' end towards whoever keys it in")


func test_the_model_fits_the_bounds_the_light_is_taken_at() -> void:
	var box := AABB()
	var first := true
	for node in _bomb().find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if not m.is_visible_in_tree():
			continue
		var b := m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	assert_almost_eq(box.position.y, 0.0, 0.002, "it stands on its origin")
	assert_almost_eq(box.size.y, cfg.case_size.y, 0.003)
	assert_almost_eq(box.size.x, cfg.case_size.x, 0.003)


func test_every_surface_is_painted_in_the_shared_light_and_the_lamp_in_its_state() -> void:
	var lamp_seen := false
	for node in view.prop().find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var shown := m.get_surface_override_material(i)
			assert_not_null(shown, "%s surface %d painted" % [m.name, i])
			if shown is StandardMaterial3D:
				lamp_seen = true
				assert_eq(m.mesh.surface_get_material(i).resource_name, PlantView.LAMP_MATERIAL)
	assert_true(lamp_seen, "the lamp's own material is the view's, tinted by the bomb's state")
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_true(view.materials().size() > 4, "the lamp, the rings and the models' paints prewarm")


func test_the_cutters_show_only_while_someone_makes_it_safe_and_snip() -> void:
	assert_not_null(_cutters())
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_false(_cutters().visible, "on the ground: no cutters")
	ps.status = PlantState.Status.PLANTED
	ps.site = 0
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_false(_cutters().visible, "armed and nobody at it: none")
	ps.defuser = 4
	view.refresh(ps, 0, null, 1.0, false, 0.0)
	assert_true(_cutters().visible)
	var top := _cutters().find_child("CutterTop", true, false) as Node3D
	var first := top.rotation.y
	view.refresh(ps, 0, null, 1.0, false, 0.25 / cfg.cutters_snips)
	assert_ne(top.rotation.y, first, "the halves open and close")
	assert_between(-top.rotation.y, 0.0, cfg.cutters_open + 0.001)
	ps.defuser = -1
	ps.status = PlantState.Status.DEFUSED
	view.refresh(ps, 0, null, 1.0, false, 0.01)
	assert_false(_cutters().visible, "made safe: put away")


func test_the_cutters_tip_is_at_the_red_wire() -> void:
	var cut := _bomb().find_child(PlantView.CUT_MARK, true, false) as Node3D
	var tip := _cutters().transform * Vector3(0.0, 0.0, -PlantView.CUTTERS_TIP)
	assert_almost_eq(tip.distance_to(cut.position), 0.0, 0.0005)
