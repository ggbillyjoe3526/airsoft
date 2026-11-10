class_name FigureGraph
extends RefCounted
## The legs' animation graph (step 23, FI2), built once a kind by FigureModels and shared by every figure of it (each
## AnimationTree keeps its own parameters): a gait BlendSpace2D (Idle, then each gait clip at its way times its pace)
## and a crouch BlendSpace1D (CrouchIdle, CrouchWalk at its pace), each under a TimeSeek, blended by crouch; on stairs
## (CL1) the gait goes through a Blend3 from Stairs_Down to Stairs_Up, each behind a gate; then the jump, the vault (or
## the climb, CL1: a Transition picks the clip) and the hit call, each its clip under a TimeSeek, and the walk-off under
## a TimeScale, each a Blend2 over what is below it. Each stepping clip's timeline is stretched to one walk cycle (TAU),
## its start offset set so the sample where its leg (FigureConfig.swing_hip to swing_ankle) swings furthest forward
## lands where Hitbox's left leg does (FORWARD_PHASE): seeking the walk cycle keeps the drawn legs in step with the hit
## volume's. Over the legs (FI3) the upper body (every bone but FigureConfig.lower_bones) takes a filtered Blend2: the
## rifle's or the pistol's aim (a BlendSpace1D down, level and up by pitch, the two blended by the hold), the holster's
## hanging arms over it, the reload as a OneShot through a TimeSeek (FI4: the rifle's or the pistol's clip at the
## reload's share), the Switch as a OneShot through a TimeScale (forwards to a pistol, backwards to a rifle), and on top
## of all the trigger press as an additive OneShot. The upper body's branch sits beside the legs' TimeSeeks, never under
## them.

## The walk cycle's phase where Hitbox.leg_swing's sine peaks: the left leg furthest forward.
const FORWARD_PHASE := PI * 0.5

## The graph's nodes.
const GAIT := &"gait"
const GAIT_SEEK := &"gait_seek"
const CROUCH_SPACE := &"crouch_space"
const CROUCH_SEEK := &"crouch_seek"
const CROUCH := &"crouch"
const JUMP_CLIP := &"jump_clip"
const JUMP_SEEK := &"jump_seek"
const JUMP := &"jump"
const STAIRS_UP := &"stairs_up"
const STAIRS_DOWN := &"stairs_down"
const STAIRS_UP_GATE := &"stairs_up_gate"
const STAIRS_DOWN_GATE := &"stairs_down_gate"
const STAIRS_UP_REST := &"stairs_up_rest"
const STAIRS_DOWN_REST := &"stairs_down_rest"
const STAIRS := &"stairs"
const VAULT_CLIP := &"vault_clip"
const CLIMB_CLIP := &"climb_clip"
const VAULT_WAY := &"vault_way"
const VAULT_SEEK := &"vault_seek"
const VAULT := &"vault"
## The vault way's two inputs: the Vault clip or the Climb clip.
const VAULT_OVER := "over"
const VAULT_CLIMB := "climb"
const CALL_CLIP := &"call_clip"
const CALL_SEEK := &"call_seek"
const CALL := &"call"
const WALK_OFF_CLIP := &"walk_off_clip"
const WALK_OFF_PACE := &"walk_off_pace"
const WALK_OFF := &"walk_off"
const RIFLE_AIM := &"rifle_aim"
const PISTOL_AIM := &"pistol_aim"
const HOLD := &"hold"
const HOLSTER_CLIP := &"holster_clip"
const HOLSTER_SPRINT_CLIP := &"holster_sprint_clip"
const HOLSTER_SPRINT_SEEK := &"holster_sprint_seek"
const HOLSTER_MIX := &"holster_mix"
const HOLSTER := &"holster"
const HOLD_GATE := &"hold_gate"
const HOLD_REST := &"hold_rest"
const HOLSTER_GATE := &"holster_gate"
const HOLSTER_REST := &"holster_rest"
const UPPER_GATE := &"upper_gate"
const UPPER_REST := &"upper_rest"
## A gate's two inputs: the branch itself, or a one-frame clip standing in while the branch has no weight.
const GATE_ON := "on"
const GATE_REST := "rest"
const RIFLE_RELOAD := &"rifle_reload"
const PISTOL_RELOAD := &"pistol_reload"
const RELOAD_WAY := &"reload_way"
const RELOAD_SEEK := &"reload_seek"
const RELOAD := &"reload"
## The reload way's two inputs: the rifle's clip or the pistol's.
const RELOAD_RIFLE := "rifle"
const RELOAD_PISTOL := "pistol"
const SWITCH_FORWARD := &"switch_forward"
const SWITCH_BACK := &"switch_back"
const SWITCH_WAY := &"switch_way"
const SWITCH_PACE := &"switch_pace"
const SWITCH := &"switch"
const UPPER := &"upper"
const RIFLE_FIRE := &"rifle_fire"
const PISTOL_FIRE := &"pistol_fire"
const FIRE_HOLD := &"fire_hold"
const FIRE := &"fire"

## Each figure's parameters (AnimationTree properties), set every frame before it advances.
const P_GAIT := &"parameters/gait/blend_position"
const P_GAIT_SEEK := &"parameters/gait_seek/seek_request"
const P_CROUCH_SPACE := &"parameters/crouch_space/blend_position"
const P_CROUCH_SEEK := &"parameters/crouch_seek/seek_request"
const P_CROUCH := &"parameters/crouch/blend_amount"
const P_JUMP_SEEK := &"parameters/jump_seek/seek_request"
const P_JUMP := &"parameters/jump/blend_amount"
const P_STAIRS := &"parameters/stairs/blend_amount"
const P_STAIRS_UP_GATE := &"parameters/stairs_up_gate/transition_request"
const P_STAIRS_DOWN_GATE := &"parameters/stairs_down_gate/transition_request"
const P_VAULT_WAY := &"parameters/vault_way/transition_request"
const P_VAULT_SEEK := &"parameters/vault_seek/seek_request"
const P_VAULT := &"parameters/vault/blend_amount"
const P_CALL_SEEK := &"parameters/call_seek/seek_request"
const P_CALL := &"parameters/call/blend_amount"
const P_WALK_OFF_PACE := &"parameters/walk_off_pace/scale"
const P_WALK_OFF := &"parameters/walk_off/blend_amount"
const P_RIFLE_AIM := &"parameters/rifle_aim/blend_position"
const P_PISTOL_AIM := &"parameters/pistol_aim/blend_position"
const P_HOLD := &"parameters/hold/blend_amount"
const P_HOLSTER_SPRINT_SEEK := &"parameters/holster_sprint_seek/seek_request"
const P_HOLSTER_MIX := &"parameters/holster_mix/blend_amount"
const P_HOLSTER := &"parameters/holster/blend_amount"
const P_HOLD_GATE := &"parameters/hold_gate/transition_request"
const P_HOLSTER_GATE := &"parameters/holster_gate/transition_request"
const P_UPPER_GATE := &"parameters/upper_gate/transition_request"
const P_RELOAD_WAY := &"parameters/reload_way/transition_request"
const P_RELOAD_SEEK := &"parameters/reload_seek/seek_request"
const P_RELOAD := &"parameters/reload/request"
const P_RELOAD_ACTIVE := &"parameters/reload/active"
const P_SWITCH_WAY := &"parameters/switch_way/blend_amount"
const P_SWITCH_PACE := &"parameters/switch_pace/scale"
const P_SWITCH := &"parameters/switch/request"
const P_SWITCH_ACTIVE := &"parameters/switch/active"
const P_UPPER := &"parameters/upper/blend_amount"
const P_FIRE_HOLD := &"parameters/fire_hold/blend_amount"
const P_FIRE := &"parameters/fire/request"
const P_FIRE_ACTIVE := &"parameters/fire/active"


## The graph for a kind: its sidecar `side`, its clips `library` (looped as the sidecar says) and `skeleton` (its rest
## pose, reached from the clips' root by `prefix`, as the tracks name it), by `cfg`. A clip the library lacks is left
## out of its blend with a warning.
static func build(side: FigureSidecar, library: AnimationLibrary, skeleton: Skeleton3D, prefix: String,
		cfg: FigureConfig) -> AnimationNodeBlendTree:
	var graph := AnimationNodeBlendTree.new()
	var gait := AnimationNodeBlendSpace2D.new()
	var reach := 0.0
	for name in cfg.gait_clips:
		reach = maxf(reach, _pace(side, name))
	gait.min_space = Vector2(-reach, -reach)
	gait.max_space = Vector2(reach, reach)
	gait.add_blend_point(_clip(library, cfg.idle_clip), Vector2.ZERO, -1, cfg.idle_clip)
	for i in cfg.gait_clips.size():
		var name := StringName(cfg.gait_clips[i])
		if not library.has_animation(name) or i >= cfg.gait_ways.size():
			push_warning("FigureGraph: no clip or way for %s" % name)
			continue
		var way := cfg.gait_ways[i]
		gait.add_blend_point(_stepping(library, name, skeleton, prefix, cfg, Vector3(-way.x, 0.0, way.y).normalized()),
				way * _pace(side, name), -1,
				name)
	var crouch := AnimationNodeBlendSpace1D.new()
	crouch.min_space = 0.0
	crouch.max_space = maxf(_pace(side, cfg.crouch_walk_clip), 1.0)
	crouch.add_blend_point(_clip(library, cfg.crouch_idle_clip), 0.0, -1, cfg.crouch_idle_clip)
	if library.has_animation(cfg.crouch_walk_clip):
		crouch.add_blend_point(_stepping(library, cfg.crouch_walk_clip, skeleton, prefix, cfg), crouch.max_space, -1,
				cfg.crouch_walk_clip)
	graph.add_node(GAIT, gait)
	_stairs(graph, library, skeleton, prefix, cfg)
	graph.add_node(GAIT_SEEK, AnimationNodeTimeSeek.new())
	graph.connect_node(GAIT_SEEK, 0, STAIRS)
	graph.add_node(CROUCH_SPACE, crouch)
	graph.add_node(CROUCH_SEEK, AnimationNodeTimeSeek.new())
	graph.connect_node(CROUCH_SEEK, 0, CROUCH_SPACE)
	_layer(graph, CROUCH, GAIT_SEEK, CROUCH_SEEK)
	_seeked(graph, JUMP_CLIP, JUMP_SEEK, _clip(library, cfg.jump_clip))
	_layer(graph, JUMP, CROUCH, JUMP_SEEK)
	# The vault or the climb (CL1): a Transition picks the clip, so only the one picked plays.
	var vault_way := AnimationNodeTransition.new()
	vault_way.xfade_time = 0.0
	vault_way.input_count = 2
	vault_way.set_input_name(0, VAULT_OVER)
	vault_way.set_input_name(1, VAULT_CLIMB)
	graph.add_node(VAULT_CLIP, _clip(library, cfg.vault_clip))
	graph.add_node(CLIMB_CLIP, _clip(library, cfg.climb_clip))
	graph.add_node(VAULT_WAY, vault_way)
	graph.connect_node(VAULT_WAY, 0, VAULT_CLIP)
	graph.connect_node(VAULT_WAY, 1, CLIMB_CLIP)
	graph.add_node(VAULT_SEEK, AnimationNodeTimeSeek.new())
	graph.connect_node(VAULT_SEEK, 0, VAULT_WAY)
	_layer(graph, VAULT, JUMP, VAULT_SEEK)
	_seeked(graph, CALL_CLIP, CALL_SEEK, _clip(library, cfg.call_clip))
	_layer(graph, CALL, VAULT, CALL_SEEK)
	graph.add_node(WALK_OFF_CLIP, _clip(library, cfg.walk_off_clip))
	graph.add_node(WALK_OFF_PACE, AnimationNodeTimeScale.new())
	graph.connect_node(WALK_OFF_PACE, 0, WALK_OFF_CLIP)
	_layer(graph, WALK_OFF, CALL, WALK_OFF_PACE)
	_upper_body(graph, library, skeleton, prefix, cfg, sprint_offset(gait, cfg))
	graph.connect_node(&"output", 0, FIRE)
	return graph


## The stairs (CL1): a Blend3 (-1 Stairs_Down, 0 the gait, 1 Stairs_Up; each stairs clip stepping as the gait's
## clips do, in step with Run_F), each stairs clip behind a gate whose rest is the one-frame gate clip, so off stairs
## neither plays. A clip the library lacks leaves its gate on the rest (no stairs that way).
static func _stairs(graph: AnimationNodeBlendTree, library: AnimationLibrary, skeleton: Skeleton3D, prefix: String,
		cfg: FigureConfig) -> void:
	graph.add_node(STAIRS, AnimationNodeBlend3.new())
	for row: Array in [[STAIRS_DOWN, STAIRS_DOWN_GATE, STAIRS_DOWN_REST, cfg.stairs_down_clip, 0],
			[STAIRS_UP, STAIRS_UP_GATE, STAIRS_UP_REST, cfg.stairs_up_clip, 2]]:
		var clip_name: StringName = row[3]
		var clip: AnimationNode = _clip(library, cfg.gate_clip)
		if library.has_animation(clip_name):
			clip = _stepping(library, clip_name, skeleton, prefix, cfg)
		else:
			push_warning("FigureGraph: no clip %s" % clip_name)
		graph.add_node(row[0], clip)
		_gate(graph, row[1], row[0], row[2], _clip(library, cfg.gate_clip))
		graph.connect_node(STAIRS, row[4], row[1])
	graph.connect_node(STAIRS, 1, GAIT)


## The Sprint clip's start offset in the gait (its forward swing at FORWARD_PHASE), for Holster_Sprint's arms.
static func sprint_offset(gait: AnimationNodeBlendSpace2D, cfg: FigureConfig) -> float:
	for i in gait.get_blend_point_count():
		var node := gait.get_blend_point_node(i) as AnimationNodeAnimation
		if node != null and node.animation == cfg.holster_sprint_pace_clip:
			return node.start_offset
	return 0.0


## The upper body over WALK_OFF (the legs): the aim, the holster, the switch, the filter, the trigger press on top.
static func _upper_body(graph: AnimationNodeBlendTree, library: AnimationLibrary, skeleton: Skeleton3D, prefix: String,
		cfg: FigureConfig, sprint_start: float) -> void:
	graph.add_node(RIFLE_AIM, _aim(library, cfg.rifle_aim_clips))
	graph.add_node(PISTOL_AIM, _aim(library, cfg.pistol_aim_clips))
	_layer(graph, HOLD, RIFLE_AIM, PISTOL_AIM)
	graph.add_node(HOLSTER_CLIP, _clip(library, cfg.holster_clip))
	# Holster_Sprint's arms pump on the Sprint's stride: one walk cycle long, its start where the Sprint's is.
	var pumping := _clip(library, cfg.holster_sprint_clip)
	pumping.use_custom_timeline = true
	pumping.timeline_length = TAU
	pumping.stretch_time_scale = true
	pumping.loop_mode = Animation.LOOP_LINEAR
	pumping.start_offset = sprint_start
	_seeked(graph, HOLSTER_SPRINT_CLIP, HOLSTER_SPRINT_SEEK, pumping)
	_layer(graph, HOLSTER_MIX, HOLSTER_CLIP, HOLSTER_SPRINT_SEEK)
	# Godot's Blend2 evaluates an input at weight 0 all the same: each branch that can sit unweighted (the aim under a
	# full holster, the holster's arms, the whole upper body calling the hit, walking off or vaulting) stands behind a
	# gate that swaps in a one-frame clip meanwhile.
	_gate(graph, HOLD_GATE, HOLD, HOLD_REST, _clip(library, cfg.gate_clip))
	_gate(graph, HOLSTER_GATE, HOLSTER_MIX, HOLSTER_REST, _clip(library, cfg.gate_clip))
	_layer(graph, HOLSTER, HOLD_GATE, HOLSTER_GATE)
	# The reload (FI4): the class's clip, picked by a Transition (only the one picked plays), placed by a TimeSeek every
	# frame at the reload's share, so it keeps step with the simulation's reload_left; a OneShot over the holster.
	var way := AnimationNodeTransition.new()
	way.xfade_time = 0.0
	way.input_count = 2
	way.set_input_name(0, RELOAD_RIFLE)
	way.set_input_name(1, RELOAD_PISTOL)
	graph.add_node(RIFLE_RELOAD, _held_open(library, cfg.rifle_reload_clip))
	graph.add_node(PISTOL_RELOAD, _held_open(library, cfg.pistol_reload_clip))
	graph.add_node(RELOAD_WAY, way)
	graph.connect_node(RELOAD_WAY, 0, RIFLE_RELOAD)
	graph.connect_node(RELOAD_WAY, 1, PISTOL_RELOAD)
	graph.add_node(RELOAD_SEEK, AnimationNodeTimeSeek.new())
	graph.connect_node(RELOAD_SEEK, 0, RELOAD_WAY)
	var reload := AnimationNodeOneShot.new()
	reload.fadein_time = cfg.settle_overlay
	reload.fadeout_time = cfg.settle_overlay
	graph.add_node(RELOAD, reload)
	graph.connect_node(RELOAD, 0, HOLSTER)
	graph.connect_node(RELOAD, 1, RELOAD_SEEK)
	graph.add_node(SWITCH_FORWARD, _clip(library, cfg.switch_clip))
	var back := _clip(library, cfg.switch_clip)
	back.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
	graph.add_node(SWITCH_BACK, back)
	_layer(graph, SWITCH_WAY, SWITCH_FORWARD, SWITCH_BACK)
	graph.add_node(SWITCH_PACE, AnimationNodeTimeScale.new())
	graph.connect_node(SWITCH_PACE, 0, SWITCH_WAY)
	var switch := AnimationNodeOneShot.new()
	switch.fadein_time = cfg.settle_overlay
	switch.fadeout_time = cfg.settle_overlay
	graph.add_node(SWITCH, switch)
	graph.connect_node(SWITCH, 0, RELOAD)
	graph.connect_node(SWITCH, 1, SWITCH_PACE)
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	for b in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(b)
		if not cfg.lower_bones.has(bone):
			upper.set_filter_path(NodePath(prefix + ":" + bone), true)
	graph.add_node(UPPER, upper)
	graph.connect_node(UPPER, 0, WALK_OFF)
	_gate(graph, UPPER_GATE, SWITCH, UPPER_REST, _clip(library, cfg.gate_clip))
	graph.connect_node(UPPER, 1, UPPER_GATE)
	graph.add_node(RIFLE_FIRE, _clip(library, StringName(cfg.rifle_fire_clip + cfg.additive_suffix)))
	graph.add_node(PISTOL_FIRE, _clip(library, StringName(cfg.pistol_fire_clip + cfg.additive_suffix)))
	_layer(graph, FIRE_HOLD, RIFLE_FIRE, PISTOL_FIRE)
	var fire := AnimationNodeOneShot.new()
	fire.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD
	fire.fadein_time = cfg.settle_overlay
	fire.fadeout_time = 0.0
	graph.add_node(FIRE, fire)
	graph.connect_node(FIRE, 0, UPPER)
	graph.connect_node(FIRE, 1, FIRE_HOLD)


## A Transition `name` between `branch` (GATE_ON, the first and the start) and `rest` (GATE_REST, the node
## `rest_name`), switched at once and never restarting either: only the input chosen is evaluated.
static func _gate(graph: AnimationNodeBlendTree, name: StringName, branch: StringName, rest_name: StringName,
		rest: AnimationNode) -> void:
	var gate := AnimationNodeTransition.new()
	gate.xfade_time = 0.0
	gate.input_count = 2
	gate.set_input_name(0, GATE_ON)
	gate.set_input_name(1, GATE_REST)
	gate.set_input_reset(0, false)
	gate.set_input_reset(1, false)
	graph.add_node(rest_name, rest)
	graph.add_node(name, gate)
	graph.connect_node(name, 0, branch)
	graph.connect_node(name, 1, rest_name)


## Clip `name` looping on its own timeline, so a OneShot over it never ends it by itself (its guess of the time left
## goes wrong under a TimeSeek that jumps): the reload ends when asked (RELOAD_END, a switch, the holster).
static func _held_open(library: AnimationLibrary, name: StringName) -> AnimationNodeAnimation:
	var node := _clip(library, name)
	var anim := library.get_animation(name) if library.has_animation(name) else null
	node.use_custom_timeline = true
	node.timeline_length = anim.length if anim != null else 1.0
	node.stretch_time_scale = false
	node.loop_mode = Animation.LOOP_LINEAR
	return node


## An aim BlendSpace1D: `clips` (down, level, up) at -1, 0 and 1, blended by the pitch's share of FigureConfig.aim_pitch.
static func _aim(library: AnimationLibrary, clips: PackedStringArray) -> AnimationNodeBlendSpace1D:
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = -1.0
	space.max_space = 1.0
	for i in clips.size():
		space.add_blend_point(_clip(library, StringName(clips[i])), float(i - 1), -1, StringName(clips[i]))
	return space


## `anim` made additive against its first frame, over `skeleton`'s rest (its bone tracks reached by `prefix`): each
## key's change from frame 0 put on the rest, which is what an additive blend adds from (the sidecar's
## makeClipAdditive(clip, 0)). A copy; `anim` is left as it is.
static func additive(anim: Animation, skeleton: Skeleton3D, prefix: String) -> Animation:
	var made := anim.duplicate(true) as Animation
	for track in made.get_track_count():
		var path := String(made.track_get_path(track))
		if not path.begins_with(prefix + ":"):
			continue
		var bone := skeleton.find_bone(path.substr(prefix.length() + 1))
		if bone < 0 or made.track_get_key_count(track) == 0:
			continue
		var rest := skeleton.get_bone_rest(bone)
		match made.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				var first := (made.track_get_key_value(track, 0) as Quaternion).inverse()
				var rest_rotation := rest.basis.get_rotation_quaternion()
				for k in made.track_get_key_count(track):
					var q := made.track_get_key_value(track, k) as Quaternion
					made.track_set_key_value(track, k, (rest_rotation * (first * q)).normalized())
			Animation.TYPE_POSITION_3D:
				var start := made.track_get_key_value(track, 0) as Vector3
				for k in made.track_get_key_count(track):
					made.track_set_key_value(track, k, rest.origin + (made.track_get_key_value(track, k) as Vector3) - start)
			Animation.TYPE_SCALE_3D:
				var base := made.track_get_key_value(track, 0) as Vector3
				var rest_scale := rest.basis.get_scale()
				for k in made.track_get_key_count(track):
					made.track_set_key_value(track, k, rest_scale * (made.track_get_key_value(track, k) as Vector3) / base)
	return made


## The time (s) in `anim` where the leg from `cfg.swing_hip` to `cfg.swing_ankle` swings furthest along `way` (the
## clip's travel in the model's frame, which faces +Z: ahead by default), of `cfg.swing_samples` points, posed from the
## tracks over `skeleton`'s rest. Measured along the travel, every clip's leading left leg (GA1: a step back, a step
## aside) meets FORWARD_PHASE, so neighbouring clips blend in step.
static func forward_time(anim: Animation, skeleton: Skeleton3D, prefix: String, cfg: FigureConfig,
		way: Vector3 = Vector3.BACK) -> float:
	var hip := skeleton.find_bone(cfg.swing_hip)
	var ankle := skeleton.find_bone(cfg.swing_ankle)
	if hip < 0 or ankle < 0:
		push_warning("FigureGraph: no bone %s or %s" % [cfg.swing_hip, cfg.swing_ankle])
		return 0.0
	var best := -INF
	var at := 0.0
	var samples := maxi(cfg.swing_samples, 1)
	for i in samples:
		var t := anim.length * i / samples
		var swing := swing_angle(bone_pose(anim, skeleton, prefix, hip, t).origin,
				bone_pose(anim, skeleton, prefix, ankle, t).origin, way)
		if swing > best:
			best = swing
			at = t
	return at


## How far along `way` (rad; a flat unit vector, ahead by default) the leg from `hip` to `ankle` swings, both in the
## model's frame (it faces +Z).
static func swing_angle(hip: Vector3, ankle: Vector3, way: Vector3 = Vector3.BACK) -> float:
	return atan2((ankle - hip).dot(way), hip.y - ankle.y)


## A stepping clip: its timeline stretched to one walk cycle, looping, its swing furthest along `way` (its travel in the
## model's frame) at FORWARD_PHASE.
static func _stepping(library: AnimationLibrary, name: StringName, skeleton: Skeleton3D, prefix: String,
		cfg: FigureConfig, way: Vector3 = Vector3.BACK) -> AnimationNodeAnimation:
	var node := _clip(library, name)
	var anim := library.get_animation(name)
	node.use_custom_timeline = true
	node.timeline_length = TAU
	node.stretch_time_scale = true
	node.loop_mode = Animation.LOOP_LINEAR
	if anim != null and anim.length > 0.0:
		var forward := forward_time(anim, skeleton, prefix, cfg, way) / anim.length * TAU
		node.start_offset = fposmod(forward - FORWARD_PHASE, TAU)
	return node


static func _clip(library: AnimationLibrary, name: StringName) -> AnimationNodeAnimation:
	if not library.has_animation(name):
		push_warning("FigureGraph: no clip %s" % name)
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node


static func _seeked(graph: AnimationNodeBlendTree, clip_name: StringName, seek_name: StringName,
		clip: AnimationNodeAnimation) -> void:
	graph.add_node(clip_name, clip)
	graph.add_node(seek_name, AnimationNodeTimeSeek.new())
	graph.connect_node(seek_name, 0, clip_name)


## A Blend2 `name` with `under` as its first input and `over` as its second.
static func _layer(graph: AnimationNodeBlendTree, name: StringName, under: StringName, over: StringName) -> void:
	graph.add_node(name, AnimationNodeBlend2.new())
	graph.connect_node(name, 0, under)
	graph.connect_node(name, 1, over)


static func _pace(side: FigureSidecar, name: StringName) -> float:
	var clip := side.clip(name)
	return clip.speed if clip != null else 0.0


## Bone `bone`'s pose in the skeleton's frame at time `t` of `anim`: each bone up its chain from its tracks, or its rest.
## With `lower` given, the bones named in `lower_bones` take their tracks from it instead (an upper-body clip over the
## legs' clip, as the upper Blend2 draws them).
static func bone_pose(anim: Animation, skeleton: Skeleton3D, prefix: String, bone: int, t: float,
		lower: Animation = null, lower_bones: PackedStringArray = PackedStringArray()) -> Transform3D:
	var pose := Transform3D.IDENTITY
	var b := bone
	while b >= 0:
		var from := lower if lower != null and lower_bones.has(skeleton.get_bone_name(b)) else anim
		pose = local_pose(from, skeleton, prefix, b, t) * pose
		b = skeleton.get_bone_parent(b)
	return pose


## Bone `bone`'s pose in its parent's frame at time `t` of `anim`: its tracks, or its rest where it has none.
static func local_pose(anim: Animation, skeleton: Skeleton3D, prefix: String, bone: int, t: float) -> Transform3D:
	var rest := skeleton.get_bone_rest(bone)
	var path := NodePath(prefix + ":" + skeleton.get_bone_name(bone))
	var position := rest.origin
	var rotation := rest.basis.get_rotation_quaternion()
	var pt := anim.find_track(path, Animation.TYPE_POSITION_3D)
	var rt := anim.find_track(path, Animation.TYPE_ROTATION_3D)
	if pt >= 0:
		position = anim.position_track_interpolate(pt, t)
	if rt >= 0:
		rotation = anim.rotation_track_interpolate(rt, t)
	return Transform3D(Basis(rotation), position)
