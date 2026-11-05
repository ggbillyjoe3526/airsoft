extends GutTest
## MAG1: the alternative magazines are their own models, built from each replica's standard magazine
## (tools/blender/parts/magazines.py): the AEG Rifle's Hi-Cap longer than its standard one and the Low-Cap shorter, the
## GBB Pistol's Extended longer than its own; each on its replica's magazine well, as wide as the standard one, with
## its figures' copy, within a part's budget and in the replica's paint materials.

const REPLICAS := "res://assets/models/replicas/"
const PARTS := "res://assets/models/replicaParts/"
## docs/CC0_ASSETS.md › Size limits: a part's triangles.
const PART_TRIS := 10000
## The owner (2026-11-05): detail up to the budget, so each part uses most of it.
const PART_TRIS_USED := 0.9
## How much further below the well each part reaches than its replica's own magazine (m, at least or at most).
const HICAP_LONGER := 0.025
const LOWCAP_SHORTER := 0.020
const EXTENDED_LONGER := 0.030
## How far a part's side may stand out past the standard magazine's (its base plate's rim, m).
const WIDTH_SLACK := 0.0025
const MATERIALS: Array[String] = ["Detail", "Rubber", "BB", "Metal", "Accent", "Furniture"]


func _scene(path: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n


## The box round a mesh node's vertices in its scene's space (the root at the origin).
func _box(m: MeshInstance3D) -> AABB:
	var xf := m.global_transform
	var verts := m.mesh.get_faces()
	var box := AABB(xf * verts[0], Vector3.ZERO)
	for v: Vector3 in verts:
		box = box.expand(xf * v)
	return box


func _standard(replica: String) -> AABB:
	var model := _scene(REPLICAS + replica + ".glb")
	return _box(model.find_child("Magazine", true, false) as MeshInstance3D)


func _well(replica: String) -> Vector3:
	var model := _scene(REPLICAS + replica + ".glb")
	return (model.find_child("MagWell", true, false) as Node3D).global_position


func _part(replica: String, part_name: String) -> MeshInstance3D:
	var parts := _scene(PARTS + replica + ".glb")
	var m := parts.get_node_or_null(part_name) as MeshInstance3D
	assert_not_null(m, "%s has %s" % [replica, part_name])
	return m


func test_the_hi_cap_is_longer_and_the_low_cap_shorter_than_the_aegs_own_magazine() -> void:
	var own := _standard("aeg")
	var hicap := _box(_part("aeg", "magazine_hiCap"))
	var lowcap := _box(_part("aeg", "magazine_lowCap"))
	assert_lt(hicap.position.y, own.position.y - HICAP_LONGER, "the hi-cap reaches further down")
	assert_gt(lowcap.position.y, own.position.y + LOWCAP_SHORTER, "the low-cap stops shorter")
	for box: AABB in [hicap, lowcap]:
		assert_almost_eq(box.end.y, own.end.y, 0.003, "its top in the receiver as the standard one's")


func test_the_extended_magazine_is_longer_than_the_pistols_own() -> void:
	var own := _standard("pistol")
	var ext := _box(_part("pistol", "magazine_extended"))
	assert_lt(ext.position.y, own.position.y - EXTENDED_LONGER, "the extended magazine reaches further down")


func test_each_part_is_as_wide_as_its_standard_magazine_and_sits_on_its_well() -> void:
	for pair: Array in [["aeg", "magazine_hiCap"], ["aeg", "magazine_lowCap"], ["pistol", "magazine_extended"]]:
		var own := _standard(pair[0])
		var m := _part(pair[0], pair[1])
		var box := _box(m)
		assert_almost_eq(box.position.x, own.position.x, WIDTH_SLACK, "%s as wide as the standard one" % pair[1])
		assert_almost_eq(box.end.x, own.end.x, WIDTH_SLACK, "%s as wide as the standard one" % pair[1])
		assert_almost_eq(m.position.distance_to(_well(pair[0])), 0.0, 0.0001, "%s on the MagWell" % pair[1])


func test_each_part_uses_its_budget_has_a_cut_down_figure_and_paints_as_the_replica() -> void:
	for pair: Array in [["aeg", "magazine_hiCap"], ["aeg", "magazine_lowCap"], ["pistol", "magazine_extended"]]:
		var parts := _scene(PARTS + pair[0] + ".glb")
		var m := parts.get_node(NodePath(pair[1])) as MeshInstance3D
		var tris := m.mesh.get_faces().size() / 3
		assert_lt(tris, PART_TRIS, "%s within a part's budget" % pair[1])
		assert_gt(tris, int(PART_TRIS * PART_TRIS_USED), "%s detailed up to its budget" % pair[1])
		var fig := parts.get_node_or_null(NodePath(pair[1] + "_Figure")) as MeshInstance3D
		assert_not_null(fig, "%s has its figures' copy" % pair[1])
		if fig != null:
			assert_lt(fig.mesh.get_faces().size() / 3, 100, "%s figure copy is a few faces" % pair[1])
		for i in m.mesh.get_surface_count():
			var nm := m.mesh.surface_get_material(i).resource_name
			assert_true(nm in MATERIALS, "%s surface %d: '%s' is a replica material" % [pair[1], i, nm])
