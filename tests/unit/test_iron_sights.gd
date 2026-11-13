extends GutTest
## Iron sights under an optic (owner, 2026-11-05, a standing rule for every replica): with any optic fitted a replica's
## iron sights are removed completely, never folded, so nothing of them stands in the optic's way. Every replica model
## that takes an optic (an OpticMount) is checked, so a new one is held to it too.

const MODEL_DIR := "res://assets/models/replicas/"
## The optic each check fits (every optic-taking replica's parts file has it).
const OPTIC := &"redDot"
## How far over the rail's top (the OpticMount) anything left may reach, m.
const OVER_RAIL := 0.0005
## Half the width of the rail's top strip checked, m.
const STRIP_HW := 0.012
## Replicas built with no iron sights at all (the Pump Shotgun aims along its rail: owner, 2026-11-12): none to hide,
## and still nothing but the optic over the rail.
const NO_SIGHTS: Array[StringName] = [&"shotgun"]


## Replica keys whose model has an OpticMount, with their model instanced in the tree.
func _optic_models() -> Dictionary[StringName, Node3D]:
	var out: Dictionary[StringName, Node3D] = {}
	for file in DirAccess.get_files_at(MODEL_DIR):
		if not file.ends_with(".glb"):
			continue
		var model := (load(MODEL_DIR + file) as PackedScene).instantiate() as Node3D
		add_child_autofree(model)
		if model.find_child("OpticMount", true, false) != null:
			out[StringName(file.get_basename())] = model
	return out


func test_the_rifles_take_optics() -> void:
	var keys := _optic_models().keys()
	assert_has(keys, &"aeg")
	assert_has(keys, &"sniper")


func test_an_optic_hides_every_replicas_iron_sights_whole_and_taking_it_off_brings_them_back() -> void:
	var models := _optic_models()
	for key: StringName in models:
		var model := models[key]
		var sights := IronSights.of(model)
		assert_eq(sights.size(), 0 if NO_SIGHTS.has(key) else 2,
				"%s: a front and a rear sight bone (none on a replica built without)" % key)
		var fit := ReplicaParts.fit(model, key, {&"optic": OPTIC})
		assert_not_null(fit.optic, "%s takes the %s" % [key, OPTIC])
		for sight in sights:
			assert_false(sight.is_visible_in_tree(), "%s: %s hidden under the optic" % [key, sight.name])
		ReplicaParts.unfit(fit)
		for sight in sights:
			assert_true(sight.is_visible_in_tree(), "%s: %s back without it" % [key, sight.name])


func test_with_the_sights_hidden_nothing_but_the_optic_stands_over_the_rail() -> void:
	await wait_process_frames(1)
	var models := _optic_models()
	for key: StringName in models:
		var model := models[key]
		var mount := (model.find_child("OpticMount", true, false) as Node3D)
		var rail_top := _in_model(mount, model).origin.y
		var a := _in_model(model.find_child("FrontSight", true, false) as Node3D, model).origin.z
		var b := _in_model(model.find_child("RearSight", true, false) as Node3D, model).origin.z
		var sights := IronSights.of(model)
		var highest := -INF
		var what := ""
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			# The figures' copy (Figure and its pieces, TP1) is hidden in the hands; fit_figure hides its Figure_Sights.
			if String(mesh.name).begins_with(ReplicaParts.FIGURE_NODE) or _under_any(mesh, sights):
				continue
			var to_model := _in_model(mesh, model)
			for v in mesh.mesh.get_faces():
				var p := to_model * v
				if absf(p.x) < STRIP_HW and p.z > minf(a, b) and p.z < maxf(a, b) and p.y > highest:
					highest = p.y
					what = mesh.name
		assert_lt(highest, rail_top + OVER_RAIL,
				"%s: only the iron sights rise over the rail between them (%s at %.4f m)" % [key, what, highest])


func _under_any(node: Node, parents: Array[Node3D]) -> bool:
	for p in parents:
		if p.is_ancestor_of(node):
			return true
	return false


func _in_model(node: Node3D, model: Node3D) -> Transform3D:
	return model.global_transform.affine_inverse() * node.global_transform
