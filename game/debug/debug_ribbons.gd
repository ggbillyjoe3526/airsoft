class_name DebugRibbons
extends MeshInstance3D
## The F4 BB trails as ribbons (BP6; before, 1 px lines that faded out at range): each trail a strip of quads turned to
## face the camera and `width_px` screen pixels wide at any distance, its colour per point. Built per frame from packed
## arrays into one ArrayMesh surface (one call into the engine a frame, not one a vertex). The arrays grow to the
## busiest frame and are kept, and are handed over whole: the indices past the frame's own are zeros, triangles with
## no area that draw nothing, so no frame makes new arrays (the engine still copies them into the mesh). Only the debug
## view makes one, and only while F4 is on.

var _mesh: ArrayMesh = ArrayMesh.new()
var _arrays: Array = []
var _verts: PackedVector3Array = PackedVector3Array()
var _colours: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()
var _vert_count: int = 0
var _index_count: int = 0
## The indices the last frame used: those past this frame's are zeroed again.
var _last_index_count: int = 0
var _eye: Vector3 = Vector3.ZERO
## Metres a screen pixel spans a metre from the eye.
var _per_metre: float = 0.0
var _width_px: float = 3.0
## Segments added since `begin`.
var segment_count: int = 0


func _init() -> void:
	name = "DebugRibbons"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	_arrays.resize(Mesh.ARRAY_MAX)


## Starts a frame's ribbons, seen from `camera` (none: from the origin, a pixel a millimetre a metre), `width_px` wide.
func begin(camera: Camera3D, width_px: float) -> void:
	_vert_count = 0
	_index_count = 0
	segment_count = 0
	_width_px = width_px
	if camera != null:
		_eye = camera.global_position
		var high := maxf(camera.get_viewport().get_visible_rect().size.y, 1.0)
		_per_metre = 2.0 * tan(deg_to_rad(camera.fov) * 0.5) / high
	else:
		_eye = Vector3.ZERO
		_per_metre = 0.001


## `slot`'s trail in `points`, coloured `old` (its oldest point) to `new` (the BB).
func strip(points: BBTrails, slot: int, old: Color, new: Color) -> void:
	var n := points.count(slot)
	if n < 2:
		return
	_room(n)
	var first := _vert_count
	for k in n:
		var at := points.point(slot, k)
		var before := points.point(slot, maxi(k - 1, 0))
		var after := points.point(slot, mini(k + 1, n - 1))
		var half := _width_px * 0.5 * _per_metre * _eye.distance_to(at)
		var side := (after - before).cross(at - _eye).normalized() * half
		var colour := old.lerp(new, float(k) / (n - 1))
		_verts[_vert_count] = at - side
		_verts[_vert_count + 1] = at + side
		_colours[_vert_count] = colour
		_colours[_vert_count + 1] = colour
		_vert_count += 2
	for k in n - 1:
		var v := first + k * 2
		_indices[_index_count] = v
		_indices[_index_count + 1] = v + 1
		_indices[_index_count + 2] = v + 2
		_indices[_index_count + 3] = v + 1
		_indices[_index_count + 4] = v + 3
		_indices[_index_count + 5] = v + 2
		_index_count += 6
	segment_count += n - 1


## Hands the frame's ribbons to the mesh (a frame with none leaves it empty).
func end() -> void:
	_mesh.clear_surfaces()
	for i in range(_index_count, _last_index_count):
		_indices[i] = 0
	_last_index_count = _index_count
	if _index_count == 0:
		return
	_arrays[Mesh.ARRAY_VERTEX] = _verts
	_arrays[Mesh.ARRAY_COLOR] = _colours
	_arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	# let go of the shared copies, so the next frame's writes don't copy the arrays
	_arrays[Mesh.ARRAY_VERTEX] = null
	_arrays[Mesh.ARRAY_COLOR] = null
	_arrays[Mesh.ARRAY_INDEX] = null


## Room for `points` more points: the arrays grow (doubling) and are kept.
func _room(points: int) -> void:
	var verts := _vert_count + points * 2
	if verts > _verts.size():
		var grown := maxi(verts, _verts.size() * 2)
		_verts.resize(grown)
		_colours.resize(grown)
	var indices := _index_count + (points - 1) * 6
	if indices > _indices.size():
		_indices.resize(maxi(indices, _indices.size() * 2))
