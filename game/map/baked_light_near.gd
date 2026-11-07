class_name BakedLightNear
extends RefCounted
## The baked light near a point (BP7), for what stands beside the baked faces in the shared light with no bake of its
## own (DoorView's leaves, FlagView's and OvertimeFlagView's poles, PropDress's props), so it sits at the same share of
## its paint as the wall or floor beside it: the mean light of the baked vertices within REACH m, as the baked faces
## draw it (MapLevel._baked_mesh: a linear multiplier of the paint). Made by MapLevel.baked_lights while the baked
## light is drawn, its vertices in a grid of REACH m cells, once.

## How far (m) a point looks for baked vertices, and how nearly (the cosine) a vertex's normal must face the way asked.
const REACH := 0.75
const FACING := 0.7

var _at: PackedVector3Array = PackedVector3Array()
var _normals: PackedVector3Array = PackedVector3Array()
var _light: PackedColorArray = PackedColorArray()
var _cells: Dictionary[Vector3i, PackedInt32Array] = {}


## The baked vertices at `at`, facing `normals`, in `light` (one each).
func _init(at: PackedVector3Array, normals: PackedVector3Array, light: PackedColorArray) -> void:
	assert(at.size() == normals.size() and at.size() == light.size(), "one normal and one light a vertex")
	_at = at
	_normals = normals
	_light = light
	for v in at.size():
		var c := cell_of(at[v])
		if not _cells.has(c):
			_cells[c] = PackedInt32Array()
		_cells[c].append(v)


## The grid cell point `p` is in.
static func cell_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / REACH), floori(p.y / REACH), floori(p.z / REACH))


## The light at `p`: the mean of the baked vertices within REACH m of it whose normal faces within FACING of `facing`
## (any way, for Vector3.ZERO); `fallback` where there is none.
func at(p: Vector3, facing: Vector3 = Vector3.ZERO, fallback: Color = Color.WHITE) -> Color:
	var sum := Vector3.ZERO
	var n := 0
	var c := cell_of(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var key := c + Vector3i(dx, dy, dz)
				if not _cells.has(key):
					continue
				for v in _cells[key]:
					if _at[v].distance_squared_to(p) > REACH * REACH:
						continue
					if facing != Vector3.ZERO and _normals[v].dot(facing) < FACING:
						continue
					var l := _light[v]
					sum += Vector3(l.r, l.g, l.b)
					n += 1
	if n == 0:
		return fallback
	sum /= float(n)
	return Color(sum.x, sum.y, sum.z)


## The light at `p` from faces facing `side` (a door's face on that side of its wall), or from the opposite side's
## where none faces it, or white where neither has a baked vertex near.
func on_side(p: Vector3, side: Vector3) -> Color:
	var none := Color(0.0, 0.0, 0.0, 0.0)
	var own := at(p, side, none)
	if own.a > 0.0:
		return own
	return at(p, -side)
