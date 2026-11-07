class_name DoorView
extends Node3D
## The hinged doors (DO1; MapData.doors): each two painted plywood leaves hinged at their jambs, swinging out to the
## side the door hangs on over DoorConfig.swing_time and folding back flat against the wall's face when open. One
## MultiMesh, one draw call, casting shadows. Reads GameState.doors each frame and moves only the leaves of a door whose
## swing changed; nothing here is read by the simulation (a shut door's collider is MapLevel's). Built once; a frame
## allocates nothing.

## The colour MapStyle gives a door's leaves.
const KIND := &"door"
## The gap left between the two leaves and at each jamb (m), so the leaves read as two.
const LEAF_GAP := 0.02
## A leaf folds back by up to half a turn, flat against its wall, and stops short where another block stands in its way
## (a wall meeting its own at a corner): looked for in REACH_STEP steps (rad) back from flat, a point within REACH_SKIN
## (m) of a block's face touching it, not in it.
const REACH_SKIN := 0.002
const REACH_STEP := 0.005
## The heights up a leaf (shares of it, from its middle) and the points along it tried against the blocks.
const REACH_HEIGHTS: Array[float] = [-0.45, 0.0, 0.45]
const REACH_POINTS := 12

var _mesh: MultiMeshInstance3D = null
var _material: StandardMaterial3D = null
var _swing_time: float = 0.4
## Per door: each leaf's hinge (on the door's middle plane at its jamb), its direction from the hinge to the middle,
## its size, the sign of its turn to open, and how open the door was last drawn (-1: not yet).
var _hinges: PackedVector3Array = PackedVector3Array()
var _dirs: PackedVector3Array = PackedVector3Array()
var _sizes: PackedVector3Array = PackedVector3Array()
var _turns: PackedFloat32Array = PackedFloat32Array()
## How far each leaf turns open (rad): half a turn, or less where a block stops it (`reach`).
var _reach: PackedFloat64Array = PackedFloat64Array()
var _drawn: PackedFloat32Array = PackedFloat32Array()
## Each leaf's transform as last placed (the MultiMesh's own copy is the renderer's).
var _leaves: Array[Transform3D] = []


## The doors of `map` in `style`'s door colour, swinging in `swing_time` s; null on a map without doors.
static func build(map: MapData, style: MapStyle, swing_time: float) -> DoorView:
	if map.doors.is_empty():
		return null
	var view := DoorView.new()
	view.name = "Doors"
	view._swing_time = maxf(swing_time, 0.001)
	view._material = StandardMaterial3D.new()
	view._material.albedo_color = style.colour_of(KIND, 0)
	view._material.roughness = style.roughness
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = map.doors.size() * 2
	for d in map.doors:
		view._add_leaves(d, map.blocks)
	view._drawn.resize(map.doors.size())
	view._leaves.resize(map.doors.size() * 2)
	view._drawn.fill(-1.0)
	view._mesh = MultiMeshInstance3D.new()
	view._mesh.name = "Leaves"
	view._mesh.multimesh = mm
	view._mesh.material_override = view._material
	view.add_child(view._mesh)
	for i in map.doors.size():
		view._place(i, 0.0 if map.doors[i].shut else 1.0)
	return view


## Draws each door as `doors` has it: shut, open, or part way through its swing.
func refresh(doors: DoorState) -> void:
	var n := mini(doors.count(), _drawn.size())
	for i in n:
		var through := 1.0 - clampf(doors.swing_left[i] / _swing_time, 0.0, 1.0)
		var open := 1.0 - through if doors.is_shut(i) else through
		if open != _drawn[i]:
			_place(i, open)


## How open door `i` is drawn (0 shut, 1 open), -1 before it is first drawn.
func drawn_open(i: int) -> float:
	return _drawn[i]


## Leaf `j`'s transform as last placed (door j / 2's leaf j % 2): a unit box scaled to the leaf, turned and moved.
func leaf_at(j: int) -> Transform3D:
	return _leaves[j]


## The materials drawn, to warm their shaders before play.
func materials() -> Array[Material]:
	return [_material]


## Door `d`'s two leaves: each from its jamb to the middle, turning out to the door's side.
func _add_leaves(d: MapData.Door, blocks: Array[MapData.Block]) -> void:
	var along_z := d.size.x < d.size.z
	var width := d.size.z if along_z else d.size.x
	var thick := d.size.x if along_z else d.size.z
	var axis := Vector3(0.0, 0.0, 1.0) if along_z else Vector3(1.0, 0.0, 0.0)
	var out := (Vector3(1.0, 0.0, 0.0) if along_z else Vector3(0.0, 0.0, 1.0)) * float(d.side)
	var leaf := width * 0.5 - LEAF_GAP * 1.5
	for end: float in [-1.0, 1.0]:
		var dir := axis * -end
		_hinges.append(d.center + axis * (width * 0.5 - LEAF_GAP) * end)
		_dirs.append(dir)
		_sizes.append(Vector3(leaf, d.size.y, thick) if not along_z else Vector3(thick, d.size.y, leaf))
		# Turning by a small angle a about y moves the leaf's free end along (dir.z, 0, -dir.x) × a: out, to its side.
		_turns.append(signf(dir.z * out.x - dir.x * out.z))
		_reach.append(reach(_hinges[-1], dir, _sizes[-1], _turns[-1], blocks))


## How far (rad) a leaf hinged at `hinge`, lying along `dir`, sized `size`, turning by `turn`'s sign, folds open: half a
## turn (flat against its wall, which it only touches), or the first step back from that with no point of it inside a
## block (floors and ramps aside). Worked out once a door, at the build.
static func reach(hinge: Vector3, dir: Vector3, size: Vector3, turn: float, blocks: Array[MapData.Block]) -> float:
	var near: Array[AABB] = []
	var span := absf(dir.x) * size.x + absf(dir.z) * size.z
	for b in blocks:
		if b.kind == &"floor" or b.kind == &"ramp":
			continue
		var box := AABB(b.center - b.size * 0.5, b.size).grow(-REACH_SKIN)
		if box.intersects(AABB(hinge - Vector3(span, size.y, span), Vector3(span, size.y, span) * 2.0)):
			near.append(box)
	var thick := absf(dir.z) * size.x + absf(dir.x) * size.z
	var side := Vector3(dir.z, 0.0, -dir.x) * thick * 0.5
	var angle := PI
	while angle > PI * 0.5:
		var fold := Basis(Vector3.UP, angle * turn)
		var clear := true
		for k in REACH_POINTS + 1:
			var along := hinge + fold * (dir * span * float(k) / REACH_POINTS)
			for h in REACH_HEIGHTS:
				var up := Vector3(0.0, size.y * h, 0.0)
				for p: Vector3 in [along + fold * side + up, along - fold * side + up]:
					for box in near:
						if box.has_point(p):
							clear = false
			if not clear:
				break
		if clear:
			return angle
		angle -= REACH_STEP
	return angle


## Places door `i`'s leaves `open` of the way (0 shut, 1 folded flat against the wall), eased in and out.
func _place(i: int, open: float) -> void:
	_drawn[i] = open
	var eased := smoothstep(0.0, 1.0, open)
	var mm := _mesh.multimesh
	for k in 2:
		var j := i * 2 + k
		var turn := Basis(Vector3.UP, _reach[j] * eased * _turns[j])
		var leaf := _sizes[j]
		var middle := _hinges[j] + turn * (_dirs[j] * (absf(_dirs[j].x) * leaf.x + absf(_dirs[j].z) * leaf.z) * 0.5)
		_leaves[j] = Transform3D(turn * Basis.from_scale(leaf), middle)
		mm.set_instance_transform(j, _leaves[j])
