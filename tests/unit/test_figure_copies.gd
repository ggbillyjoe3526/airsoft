extends GutTest
## The figures' copies of the replicas and their parts (TP1): each replica's `Figure` cut down from its own model within
## its triangle budget, with its magazine, flash hider and iron sights as pieces of their own, which a fitted part
## replaces (ReplicaParts.fit_figure) as it does on the model in the hands.

const AEG := "000002"
const EPS := 1e-4
## Each replica's figure copy in all (docs/CC0_ASSETS.md › Size limits: 3,000 on a figure), and the share of it used at
## least (the owner's rule: a model uses its budget for detail).
const BUDGET := {&"aeg": 3000, &"sniper": 3000, &"pistol": 3000, &"cyber": 3000}
const USED := 0.95
## A part's copy (tools/blender/parts/figure_parts.py FIGURE_MAX).
const PART_MAX := 900

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func _tris(m: MeshInstance3D) -> int:
	return m.mesh.get_faces().size() / 3


## Replica `key`'s figure version, taken out of its model as FigureView takes it, and where the model's BarrelEnd and
## Muzzle points sit.
func _held(key: StringName) -> Array:
	var model := (load("res://assets/models/replicas/%s.glb" % key) as PackedScene).instantiate() as Node3D
	var held := model.find_child(ReplicaParts.FIGURE_NODE, true, false) as MeshInstance3D
	var ends: Array[Vector3] = []
	for n: String in [ReplicaParts.BARREL_END_NODE, ReplicaParts.MUZZLE_NODE]:
		var node := model.find_child(n, true, false) as Node3D
		ends.append(FigureView._in_model(node, model))
	held.get_parent().remove_child(held)
	held.owner = null
	for c in held.find_children("*", "", true, false):
		c.owner = null
	model.free()
	add_child_autofree(held)
	return [held, ends[0], ends[1]]


func test_each_figure_copy_uses_its_budget_and_has_its_pieces() -> void:
	for key: StringName in BUDGET:
		var held := _held(key)[0] as MeshInstance3D
		var total := _tris(held)
		for piece: Node in held.find_children("*", "MeshInstance3D", true, false):
			total += _tris(piece as MeshInstance3D)
		assert_lte(total, BUDGET[key], "%s: within its budget" % key)
		assert_gte(total, int(BUDGET[key] * USED), "%s: uses its budget" % key)
		assert_not_null(held.get_node_or_null(ReplicaParts.FIGURE_MAGAZINE), "%s: its magazine apart" % key)
	for key: StringName in [&"aeg", &"sniper"]:
		var held := _held(key)[0] as Node3D
		assert_not_null(held.get_node_or_null(ReplicaParts.FIGURE_FLASH_HIDER), "%s: its flash hider apart" % key)
		assert_not_null(held.get_node_or_null(ReplicaParts.FIGURE_SIGHTS), "%s: its iron sights apart" % key)


func test_the_figure_magazine_sits_where_the_models_magazine_does() -> void:
	for key: StringName in BUDGET:
		var model := (load("res://assets/models/replicas/%s.glb" % key) as PackedScene).instantiate() as Node3D
		add_child_autofree(model)
		var own := model.find_child(ReplicaParts.MAGAZINE_NODE, true, false) as MeshInstance3D
		var copy := model.find_child(ReplicaParts.FIGURE_MAGAZINE, true, false) as MeshInstance3D
		var a := FigureView._in_model(own, model) * own.get_aabb().get_center()
		var b := FigureView._in_model(copy, model) * copy.get_aabb().get_center()
		assert_lt(a.distance_to(b), 0.003, "%s: the copy over the magazine" % key)
		# Its mesh alone stands for the magazine (the reload draws it in the model's space).
		assert_lt((copy.mesh.get_aabb().get_center() - own.mesh.get_aabb().get_center()).length(), 0.003, "%s" % key)


func test_every_parts_copy_is_cut_down_from_its_part() -> void:
	for file: String in ["aeg", "pistol", "cyber", "sniper"]:
		var root := (load(ReplicaParts.PART_DIR + file + ".glb") as PackedScene).instantiate() as Node3D
		add_child_autofree(root)
		for c: Node in root.get_children():
			var part := c as MeshInstance3D
			if part == null or part.name.ends_with(ReplicaParts.FIGURE_SUFFIX):
				continue
			var copy := ReplicaParts.take(StringName(file), {StringName(String(part.name).split("_")[0]):
					StringName(String(part.name).split("_")[1])}, true).values()
			assert_eq(copy.size(), 1, "%s/%s has a copy" % [file, part.name])
			if copy.is_empty():
				continue
			var mesh := copy[0] as MeshInstance3D
			assert_lte(_tris(mesh), PART_MAX, "%s/%s copy within its budget" % [file, part.name])
			# The copy covers the part (it is made from it): their boxes in the replica's space nearly agree.
			var box := part.transform * part.get_aabb()
			var cbox := mesh.transform * mesh.get_aabb()
			assert_lt(box.get_center().distance_to(cbox.get_center()), 0.004, "%s/%s copy in place" % [file, part.name])
			mesh.free()


func test_an_optic_hides_the_iron_sights_and_leaves_the_rest() -> void:
	var h := _held(&"aeg")
	var held := h[0] as Node3D
	var fit := ReplicaParts.fit_figure(held, &"aeg", {&"optic": &"redDot"}, h[1], h[2])
	assert_false((held.get_node(ReplicaParts.FIGURE_SIGHTS) as Node3D).visible, "the irons folded away")
	assert_true((held.get_node(ReplicaParts.FIGURE_MAGAZINE) as Node3D).visible)
	assert_true((held.get_node(ReplicaParts.FIGURE_FLASH_HIDER) as Node3D).visible)
	assert_not_null(held.get_node_or_null("optic_redDot_Figure"))
	assert_eq(fit.magazine, held.get_node(ReplicaParts.FIGURE_MAGAZINE), "its own magazine")
	assert_almost_eq(fit.muzzle, h[2] as Vector3, Vector3.ONE * EPS, "the muzzle where it was")


func test_a_magazine_part_takes_the_magazines_place_and_is_the_reload_magazine() -> void:
	var h := _held(&"aeg")
	var held := h[0] as Node3D
	var fit := ReplicaParts.fit_figure(held, &"aeg", {&"magazine": &"hiCap"}, h[1], h[2])
	assert_false((held.get_node(ReplicaParts.FIGURE_MAGAZINE) as Node3D).visible, "the standard one hidden")
	assert_eq(String(fit.magazine.name), "magazine_hiCap_Figure")
	assert_eq(fit.magazine.transform, Transform3D.IDENTITY, "drawn in the replica's space, as the reload draws it")
	assert_true((held.get_node(ReplicaParts.FIGURE_SIGHTS) as Node3D).visible, "no optic: the irons up")


func test_a_silencer_replaces_the_flash_hider_and_moves_the_muzzle_out() -> void:
	var h := _held(&"aeg")
	var held := h[0] as Node3D
	var fit := ReplicaParts.fit_figure(held, &"aeg", {&"muzzle": &"silencer"}, h[1], h[2])
	assert_false((held.get_node(ReplicaParts.FIGURE_FLASH_HIDER) as Node3D).visible, "the flash hider off")
	# The figure faces -Z: the silencer's end is further out ahead than the replica's own muzzle.
	assert_lt(fit.muzzle.z, (h[2] as Vector3).z - 0.05, "the muzzle at the silencer's end")


func test_a_long_barrel_carries_the_flash_hider_and_muzzle_out_with_it() -> void:
	var h := _held(&"aeg")
	var held := h[0] as Node3D
	var hider := held.get_node(ReplicaParts.FIGURE_FLASH_HIDER) as Node3D
	var before := hider.position
	var fit := ReplicaParts.fit_figure(held, &"aeg", {&"barrel": &"long"}, h[1], h[2])
	var shift := fit.muzzle - (h[2] as Vector3)
	assert_lt(shift.z, -0.01, "the muzzle moved out")
	assert_almost_eq(hider.position - before, shift, Vector3.ONE * EPS, "the flash hider with it")
	assert_true(hider.visible)


func test_a_figure_reloads_the_magazine_part_it_carries() -> void:
	var l := rules.default_loadout("Test")
	if l.equipped[0] != AEG:
		rules.equip(l, 0 as Loadout.Slot, AEG)
	assert_true(rules.set_part(l, AEG, &"magazine", "000012"), "the hi-cap fits")
	var kit := rules.carried(l)
	var c := Character.new(3, 0, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights)
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.ORANGE, HitConfig.new(), GameTheme.font(800), false, kit.parts)
	var held := f._replicas[0]
	var part := held.get_node("magazine_hiCap_Figure") as MeshInstance3D
	assert_eq(f._magazines[0].mesh, part.mesh, "the hand's magazine is the hi-cap")
	assert_false((held.get_node(ReplicaParts.FIGURE_MAGAZINE) as Node3D).visible)
