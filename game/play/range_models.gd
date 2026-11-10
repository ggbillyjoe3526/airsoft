class_name RangeModels
extends RefCounted
## The practice range's Blender models (RM1, tools/blender/maps/): each file's meshes by the name of the part they draw
## (a target's stand, post, plate, peg, rails; a distance board and its post), read once a view. A part missing from
## its file draws nothing and says so once.

var _parts: Dictionary[StringName, Mesh] = {}
var _path: String = ""


## The parts of the model at `path` (a .glb of one mesh a part).
static func read(path: String) -> RangeModels:
	var m := RangeModels.new()
	m._path = path
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_error("RangeModels: %s won't load" % path)
		return m
	var root := scene.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		m._parts[StringName(node.name)] = (node as MeshInstance3D).mesh
	root.free()
	return m


## Part `part`'s mesh; null (and an error) when the file has none.
func mesh(part: StringName) -> Mesh:
	var found: Mesh = _parts.get(part, null)
	if found == null:
		push_error("RangeModels: %s has no part %s" % [_path, part])
	return found


## Part `part` drawn in `mat` under `parent` at `at`, scaled `scale`.
func add(parent: Node3D, part: StringName, at: Vector3, mat: Material, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = part
	m.mesh = mesh(part)
	m.material_override = mat
	m.position = at
	m.scale = scale
	parent.add_child(m)
	return m


## Part `part`'s bounds as modelled (empty when it is missing).
func bounds(part: StringName) -> AABB:
	var found: Mesh = _parts.get(part, null)
	return found.get_aabb() if found != null else AABB()
