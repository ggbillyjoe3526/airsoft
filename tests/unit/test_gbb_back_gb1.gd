extends GutTest
## GB1: the GBB's rear slide serrations run down to the slide's foot (the frame no longer fills their feet) and the
## slide's back has the open recess under the cover plate. Model space: x across, y up, z back-ward (the slide's back
## at +z).

const MODEL := "res://assets/models/replicas/pistol.glb"
## The build's figures (tools/blender/replicas/gbb.py): the slide's half width and groove depth, the rear grooves'
## first back edge before the slide's back, their pitch, width and count, and the recess's width and depth.
const SLIDE_HW := 0.01275
const GROOVE_DEPTH := 0.0007
const REAR_AT := 0.0094
const PITCH := 0.0050
const GROOVE_W := 0.0026
const GROOVES := 7
const RECESS_HW := 0.0078
const RECESS_DEPTH := 0.0054
const MM := 1000.0

var model: Node3D


func before_each() -> void:
	model = (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	await wait_process_frames(1)


func _verts(mesh_name: String) -> PackedVector3Array:
	var mesh := model.find_child(mesh_name, true, false) as MeshInstance3D
	var to_model := model.global_transform.affine_inverse() * mesh.global_transform
	var out := PackedVector3Array()
	for v in mesh.mesh.get_faces():
		out.append(to_model * v)
	return out


## The slide's back (greatest z) and its side foot (least y of the walls beyond the nose's width).
func _slide_back_and_foot() -> Vector2:
	var back := -INF
	var foot := INF
	for v in _verts("Slide"):
		back = maxf(back, v.z)
		if absf(v.x) > SLIDE_HW - 0.0003:
			foot = minf(foot, v.y)
	return Vector2(back, foot)


func test_the_frame_stays_inside_the_rear_grooves_floor() -> void:
	var bf := _slide_back_and_foot()
	var hi := bf.x - REAR_AT
	var lo := hi - (GROOVES - 1) * PITCH - GROOVE_W
	var outside := 0
	for v in _verts("Body"):
		if v.z > lo and v.z < hi and v.y > bf.y + 0.0001 and absf(v.x) > SLIDE_HW - GROOVE_DEPTH:
			outside += 1
	assert_eq(outside, 0, "no frame vertex above the slide's side foot reaches the grooves' floor under them")


func test_the_slides_back_has_an_open_recess_under_the_cover_plate() -> void:
	var bf := _slide_back_and_foot()
	var mesh := model.find_child("Slide", true, false) as MeshInstance3D
	var to_mm := Transform3D(Basis.from_scale(Vector3.ONE * MM), Vector3.ZERO) \
			* model.global_transform.affine_inverse() * mesh.global_transform
	var faces := TriangleMesh.new()
	faces.create_from_faces(to_mm * mesh.mesh.get_faces())
	# Beside the blocks and the tongue, low in the recess: a ray forward from behind meets the recess's floor.
	var hit := faces.intersect_ray(Vector3(0.0065, bf.y + 0.002, bf.x + 0.01) * MM, Vector3.FORWARD)
	assert_false(hit.is_empty(), "the ray meets the slide")
	if not hit.is_empty():
		var depth := bf.x - (hit["position"] as Vector3).z / MM
		assert_almost_eq(depth, RECESS_DEPTH, 0.0005, "the recess is 5.4 mm deep (its dark floor 0.1 mm in front of the cut)")
	# Beside the recess the slide's back stays flush.
	var flush := faces.intersect_ray(Vector3(RECESS_HW + 0.002, bf.y + 0.002, bf.x + 0.01) * MM, Vector3.FORWARD)
	assert_false(flush.is_empty())
	if not flush.is_empty():
		assert_almost_eq((flush["position"] as Vector3).z / MM, bf.x, 0.0003, "the walls beside it reach the back")


## The slide's surface that carries the recess's floor material ("Cavity"), its drawn material and the mesh node.
func _cavity() -> Array:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var own := mi.mesh.surface_get_material(i)
			if own != null and own.resource_name == "Cavity":
				return [mi, i]
	return []


func _drawn_albedo(mi: MeshInstance3D, i: int) -> Color:
	var m := mi.get_active_material(i)
	if m is ShaderMaterial:
		return (m as ShaderMaterial).get_shader_parameter("albedo") as Color
	return (m as BaseMaterial3D).albedo_color


func test_the_recess_floor_has_its_own_dark_material_in_the_file() -> void:
	var found := _cavity()
	assert_false(found.is_empty(), "the slide carries a Cavity surface")
	if not found.is_empty():
		var own := (found[0] as MeshInstance3D).mesh.surface_get_material(found[1] as int) as BaseMaterial3D
		assert_lt(own.albedo_color.get_luminance(), 0.08, "near black")


func test_the_recess_floor_keeps_its_material_in_every_paint() -> void:
	for paint: StringName in [&"ghost", &"onyx", &"coral"]:
		for realistic: bool in [false, true]:
			var fresh := (load(MODEL) as PackedScene).instantiate() as Node3D
			add_child_autofree(fresh)
			for surfaced: bool in [true, false]:
				ReplicaPaint.apply(fresh, paint, realistic, surfaced)
				var hit := false
				for node: Node in fresh.find_children("*", "MeshInstance3D", true, false):
					var mi := node as MeshInstance3D
					if mi.mesh == null:
						continue
					for i in mi.mesh.get_surface_count():
						var own := mi.mesh.surface_get_material(i)
						if own != null and own.resource_name == "Cavity":
							hit = true
							assert_null(mi.get_surface_override_material(i), "%s/%s/%s: not repainted" % [paint, realistic, surfaced])
							assert_lt((mi.get_active_material(i) as BaseMaterial3D).albedo_color.get_luminance(), 0.08)
				assert_true(hit, "Cavity found")


func test_the_figure_copy_of_the_pistol_has_no_cavity_surface() -> void:
	# The bots' copy (the model's `Figure` mesh, tools/blender/replicas/figure_copy.py) drops the recess floor.
	var figure := model.find_child("Figure", true, false) as MeshInstance3D
	assert_not_null(figure, "the pistol carries a Figure mesh")
	if figure != null:
		for i in figure.mesh.get_surface_count():
			assert_ne(figure.mesh.surface_get_material(i).resource_name, "Cavity")
