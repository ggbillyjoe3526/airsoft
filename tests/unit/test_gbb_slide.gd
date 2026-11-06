extends GutTest
## The GBB Pistol's slide (owner, 2026-11-05): at rest it is home, flush with the frame's nose; it only runs back
## firing or locked on an empty magazine, and then only the slide moves: the barrel stays with the frame and shows in
## front of it.

const MODEL := "res://assets/models/replicas/pistol.glb"
## How far the slide runs back (the build's SLIDE_TRAVEL), m, and the tolerance.
const TRAVEL := 0.026
const EPS := 0.0005
## The slide's nose lip (GS2, from the owner's Gen5 photos): it drops under the barrel in front of the dust cover,
## whose front sits LIP_BACK behind the slide's face, to below LIP_FOOT, and holds the recoil spring's hole (centred at
## SPRING_Y, between SPRING_HOLE m across, as the photos' ~10 mm: open beside the guide rod's 9.6 mm cap).
const LIP_BACK := 0.0034
const LIP_FOOT := -0.010
const SPRING_Y := -0.00305
const SPRING_HOLE := Vector2(0.0100, 0.0126)
## Model space in millimetres for the ray tests (Godot's ray test takes millimetre faces in metres as edge-on).
const MM := 1000.0

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer


func before_each() -> void:
	model = (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	await wait_process_frames(1)


## The frontmost point (least z, model space) of mesh `mesh_name` as drawn now.
func _front(mesh_name: String) -> float:
	var mesh := model.find_child(mesh_name, true, false) as MeshInstance3D
	var to_model := model.global_transform.affine_inverse() * mesh.global_transform
	var front := INF
	for v in mesh.mesh.get_faces():
		front = minf(front, (to_model * v).z)
	return front


func test_the_file_rests_with_the_slide_home() -> void:
	var b := skeleton.find_bone("slide")
	assert_true(skeleton.get_bone_pose_position(b).is_equal_approx(skeleton.get_bone_rest(b).origin),
			"the slide bone sits at its rest")
	assert_false(anim.is_playing(), "no clip plays on its own")
	assert_eq(anim.autoplay, "")
	assert_almost_eq(_front("Barrel") - _front("Slide"), -0.0017, EPS, "the barrel 1.7 mm proud of the slide's face")


## The lowest point (least y, model space) of mesh `mesh_name` as drawn now.
func _lowest(mesh_name: String) -> float:
	var mesh := model.find_child(mesh_name, true, false) as MeshInstance3D
	var to_model := model.global_transform.affine_inverse() * mesh.global_transform
	var low := INF
	for v in mesh.mesh.get_faces():
		low = minf(low, (to_model * v).y)
	return low


func test_the_nose_lip_drops_in_front_of_the_dust_cover_round_the_spring_hole() -> void:
	assert_lt(_lowest("Slide"), LIP_FOOT, "the slide's face drops under the barrel, in front of the dust cover")
	assert_almost_eq(_front("Body") - _front("Slide"), LIP_BACK, EPS, "the dust cover's front behind the lip")
	var mesh := model.find_child("Slide", true, false) as MeshInstance3D
	var to_mm := Transform3D(Basis.from_scale(Vector3.ONE * MM), Vector3.ZERO) \
			* model.global_transform.affine_inverse() * mesh.global_transform
	var faces := TriangleMesh.new()
	faces.create_from_faces(to_mm * mesh.mesh.get_faces())
	var face := _front("Slide")
	for side: float in [-1.0, 1.0]:
		var inside := Vector3(side * SPRING_HOLE.x * 0.5, SPRING_Y, face - 0.01) * MM
		assert_true(faces.intersect_ray(inside, Vector3.BACK).is_empty(), "the spring's hole is open (%+.0f)" % side)
		var outside := Vector3(side * SPRING_HOLE.y * 0.5, SPRING_Y, face - 0.01) * MM
		assert_false(faces.intersect_ray(outside, Vector3.BACK).is_empty(), "the lip round the hole (%+.0f)" % side)


func test_the_barrel_is_on_the_frame_not_the_slide() -> void:
	var barrel := model.find_child("Barrel", true, false)
	assert_false(barrel.get_parent() is BoneAttachment3D, "nothing moves the barrel")


func test_locked_back_only_the_slide_moves_and_the_barrel_shows() -> void:
	var barrel_front := _front("Barrel")
	var slide_front := _front("Slide")
	anim.play(&"SlideLock")
	anim.seek(anim.current_animation_length, true)
	await wait_process_frames(1)
	assert_almost_eq(_front("Slide") - slide_front, TRAVEL, EPS, "the slide runs back its travel")
	assert_almost_eq(_front("Barrel"), barrel_front, 1e-6, "the barrel stays put")


func test_only_firing_and_the_lock_move_the_slide() -> void:
	var b := skeleton.find_bone("slide")
	for clip: StringName in anim.get_animation_list():
		if clip in [&"Fire", &"SlideLock"]:
			continue
		var a := anim.get_animation(clip)
		for t in a.get_track_count():
			if String(a.track_get_path(t).get_concatenated_subnames()) != "slide" \
					or a.track_get_type(t) != Animation.TYPE_POSITION_3D:
				continue
			for k in a.track_get_key_count(t):
				assert_almost_eq(a.track_get_key_value(t, k) as Vector3, skeleton.get_bone_rest(b).origin,
						Vector3.ONE * 1e-5, "%s keeps the slide home" % clip)
