class_name FigureModels
extends RefCounted
## The rigged figures a session draws (step 23), each kind loaded once a session: its scene, its sidecar
## (FigureSidecar), its clips' loop modes set from the sidecar (the import leaves every clip unlooped), the fire clips'
## additive copies, its animation graph (FigureGraph, the stepping clips' offsets measured once here), where each
## replica class sits on the grip bone (the sidecar's replicaOnGrip turned from Blender's axes once), where the rifle on
## the back rides on the chest bone and where the holster's pistol sits (its empty, on two bones), and, made once and
## shared by every figure that asks, the team-painted materials and the shadow twins' meshes; every material its parts
## wear (`materials`, for ShaderPrewarm); and each replica's magazine mesh for the hand-off's tosses (MH3,
## `magazine_mesh`), read once a replica. Loaded at the session's build, behind the loading screen (FI7). A kind whose
## model or sidecar can't be read warns once and is not drawn (its figures draw no body). Held by PlaySession; freeing
## it frees all of it.

## One loaded kind.
class Kind:
	var scene: PackedScene = null
	var sidecar: FigureSidecar = null
	var library: AnimationLibrary = null
	var graph: AnimationNodeBlendTree = null
	## Replica class to its place on the grip bone, in Godot's axes: the replica's frame to the bone's.
	var grip: Dictionary[StringName, Transform3D] = {}
	## The rifle on the back: its middle's frame (its long axis -Z, the muzzle's way) in the chest bone's frame.
	var on_back: Transform3D = Transform3D.IDENTITY
	## The kit behind the rifle on the back, in on_back's frame: by square across (y) and along (z) it, how far out of
	## the back (x) the kit reaches (empty without one); and each replica mesh's move out onto it, once worked out.
	var back_rest: Dictionary[Vector2i, float] = {}
	var back_lift: Dictionary[Mesh, float] = {}
	## The pistol's holster (FigureConfig.holster_node) in the holster bone's frame and in the follow bone's, the
	## replica's axes; whether the kind has one.
	var holster: Transform3D = Transform3D.IDENTITY
	var holster_follow: Transform3D = Transform3D.IDENTITY
	var has_holster: bool = false
	## Every material the kind's parts wear, as modelled (each once).
	var sources: Array[Material] = []


var config: FigureConfig = null
## Blender's axes from Godot's (x, y, z to x, -z, y): a replica file's point in the replica's own Blender frame.
const BLENDER_FROM_GODOT := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0))

## By kind (FigureConfig.kinds' order): null until loaded, or when it couldn't be.
var _kinds: Array[Kind] = []
var _loaded: bool = false
## Team paint by kind, team, source material and glow; shadow twins' meshes by kind and head.
var _team_materials: Dictionary[String, Material] = {}
var _face_materials: Dictionary[String, Material] = {}
var _shadow_meshes: Dictionary[String, ArrayMesh] = {}
## Each replica's magazine mesh by its id (null: its model has none).
var _magazines: Dictionary[StringName, Mesh] = {}
## The first-person arms' holds by replica id (HG1), read the first time one is asked for.
var _arms_holds: Dictionary[StringName, FigureArmsHold] = {}
var _arms_read: bool = false


func _init(figure_config: FigureConfig) -> void:
	config = figure_config


## Loads every kind, the first time only (later calls change nothing). True when every kind loaded.
func load_kinds() -> bool:
	if not _loaded:
		_loaded = true
		for i in config.kinds.size():
			_kinds.append(_load(i))
	return not _kinds.has(null)


## Replica `replica_id`'s own magazine mesh (its model's FigureConfig.magazine_node, the figure version's), or null
## when its model or the node can't be found: read the first time it is asked for, then shared.
func magazine_mesh(replica_id: StringName) -> Mesh:
	if _magazines.has(replica_id):
		return _magazines[replica_id]
	var mesh: Mesh = null
	var path := FigureView.MODEL_DIR + replica_id + ".glb"
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene != null:
		var model := scene.instantiate()
		var node := model.find_child(config.magazine_node, true, false) as MeshInstance3D
		if node != null:
			mesh = node.mesh
		model.free()
	_magazines[replica_id] = mesh
	return mesh


## Whether `kind` loaded and can be drawn.
func has_kind(kind: int) -> bool:
	return kind >= 0 and kind < _kinds.size() and _kinds[kind] != null


func scene(kind: int) -> PackedScene:
	return _kinds[kind].scene if has_kind(kind) else null


func sidecar(kind: int) -> FigureSidecar:
	return _kinds[kind].sidecar if has_kind(kind) else null


## The kind's clips, looped as the sidecar says: the one library every figure of the kind plays from.
func library(kind: int) -> AnimationLibrary:
	return _kinds[kind].library if has_kind(kind) else null


## The kind's legs' animation graph: the one every figure of the kind's AnimationTree plays.
func graph(kind: int) -> AnimationNodeBlendTree:
	return _kinds[kind].graph if has_kind(kind) else null


## Where replica class `site_class` sits on `kind`'s grip bone: the replica's frame (Godot's axes) to the bone's;
## the rifle's place for a class the sidecar doesn't name, identity when it names none.
func grip(kind: int, site_class: StringName) -> Transform3D:
	if not has_kind(kind):
		return Transform3D.IDENTITY
	var places := _kinds[kind].grip
	return places.get(site_class, places.get(&"rifle", Transform3D.IDENTITY))


## How the first-person arms hold replica `id` (HG1), for the figures' hands; null when the arms model has no hold for
## it. The model (FigureConfig.arms_model) is read the first time, then let go.
func arms_hold(id: StringName) -> FigureArmsHold:
	if not _arms_read:
		_arms_read = true
		var scene := load(config.arms_model) as PackedScene if ResourceLoader.exists(config.arms_model) else null
		if scene == null:
			push_warning("FigureModels: no arms model at %s" % config.arms_model)
		else:
			var model := scene.instantiate()
			_arms_holds = FigureArmsHold.read_all(model, config)
			model.free()
	return _arms_holds.get(id)


## The rifle on the back: its middle's frame in `kind`'s chest bone's frame (FigureConfig back_* numbers).
func on_back(kind: int) -> Transform3D:
	return _kinds[kind].on_back if has_kind(kind) else Transform3D.IDENTITY


## How far out of the back (m, along on_back's x) `mesh`, its origin moved to `middle` (on its left side), goes from
## on_back to rest FigureConfig.back_rest_gap off `kind`'s kit behind it (negative to come in to it): 0 for a kind with
## no kit there (a robot) or a mesh that misses it. Each triangle is looked at every back_rest_cell, once per mesh.
func rest_on_back(kind: int, mesh: Mesh, middle: Vector3) -> float:
	if not has_kind(kind) or mesh == null or _kinds[kind].back_rest.is_empty() or config.back_rest_cell <= 0.0:
		return 0.0
	var k := _kinds[kind]
	if k.back_lift.has(mesh):
		return k.back_lift[mesh]
	var lift := -INF
	var faces := mesh.get_faces()
	for t in range(0, faces.size() - 2, 3):
		var a := faces[t] - middle
		var ab := faces[t + 1] - faces[t]
		var ac := faces[t + 2] - faces[t]
		var steps := back_steps(ab, ac, config.back_rest_cell)
		for i in steps + 1:
			for j in steps + 1 - i:
				var p := a + ab * (float(i) / steps) + ac * (float(j) / steps)
				var cell := back_cell(p, config.back_rest_cell)
				if k.back_rest.has(cell):
					lift = maxf(lift, k.back_rest[cell] - p.x)
	lift = lift + config.back_rest_gap if is_finite(lift) else 0.0
	k.back_lift[mesh] = lift
	return lift


## How many steps along each of a triangle's sides `ab` and `ac` keep its samples within `cell` (m) of each other.
static func back_steps(ab: Vector3, ac: Vector3, cell: float) -> int:
	return maxi(1, ceili(maxf(ab.length(), ac.length()) / cell))


## The square of `cell` (m) across (y) and along (z) the rifle on the back that its frame's point `p` lies over.
static func back_cell(p: Vector3, cell: float) -> Vector2i:
	return Vector2i(floori(p.y / cell), floori(p.z / cell))


## Whether `kind` has a pistol holster (FigureConfig.holster_node).
func has_holster(kind: int) -> bool:
	return has_kind(kind) and _kinds[kind].has_holster


## `kind`'s pistol holster in its holster bone's frame, the replica's axes (identity without one).
func holster(kind: int) -> Transform3D:
	return _kinds[kind].holster if has_holster(kind) else Transform3D.IDENTITY


## `kind`'s pistol holster in its follow bone's frame (FigureConfig.holster_follow_bone; identity without one).
func holster_follow(kind: int) -> Transform3D:
	return _kinds[kind].holster_follow if has_holster(kind) else Transform3D.IDENTITY


## A replicaOnGrip matrix (Blender's axes: X right, Y forward, Z up, for both the replica and the bone) as the replica's
## frame in Godot's axes (X right, Y up, -Z forward) to the bone's: the figure's joints keep Blender's bone axes (the
## glTF export turns the armature, not each bone), so only the replica's side is turned.
static func grip_from_blender(m: Transform3D) -> Transform3D:
	return m * Transform3D(BLENDER_FROM_GODOT, Vector3.ZERO)


## A vector in Blender's axes (the sidecar's throw: X right, Y forward, Z up) in Godot's (three.js's x, z, -y).
static func godot_from_blender(v: Vector3) -> Vector3:
	return BLENDER_FROM_GODOT.transposed() * v


## The rifle on the back: the frame of its middle (on its left side, against the kit) in the chest bone's frame: at
## `middle` (x to the figure's right, y above the feet), `back` behind the chest, the long axis `tilt` from upright
## with the muzzle down to the figure's left, leaning `lean` (rad, the butt toward the body, as the pack's back slopes)
## and its right side facing out of the back; `chest` the chest bone's pose (the skeleton's frame, facing +Z).
static func on_back_frame(chest: Transform3D, middle: Vector2, back: float, tilt: float, lean: float) -> Transform3D:
	# The file faces +Z, so the figure's left is +X and behind it is -Z.
	var muzzle := Vector3(sin(tilt) * cos(lean), -cos(tilt) * cos(lean), -sin(lean))
	var z := -muzzle
	var right_side := Vector3(0.0, 0.0, -1.0)
	right_side = (right_side - z * right_side.dot(z)).normalized()
	var frame := Basis(right_side, z.cross(right_side), z)
	return chest.affine_inverse() * Transform3D(frame, Vector3(-middle.x, middle.y, chest.origin.z - back))


## `source` (a Team* material of `kind`) painted `colour` for `team`, lit with `glow` of it (TeamColours' High contrast
## glow; a source that already glows keeps its own strength in the team's colour): made the first time it is asked
## for, then shared.
func team_material(kind: int, source: Material, team: int, colour: Color, glow: float) -> Material:
	var key := "%d/%d/%s/%.3f" % [kind, team, source.resource_name, glow]
	var made: Material = _team_materials.get(key)
	if made != null:
		return made
	var m := source.duplicate() as BaseMaterial3D
	if m == null:
		return source
	m.albedo_color = Color(colour, m.albedo_color.a)
	if m.emission_enabled:
		m.emission = colour
	elif glow > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = glow
	_team_materials[key] = m
	return m


## `source` (a Face* material of `kind`) showing face look `look`: its UVs offset by FigureConfig.face_offsets[look];
## look 0 (no offset) is the source itself. Made the first time it is asked for, then shared.
func face_material(kind: int, source: Material, look: int) -> Material:
	if look <= 0 or look >= config.face_offsets.size():
		return source
	var key := "%d/%d/%d" % [kind, source.get_instance_id(), look]
	var made: Material = _face_materials.get(key)
	if made != null:
		return made
	var m := source.duplicate() as BaseMaterial3D
	if m == null:
		return source
	var offset := config.face_offsets[look]
	m.uv1_offset = m.uv1_offset + Vector3(offset.x, offset.y, 0.0)
	_face_materials[key] = m
	return m


## How many face looks have been made (tests).
func face_material_count() -> int:
	return _face_materials.size()


## Every material the loaded kinds draw with: each modelled one, each Face* one's looks (face_material), and each Team*
## one painted for each team, `colours[team]` lit with `glow` (team_material: the very ones the figures will wear), for
## ShaderPrewarm.
func materials(colours: PackedColorArray, glow: float) -> Array[Material]:
	var out: Array[Material] = []
	for kind in _kinds.size():
		if _kinds[kind] == null:
			continue
		for source in _kinds[kind].sources:
			var mat_name := source.resource_name.to_lower()
			if mat_name.begins_with(config.face_material_prefix):
				for look in maxi(config.face_offsets.size(), 1):
					out.append(face_material(kind, source, look))
				continue
			if not mat_name.begins_with(config.team_material_prefix):
				out.append(source)
				continue
			for team in colours.size():
				out.append(team_material(kind, source, team, colours[team], glow))
	return out


## How many team materials have been made (tests).
func team_material_count() -> int:
	return _team_materials.size()


## The shadow twin for `kind` wearing `head`: `sources` (the figure's coarsest meshes, one skin) merged into one
## surface, so the shadow is one draw. Made once a kind and head, then shared.
func shadow_mesh(kind: int, head: StringName, sources: Array[Mesh]) -> ArrayMesh:
	var key := "%d/%s" % [kind, head]
	var made: ArrayMesh = _shadow_meshes.get(key)
	if made != null:
		return made
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	for mesh in sources:
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var base := verts.size()
			verts.append_array(a[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			normals.append_array(a[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			bones.append_array(a[Mesh.ARRAY_BONES] as PackedInt32Array)
			weights.append_array(a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array)
			for i: int in a[Mesh.ARRAY_INDEX] as PackedInt32Array:
				indices.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	made = ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_shadow_meshes[key] = made
	return made


func _load(kind: int) -> Kind:
	var base := config.models_dir + config.kinds[kind]
	var side := FigureSidecar.read(base + ".json")
	if side == null:
		return null
	var packed: PackedScene = null
	if ResourceLoader.exists(base + ".glb"):
		packed = load(base + ".glb") as PackedScene
	if packed == null:
		push_warning("FigureModels: %s.glb could not be loaded; its figures draw no body" % base)
		return null
	var k := Kind.new()
	k.scene = packed
	k.sidecar = side
	# The clips live in the scene's AnimationPlayer: take its library, loop it as the sidecar says, build the legs'
	# graph over the skeleton's rest, free the copy.
	var probe := packed.instantiate()
	var players := probe.find_children("*", "AnimationPlayer", true, false)
	var named := 0
	for part in side.parts:
		var mi := probe.find_child(part, true, false) as MeshInstance3D
		if mi == null:
			continue
		named += 1
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and not k.sources.has(m):
				k.sources.append(m)
	var skeletons := probe.find_children("*", "Skeleton3D", true, false)
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		k.library = player.get_animation_library(&"")
	if k.library != null:
		for clip in side.clips:
			var anim := k.library.get_animation(clip.name)
			if anim == null:
				push_warning("FigureModels: %s.glb has no clip %s" % [base, clip.name])
				continue
			anim.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
		if not skeletons.is_empty():
			var skeleton := skeletons[0] as Skeleton3D
			var prefix := String(probe.get_path_to(skeleton))
			_add_additive(k.library, skeleton, prefix)
			k.graph = FigureGraph.build(side, k.library, skeleton, prefix, config)
			k.on_back = _on_back(kind, side, k.library, skeleton, prefix)
			if side.parts.has(config.back_pack_part):
				k.back_rest = _back_rest(probe, skeleton, k.on_back)
	if not skeletons.is_empty():
		k.has_holster = _holster(probe, skeletons[0] as Skeleton3D, k)
	for site_class in side.replica_on_grip:
		k.grip[site_class] = grip_from_blender(side.replica_on_grip[site_class])
	probe.free()
	if named == 0:
		push_warning("FigureModels: %s.glb has none of its sidecar's parts; its figures draw no body" % base)
		return null
	if k.library == null:
		push_warning("FigureModels: %s.glb has no clips; its figures draw no body" % base)
		return null
	return k


## The holster empty's frame in the holster bone's and the follow bone's rest frames into `k` (all read from the scene
## `probe`, which isn't in the tree: the frames are its nodes' own, chained up to its root); whether the scene has them.
func _holster(probe: Node, skeleton: Skeleton3D, k: Kind) -> bool:
	var socket := probe.find_child(config.holster_node, true, false) as Node3D
	var bone := skeleton.find_bone(config.holster_bone)
	var follow := skeleton.find_bone(config.holster_follow_bone)
	if socket == null or bone < 0 or follow < 0:
		return false
	var rig := _to_root(skeleton, probe)
	var at := _to_root(socket, probe)
	k.holster = (rig * skeleton.get_bone_global_rest(bone)).affine_inverse() * at
	k.holster_follow = (rig * skeleton.get_bone_global_rest(follow)).affine_inverse() * at
	return true


## The kit behind the rifle on the back (FigureConfig.back_rest_parts' triangles whose corners are all rigged at least
## back_rest_share to the chest bone, so they move with it), in the rifle's frame `on_back`: by square (back_cell), how
## far out of the back it reaches. Each triangle is looked at every back_rest_cell, so a wide flat face counts too.
func _back_rest(probe: Node, skeleton: Skeleton3D, on_back: Transform3D) -> Dictionary[Vector2i, float]:
	var rest: Dictionary[Vector2i, float] = {}
	if config.back_rest_cell <= 0.0:
		return rest
	for part in config.back_rest_parts:
		var mi := probe.find_child(part, true, false) as MeshInstance3D
		if mi == null or mi.skin == null:
			continue
		var chest := -1
		for b in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_bone(b)
			var named := mi.skin.get_bind_name(b)
			if named == config.chest_bone or (bone >= 0 and skeleton.get_bone_name(bone) == config.chest_bone):
				chest = b
		if chest < 0:
			continue
		var to_back := on_back.affine_inverse() * mi.skin.get_bind_pose(chest)
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var corners: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if points.is_empty() or bones.size() != weights.size() or bones.size() % points.size() != 0:
				continue
			if corners.is_empty():
				corners = PackedInt32Array(range(points.size()))
			var per := bones.size() / points.size()
			var on_back_points := PackedVector3Array()
			on_back_points.resize(points.size())
			var on_chest := PackedByteArray()
			on_chest.resize(points.size())
			for i in points.size():
				var share := 0.0
				for w in per:
					if bones[i * per + w] == chest:
						share += weights[i * per + w]
				on_chest[i] = 1 if share >= config.back_rest_share else 0
				on_back_points[i] = to_back * points[i]
			for t in range(0, corners.size() - 2, 3):
				var i0 := corners[t]
				var i1 := corners[t + 1]
				var i2 := corners[t + 2]
				if on_chest[i0] == 0 or on_chest[i1] == 0 or on_chest[i2] == 0:
					continue
				var a := on_back_points[i0]
				var ab := on_back_points[i1] - a
				var ac := on_back_points[i2] - a
				var steps := back_steps(ab, ac, config.back_rest_cell)
				for u in steps + 1:
					for v in steps + 1 - u:
						var p := a + ab * (float(u) / steps) + ac * (float(v) / steps)
						var cell := back_cell(p, config.back_rest_cell)
						rest[cell] = maxf(rest.get(cell, -INF), p.x)
	return rest


## `node`'s frame in `root`'s, by its own and its parents' transforms.
static func _to_root(node: Node3D, root: Node) -> Transform3D:
	var t := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t


## The fire clips' additive copies (FigureConfig.additive_suffix), made once into the kind's library.
func _add_additive(library: AnimationLibrary, skeleton: Skeleton3D, prefix: String) -> void:
	for clip: StringName in [config.rifle_fire_clip, config.pistol_fire_clip]:
		var made := StringName(clip + config.additive_suffix)
		if library.has_animation(made):
			continue
		if not library.has_animation(clip):
			push_warning("FigureModels: no clip %s" % clip)
			continue
		library.add_animation(made, FigureGraph.additive(library.get_animation(clip), skeleton, prefix))


## Kind `kind`'s rifle on the back against the chest drawn standing holstered: the Holster clip's first frame over
## Idle's (the rest without the clips).
func _on_back(kind: int, side: FigureSidecar, library: AnimationLibrary, skeleton: Skeleton3D,
		prefix: String) -> Transform3D:
	var chest_bone := skeleton.find_bone(config.chest_bone)
	if chest_bone < 0:
		push_warning("FigureModels: no bone %s" % config.chest_bone)
		return Transform3D.IDENTITY
	var chest := skeleton.get_bone_global_rest(chest_bone)
	if library.has_animation(config.holster_clip):
		var idle := library.get_animation(config.idle_clip) if library.has_animation(config.idle_clip) else null
		chest = FigureGraph.bone_pose(library.get_animation(config.holster_clip), skeleton, prefix, chest_bone, 0.0,
				idle, config.lower_bones)
	var back := config.back_depth_human
	var lean := 0.0
	if side.parts.has(config.back_pack_part):
		back = config.back_depth_pack
		lean = config.back_lean
	elif kind == FigureMix.ROBOT:
		back = config.back_depth_robot
	return on_back_frame(chest, config.back_middle, back, config.back_tilt, lean)
