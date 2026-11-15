extends GutTest
## AF1: the AEG rifle's delta ring shows all round, the forward assist stands out past the upper, and the bots' copy has
## no faces of the hollow handguard's gas tube. Checked on the built model (assets/models/replicas/aeg.glb).

const RIFLE := "res://assets/models/replicas/aeg.glb"
## Godot units: y up, -z forward. The ring sits at Blender y 0.0977 to 0.1172, so Godot z -0.0977 to -0.1172.
const RING_Z := -0.107
const RAIL_TOP := 0.0705
const UPPER_HW := 0.015
const FIGURE_TRIS := 3000


func _rifle() -> Node3D:
	var n := (load(RIFLE) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n


func _body() -> MeshInstance3D:
	return _rifle().find_child("Body", true, false) as MeshInstance3D


func test_the_ring_top_is_round_with_no_rail_running_over_it() -> void:
	var tm := _body().mesh.generate_triangle_mesh()
	var mid := tm.intersect_ray(Vector3(0.0, 0.3, RING_Z), Vector3.DOWN)
	var side := tm.intersect_ray(Vector3(0.009, 0.3, RING_Z), Vector3.DOWN)
	assert_false(mid.is_empty(), "something is at the ring's top")
	assert_false(side.is_empty(), "something is beside the ring's top")
	if mid.is_empty() or side.is_empty():
		return
	assert_lt((mid["position"] as Vector3).y, RAIL_TOP - 0.005, "the ring is under the rail's height, no rail over it")
	assert_lt((side["position"] as Vector3).y, (mid["position"] as Vector3).y - 0.003, "it falls away round the ring")


func test_the_rails_start_after_the_ring_on_both_sides() -> void:
	var tm := _body().mesh.generate_triangle_mesh()
	for z: float in [-0.090, -0.125]:
		var h := tm.intersect_ray(Vector3(0.0, 0.3, z), Vector3.DOWN)
		assert_false(h.is_empty(), "rail at z %s" % z)
		if not h.is_empty():
			assert_gt((h["position"] as Vector3).y, RAIL_TOP - 0.002, "rail height at z %s" % z)


func test_the_forward_assist_stands_out_past_the_upper_side() -> void:
	var worst := -1.0
	for v: Vector3 in _body().mesh.get_faces():
		if v.z > 0.03 and v.z < 0.09 and v.y > 0.03 and v.y < 0.058:
			worst = maxf(worst, v.x)
	assert_gt(worst, 0.030, "the forward assist's head stands well out of the upper")


func test_the_bots_copy_has_no_gas_tube_and_stays_under_budget() -> void:
	var r := _rifle()
	assert_null(r.find_child("GasTube", true, false), "no loose gas tube in the model")
	assert_null(r.find_child("GuardStandIn", true, false), "the stand-in is not shipped")
	var fig := r.find_child("Figure", true, false) as MeshInstance3D
	assert_not_null(fig)
	if fig:
		assert_lte(fig.mesh.get_faces().size() / 3 + _extra(r), FIGURE_TRIS, "figure triangles")


func _extra(r: Node) -> int:
	var t := 0
	for n: Node in r.find_children("Figure_*", "MeshInstance3D", true, false):
		t += (n as MeshInstance3D).mesh.get_faces().size() / 3
	return t
