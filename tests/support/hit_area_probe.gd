class_name HitAreaProbe
extends RefCounted
## The hit area measured against the drawn figure (FI7; the browser game's M85 measure): a rigged figure posed from a
## Character (FigureBody, its tree and FigureBend as in play), its level 0 meshes baked
## (`bake_mesh_from_current_skeleton_pose`, inside `skeleton_updated`, so FigureBend's lean, crouch and aim show), the
## arms' triangles left out as Hitbox's volume leaves them out (no replica is handed to it), and parallel rays on a 1 cm
## grid from 8 sides round it, level, each tested against the baked triangles and against Hitbox's volume built from the
## same Character. Two shares, over every side's rays: of the rays that meet the drawn body, those the volume misses, and
## of the rays that meet the volume, those that meet only thin air; a ray counts only past a 2 cm rim (M85's), so a
## miss within 2 cm of a hit across the grid is not one. A parallel ray meets the same shapes from either end, so the
## 8 sides are 4 silhouettes, each counted twice. Test-only (tests/ never ships).

## The grid (m): the cell, the rim, the window round the feet each side's rays cover (across, then from under the feet
## to over the head).
const CELL := 0.01
const RIM := 0.02
const ACROSS := 1.1
const BELOW := -0.3
const ABOVE := 2.5
const SIDES := 8
## A vertex is the arm's when this much of its weight is on the arm's bones (the upper arm down to the fingers; the
## shoulder blade stays the chest's), and a triangle is left out when at least ARM_CORNERS of its corners are.
const ARM_WEIGHT := 0.5
const ARM_CORNERS := 2
const ARM_BONES: PackedStringArray = ["UpperArm", "ElbowHelper", "Forearm", "Hand", "Grip", "Index", "Middle", "Ring",
		"Pinky", "Thumb"]
## The poses measured, each a Character's state (`character`).
const POSES: Array[StringName] = [&"stand", &"crouch", &"lean_left", &"lean_right", &"walk_0", &"walk_1", &"walk_2",
		&"walk_3", &"run_0", &"run_1", &"run_2", &"run_3", &"crouch_walk", &"vault", &"aim_up", &"aim_down",
		&"between", &"crouch_half", &"crouch_back"]
## Between the fitted volume's samples (HV1): a way, a speed and a walk-cycle phase none of HitFit's samples sits on.
const BETWEEN_WAY := PI / 8.0
const BETWEEN_PHASE := PI / 8.0


## A level 0 surface as skinning reads it (`_parts`).
class Part:
	extends RefCounted
	var mesh: MeshInstance3D = null
	var surface: int = 0
	var points: PackedVector3Array = PackedVector3Array()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var per: int = 4
	var binds: PackedInt32Array = PackedInt32Array()
	var bind_poses: Array[Transform3D] = []
	var kept: PackedInt32Array = PackedInt32Array()


## One measure: the shares (percentage points) and the rays they come from.
class Result:
	extends RefCounted
	var missed: float = 0.0
	var thin_air: float = 0.0
	var drawn_rays: int = 0
	var volume_rays: int = 0
	## Rays meeting the drawn body outside the grid's window (it should be none).
	var outside: int = 0


var _models: FigureModels = null
var _hits: HitConfig = null
var _moves: MovementConfig = null
var _parent: Node = null
var _bodies: Dictionary[String, FigureBody] = {}
var _baked: Array[PackedVector3Array] = []
var _parts_of: Dictionary[int, Array] = {}
var _volume: Hitbox.Volume = Hitbox.Volume.new()
var _cols: int = 0
var _rows: int = 0
var _rim: Array[Vector2i] = []


## Measures `models`' figures against `hits`' volume; the figures are built under `parent` (they must be in the tree).
func _init(models: FigureModels, hits: HitConfig, moves: MovementConfig, parent: Node) -> void:
	_models = models
	_hits = hits
	_moves = moves
	_parent = parent
	_cols = int(round(2.0 * ACROSS / CELL))
	_rows = int(round((ABOVE - BELOW) / CELL))
	var reach := int(round(RIM / CELL))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx * dx + dy * dy <= reach * reach and (dx != 0 or dy != 0):
				_rim.append(Vector2i(dx, dy))


## Frees the figures built.
func free_bodies() -> void:
	for b: FigureBody in _bodies.values():
		b.queue_free()
	_bodies.clear()


## The heads `kind` can wear (one, &"", for a kind with none to pick from), in FigureConfig.heads' order.
func heads(kind: int) -> Array[StringName]:
	var side := _models.sidecar(kind)
	var out: Array[StringName] = []
	for h in _models.config.heads:
		if side.parts.has(h):
			out.append(StringName(h))
	if out.is_empty():
		out.append(&"")
	return out


## The Character for pose `pose_name` (POSES), standing on the origin facing -Z.
func character(pose_name: StringName) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var name := String(pose_name)
	var phase := float(name.right(1).to_int()) * PI * 0.5 if name.right(2).begins_with("_") else 0.0
	match pose_name:
		&"crouch":
			c.crouch_amount = 1.0
		&"lean_left":
			c.lean = -1.0
		&"lean_right":
			c.lean = 1.0
		&"crouch_walk":
			c.crouch_amount = 1.0
			c.velocity = Vector3(0.0, 0.0, -_moves.crouch_speed)
			c.walk_cycle = PI * 0.5
		&"vault":
			c.vault.active = true
			c.vault.rise_end = 0.3
			c.vault.end = 0.6
			c.vault.time = 0.3
			c.grounded = false
		&"aim_up":
			c.pitch = _models.config.aim_pitch
		&"aim_down":
			c.pitch = -_models.config.aim_pitch
		&"between":
			var speed := (_moves.walk_speed + _moves.run_speed) * 0.5
			c.velocity = Vector3(sin(BETWEEN_WAY), 0.0, -cos(BETWEEN_WAY)) * speed
			c.walk_cycle = BETWEEN_PHASE
			c.pitch = _models.config.aim_pitch * 0.3
		&"crouch_half":
			c.crouch_amount = 0.5
		&"crouch_back":
			c.crouch_amount = 1.0
			c.velocity = Vector3(0.0, 0.0, _moves.crouch_speed)
			c.walk_cycle = PI * 0.5 + BETWEEN_PHASE
	if name.begins_with("walk_"):
		c.velocity = Vector3(0.0, 0.0, -_moves.walk_speed)
		c.walk_cycle = phase
	elif name.begins_with("run_"):
		c.velocity = Vector3(0.0, 0.0, -_moves.sprint_speed)
		c.sprinting = true
		c.walk_cycle = phase
	c.prev_position = c.position
	c.prev_yaw = c.yaw
	c.prev_pitch = c.pitch
	c.prev_lean = c.lean
	c.prev_crouch_amount = c.crouch_amount
	c.prev_walk_cycle = c.walk_cycle
	return c


## Kind `kind` wearing `head` (heads()) in pose `pose_name`, against the volume.
func measure(kind: int, head: StringName, pose_name: StringName) -> Result:
	var c := character(pose_name)
	_bake(_body(kind, head), c)
	Hitbox.build_volume(c, _hits, _volume)
	var r := Result.new()
	var missed := 0
	var thin := 0
	for s in SIDES / 2:
		var angle := PI * float(s) / float(SIDES / 2)
		var drawn := PackedByteArray()
		drawn.resize(_cols * _rows)
		var volume := PackedByteArray()
		volume.resize(_cols * _rows)
		r.outside += _draw_mesh(drawn, angle)
		_draw_volume(volume, angle)
		for i in drawn.size():
			var d := drawn[i] != 0
			var v := volume[i] != 0
			if d:
				r.drawn_rays += 2
			if v:
				r.volume_rays += 2
			if d and not v and not _near(volume, i):
				missed += 2
			elif v and not d and not _near(drawn, i):
				thin += 2
	r.missed = 100.0 * missed / maxf(r.drawn_rays, 1.0)
	r.thin_air = 100.0 * thin / maxf(r.volume_rays, 1.0)
	return r


## Level rays at kind `kind` wearing `head` in pose `pose_name` from side `angle` (round +Y from +Z), every `stride`th
## cell across and up: each ray's start `back` m out on the near side and its unit way, in pairs (start, way). `inside`:
## the drawn body's cells whose rim is all drawn body too (a BB there strikes the figure you see); else the cells whose
## rim is all clear of it but within `reach` m of it across the grid (a BB there passes beside it).
func drawn_rays(kind: int, head: StringName, pose_name: StringName, angle: float, stride: int, back: float,
		inside: bool, reach: float = 0.1) -> PackedVector3Array:
	var c := character(pose_name)
	_bake(_body(kind, head), c)
	var drawn := PackedByteArray()
	drawn.resize(_cols * _rows)
	_draw_mesh(drawn, angle)
	var near := int(round(reach / CELL))
	var across := Vector3(cos(angle), 0.0, -sin(angle))
	var way := Vector3(sin(angle), 0.0, cos(angle))
	var out := PackedVector3Array()
	for y in range(0, _rows, stride):
		for x in range(0, _cols, stride):
			var i := y * _cols + x
			var hit := drawn[i] != 0
			if inside != hit or _near_clear(drawn, i, hit):
				continue
			if not inside and not _within(drawn, x, y, near):
				continue
			var at := across * ((x + 0.5) * CELL - ACROSS) + Vector3(0.0, (y + 0.5) * CELL + BELOW, 0.0)
			out.append(at - way * back)
			out.append(way)
	return out


## Whether any cell within the rim of cell `i` differs from `hit` (drawn or not).
func _near_clear(cells: PackedByteArray, i: int, hit: bool) -> bool:
	var x := i % _cols
	var y := i / _cols
	for o in _rim:
		var nx := x + o.x
		var ny := y + o.y
		if nx >= 0 and ny >= 0 and nx < _cols and ny < _rows and (cells[ny * _cols + nx] != 0) != hit:
			return true
	return false


## Whether a drawn cell lies within `reach` cells of (`x`, `y`), across or up.
func _within(cells: PackedByteArray, x: int, y: int, reach: int) -> bool:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and ny >= 0 and nx < _cols and ny < _rows and cells[ny * _cols + nx] != 0:
				return true
	return false


func _body(kind: int, head: StringName) -> FigureBody:
	var key := "%d/%s" % [kind, head]
	if _bodies.has(key):
		return _bodies[key]
	var id := maxi(0, _models.config.heads.find(String(head)))
	var b := FigureBody.new()
	b.setup(_models, kind, id, 0, Color.RED, 0.0, _models.config.lod_high)
	_parent.add_child(b)
	_bodies[key] = b
	return b


## Poses `b` as `c` and bakes its level 0 meshes, the arms left out, into _baked (world points, three per triangle).
func _bake(b: FigureBody, c: Character) -> void:
	var pose := FigurePose.new(_models.config)
	pose.read(c, 1.0, _hits)
	pose.snap()
	b.animate(pose, _hits, 0.0)
	b.animate(pose, _hits, 0.0)
	var sk := b.skeleton
	if _renders():
		# The bake reads the skins as the update leaves them, FigureBend's bend in: after it.
		sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
		_take(b)
		return
	# By hand the bones are read while FigureBend's bend is on them: Skeleton3D puts the clips' pose back after it.
	var baking := func() -> void: _take(b)
	sk.skeleton_updated.connect(baking, CONNECT_ONE_SHOT)
	sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	if sk.skeleton_updated.is_connected(baking):
		sk.skeleton_updated.disconnect(baking)
		push_error("HitAreaProbe: the skeleton didn't update")


## Whether a renderer registers the skins, so `bake_mesh_from_current_skeleton_pose` works (not headless).
static func _renders() -> bool:
	return DisplayServer.get_name() != "headless"


## The posed figure's level 0 triangles, the arms' left out, in world space: baked by
## `bake_mesh_from_current_skeleton_pose` where a renderer registers the skins; headless (the dummy renderer registers
## none, so the bake refuses) by the same sum it makes, each point by its weights' bones' posed global pose times their
## bind pose.
func _take(b: FigureBody) -> void:
	_baked.clear()
	var sk := b.skeleton
	var bake := _renders()
	var place := sk.global_transform
	var parts := _parts(b)
	var bones: Array[Transform3D] = []
	for part in parts:
		var skinned := PackedVector3Array()
		if bake:
			var mesh := part.mesh.bake_mesh_from_current_skeleton_pose()
			skinned = mesh.surface_get_arrays(part.surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			place = part.mesh.global_transform
		else:
			bones.resize(part.binds.size())
			for i in part.binds.size():
				bones[i] = sk.get_bone_global_pose(part.binds[i]) * part.bind_poses[i] if part.binds[i] >= 0 else \
						Transform3D.IDENTITY
			skinned.resize(part.points.size())
			for v in part.points.size():
				var at := Vector3.ZERO
				for k in part.per:
					var w := part.weights[v * part.per + k]
					if w > 0.0:
						at += bones[part.bones[v * part.per + k]] * part.points[v] * w
				skinned[v] = at
		var tris := PackedVector3Array()
		tris.resize(part.kept.size())
		for t in part.kept.size():
			tris[t] = place * skinned[part.kept[t]]
		_baked.append(tris)


## `b`'s level 0 surfaces as skinning reads them, made once a figure: the points, each one's binds and weights, each
## bind's bone and bind pose, and the corners of the triangles kept (the arms' left out).
func _parts(b: FigureBody) -> Array[Part]:
	var key := b.get_instance_id()
	var out: Array[Part] = []
	if _parts_of.has(key):
		out.assign(_parts_of[key])
		return out
	var sk := b.skeleton
	for i in b.meshes.size():
		if b.levels[i] != 0:
			continue
		var mi := b.meshes[i]
		var skin := mi.skin
		var arm := PackedByteArray()
		var binds := PackedInt32Array()
		var poses: Array[Transform3D] = []
		for k in skin.get_bind_count():
			var bone_name := String(skin.get_bind_name(k))
			var bone := sk.find_bone(bone_name) if not bone_name.is_empty() else skin.get_bind_bone(k)
			binds.append(bone)
			poses.append(skin.get_bind_pose(k))
			arm.append(1 if bone >= 0 and _on_arm(sk.get_bone_name(bone)) else 0)
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_arrays(s)
			var part := Part.new()
			part.mesh = mi
			part.surface = s
			part.points = source[Mesh.ARRAY_VERTEX] as PackedVector3Array
			part.bones = source[Mesh.ARRAY_BONES] as PackedInt32Array
			part.weights = source[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
			part.per = part.bones.size() / maxi(part.points.size(), 1)
			part.binds = binds
			part.bind_poses = poses
			var is_arm := PackedByteArray()
			is_arm.resize(part.points.size())
			for v in part.points.size():
				var share := 0.0
				for k in part.per:
					if arm[part.bones[v * part.per + k]] != 0:
						share += part.weights[v * part.per + k]
				is_arm[v] = 1 if share >= ARM_WEIGHT else 0
			var index := source[Mesh.ARRAY_INDEX] as PackedInt32Array
			for t in range(0, index.size(), 3):
				if is_arm[index[t]] + is_arm[index[t + 1]] + is_arm[index[t + 2]] < ARM_CORNERS:
					part.kept.append(index[t])
					part.kept.append(index[t + 1])
					part.kept.append(index[t + 2])
			out.append(part)
	_parts_of[key] = out
	return out


static func _on_arm(bone_name: String) -> bool:
	for prefix in ARM_BONES:
		if bone_name.begins_with(prefix):
			return true
	return false


## The grid's column for `p` seen from `angle` (round +Y from +Z), as a fraction of cells (a cell's centre whole).
func _across(p: Vector3, cos_a: float, sin_a: float) -> float:
	return (p.x * cos_a - p.z * sin_a + ACROSS) / CELL - 0.5


func _up(p: Vector3) -> float:
	return (p.y - BELOW) / CELL - 0.5


## Marks the cells whose ray meets a baked triangle; returns how many triangles reach outside the window.
func _draw_mesh(cells: PackedByteArray, angle: float) -> int:
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var outside := 0
	for tris in _baked:
		for t in range(0, tris.size(), 3):
			var x0 := _across(tris[t], cos_a, sin_a)
			var y0 := _up(tris[t])
			var x1 := _across(tris[t + 1], cos_a, sin_a)
			var y1 := _up(tris[t + 1])
			var x2 := _across(tris[t + 2], cos_a, sin_a)
			var y2 := _up(tris[t + 2])
			var area := (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
			if absf(area) < 1e-9:
				continue
			var lo_x := ceili(minf(x0, minf(x1, x2)))
			var hi_x := floori(maxf(x0, maxf(x1, x2)))
			var lo_y := ceili(minf(y0, minf(y1, y2)))
			var hi_y := floori(maxf(y0, maxf(y1, y2)))
			if lo_x < 0 or lo_y < 0 or hi_x >= _cols or hi_y >= _rows:
				outside += 1
				lo_x = maxi(lo_x, 0)
				lo_y = maxi(lo_y, 0)
				hi_x = mini(hi_x, _cols - 1)
				hi_y = mini(hi_y, _rows - 1)
			var flip := 1.0 if area > 0.0 else -1.0
			for y in range(lo_y, hi_y + 1):
				for x in range(lo_x, hi_x + 1):
					var e0 := ((x1 - x0) * (y - y0) - (y1 - y0) * (x - x0)) * flip
					var e1 := ((x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)) * flip
					var e2 := ((x0 - x2) * (y - y2) - (y0 - y2) * (x - x2)) * flip
					if e0 >= 0.0 and e1 >= 0.0 and e2 >= 0.0:
						cells[y * _cols + x] = 1
	return outside


## Marks the cells whose ray meets Hitbox's volume: each capsule seen side on is its segment's points within its radius.
func _draw_volume(cells: PackedByteArray, angle: float) -> void:
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	_draw_capsule(cells, _volume.head, cos_a, sin_a)
	for cap in _volume.parts:
		_draw_capsule(cells, cap, cos_a, sin_a)


func _draw_capsule(cells: PackedByteArray, cap: Hitbox.Capsule, cos_a: float, sin_a: float) -> void:
	if cap.r <= 0.0:
		return
	var a := Vector2(_across(cap.a, cos_a, sin_a), _up(cap.a))
	var b := Vector2(_across(cap.b, cos_a, sin_a), _up(cap.b))
	var r := cap.r / CELL
	var lo_x := maxi(0, ceili(minf(a.x, b.x) - r))
	var hi_x := mini(_cols - 1, floori(maxf(a.x, b.x) + r))
	var lo_y := maxi(0, ceili(minf(a.y, b.y) - r))
	var hi_y := mini(_rows - 1, floori(maxf(a.y, b.y) + r))
	var ab := b - a
	var len2 := ab.length_squared()
	var r2 := r * r
	for y in range(lo_y, hi_y + 1):
		for x in range(lo_x, hi_x + 1):
			var ap := Vector2(x, y) - a
			var s := clampf(ap.dot(ab) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
			if (ap - ab * s).length_squared() <= r2:
				cells[y * _cols + x] = 1


## Whether any cell within the rim of cell `i` is marked in `cells`.
func _near(cells: PackedByteArray, i: int) -> bool:
	var x := i % _cols
	var y := i / _cols
	for o in _rim:
		var nx := x + o.x
		var ny := y + o.y
		if nx >= 0 and ny >= 0 and nx < _cols and ny < _rows and cells[ny * _cols + nx] != 0:
			return true
	return false
