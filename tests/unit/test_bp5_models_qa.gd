extends GutTest
## BP5 models, QA: what merging the held replica must not change (its box, the parts it shows) and what it must keep.

var figures: FigureConfig = PlayTuning.load_default().figures
var hits: HitConfig = HitConfig.new()


func after_each() -> void:
	HeldMerge.clear()


func _view(parts: Array[Dictionary] = []) -> FigureView:
	var c := Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.BLUE, hits, GameTheme.font(800), false, parts, 0.0, figures)
	return v


func test_the_merged_replica_keeps_the_box_of_the_figure_mesh_it_replaced() -> void:
	var v := _view([{}, {}])
	var replicas: Array[MeshInstance3D] = v.get("_replicas")
	var ids: Array[String] = ["aeg", "pistol"]
	for i in replicas.size():
		var held := replicas[i]
		var scene := load("res://assets/models/replicas/%s.glb" % ids[i]) as PackedScene
		var raw := scene.instantiate().find_child(ReplicaParts.FIGURE_NODE, true, false) as MeshInstance3D
		var was := raw.get_aabb()
		var now := HeldMerge.figure_mesh(held).get_aabb()
		assert_true(now.is_equal_approx(was), "%s box (holster/back placement reads it)" % held.name)
		assert_true(FigureHands._butt(held, figures.shoulder_butt_depth).is_equal_approx(
				FigureHands._butt(raw, figures.shoulder_butt_depth)), "%s: the butt against the shoulder" % held.name)
		var root: Node = raw
		while root.get_parent() != null:
			root = root.get_parent()
		root.free()


func test_merge_key_tells_parts_paint_and_realistic_apart() -> void:
	var a := FigureView._merge_key(&"aeg", &"black", false, {&"optic": &"redDot"})
	assert_ne(a, FigureView._merge_key(&"aeg", &"black", true, {&"optic": &"redDot"}))
	assert_ne(a, FigureView._merge_key(&"aeg", &"tan", false, {&"optic": &"redDot"}))
	assert_ne(a, FigureView._merge_key(&"aeg", &"black", false, {}))
	assert_ne(a, FigureView._merge_key(&"aeg", &"black", false, {&"optic": &"scope2x"}))
	assert_eq(a, FigureView._merge_key(&"aeg", &"black", false, {&"optic": &"redDot"}))


func test_setting_up_the_same_figures_again_keeps_the_merged_meshes_to_the_same_few() -> void:
	_view([{}, {}])
	var once := HeldMerge.made_count()
	assert_gt(once, 0)
	for i in 4:
		_view([{}, {}])
	assert_eq(HeldMerge.made_count(), once, "same paints, same materials: no new meshes a setup")


func test_a_replica_with_no_mesh_is_placed_without_error() -> void:
	var bare := MeshInstance3D.new()
	add_child_autofree(bare)
	assert_null(HeldMerge.figure_mesh(bare))
	assert_eq(FigureHands._butt(bare, figures.shoulder_butt_depth), Vector3.ZERO)
