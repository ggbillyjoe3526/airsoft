extends GutTest
## BA1 QA: the barrels' _Inside child never shows in a fitted, figure or painted view, the file stays in budget and
## the sniper's parts file is untouched.

const AEG_PARTS := "res://assets/models/replicaParts/aeg.glb"
const SNIPER_PARTS := "res://assets/models/replicaParts/sniper.glb"
const RIFLE := "res://assets/models/replicas/aeg.glb"
const FILE_BUDGET := 2 * 1024 * 1024
const BARRELS: Array[StringName] = [&"tightBore", &"long"]
const INNER_MATERIALS: Array[String] = ["Steel", "Brass", "Etch", "Chamber", "Bucking", "Bore"]


func _model() -> Node3D:
	var n := (load(RIFLE) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n


func _insides(root: Node) -> Array[Node]:
	return root.find_children("*_Inside", "", true, false)


func test_the_parts_file_is_under_two_megabytes() -> void:
	var f := FileAccess.open(AEG_PARTS, FileAccess.READ)
	assert_not_null(f)
	if f != null:
		assert_lt(f.get_length(), FILE_BUDGET)


func test_a_fitted_barrel_shows_no_inside_and_unfit_frees_it_all() -> void:
	for key: StringName in BARRELS:
		var model := _model()
		var before := model.find_children("*", "", true, false).size()
		var fit := ReplicaParts.fit(model, &"aeg", {&"barrel": key})
		assert_eq(_insides(model).size(), 0, "%s: nothing inside shows once fitted" % key)
		ReplicaParts.unfit(fit)
		assert_eq(model.find_children("*", "", true, false).size(), before, "%s: unfit leaves the rifle as it was" % key)
		assert_eq(_insides(model).size(), 0)
		# Fitting again after an unfit works the same.
		fit = ReplicaParts.fit(model, &"aeg", {&"barrel": key})
		assert_eq(fit.nodes.size(), 1)
		assert_eq(_insides(model).size(), 0)
		ReplicaParts.unfit(fit)


func test_a_fitted_barrel_among_other_parts_shows_no_inside_and_other_parts_survive() -> void:
	var model := _model()
	var fit := ReplicaParts.fit(model, &"aeg", {&"barrel": &"long", &"muzzle": &"silencer", &"optic": &"redDot"})
	assert_eq(_insides(model).size(), 0)
	assert_gt(fit.nodes.size(), 1)
	ReplicaParts.unfit(fit)


func test_figure_copies_carry_no_inside() -> void:
	for key: StringName in BARRELS:
		var meshes := ReplicaParts.figure_meshes(&"aeg", {&"barrel": key})
		assert_gt(meshes.size(), 0, "%s has a figure copy" % key)
		for m in meshes:
			assert_eq(_insides(m).size(), 0)
			assert_false(String(m.name).ends_with("_Inside"))
			m.free()


func test_a_barrels_inside_comes_from_its_own_file_and_the_part_alone_keeps_no_figure() -> void:
	for key: StringName in BARRELS:
		var node := ReplicaParts.take(&"aeg", {&"barrel": key}, false)[&"barrel"] as Node3D
		assert_null(node.get_node_or_null("barrel_%s_Inside" % key), "the parts file carries no inside")
		assert_null(node.get_node_or_null("barrel_%s_Figure" % key), "the figure copy is left out of the picture")
		node.free()
		var inside := ReplicaParts.inside(&"aeg", &"barrel", key)
		assert_not_null(inside, "barrel_%s has its inside" % key)
		if inside != null:
			assert_true(inside.visible)
			assert_null(inside.owner)
			inside.free()
	assert_null(ReplicaParts.inside(&"aeg", &"optic", &"redDot"), "a part with nothing inside has none")
	assert_null(ReplicaParts.inside(&"pistol", &"barrel", &"long"), "a replica with no insides file has none")


func test_paint_changes_the_extension_metal_but_not_the_inner_materials() -> void:
	var node := ReplicaParts.take(&"aeg", {&"barrel": &"long"}, false)[&"barrel"] as Node3D
	var holder := Node3D.new()
	add_child_autofree(holder)
	holder.add_child(node)
	ReplicaPaint.apply(holder, &"cobalt", false)
	var metal_painted := false
	for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(i)
			var over := m.get_surface_override_material(i)
			if own != null and own.resource_name in INNER_MATERIALS:
				assert_null(over, "%s keeps its own" % own.resource_name)
			elif own != null and own.resource_name == "Metal":
				metal_painted = metal_painted or over != null
	assert_true(metal_painted, "the extension's Metal takes the paint")


func test_the_sniper_parts_file_has_no_barrels_and_no_inside() -> void:
	var root := (load(SNIPER_PARTS) as PackedScene).instantiate() as Node3D
	assert_eq(root.find_children("barrel*", "", true, false).size(), 0)
	assert_eq(_insides(root).size(), 0)
	root.free()
