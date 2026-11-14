class_name FigureBody
extends Node3D
## One character's rigged figure (step 23), from a kind FigureModels loaded: a human wears one head, picked by the
## figure's id (FigureConfig.heads), the other heads freed; each part draws one level of detail by distance
## (GeometryInstance3D visibility ranges: LOD0 to the near line, LOD1 to the far line, LOD2 beyond, each crossed
## FigureConfig.lod_margin past it); the levels cast no shadow and one shadow twin (the coarsest level merged into one
## mesh, shadows only) casts it at every range; the Team* materials wear the team's shared paint. Meshes and bones are
## found by name, never by index (the two files order their bones differently). Its legs play the kind's shared graph
## (FigureGraph) in an AnimationTree of its own, advanced by hand from a FigurePose (`animate`), then FigureBend lowers
## and leans it and draws the hit flinch (`set_flinch`); it fades through GeometryInstance3D.transparency, so no
## material is copied. Its upper body (FI3) plays over the legs in the same tree (the aim by pitch, the holster, a
## switch, a trigger press per shot, a reload: FI4), FigureBend leans the aim the rest of the way, and FigureHands puts
## the replicas in the hand, on the back, in the holster or hanging from the hand, and a reload's magazines on the left
## hand. A bomb thrown (GT1): FigureBend's FigureThrow swings the arms, FigureHands holds the bomb in the right hand
## until it leaves.

## A gate of the upper body (FigureGraph's Transitions) as last asked: not yet, shut (a stand-in plays), open.
const GATE_UNSET := -1
const GATE_SHUT := 0
const GATE_OPEN := 1
## The vault layer's two clips as asked of its Transition (CL1).
const VAULT_OVER := 0
const VAULT_CLIMB := 1
## The render layer a body is drawn on, its own in place of the world's: the floor's wear marks leave it out
## (WearMarks: their decals reach up to meet slopes and steps, and a figure standing on a stain took it on its boots).
## Every camera and light keeps it (inside OpticGlass.ALL_LAYERS).
const LAYER := 1 << 15

## The parts it draws (the shadow twin last) and each one's level (0, 1, 2; -1 for the twin).
var meshes: Array[MeshInstance3D] = []
var levels: PackedInt32Array = PackedInt32Array()
## Each level's opaque parts folded into one mesh (BodyMerge, BP6: a draw a material, not a part's), drawn in place of
## them while the figure is solid; the parts show again while it fades (each sorted by its own depth, as before). Each
## one's level beside it.
var merged: Array[MeshInstance3D] = []
var merged_levels: PackedInt32Array = PackedInt32Array()
## The parts the merged meshes draw (hidden while solid), and each part's coarsest level by `meshes`' index: a part
## with no coarser level (the human's radio, no LOD2) draws its last one to every distance.
var _folded: Array[MeshInstance3D] = []
var _last_level: PackedInt32Array = PackedInt32Array()
var skeleton: Skeleton3D = null
## The legs' tree (its graph the kind's, its parameters its own) and the bend after it; null without a skeleton.
var tree: AnimationTree = null
var bend: FigureBend = null
## The replicas on the figure (FigureView hands them over), placed each time the skeleton is posed.
var hands: FigureHands = null
## The head it wears (&"" for a kind with one head).
var head: StringName = &""
## Whether the figure stands within LOD0's line of the eye, where its fingers close on the replica (HG1; FigureView).
var near: bool = true
## Whether its hands and replica may show in the camera's view (FigureView's `_seen`, every hold_view_stride-th frame): out of it they keep the clips'.
var seen: bool = true
var _config: FigureConfig = null
var _bones: Dictionary[StringName, int] = {}
var _fade: float = 1.0
## How far the rifle in the hand is drawn into the shoulder, eased (TP2).
var _shoulder: float = 0.0
## How far the left hand is on a rifle's handguard, and the right hand holds the replica as the arms do, eased (HG1).
var _support: float = 0.0
var _grasp: float = 0.0
## The Vault, Climb and HitCall clips' lengths (s) and the WalkOff clip's own pace (m/s).
var _vault_seconds: float = 0.0
var _climb_seconds: float = 0.0
var _call_seconds: float = 0.0
var _walk_off_pace: float = 0.0
## Turns a way in the figure's frame (x right, -z ahead) into the skeleton's (the file's, facing +Z).
var _to_skeleton: Basis = Basis.IDENTITY
## The Switch clip's length (s), time-scaled to each draw; the reload clips' (the rifle's, the pistol's), seeked to each
## reload's share.
var _switch_seconds: float = 0.0
var _rifle_reload_seconds: float = 0.0
var _pistol_reload_seconds: float = 0.0
## The reload OneShot asked for the reload under way, and its way as last asked (GATE_UNSET, 0 rifle, 1 pistol).
var _reload_asked: bool = false
var _reload_way: int = GATE_UNSET
## The upper body's gates as last asked (GATE_UNSET until the first pose asks): the aim, the holster's arms, the whole
## upper body; open, it is evaluated.
var _hold_gate: int = GATE_UNSET
var _holster_gate: int = GATE_UNSET
var _upper_gate: int = GATE_UNSET
## The stairs clips' gates as last asked (CL1), and the vault layer's clip (GATE_UNSET, VAULT_OVER or VAULT_CLIMB).
var _stairs_down_gate: int = GATE_UNSET
var _stairs_up_gate: int = GATE_UNSET
var _vault_way: int = GATE_UNSET


## Builds kind `kind` of `models` for figure `figure_id` of `team`, painted `colour` with `glow`, its levels changing at
## `lines` (m). False, with nothing built, when the kind isn't loaded.
func setup(models: FigureModels, kind: int, figure_id: int, team: int, colour: Color, glow: float,
		lines: Vector2) -> bool:
	if not models.has_kind(kind):
		return false
	_config = models.config
	name = "Body"
	var model := models.scene(kind).instantiate() as Node3D
	model.rotation = Vector3(0.0, _config.model_yaw, 0.0)
	add_child(model)
	var found := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	skeleton = found[0] as Skeleton3D if not found.is_empty() else null
	if skeleton == null:
		push_warning("FigureBody: %s has no skeleton" % _config.kinds[kind])
		return false
	var side := models.sidecar(kind)
	head = _head_for(side.parts, figure_id)
	var coarsest: Array[Mesh] = []
	var skin: Skin = null
	var last_of: Dictionary[String, int] = {}
	for part in side.parts:
		last_of[_base(part)] = maxi(last_of.get(_base(part), 0), _level(part))
	for part in side.parts:
		var mi := skeleton.get_node_or_null(NodePath(part)) as MeshInstance3D
		if mi == null:
			push_warning("FigureBody: %s has no part %s" % [_config.kinds[kind], part])
			continue
		var part_base := _base(part)
		if _config.heads.has(part_base) and StringName(part_base) != head:
			mi.free()
			continue
		var level := _level(part)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_paint(mi, models, kind, team, colour, glow, _config.face_look(figure_id))
		meshes.append(mi)
		levels.append(level)
		_last_level.append(last_of[part_base])
		if level == _config.shadow_level:
			coarsest.append(mi.mesh)
			skin = mi.skin
	# A mesh the sidecar doesn't list would draw at every range: it goes.
	for child in skeleton.get_children():
		if child is MeshInstance3D and not meshes.has(child as MeshInstance3D):
			child.free()
	if not coarsest.is_empty():
		var twin := MeshInstance3D.new()
		twin.name = "ShadowTwin"
		twin.mesh = models.shadow_mesh(kind, head, coarsest)
		twin.skin = skin
		twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		skeleton.add_child(twin)
		twin.skeleton = NodePath("..")
		meshes.append(twin)
		levels.append(-1)
		_last_level.append(-1)
	_merge_levels(models, kind, team, colour, glow, _config.face_look(figure_id), skin)
	for mi in meshes:
		mi.layers = LAYER
	for mi in merged:
		mi.layers = LAYER
	set_lod_lines(lines)
	for bone in _config.bones:
		var index := skeleton.find_bone(bone)
		if index < 0:
			push_warning("FigureBody: %s has no bone %s" % [_config.kinds[kind], bone])
		_bones[StringName(bone)] = index
	# The tree plays the kind's clips in place of the model's own player, which is freed.
	for p in players:
		(p as Node).free()
	tree = AnimationTree.new()
	tree.name = "Legs"
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.add_animation_library(&"", models.library(kind))
	tree.tree_root = models.graph(kind)
	model.add_child(tree)
	tree.root_node = NodePath("..")
	bend = FigureBend.new()
	bend.setup(skeleton, _config)
	skeleton.add_child(bend)
	var placed := Transform3D.IDENTITY
	var node: Node3D = skeleton
	while node != self:
		placed = node.transform * placed
		node = node.get_parent() as Node3D
	_to_skeleton = placed.basis.orthonormalized().inverse()
	hands = FigureHands.new()
	hands.setup(skeleton, models, kind, _config)
	skeleton.add_child(hands)
	_switch_seconds = _seconds(side, _config.switch_clip)
	_rifle_reload_seconds = _seconds(side, _config.rifle_reload_clip)
	_pistol_reload_seconds = _seconds(side, _config.pistol_reload_clip)
	_vault_seconds = _seconds(side, _config.vault_clip)
	_climb_seconds = _seconds(side, _config.climb_clip)
	_call_seconds = _seconds(side, _config.call_clip)
	var walk_off := side.clip(_config.walk_off_clip)
	_walk_off_pace = walk_off.speed if walk_off != null else 0.0
	return true


## Poses the legs and the upper body from `pose` (`hits`: the hit volume's lean geometry; `fired`: a shot since the last
## pose, one trigger press) and moves the tree on `delta` seconds; the bend and the replicas follow when the skeleton
## next updates.
func animate(pose: FigurePose, hits: HitConfig, delta: float, fired: bool = false) -> void:
	if tree == null:
		return
	_animate_upper(pose, fired)
	tree.set(FigureGraph.P_GAIT, pose.gait_position())
	_stairs_down_gate = _gate(FigureGraph.P_STAIRS_DOWN_GATE, _stairs_down_gate, pose.stairs < -HitPose.GATE)
	_stairs_up_gate = _gate(FigureGraph.P_STAIRS_UP_GATE, _stairs_up_gate, pose.stairs > HitPose.GATE)
	tree.set(FigureGraph.P_STAIRS, pose.stairs if absf(pose.stairs) > HitPose.GATE else 0.0)
	tree.set(FigureGraph.P_CROUCH_SPACE, pose.speed)
	tree.set(FigureGraph.P_CROUCH, pose.crouch)
	if pose.stepping():
		tree.set(FigureGraph.P_GAIT_SEEK, fposmod(pose.cycle, TAU))
		# Backwards, the crouched walk mirrored about its forward swing, which stays at the hit legs' forward peak.
		var crouched := FigureGraph.FORWARD_PHASE * 2.0 - pose.cycle if pose.backward else pose.cycle
		tree.set(FigureGraph.P_CROUCH_SEEK, fposmod(crouched, TAU))
	tree.set(FigureGraph.P_JUMP, pose.jump_weight)
	tree.set(FigureGraph.P_JUMP_SEEK, pose.jump_time)
	tree.set(FigureGraph.P_VAULT, pose.vault_weight)
	# The vault layer's clip, asked of the tree only when it changes (a Transition plays no input until asked once).
	var way := VAULT_CLIMB if pose.climb else VAULT_OVER
	if way != _vault_way:
		_vault_way = way
		tree.set(FigureGraph.P_VAULT_WAY, FigureGraph.VAULT_CLIMB if pose.climb else FigureGraph.VAULT_OVER)
	tree.set(FigureGraph.P_VAULT_SEEK, pose.vault_share * (_climb_seconds if pose.climb else _vault_seconds))
	tree.set(FigureGraph.P_CALL, pose.call_weight)
	tree.set(FigureGraph.P_CALL_SEEK, minf(pose.call_time, _call_seconds))
	tree.set(FigureGraph.P_WALK_OFF, pose.walk_off_weight)
	tree.set(FigureGraph.P_WALK_OFF_PACE, pose.walk_off_speed / _walk_off_pace if _walk_off_pace > 0.0 else 1.0)
	tree.advance(delta)
	bend.hits = hits
	bend.steady = pose.upper_weight()
	bend.lean = pose.lean
	bend.crouch = pose.crouch
	# The spine leans what the aim clips leave of the pitch, while they show (not holstered, not calling the hit).
	var aiming := pose.upper_weight() * (1.0 - pose.holster_weight)
	bend.aim_lean = pose.aim_lean() * aiming
	# Muzzle up at a wall (FB5), as far as the aim shows.
	bend.high_ready = pose.raise * aiming
	# A rifle in the hand rests in the shoulder (TP2), as far as the aim shows and the high ready leaves it; a pistol
	# is held out. Eased over settle_shoulder, and let go through a switch, so the replica in the hand (and its butt)
	# changes with none of it left.
	var rifle := hands.site_class(pose.in_hand) != &"pistol" and not pose.hanging and not pose.switching
	var target := aiming * (1.0 - pose.raise) * _config.shoulder_rifle if pose.in_hand >= 0 and rifle else 0.0
	_shoulder = target if pose.snapped else lerpf(_shoulder, target,
			FigurePose.settle_share(delta, _config.settle_shoulder))
	if target == 0.0 and _shoulder < _config.raise_rest:
		_shoulder = 0.0
	bend.shouldered = _shoulder
	# The cheek on the stock while a rifle is aimed, as the hit volume's head (HitPose), easing over a switch with the
	# pistol's clips.
	var cheek := aiming * (1.0 - pose.pistol_weight) if pose.in_hand >= 0 and not pose.hanging else 0.0
	bend.cheek = cheek if cheek >= _config.raise_rest else 0.0
	bend.butt_on_grip = hands.butt_on_grip(pose.in_hand)
	# The right fist closed on the grip (TP3), while the replica is held in it.
	var gripped := pose.in_hand >= 0 and not pose.hanging
	bend.grip_fit = hands.grip_fit(pose.in_hand) if gripped else Vector3.ZERO
	# Not the left hand in a reload: it takes the magazine out of the replica, as its clip does.
	bend.grip_fit_both = hands.grip_fit_both(pose.in_hand) and not pose.reloading
	# The hands on the replica as the first-person arms hold it (HG1), as far as the aim shows, both eased: the right on
	# its grip, the left on a rifle's handguard or lowered from a pistol (held one-handed); the left not in a reload (it
	# fetches the magazine); neither in a switch or a throw.
	var throwing := pose.throw_share >= 0.0 or pose.bomb_held
	var holding := gripped and not pose.switching and not throwing
	var held := hands.held(pose.in_hand)
	var support := 0.0
	if holding and not pose.reloading and held != null:
		# A pistol's left hand is lowered from the aim, not on the replica: it goes with the aim (none in the high ready).
		support = aiming * (1.0 - pose.raise) if held.one_handed else aiming
	if _support != support:
		_support = _eased(_support, support, delta, pose.snapped)
	var grasp := aiming if holding else 0.0
	if _grasp != grasp:
		_grasp = _eased(_grasp, grasp, delta, pose.snapped)
	bend.held = held if seen else null
	bend.grasp = _grasp
	bend.support = _support
	bend.close_fingers = near
	hands.grasp = _grasp if seen else 0.0
	# A bomb thrown or held in hand (GT1): the arms throw it, the bomb in the right hand until it leaves.
	bend.throw_share = pose.throw_share
	bend.throw_held = pose.bomb_held
	bend.throw_from_hand = pose.throw_from_hand
	hands.show_hands(pose.in_hand, pose.on_back, pose.hanging, pose.in_holster)
	hands.show_bomb(pose.bomb)
	hands.feet = pose.feet
	hands.velocity = pose.velocity
	hands.show_reload(pose.reload_slot if pose.reloading else -1, pose.reload_share, pose.snapped)


## The upper body's parameters: a trigger press when `fired`; the upper body's weight, its gate shut (not evaluated)
## under FigureConfig.gate_below; then, while it shows, the aim by pitch, the hold, the holster (its arms' and the aim's
## gates shut at none and at full; Holster_Sprint on the walk cycle), a switch begun (forwards to a pistol, backwards to
## a rifle, scaled to the draw), cut when the draw is (a holster, a hit).
func _animate_upper(pose: FigurePose, fired: bool) -> void:
	tree.set(FigureGraph.P_FIRE_HOLD, pose.pistol_weight)
	if fired:
		tree.set(FigureGraph.P_FIRE, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var below := _config.gate_below
	var upper := pose.upper_weight()
	upper = 0.0 if upper < below else upper
	_upper_gate = _gate(FigureGraph.P_UPPER_GATE, _upper_gate, upper > 0.0)
	tree.set(FigureGraph.P_UPPER, upper)
	if _upper_gate == GATE_SHUT:
		# Calling the hit, walking off or vaulting: nothing under the gate plays, so nothing there is asked (a switch
		# begun now would wait in its OneShot and play late).
		return
	var aim := pose.aim_blend()
	tree.set(FigureGraph.P_RIFLE_AIM, aim)
	tree.set(FigureGraph.P_PISTOL_AIM, aim)
	tree.set(FigureGraph.P_HOLD, pose.pistol_weight)
	var holster := pose.holster_weight
	holster = 0.0 if holster < below else (1.0 if holster > 1.0 - below else holster)
	_hold_gate = _gate(FigureGraph.P_HOLD_GATE, _hold_gate, holster < 1.0)
	_holster_gate = _gate(FigureGraph.P_HOLSTER_GATE, _holster_gate, holster > 0.0)
	tree.set(FigureGraph.P_HOLSTER, holster)
	tree.set(FigureGraph.P_HOLSTER_MIX, pose.sprint_weight)
	if pose.stepping():
		tree.set(FigureGraph.P_HOLSTER_SPRINT_SEEK, fposmod(pose.cycle, TAU))
	if pose.switch_started and pose.draw_seconds > 0.0:
		tree.set(FigureGraph.P_SWITCH_WAY, 1.0 if pose.switch_back else 0.0)
		tree.set(FigureGraph.P_SWITCH_PACE, _switch_seconds / pose.draw_seconds)
		tree.set(FigureGraph.P_SWITCH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif not pose.switching and tree.get(FigureGraph.P_SWITCH_ACTIVE):
		tree.set(FigureGraph.P_SWITCH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_animate_reload(pose)


## The reload OneShot: asked when a reload begins (or the gate opens on one under way), the class's clip seeked every
## frame to the reload's share of it (fitted to the replica's reload time, in step with reload_left); faded out when the
## reload stops short of its clip's end (RELOAD_END, a switch, the holster, the hit call).
func _animate_reload(pose: FigurePose) -> void:
	if not pose.reloading:
		if _reload_asked:
			_reload_asked = false
			if tree.get(FigureGraph.P_RELOAD_ACTIVE):
				tree.set(FigureGraph.P_RELOAD, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		return
	var way := 1 if pose.reload_pistol else 0
	if way != _reload_way:
		_reload_way = way
		tree.set(FigureGraph.P_RELOAD_WAY, FigureGraph.RELOAD_PISTOL if way == 1 else FigureGraph.RELOAD_RIFLE)
	if pose.reload_started or not _reload_asked:
		_reload_asked = true
		tree.set(FigureGraph.P_RELOAD, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var seconds := _pistol_reload_seconds if way == 1 else _rifle_reload_seconds
	tree.set(FigureGraph.P_RELOAD_SEEK, pose.reload_share * seconds)


## The hit flinch drawn from the next skeleton update: `tilt` (rad) in the figure's frame (FigureFlinch).
func set_flinch(tilt: Vector3) -> void:
	if bend != null:
		bend.flinch = _to_skeleton * tilt


## The bone `bone_name`'s index in this figure's skeleton (-1 when it has none), as looked up by name at setup.
func bone(bone_name: StringName) -> int:
	return _bones.get(bone_name, -1)


## Each level drawn between its lines (m): LOD0 to `lines.x`, LOD1 to `lines.y`, LOD2 beyond, each line crossed a
## margin past it. A part's coarsest level draws to every distance, so one with no LOD2 (the human's radio) keeps its
## LOD1 past the far line; the twin casts at every range. The merged meshes take the same lines.
func set_lod_lines(lines: Vector2) -> void:
	for i in meshes.size():
		if levels[i] >= 0:
			_set_range(meshes[i], levels[i], levels[i] == _last_level[i], lines)
	for i in merged.size():
		_set_range(merged[i], merged_levels[i], merged_levels[i] == _config.shadow_level, lines)


## `mi`, at `level`, drawn between its lines (to every distance when it is its part's `last`).
func _set_range(mi: MeshInstance3D, level: int, last: bool, lines: Vector2) -> void:
	mi.visibility_range_begin = 0.0 if level == 0 else (lines.x if level == 1 else lines.y)
	mi.visibility_range_begin_margin = 0.0 if level == 0 else _config.lod_margin
	mi.visibility_range_end = 0.0 if last else (lines.x if level == 0 else lines.y)
	mi.visibility_range_end_margin = 0.0 if last else _config.lod_margin


## Each level's foldable parts (BodyMerge.foldable) as one merged mesh, made once a kind, head and level and shared,
## painted as the parts are; a part's last level folds into the coarser levels too (the radio's LOD1 into LOD2). Only
## parts on the body's own skin fold (one skin binds the merged mesh); a part on another keeps its own draw. The parts it
## draws are hidden while the figure is solid (`set_fade`). A level that can't be merged keeps its parts.
func _merge_levels(models: FigureModels, kind: int, team: int, colour: Color, glow: float, look: int,
		skin: Skin) -> void:
	for level in _config.shadow_level + 1:
		var parts: Array[MeshInstance3D] = []
		var sources: Array[Mesh] = []
		for i in meshes.size():
			var at := levels[i]
			if at < 0 or meshes[i].skin != skin or not BodyMerge.foldable(meshes[i].mesh):
				continue
			if at == level or (at == _last_level[i] and at < level):
				parts.append(meshes[i])
				sources.append(meshes[i].mesh)
		if parts.size() < 2:
			continue
		var mesh := models.merged_mesh(kind, level, sources)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Merged_LOD%d" % level
		mi.mesh = mesh
		mi.skin = skin
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_paint(mi, models, kind, team, colour, glow, look)
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		merged.append(mi)
		merged_levels.append(level)
		for part in parts:
			part.visible = false
			if not _folded.has(part):
				_folded.append(part)


## Draws the shadow twin (shadows only) or not: hidden while no light casts shadows.
func set_shadow_twin(on: bool) -> void:
	if not levels.is_empty() and levels[levels.size() - 1] == -1:
		meshes[meshes.size() - 1].visible = on


## Seen `fade` of the way (1 solid, 0 gone), through each mesh's transparency: drawn see-through only while it fades.
func set_fade(fade: float) -> void:
	if fade == _fade:
		return
	var whole := fade >= 1.0
	if whole != (_fade >= 1.0):
		for mi in _folded:
			mi.visible = not whole
		for mi in merged:
			mi.visible = whole
	_fade = fade
	for mi in meshes:
		mi.transparency = 1.0 - fade
	for mi in merged:
		mi.transparency = 1.0 - fade


## The head figure `figure_id` wears: FigureConfig.heads[id % size] when the kind has those heads, else &"".
func _head_for(parts: PackedStringArray, figure_id: int) -> StringName:
	if _config.heads.is_empty() or not parts.has(_config.heads[0]):
		return &""
	return StringName(_config.heads[absi(figure_id) % _config.heads.size()])


## Team* surfaces (any case) get the team's shared paint, Face* surfaces the figure's face `look`; the rest stay as
## modelled.
func _paint(mi: MeshInstance3D, models: FigureModels, kind: int, team: int, colour: Color, glow: float,
		look: int) -> void:
	for s in mi.mesh.get_surface_count():
		var source := mi.mesh.surface_get_material(s)
		if source == null:
			continue
		var material_name := source.resource_name.to_lower()
		if material_name.begins_with(_config.team_material_prefix):
			mi.set_surface_override_material(s, models.team_material(kind, source, team, colour, glow))
		elif material_name.begins_with(_config.face_material_prefix):
			var face := models.face_material(kind, source, look)
			if face != source:
				mi.set_surface_override_material(s, face)


## `part`'s level of detail from its name (Body 0, Body_LOD1 1, Body_LOD2 2).
func _level(part: String) -> int:
	var at := part.rfind(_config.lod_suffix)
	if at < 0:
		return 0
	var tail := part.substr(at + _config.lod_suffix.length())
	return tail.to_int() if tail.is_valid_int() else 0


## Gate `param` (as last asked, `state`) opened or shut as `open` says, asked of the tree only when that changes (a
## Transition plays no input until asked once); its state after.
func _gate(param: StringName, state: int, open: bool) -> int:
	var wanted := GATE_OPEN if open else GATE_SHUT
	if wanted != state:
		tree.set(param, FigureGraph.GATE_ON if open else FigureGraph.GATE_REST)
	return wanted


static func _seconds(side: FigureSidecar, clip_name: StringName) -> float:
	var clip := side.clip(clip_name)
	return clip.seconds if clip != null else 0.0


## `part` without its level suffix.
func _base(part: String) -> String:
	var at := part.rfind(_config.lod_suffix)
	return part.substr(0, at) if at >= 0 and part.substr(at + _config.lod_suffix.length()).is_valid_int() else part


## `now` eased toward `target` (HG1): in over FigureConfig.settle_support, out quicker over settle_support_off; at once
## when the pose `snapped`, and the rest of the way once within raise_rest.
func _eased(now: float, target: float, delta: float, snapped: bool) -> float:
	var settle := _config.settle_support if target > now else _config.settle_support_off
	var out := target if snapped else lerpf(now, target, FigurePose.settle_share(delta, settle))
	return target if absf(out - target) < _config.raise_rest else out
