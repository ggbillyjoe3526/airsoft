extends GutTest
## The GBB Pistol's sights and port (GS1, owner 2026-11-05): aimed, the eye on the sight line sees the front post in
## the rear sight's notch with light either side, and the barrel's hood fills the ejection port, no slit round it.

const MODEL := "res://assets/models/replicas/pistol.glb"
## How far the replica sits ahead of the eye aimed (ViewModelConfig.aim_forward's pistol entry).
const EYE_BACK := 0.36
## A point on the post this far under its top must be seen; the light either side is looked for this far out.
const POST_DROP := 0.001
## The post under its dot (the dot's foot 2.1 mm under the top) must be seen too: nothing white bridges the notch.
const UNDER_DOT := 0.0026
const LIGHT_OUT := 0.0024
## The port: the slide's top is sampled every STEP (m) on lines across and along it, between the sights and inside
## its bevelled edges (SIDE_MARGIN); a sample more than DEEP under the top is open (past the hood's sloped front, 3 mm
## down, into the port), and no open run may be longer than HAIRLINE (the hood's clearance, with its bevel).
const STEP := 0.0001
const LINE_PITCH := 0.004
const SIDE_MARGIN := 0.0025
const DEEP := 0.0035
const HAIRLINE := 0.0004
const SLIDE_HW := 0.01275

## Model space in millimetres for the ray tests: Godot's ray-triangle test takes a triangle whose sides' cross
## product is under 1e-5 as edge-on, which a sight's millimetre faces are in metres.
const MM := 1000.0

var model: Node3D
var faces: TriangleMesh
var rear: Vector3
var front: Vector3


## The model, in the tree a frame so the slide's bone attachment has placed it.
func _load() -> void:
	model = (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	await wait_process_frames(1)
	# The slide and the barrel, whose hood fills the port (the barrel stays with the frame as the slide cycles).
	var all := PackedVector3Array()
	for mesh_name: String in ["Slide", "Barrel"]:
		var mesh := model.find_child(mesh_name, true, false) as MeshInstance3D
		assert_not_null(mesh, "the %s's mesh" % mesh_name)
		var to_mm := Transform3D(Basis.from_scale(Vector3.ONE * MM), Vector3.ZERO) \
				* model.global_transform.affine_inverse() * mesh.global_transform
		all.append_array(to_mm * mesh.mesh.get_faces())
	faces = TriangleMesh.new()
	faces.create_from_faces(all)
	rear = (model.find_child("RearSight", true, false) as Node3D).global_position
	front = (model.find_child("FrontSight", true, false) as Node3D).global_position


## The nearest point the ray from `from` towards `to` (and on past it) meets on the slide; Vector3.INF when none.
func _hit(from: Vector3, to: Vector3) -> Vector3:
	var hit: Dictionary = faces.intersect_ray(from * MM, (to - from).normalized())
	return Vector3.INF if hit.is_empty() else (hit[&"position"] as Vector3) / MM


## The slide's top straight under `p`, or -INF where there is none.
func _height(p: Vector3) -> float:
	var hit := _hit(p, p + Vector3.DOWN)
	return -INF if hit == Vector3.INF else hit.y


func test_the_sight_line_is_level_and_the_front_post_reaches_it() -> void:
	await _load()
	assert_almost_eq(rear.y, front.y, 1e-5, "the sight line runs level, along the bore")
	assert_almost_eq(_height(front + Vector3(0.0, 0.01, 0.0)), front.y, 0.0002, "the post's top is on the sight line")


func test_aimed_the_eye_sees_the_front_post_in_the_notch() -> void:
	await _load()
	var eye := rear + Vector3(0.0, 0.0, EYE_BACK)
	var post := front + Vector3(0.0, -POST_DROP, 0.0)
	var hit := _hit(eye, post)
	assert_almost_eq(eye.distance_to(hit), eye.distance_to(post), 0.003,
			"the first thing seen under the post's top is the post, not the rear sight")
	var low := front + Vector3(0.0, -UNDER_DOT, 0.0)
	assert_almost_eq(eye.distance_to(_hit(eye, low)), eye.distance_to(low), 0.003,
			"the post under its dot shows over the notch's floor (no outline across the notch)")
	for side: float in [-LIGHT_OUT, LIGHT_OUT]:
		assert_eq(_hit(eye, post + Vector3(side, 0.0, 0.0)), Vector3.INF, "light beside the post (%+.4f m)" % side)


func test_the_barrel_hood_fills_the_port() -> void:
	await _load()
	var top := front.y
	var tops: Array[float] = []
	var lines: Array[PackedFloat32Array] = []
	# Lines across the slide (x) every LINE_PITCH along it, and three lines along it (z), between the sights.
	var z := front.z + 0.004
	while z < rear.z - 0.006:
		lines.append(_line(Vector3(-SLIDE_HW + SIDE_MARGIN, top, z), Vector3(SLIDE_HW - SIDE_MARGIN, top, z), tops))
		z += LINE_PITCH
	for x: float in [-0.002, 0.003, 0.007]:
		lines.append(_line(Vector3(x, top, front.z + 0.004), Vector3(x, top, rear.z - 0.006), tops))
	tops.sort()
	var surface := tops[tops.size() / 2]
	var longest := 0.0
	for line: PackedFloat32Array in lines:
		var run := 0.0
		for y: float in line:
			run = run + STEP if y < surface - DEEP else 0.0
			longest = maxf(longest, run)
	assert_lt(longest, HAIRLINE, "no slit in the slide's top wider than the hood's hairline (%.4f m)" % longest)


## The slide's top heights straight down from 1 cm over the line `a` to `b`, every STEP; each also added to `tops`.
func _line(a: Vector3, b: Vector3, tops: Array[float]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(a.distance_to(b) / STEP)
	for i in count + 1:
		var p := a.lerp(b, float(i) / float(count)) + Vector3(0.0, 0.01, 0.0)
		var y := _height(p)
		out.append(y)
		tops.append(y)
	return out
