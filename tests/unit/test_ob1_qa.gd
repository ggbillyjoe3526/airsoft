extends GutTest
## OB1 (0.1 Beta 2, the owner): a magazine shows one BB at its lips, not three; the pistols' hip angle matches the
## rifle's (no turn in).

const REPLICAS := "res://assets/models/replicas/%s.glb"
const PARTS := "res://assets/models/replicaParts/%s.glb"
const DT := 1.0 / 60.0
## A BB is 6 mm across (m; the Sniper's is a little flat, 4 mm tall); a ball's box may be this far off that.
const BB_SIZE := 0.006
const BB_SLACK := 0.0006
## Corners closer than this are one corner (a seam in the unwrap).
const SNAP := 0.000002
## Which surface holds the BB: the AEG, Pump Shotgun and Sniper fold it into Rubber, the others keep a BB material.
const OWN := [["aeg", "Rubber"], ["pistol", "BB"], ["shotgun", "Rubber"], ["sniper", "Rubber"]]
const MAGS := [["aeg", "magazine_hiCap"], ["aeg", "magazine_lowCap"], ["pistol", "magazine_extended"]]


func _mesh(path: String, node_name: String) -> MeshInstance3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n.find_child(node_name, true, false) as MeshInstance3D


func _root(root: Array[int], i: int) -> int:
	while root[i] != i:
		root[i] = root[root[i]]
		i = root[i]
	return i


## How many separate pieces of a surface are a 6 mm ball (6 mm across, 3.5 to 6 mm tall).
func _balls(mi: MeshInstance3D, surface_name: String) -> int:
	var at := -1
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		if m != null and m.resource_name == surface_name:
			at = s
	assert_gte(at, 0, "%s has a %s surface" % [mi.name, surface_name])
	if at < 0:
		return -1
	var arrays := mi.mesh.surface_get_arrays(at)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var place: Dictionary[Vector3i, int] = {}
	var root: Array[int] = []
	var unique: Array[Vector3] = []
	var of: Array[int] = []
	for p in points:
		var key := Vector3i((p / SNAP).round())
		if not place.has(key):
			place[key] = unique.size()
			root.append(unique.size())
			unique.append(p)
		of.append(place[key])
	for t in range(0, index.size(), 3):
		for k in 2:
			var a := _root(root, of[index[t + k]])
			var b := _root(root, of[index[t + k + 1]])
			if a != b:
				root[a] = b
	var boxes: Dictionary[int, AABB] = {}
	for i in unique.size():
		var r := _root(root, i)
		boxes[r] = boxes[r].expand(unique[i]) if boxes.has(r) else AABB(unique[i], Vector3.ZERO)
	var n := 0
	for r: int in boxes:
		var s: Vector3 = boxes[r].size
		var tall := s.y > 0.0035 and s.y < BB_SIZE + BB_SLACK
		if tall and absf(s.x - BB_SIZE) < BB_SLACK and absf(s.z - BB_SIZE) < BB_SLACK:
			n += 1
	return n


func test_each_replicas_own_magazine_shows_one_bb() -> void:
	for row: Array in OWN:
		var mi := _mesh(REPLICAS % row[0], "Magazine")
		assert_not_null(mi, "%s has a Magazine" % row[0])
		if mi != null:
			assert_eq(_balls(mi, row[1]), 1, "%s: one BB ball at the lips" % row[0])


func test_each_magazine_part_shows_one_bb() -> void:
	for row: Array in MAGS:
		var mi := _mesh(PARTS % row[0], row[1])
		assert_not_null(mi, "%s has %s" % [row[0], row[1]])
		if mi != null:
			assert_eq(_balls(mi, "BB"), 1, "%s: one BB ball" % row[1])


func _view(id: StringName, cfg: ViewModelConfig) -> ReplicaView:
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(cfg, loadout, BoxWorld.new())
	for i in 40:
		view.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, 0.0)
	return view


## The way the replica points at the hip, in the view's space: its rear sight to its muzzle.
func _aim(id: StringName) -> Vector3:
	var view := _view(id, ViewModelConfig.new())
	var root: Node3D = view._held[0].root
	var muzzle := root.find_child("Muzzle", true, false) as Node3D
	var rear := root.find_child("RearSight", true, false) as Node3D
	assert_not_null(muzzle, "%s has a Muzzle" % id)
	assert_not_null(rear, "%s has a RearSight" % id)
	var inv := view.global_transform.affine_inverse()
	return (inv * muzzle.global_position - inv * rear.global_position).normalized()


func test_pistols_lie_square_at_the_hip_and_point_as_the_rifle_does() -> void:
	var rifle := _aim(&"aeg")
	for id: StringName in [&"pistol", &"cyber"]:
		var view := _view(id, ViewModelConfig.new())
		assert_almost_eq(view._held[0].root.rotation, Vector3.ZERO, Vector3.ONE * 1e-3, "%s square" % id)
		var dir := _aim(id)
		assert_gt(dir.dot(rifle), 0.998, "%s: muzzle parallel to the rifle's (within ~3.5 deg; the old 0.15 rad turn was 0.989)" % id)
		assert_lt(absf(dir.x), 0.03, "%s: not turned left or right" % id)


func test_no_replica_has_a_hip_turn() -> void:
	assert_true(ViewModelConfig.new().hip_turn.is_empty(), "no replica is turned at the hip")
