extends GutTest
## BA1: the AEG Rifle's barrel upgrades in assets/models/replicaParts/aeg.glb. Each is an inner barrel in its hop-up unit
## (the long barrel with its outer extension): what sits inside the rifle is in replicaParts/inside/aeg.glb, drawn only in
## the part's own picture (ReplicaParts.inside), never loaded by a fit.

const PARTS_FILE := "res://assets/models/replicaParts/aeg.glb"
const INSIDE_FILE := "res://assets/models/replicaParts/inside/aeg.glb"
const RIFLE := "res://assets/models/replicas/aeg.glb"
const BARRELS: Array[StringName] = [&"tightBore", &"long"]
const PART_TRIS := 10000
## The rifle's barrel end and hop-up dial along the bore (tools/blender/replicas/aeg.py), and its flash hider's bore.
const BARREL_END_Y := 0.339
const HOP_DIAL_Y := 0.026
const HIDER_BORE_R := 0.006
## The rifle's barrel's radius at its end and the long barrel's coupling over it (tools/blender/parts/barrels.py).
const BARREL_R := 0.0086
const COUPLING_R := 0.01045
const LONG_END := 0.1
const SLACK := 0.0005


func _load(path: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n


func _tris(m: MeshInstance3D) -> int:
	return m.mesh.get_faces().size() / 3


## Every mesh's box under `root`, in `root`'s space.
func _box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n: Node in meshes:
		var m := n as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var at: Node = m
		while at != root:
			xf = (at as Node3D).transform * xf
			at = at.get_parent()
		var b := xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func test_each_barrel_has_its_figure_and_inside_and_keeps_the_whole_part_under_budget() -> void:
	var root := _load(PARTS_FILE)
	var insides := _load(INSIDE_FILE)
	for key: StringName in BARRELS:
		var n := "barrel_%s" % key
		var part := root.get_node_or_null(n) as MeshInstance3D
		assert_not_null(part, n)
		if part == null:
			continue
		var inside := insides.get_node_or_null(n + "_Inside") as MeshInstance3D
		var fig := part.get_node_or_null(n + "_Figure") as MeshInstance3D
		assert_not_null(inside, "%s has its inner barrel and hop-up unit" % n)
		assert_not_null(fig, "%s has its figure copy" % n)
		if inside == null or fig == null:
			continue
		assert_lt(_tris(part) + _tris(inside) + _tris(fig), PART_TRIS, "%s with all it carries" % n)
		assert_lt(_tris(fig), _tris(part), "%s figure is cut down" % n)
		assert_almost_eq(part.position, Vector3(0.0, 0.044, -BARREL_END_Y), Vector3.ONE * 0.0001,
				"%s sits on the rifle's barrel end" % n)
		assert_almost_eq(inside.position, part.position, Vector3.ONE * 0.0001, "%s inside sits where it does" % n)


func test_the_inner_barrel_reaches_back_to_the_rifles_hop_up_and_out_to_the_crown() -> void:
	var root := _load(INSIDE_FILE)
	for key: StringName in BARRELS:
		var part := root.get_node(NodePath("barrel_%s_Inside" % key)) as Node3D
		var box := part.transform * _box(part)
		# In the rifle's space Godot's -Z is the bore's forward: the box's back is its largest z.
		var back := -(box.position.z + box.size.z)
		assert_lt(back, HOP_DIAL_Y - 0.02, "barrel_%s: its hop-up unit is round the rifle's dial" % key)
		assert_gt(back, HOP_DIAL_Y - 0.04, "barrel_%s: and no further back" % key)


func test_a_fitted_tight_bore_leaves_only_its_crown_in_the_flash_hiders_bore() -> void:
	var model := _load(RIFLE)
	var fit := ReplicaParts.fit(model, &"aeg", {&"barrel": &"tightBore"})
	assert_eq(fit.nodes.size(), 1)
	var node := fit.nodes[0]
	var box := _box(node)
	assert_lt(maxf(absf(box.position.x), absf(box.end.x)), HIDER_BORE_R, "the crown fits the hider's bore")
	assert_lt(maxf(absf(box.position.y), absf(box.end.y)), HIDER_BORE_R)
	assert_lt(-box.position.z, 0.01, "it stands under a centimetre past the barrel's end")
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	assert_eq(fit.muzzle, muzzle, "the muzzle stays where it is")
	ReplicaParts.unfit(fit)


func test_a_fitted_long_barrel_keeps_its_extension_and_end() -> void:
	var model := _load(RIFLE)
	var fit := ReplicaParts.fit(model, &"aeg", {&"barrel": &"long"})
	var node := fit.nodes[0]
	var end := node.get_node_or_null("barrel_long_BarrelEnd") as Node3D
	assert_not_null(end)
	if end != null:
		assert_almost_eq(end.position, Vector3(0.0, 0.0, -LONG_END), Vector3.ONE * 0.0001)
	var box := _box(node)
	assert_lt(box.size.x, 2.0 * COUPLING_R + SLACK, "the coupling is as slim as the rifle's barrel allows")
	assert_gt(box.size.x, 2.0 * BARREL_R, "and covers the barrel's end")
	ReplicaParts.unfit(fit)


func test_a_barrels_inside_keeps_its_own_materials_under_paint() -> void:
	for key: StringName in BARRELS:
		var inside := ReplicaParts.inside(&"aeg", &"barrel", key)
		assert_not_null(inside, "barrel_%s has its inside" % key)
		if inside == null:
			continue
		var holder := Node3D.new()
		add_child_autofree(holder)
		holder.add_child(inside)
		ReplicaPaint.apply(holder, &"cobalt", false)
		var m := inside as MeshInstance3D
		var named := ReplicaSurfaces.named(m.mesh)
		var surfaced := 0
		for i in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(i)
			var worn := m.get_surface_override_material(i)
			if not named.has(StringName(own.resource_name)):
				assert_null(worn, "barrel_%s inside surface %d (%s) keeps its own" % [key, i, own.resource_name])
				continue
			# MQ2: what it names a kind for (the inner barrel, the chamber, the bucking) is drawn on that surface, still
			# in its own colour and never the paint's.
			surfaced += 1
			assert_true(ReplicaPaint.is_surface(worn), "barrel_%s inside %s is drawn on its surface" % [key, own.resource_name])
			assert_eq(ReplicaPaint.plain_of(worn), own, "barrel_%s inside %s keeps its own colour" % [key, own.resource_name])
		assert_gt(surfaced, 0, "barrel_%s: its inner barrel names what it is made of" % key)


func test_the_barrel_cards_are_turned_so_they_read() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	for key: StringName in BARRELS:
		var e := pictures.part_extent(&"aeg", &"barrel", key)
		assert_lt(e.x / e.y, 9.0, "barrel_%s: its picture is not a thin line (%s)" % [key, e])
	var tight := pictures.part_extent(&"aeg", &"barrel", &"tightBore")
	var long := pictures.part_extent(&"aeg", &"barrel", &"long")
	assert_gt(long.x, tight.x, "the long barrel's picture is the longer")
