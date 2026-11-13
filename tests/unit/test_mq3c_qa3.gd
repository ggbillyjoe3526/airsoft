extends GutTest
## MQ3C QA, attempt 3: the brow ridge and the lower eyes leave the eyewear clear (no skin outside the knit or near the
## lens), and the LOD2 flat copy's eye opening lies on the painted eye.

const HEADS: Array[String] = ["Head_HighCut", "Head_FullCut", "Head_Cap", "Head_Boonie"]
const MAP := Vector2(2048.0, 1024.0)
## face.py: EYE_AZ's x (the eyes' middles across), EYE_Z (their height), and the zone round them read here.
const EYE_X := 0.0305
const EYE_Y := 1.6115
const ZONE := 0.0165
## The lens stays at least this far (m) from any skin; no knit triangle lies this near behind a skin vertex (that
## vertex would stand out of the knit); a vertex under the knit may not be level with it (z-fight) closer than this.
const LENS_CLEAR_AT_LEAST := 0.005
const OUTSIDE_KNIT_WITHIN := 0.010
const UNDER_KNIT_AT_LEAST := 0.0001
## The painted pupils' places in look 0's cell (px; test_face_map.gd PUPILS) and how far the LOD2 eye vertex's map
## place may be from them.
const PUPILS: Array[Vector2] = [Vector2(282.0, 246.0), Vector2(741.0, 246.0)]
const CELL0_TOP := 512.0
const LOD2_EYE_WITHIN_PX := 3.0

var config: FigureConfig = null
var models: FigureModels = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


static func _triangles(mesh: Mesh, surface: int) -> Array[PackedVector3Array]:
	var arrays := mesh.surface_get_arrays(surface)
	var v := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var idx := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var out: Array[PackedVector3Array] = []
	for t in idx.size() / 3:
		var tri := PackedVector3Array([v[idx[t * 3]], v[idx[t * 3 + 1]], v[idx[t * 3 + 2]]])
		var lo := tri[0].min(tri[1]).min(tri[2])
		var hi := tri[0].max(tri[1]).max(tri[2])
		if hi.y < EYE_Y - 0.06 or lo.y > EYE_Y + 0.06 or lo.x > 0.1 and hi.x > 0.1 or hi.x < -0.1 and lo.x < -0.1:
			continue
		out.append(tri)
	return out


static func _surface(mesh: Mesh, material: String) -> int:
	for i in mesh.get_surface_count():
		var own := mesh.surface_get_material(i)
		if own != null and own.resource_name == material:
			return i
	return -1


## The shortest distance (m) from `p` along `d` to a triangle in front (`d`) of it, and the shortest along `-d`.
static func _rays(p: Vector3, d: Vector3, tris: Array[PackedVector3Array]) -> Vector2:
	var fwd := INF
	var back := INF
	for tri in tris:
		var h: Variant = Geometry3D.ray_intersects_triangle(p, d, tri[0], tri[1], tri[2])
		if h != null:
			fwd = minf(fwd, p.distance_to(h as Vector3))
		var b: Variant = Geometry3D.ray_intersects_triangle(p, -d, tri[0], tri[1], tri[2])
		if b != null:
			back = minf(back, p.distance_to(b as Vector3))
	return Vector2(fwd, back)


## The least clearance (m) over the face's vertices round the eyes, with every vertex pushed `push` out along its
## normal: [lens clearance ahead, nearest knit triangle behind a vertex, thinnest cover of knit over a vertex].
func _clearance(mesh: Mesh, push: float) -> Vector3:
	var face := _surface(mesh, "Face")
	var arrays := mesh.surface_get_arrays(face)
	var fv := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var fn := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var knit := _triangles(mesh, _surface(mesh, "Headwear"))
	var lens := _triangles(mesh, _surface(mesh, "Lens"))
	var out := Vector3(INF, INF, INF)
	for i in fv.size():
		if absf(absf(fv[i].x) - EYE_X) > ZONE or absf(fv[i].y - EYE_Y) > ZONE:
			continue
		var d := fn[i].normalized()
		var p := fv[i] + d * push
		var l := _rays(p, d, lens)
		var k := _rays(p, d, knit)
		out.x = minf(out.x, minf(l.x, l.y))
		out.y = minf(out.y, k.y)
		out.z = minf(out.z, k.x)
	return out


func test_the_brow_ridge_and_the_lower_eyes_keep_clear_of_the_knit_and_the_lens() -> void:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	for head in HEADS:
		for level: String in ["", "_LOD1"]:
			var mesh := (root.find_child(head + level, true, false) as MeshInstance3D).mesh
			var c := _clearance(mesh, 0.0)
			gut.p("%s%s: lens %.1f mm, knit behind %.1f mm, cover %.2f mm" % [head, level, c.x * 1000.0, c.y * 1000.0, c.z * 1000.0])
			assert_gt(c.x, LENS_CLEAR_AT_LEAST, "%s%s: the lens is clear of the skin" % [head, level])
			assert_gt(c.y, OUTSIDE_KNIT_WITHIN, "%s%s: no skin stands out of the knit" % [head, level])
			assert_gt(c.z, UNDER_KNIT_AT_LEAST, "%s%s: skin under the knit is not level with it" % [head, level])


func test_the_clearance_check_sees_skin_pushed_through_the_knit_and_the_lens() -> void:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	var mesh := (root.find_child("Head_HighCut", true, false) as MeshInstance3D).mesh
	var pushed := _clearance(mesh, 0.03)
	assert_lt(pushed.x, LENS_CLEAR_AT_LEAST, "skin 30 mm out meets the lens")
	assert_lt(pushed.y, OUTSIDE_KNIT_WITHIN, "skin 30 mm out stands out of the knit")


func test_the_lod2_eye_opening_lies_where_the_eye_is_painted() -> void:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	for head in HEADS:
		var mesh := (root.find_child(head + "_LOD2", true, false) as MeshInstance3D).mesh
		var arrays := mesh.surface_get_arrays(_surface(mesh, "Face"))
		var v := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var uv := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		for eye in 2:
			var at := Vector2(EYE_X * (1.0 if eye == 1 else -1.0), EYE_Y)
			var best := 0
			for i in v.size():
				if Vector2(v[i].x, v[i].y).distance_to(at) < Vector2(v[best].x, v[best].y).distance_to(at):
					best = i
			var px := Vector2(uv[best].x * MAP.x, uv[best].y * MAP.y - CELL0_TOP)
			assert_lt(px.distance_to(PUPILS[eye]), LOD2_EYE_WITHIN_PX, "%s eye %d: the LOD2 vertex maps to the pupil" % [head, eye])
