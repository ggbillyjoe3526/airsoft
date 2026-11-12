extends GutTest
## QA for the Cyber Pistol's rebuilt grip (MQ1B): the model's contract (docs/CC0_ASSETS.md > Replica models) still holds.

const PATH := "res://assets/models/replicas/cyber.glb"
const BUDGET := 40000
const FIGURE_BUDGET := 3000
const EMPTIES: Array[StringName] = [&"Muzzle", &"FrontSight", &"RearSight", &"MagWell", &"SlideBack", &"TorchMount"]
const CLIPS: Array[StringName] = [&"Fire", &"Selector", &"Reload", &"Inspect"]
## The GBB-sized envelope (m): about 206 x 152 x 32 mm, a few mm of slack.
const SIZE := Vector3(0.032, 0.152, 0.206)
const SLACK := 0.012
## How far (m) the cell may stand proud of the body at its widest, so its window reads.
const FLUSH := 0.001
const SLICE := 0.003

var _model: Node3D


func before_each() -> void:
	_model = (load(PATH) as PackedScene).instantiate() as Node3D
	add_child_autofree(_model)


func _box(mi: MeshInstance3D) -> AABB:
	return _model.global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb()


func _mesh(mesh_name: String) -> MeshInstance3D:
	return _model.find_child(mesh_name, true, false) as MeshInstance3D


func _tris(mi: MeshInstance3D) -> int:
	var n := 0
	for s in mi.mesh.get_surface_count():
		var idx: PackedInt32Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += idx.size() / 3
	return n


func test_the_empties_and_clips_are_all_still_there() -> void:
	for e: StringName in EMPTIES:
		assert_not_null(_model.find_child(String(e), true, false), "%s empty" % e)
	var anim := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim)
	for c: StringName in CLIPS:
		assert_true(anim.has_animation(c), "%s clip" % c)
	assert_not_null(_model.find_child("Skeleton3D", true, false))


func test_the_body_is_still_the_gbb_pistols_size() -> void:
	var box := AABB()
	var first := true
	for m: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.name.begins_with("Figure"):
			continue
		box = _box(mi) if first else box.merge(_box(mi))
		first = false
	assert_almost_eq(box.size.x, SIZE.x, SLACK, "width")
	assert_almost_eq(box.size.y, SIZE.y, SLACK, "height")
	assert_almost_eq(box.size.z, SIZE.z, SLACK, "length")


func test_the_power_cell_rests_inside_the_grip_and_leaves_down_on_reload() -> void:
	var mag := _mesh("Magazine")
	var body := _mesh("Body")
	assert_not_null(mag)
	var rest := _box(mag)
	var shell := _box(body)
	assert_gte(rest.position.x, shell.position.x - FLUSH, "within the body's width")
	assert_lte(rest.end.x, shell.end.x + FLUSH, "within the body's width")
	assert_gte(rest.position.z, shell.position.z, "inside the body's length")
	assert_lte(rest.end.z, shell.end.z, "inside the body's length")
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skeleton.find_bone("magazine")
	assert_gt(bone, -1, "the magazine bone")
	var anim := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var rest_y := skeleton.get_bone_global_pose(bone).origin.y
	anim.play(&"Reload")
	var lowest := rest_y
	var length := anim.current_animation_length
	for i in 8:
		anim.seek(length * i / 7.0, true)
		lowest = minf(lowest, skeleton.get_bone_global_pose(bone).origin.y)
	assert_lt(lowest, rest_y - 0.02, "the cell comes out down the grip")


func test_the_torch_mount_is_clear_of_the_trigger_guard() -> void:
	var mount := _model.find_child("TorchMount", true, false) as Node3D
	var at := _model.global_transform.affine_inverse() * mount.global_position
	var guard := _mesh("Body")
	var tris := guard.mesh.get_faces()
	var xf := _model.global_transform.affine_inverse() * guard.global_transform
	var near := INF
	for v: Vector3 in tris:
		near = minf(near, (xf * v).distance_to(at))
	assert_gt(near, 0.0005, "the mount does not sit inside a vertex of the body")
	assert_lt(at.y, _box(guard).end.y, "under the rail")


func test_the_figure_copy_has_no_kinds_and_fits_its_budget() -> void:
	var total := 0
	for n: String in ["Figure", "Figure_Magazine"]:
		var mi := _mesh(n)
		assert_not_null(mi, n)
		if mi == null:
			continue
		total += _tris(mi)
		for s in mi.mesh.get_surface_count():
			assert_false(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] is PackedColorArray \
					and not (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray).is_empty(),
					"%s carries no vertex-colour kinds" % n)
	assert_lte(total, FIGURE_BUDGET, "figure copy triangles")


func test_the_hand_held_model_stays_within_the_triangle_budget() -> void:
	var total := 0
	for m: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.name.begins_with("Figure"):
			total += _tris(mi)
	assert_lte(total, BUDGET)


## Every vertex of `mi`, in the model's space.
func _points(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var xf := _model.global_transform.affine_inverse() * mi.global_transform
	for s in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


func test_the_raked_cell_and_base_pad_stay_inside_the_grips_skin_at_rest() -> void:
	var body := _points(_mesh("Body"))
	var foot := INF
	for p in body:
		foot = minf(foot, p.y)
	var worst := 0.0
	for c in _points(_mesh("Magazine")):
		if c.y < foot + SLICE:
			continue # the pad's own foot stands below the body
		var front := INF
		var back := -INF
		var half := 0.0
		for p in body:
			if absf(p.y - c.y) <= SLICE:
				front = minf(front, p.z)
				back = maxf(back, p.z)
				half = maxf(half, absf(p.x))
		worst = maxf(worst, maxf(absf(c.x) - half, maxf(front - c.z, c.z - back)))
	assert_lt(worst, FLUSH, "no cell or pad vertex stands past the grip's slice (m)")


func test_the_cell_and_pad_are_one_part_riding_the_magazine_bone() -> void:
	# The pad is built into the Magazine mesh, which rides the magazine bone the Reload clip pulls down, so it cannot be
	# left behind on the Body.
	var mag := _mesh("Magazine")
	var attach := mag.get_parent() as BoneAttachment3D
	assert_not_null(attach, "the Magazine hangs from a bone attachment")
	if attach != null:
		assert_eq(attach.bone_name, "magazine")
	assert_false(_mesh("Body").get_parent() is BoneAttachment3D, "the Body stays put")
