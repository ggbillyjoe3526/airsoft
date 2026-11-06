extends GutTest
## The Cyber Pistol's iron sights (CZ1, owner 2026-11-05: "you can't see the cyber pistols iron sights"): aimed, the
## eye on the sight line sees the front post and its glowing dot in the rear sight's notch, with light either side.
## BL6's notch floor sat on the sight line, so the rear sight hid the whole post (the GBB's GS1 bug).

const MODEL := "res://assets/models/replicas/cyber.glb"
## How far the replica sits ahead of the eye aimed (ViewModelConfig.aim_forward's cyber entry).
const EYE_BACK := 0.25
## Points on the post this far under its top must be seen: just under the top, and through its dot (the dot's centre
## 1 mm under the top as fitted).
const POST_DROP := 0.0005
const DOT_DROP := 0.001
## The light either side of the post is looked for this far out from its centre (the post is 1.6 mm a side).
const LIGHT_OUT := 0.0024
## Model space in millimetres for the ray tests: Godot's ray-triangle test takes a triangle whose sides' cross
## product is under 1e-5 as edge-on, which a sight's millimetre faces are in metres.
const MM := 1000.0

var faces: TriangleMesh
var rear: Vector3
var front: Vector3


## The model, in the tree a frame so its meshes are placed; its body's faces (the sights are in it) in millimetres.
func _load() -> void:
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	await wait_process_frames(1)
	var body := model.find_child("Body", true, false) as MeshInstance3D
	assert_not_null(body, "the body's mesh")
	var to_mm := Transform3D(Basis.from_scale(Vector3.ONE * MM), Vector3.ZERO) * model.global_transform.affine_inverse() \
			* body.global_transform
	faces = TriangleMesh.new()
	faces.create_from_faces(to_mm * body.mesh.get_faces())
	var inverse := model.global_transform.affine_inverse()
	rear = inverse * (model.find_child("RearSight", true, false) as Node3D).global_position
	front = inverse * (model.find_child("FrontSight", true, false) as Node3D).global_position


## The nearest point the ray from `from` towards `to` (and on past it) meets on the body; Vector3.INF when none.
func _hit(from: Vector3, to: Vector3) -> Vector3:
	var hit: Dictionary = faces.intersect_ray(from * MM, (to - from).normalized())
	return Vector3.INF if hit.is_empty() else (hit[&"position"] as Vector3) / MM


func test_the_sight_line_is_level_and_the_front_post_reaches_it() -> void:
	await _load()
	assert_almost_eq(rear.y, front.y, 1e-5, "the sight line runs level")
	var top := _hit(front + Vector3(0.0, 0.01, 0.0), front)
	assert_almost_eq(top.y, front.y, 0.0002, "the post's top is on the sight line")


func test_aimed_the_eye_sees_the_front_post_and_its_dot_in_the_notch() -> void:
	await _load()
	var eye := rear + Vector3(0.0, 0.0, EYE_BACK)
	for drop: float in [POST_DROP, DOT_DROP]:
		var post := front + Vector3(0.0, -drop, 0.0)
		assert_almost_eq(eye.distance_to(_hit(eye, post)), eye.distance_to(post), 0.004,
				"%.4f m under the post's top the eye sees the post, not the rear sight or the shroud" % drop)
	for side: float in [-LIGHT_OUT, LIGHT_OUT]:
		var beside := front + Vector3(side, -POST_DROP, 0.0)
		assert_eq(_hit(eye, beside), Vector3.INF, "light beside the post (%+.4f m)" % side)
