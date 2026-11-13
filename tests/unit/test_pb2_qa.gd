extends GutTest
## PB2 QA: the cutters across round resets, a defuser lost, a round ending mid-defuse; the lamp's material in every
## state; the view freeing everything it built.

var cfg := PlantViewConfig.new()
var ps: PlantState
var view: PlantView


func before_each() -> void:
	ps = PlantState.new()
	ps.set_sites(PackedVector3Array([Vector3(20.0, 0.0, -10.0)]), PackedFloat32Array([0.0]), 4.5)
	ps.start = Vector3(-20.0, 0.0, 0.0)
	ps.reset()
	view = PlantView.new()
	add_child_autofree(view)
	view.setup(cfg, TeamConfig.new(), ps)


func _cutters() -> Node3D:
	return view.prop().find_child("Cutters", true, false) as Node3D


func _defusing() -> void:
	ps.status = PlantState.Status.PLANTED
	ps.site = 0
	ps.position = ps.sites[0]
	ps.defuser = 2
	view.refresh(ps, 0, null, 1.0, false, 0.016)


func test_a_new_round_puts_the_cutters_away_and_the_bomb_back_at_the_start() -> void:
	_defusing()
	assert_true(_cutters().visible)
	ps.reset()
	view.refresh(ps, 0, null, 1.0, false, 0.016)
	assert_false(_cutters().visible)
	assert_eq(view.prop().position, ps.start)


func test_the_cutters_go_when_the_defuser_dies_or_lets_go_mid_defuse() -> void:
	_defusing()
	ps.defuser = -1
	view.refresh(ps, 0, null, 1.0, false, 0.016)
	assert_false(_cutters().visible)
	ps.defuser = 5
	view.refresh(ps, 0, null, 1.0, false, 0.016)
	assert_true(_cutters().visible, "a second defuser takes it up again")


func test_a_round_ending_mid_defuse_never_leaves_the_cutters_up() -> void:
	for end: PlantState.Status in [PlantState.Status.GONE_OFF, PlantState.Status.DEFUSED, PlantState.Status.DOWN]:
		_defusing()
		ps.status = end
		view.refresh(ps, 0, null, 1.0, false, 0.016)
		assert_false(_cutters().visible, "status %d with a defuser still set" % end)


func test_the_cutters_stay_up_in_the_carriers_own_view_only_when_armed() -> void:
	# An armed bomb is never carried, so hiding the carried prop must not hide a bomb being made safe.
	_defusing()
	view.refresh(ps, 0, null, 1.0, true, 0.016)
	assert_true(view.prop().visible)
	assert_true(_cutters().visible)


func test_the_cutters_snip_open_and_shut_symmetrically_and_a_zero_rate_holds_still() -> void:
	_defusing()
	var top := _cutters().find_child("CutterTop", true, false) as Node3D
	var bottom := _cutters().find_child("CutterBottom", true, false) as Node3D
	view.refresh(ps, 0, null, 1.0, false, 0.37)
	assert_almost_eq(top.rotation.y, -bottom.rotation.y, 0.0001)
	cfg.cutters_snips = 0.0
	view.refresh(ps, 0, null, 1.0, false, 5.0)
	var held := top.rotation.y
	view.refresh(ps, 0, null, 1.0, false, 5.0)
	assert_eq(top.rotation.y, held)


func test_the_lamps_material_takes_each_states_colour() -> void:
	var want: Dictionary = {
		PlantState.Status.DEFUSED: cfg.lamp_safe,
		PlantState.Status.PLANTED: cfg.lamp_off,
	}
	for status: PlantState.Status in want:
		ps.status = status
		view.refresh(ps, 0, null, 1.0, false, 0.016)
		assert_eq(view.lamp_colour(), want[status])
		assert_eq(view.materials()[0].albedo_color, want[status], "the model's lamp uses the tint")
	view.on_cue(Plant.Cue.BEEP, Vector3.ZERO, null)
	ps.status = PlantState.Status.PLANTED
	view.refresh(ps, 0, null, 1.0, false, 0.016)
	assert_eq(view.materials()[0].albedo_color, cfg.lamp_armed)


func test_the_lamp_node_is_drawn_with_the_views_lamp_material() -> void:
	var lamp := view.prop().find_child(PlantView.LAMP_NODE, true, false) as MeshInstance3D
	var found := false
	for i in lamp.mesh.get_surface_count():
		if lamp.get_surface_override_material(i) == view.materials()[0]:
			found = true
	assert_true(found)


func test_the_view_frees_all_it_built() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var v := PlantView.new()
	add_child(v)
	v.setup(cfg, TeamConfig.new(), ps)
	v.refresh(ps, 0, null, 1.0, false, 0.016)
	remove_child(v)
	v.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)


func test_the_cutters_are_scenery_without_a_collider() -> void:
	assert_eq(view.find_children("*", "CollisionObject3D", true, false).size(), 0)
