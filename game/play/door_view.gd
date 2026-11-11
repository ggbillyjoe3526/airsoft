class_name DoorView
extends Node3D
## The hinged doors (DO1; MapData.doors): each two painted plywood leaves hinged at their jambs, swinging out to the
## side the door hangs on over DoorConfig.swing_time and folding back flat against the wall's face when open. One
## MultiMesh, one draw call, casting shadows, in the shared light (door_leaf.gdshader, BP7), each face of a leaf in the
## baked light of the wall beside its jamb on its own side while a bake is drawn (`relight`), so it sits at that wall's
## share of its paint: a door into a dim room is dim on the room's side. Reads
## GameState.doors each frame and moves only the leaves of a door whose swing changed; nothing here is read by the
## simulation (a shut door's collider is MapLevel's). Built once; a frame allocates nothing.

## The colour MapStyle gives a door's leaves, and their shader.
const KIND := &"door"
const LEAF_SHADER := preload("res://game/play/door_leaf.gdshader")
## The leaf's models (DM1, tools/blender/maps/door.py): two-panel timber leaves in their own colours, each built for
## a leaf the size (m, wide and high) given here, its body a 1 m cube (x the width, the hinge at -x; y up; z the
## thickness) scaled to each leaf. A map's doors take the one built nearest their first leaf's shape, so stiles and
## handles stretch little (Depot's, the huts', a narrow house door's); a plain box painted the style's door colour when it won't
## load.
const LEAF_MODELS: Dictionary[String, Vector2] = {
	"res://assets/models/props/door_leaf.glb": Vector2(0.97, 2.6),
	"res://assets/models/props/door_leaf_mid.glb": Vector2(0.78, 2.5),
	"res://assets/models/props/door_leaf_narrow.glb": Vector2(0.43, 2.1),
}
## The frame's models: the opening's linings and architraves (and a head over it, where a wall is above), each built
## for an opening the size given (m: wide, high, in a wall z thick), its origin at the opening's foot, stretched to
## each door's opening and wall; the nearest to the map's first door.
const FRAME_MODELS: Dictionary[String, Vector3] = {
	"res://assets/models/props/door_frame.glb": Vector3(2.0, 2.6, 0.3),
	"res://assets/models/props/door_frame_mid.glb": Vector3(1.6, 2.5, 0.3),
	"res://assets/models/props/door_frame_narrow.glb": Vector3(0.9, 2.1, 0.3),
}
## A door's wall is the thinnest block across it this far (m) past a jamb, at the door's middle height; its thickness
## the frame's depth (a wall's end meeting it at a corner is thicker that way, so it isn't taken).
const WALL_PROBE := 0.05
## A leaf hangs on its wall's face, not in its middle (tools/depot/build_map.py): a block counts as the door's wall when
## its face is within this far (m) of the leaf's middle across the wall. The frame then sits in that wall's middle.
const WALL_REACH := 0.1
## A frame is at least this deep (m), whatever thin block stands at its jamb.
const MIN_WALL := 0.1
## A frame takes the baked light this far (m) over its foot.
const FRAME_LIGHT_LIFT := 1.0
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
## A leaf takes the baked light of the wall this far (m) past its jamb, at its middle height (`relight`).
const JAMB_STEP := 0.4

var _mesh: MultiMeshInstance3D = null
var _material: ShaderMaterial = null
var _frames: MultiMeshInstance3D = null
var _frame_material: ShaderMaterial = null
## Each frame's transform (one a door) and each leaf's turn from the model's axes to its hinge's (its +x along the
## leaf from the hinge, a quarter or half turn about up).
var _frame_at: Array[Transform3D] = []
var _bases: Array[Basis] = []
var _swing_time: float = 0.4
## Per door: each leaf's hinge (on the door's middle plane at its jamb), its direction from the hinge to the middle,
## its size, the sign of its turn to open, and how open the door was last drawn (-1: not yet).
var _hinges: PackedVector3Array = PackedVector3Array()
var _dirs: PackedVector3Array = PackedVector3Array()
var _sizes: PackedVector3Array = PackedVector3Array()
var _turns: PackedFloat32Array = PackedFloat32Array()
## Each leaf's thin axis (the world x or z its faces look along when shut), and the light on its face looking down
## that axis and on its face looking up it (white: no bake).
var _outs: PackedVector3Array = PackedVector3Array()
var _lights_down: PackedColorArray = PackedColorArray()
var _lights_up: PackedColorArray = PackedColorArray()
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
	var first := map.doors[0]
	var first_width := maxf(first.size.x, first.size.z)
	var leaf_path := _nearest(LEAF_MODELS, Vector3(first_width * 0.5 - LEAF_GAP * 1.5, first.size.y, 0.0))
	var leaf_mesh := PropDressConfig.load_mesh(leaf_path)
	view._material = ShaderMaterial.new()
	view._material.shader = LEAF_SHADER
	view._material.set_shader_parameter(&"tint", style.colour_of(KIND, 0) if leaf_mesh == null else Color.WHITE)
	view._material.set_shader_parameter(&"roughness", style.roughness)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = leaf_mesh if leaf_mesh != null else BoxMesh.new()
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
	view._add_frames(map, style)
	for i in map.doors.size():
		view._place(i, 0.0 if map.doors[i].shut else 1.0)
	view._lights_down.resize(mm.instance_count)
	view._lights_up.resize(mm.instance_count)
	view.relight(null)
	return view


## Draws each face of each leaf in the light of the wall's face on its side, JAMB_STEP m past the jamb at the leaf's
## middle height (BakedLightNear.on_side), or in the shared light alone with `lights` null (no bake drawn). Once a
## switch.
func relight(lights: BakedLightNear) -> void:
	var mm := _mesh.multimesh
	for j in _hinges.size():
		var at := _hinges[j] - _dirs[j] * JAMB_STEP
		_lights_down[j] = lights.on_side(at, -_outs[j]) if lights != null else Color.WHITE
		_lights_up[j] = lights.on_side(at, _outs[j]) if lights != null else Color.WHITE
		# The instance colour lights the faces looking down the leaf model's z; its custom data is the faces looking up
		# it, as a share of that (door_leaf.gdshader), the model's z turned to the wall's thin axis either way.
		var flipped := (_bases[j] * Vector3.BACK).dot(_outs[j]) < 0.0
		var down := _lights_up[j] if flipped else _lights_down[j]
		var up := _lights_down[j] if flipped else _lights_up[j]
		mm.set_instance_color(j, down)
		mm.set_instance_custom_data(j, Color(up.r / maxf(down.r, 0.001), up.g / maxf(down.g, 0.001),
				up.b / maxf(down.b, 0.001)))
	if _frames != null:
		var fm := _frames.multimesh
		for i in _frame_at.size():
			fm.set_instance_color(i, lights.at(_frame_at[i].origin + Vector3(0.0, FRAME_LIGHT_LIFT, 0.0))
					if lights != null else Color.WHITE)


## Leaf `j`'s light on its face looking up its thin axis (`up`) or down it (a linear multiplier of its paint; white
## with no bake drawn).
func light_of(j: int, up: bool) -> Color:
	return _lights_up[j] if up else _lights_down[j]


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


## Leaf `j`'s transform as last placed (door j / 2's leaf j % 2): the leaf model's unit cube (its x along the leaf
## from the hinge) scaled to the leaf, turned and moved.
func leaf_at(j: int) -> Transform3D:
	return _leaves[j]


## Door `i`'s frame transform as placed (the frame model scaled to its opening and wall), or the identity with none.
## The MultiMesh's own copy reads back as the identity under the headless renderer, so tests read this.
func frame_at(i: int) -> Transform3D:
	return _frame_at[i] if i < _frame_at.size() else Transform3D.IDENTITY


## The materials drawn, to warm their shaders before play.
func materials() -> Array[Material]:
	return [_material] if _frame_material == null else [_material, _frame_material]


## Each door's frame (DM1): the frame model stretched to the opening and its wall's thickness, in one MultiMesh;
## none when the model won't load.
func _add_frames(map: MapData, style: MapStyle) -> void:
	var first := map.doors[0]
	var path := _nearest(FRAME_MODELS, Vector3(maxf(first.size.x, first.size.z), first.size.y, 0.0))
	var opening: Vector3 = FRAME_MODELS[path]
	var mesh := PropDressConfig.load_mesh(path)
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = map.doors.size()
	for i in map.doors.size():
		var d := map.doors[i]
		var along_z := d.size.x < d.size.z
		var width := d.size.z if along_z else d.size.x
		var axis := Vector3(0.0, 0.0, 1.0) if along_z else Vector3(1.0, 0.0, 0.0)
		var across := Vector3(1.0, 0.0, 0.0) if along_z else Vector3(0.0, 0.0, 1.0)
		var wall := INF
		var middle := d.center.dot(across)
		for side: float in [-1.0, 1.0]:
			var probe := d.center + axis * side * (width * 0.5 + WALL_PROBE)
			for b in map.blocks:
				var thick := b.size.dot(across)
				var reach := b.size + across * WALL_REACH * 2.0
				if thick < wall and AABB(b.center - reach * 0.5, reach).has_point(probe):
					wall = thick
					middle = b.center.dot(across)
		wall = opening.z if wall == INF else maxf(wall, MIN_WALL)
		var foot := d.center - Vector3(0.0, d.size.y * 0.5, 0.0) + across * (middle - d.center.dot(across))
		var turn := Basis(Vector3.UP, PI * 0.5) if along_z else Basis.IDENTITY
		var at := Transform3D(turn * Basis.from_scale(Vector3(width / opening.x, d.size.y / opening.y,
				wall / opening.z)), foot)
		_frame_at.append(at)
		mm.set_instance_transform(i, at)
		mm.set_instance_color(i, Color.WHITE)
	_frame_material = LookMaterials.vertex_colour(style.roughness, 0.0)
	_frames = MultiMeshInstance3D.new()
	_frames.name = "Frames"
	_frames.multimesh = mm
	_frames.material_override = _frame_material
	# The frame sits in its wall, which casts the shadow already.
	_frames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_frames)


## Of `models` (path: the size each is built for, x wide and y high), the one nearest `size` in width and height by
## ratio.
static func _nearest(models: Dictionary, size: Vector3) -> String:
	var best := ""
	var best_gap := INF
	for path: String in models:
		var built: Vector3 = Vector3(models[path].x, models[path].y, 0.0)
		var gap := absf(log(maxf(size.x, 0.01) / built.x)) + absf(log(maxf(size.y, 0.01) / built.y))
		if gap < best_gap:
			best = path
			best_gap = gap
	return best


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
		_outs.append(out.abs())
		_sizes.append(Vector3(leaf, d.size.y, thick) if not along_z else Vector3(thick, d.size.y, leaf))
		_bases.append(Basis(Vector3.UP, atan2(-dir.z, dir.x)))
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
		var width := absf(_dirs[j].x) * leaf.x + absf(_dirs[j].z) * leaf.z
		var thick := absf(_dirs[j].z) * leaf.x + absf(_dirs[j].x) * leaf.z
		var middle := _hinges[j] + turn * (_dirs[j] * width * 0.5)
		_leaves[j] = Transform3D(turn * _bases[j] * Basis.from_scale(Vector3(width, leaf.y, thick)), middle)
		mm.set_instance_transform(j, _leaves[j])
