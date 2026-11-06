class_name ArmsView
extends Node3D
## Your arms in first person (BL4): the gloved arms model (assets/models/arms/arms.glb, built by
## tools/blender/arms/arms.py) holding the replica in hand. The model carries one hold per replica: a clip `<id>_Hold`
## posing both arms on it and an empty `Hold_<id>` where that replica's origin sits, so the arms ride the replica's
## node (ReplicaView's Held.root) and follow its sway, kick, cant and drop. A replica the model has no hold for shows no
## arms. One-handed replicas (ViewModelConfig.one_hand) hide the left arm. A robot's arms (FigureMix.ROBOT) wear
## ViewModelConfig.robot_arms. Holding a bomb, they can throw it (ArmsThrow, GT3: `ready_throw`, `throw_pose`). The
## materials press their depth as the replica's do, cast no shadow, take none (the sun's shadow on pressed depth breaks
## into hard patches over the sleeve) and stay out of an optic's view. A child of ReplicaView.

const MODEL := "res://assets/models/arms/arms.glb"
## The model's names (tools/blender/arms/arms.py).
const HOLD_PREFIX := "Hold_"
const CLIP_SUFFIX := "_Hold"
## The replica's clip a shot plays (ReplicaView.FIRE_CLIP), and the suffix of the arms' clip that works it with the
## right hand (`<id>_Fire`: a bolt-action replica's bolt, cycle.py), played in step with it.
const FIRE_CLIP := &"Fire"
const WORK_SUFFIX := "_Fire"
const LEFT_ARM := "Arm_L"

var _cfg: ViewModelConfig = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _left: MeshInstance3D = null
var _meshes: Array[MeshInstance3D] = []
## Each kind's material, by the model's material: [human, robot], the depth pressed in both.
var _worn: Dictionary[Material, Array] = {}
var _kind: int = FigureMix.HUMAN
var _on: StringName = &""
## False while the arms are elsewhere (a bomb in hand: GrenadeView), the hold kept.
var _shown: bool = true
var _skeleton: Skeleton3D = null
## The throw drawn over a bomb's hold (none without the model's skeleton).
var _throw: ArmsThrow = null
## The hold's clip, and the clip that works the replica's Fire clip (empty when the model has none for it).
var _hold_clip: StringName = &""
var _work: StringName = &""
## How far into the working clip the arms are (s).
var _work_at: float = 0.0


## Loads the model; nothing shows until `hold`.
func setup(cfg: ViewModelConfig) -> void:
	_cfg = cfg
	name = "Arms"
	var scene := load(MODEL) as PackedScene
	if scene == null:
		push_warning("ArmsView: no arms model at %s" % MODEL)
		return
	_model = scene.instantiate() as Node3D
	_model.visible = false
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_left = _model.find_child(LEFT_ARM, true, false) as MeshInstance3D
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if _skeleton != null:
		_throw = ArmsThrow.new(_skeleton, cfg)
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.layers = OpticGlass.HANDS_LAYER
		_meshes.append(mesh_node)
	_dress()


## Puts the arms on replica `id`, drawn under `root` (its origin the replica's): posed by the model's hold for it,
## hidden where it has none.
func hold(id: StringName, root: Node3D) -> void:
	if _model == null:
		return
	var mark := _model.find_child(HOLD_PREFIX + id, true, false) as Node3D
	var clip := StringName(id + CLIP_SUFFIX)
	if mark == null or _anim == null or not _anim.has_animation(clip):
		_model.visible = false
		_on = &""
		_work = &""
		return
	if _model.get_parent() != root:
		_model.reparent(root, false)
	_model.transform = _to_root(mark).affine_inverse()
	_anim.play(clip)
	_anim.seek(0.0, true)
	_anim.pause()
	if _left != null:
		_left.visible = not _cfg.one_hand.has(id)
	_model.visible = _shown
	_on = id
	_hold_clip = clip
	var work := StringName(id + WORK_SUFFIX)
	_work = work if _anim.has_animation(work) else &""


## Keeps the arms in step with the replica in hand's AnimationPlayer `anim`, each frame (`delta` s): while it plays its
## Fire clip, the arms play their clip working it at the same point; once that clip has ended, theirs runs on to its
## own end (the hand back on the grip); otherwise (another clip cut in) they keep the hold. Nothing for a replica the
## model has no such clip for.
func follow(anim: AnimationPlayer, delta: float) -> void:
	if _work == &"" or anim == null:
		return
	if anim.is_playing() and anim.current_animation == FIRE_CLIP:
		_work_at = anim.current_animation_position
	elif _anim.assigned_animation == _work and anim.assigned_animation == FIRE_CLIP \
			and _work_at < _anim.current_animation_length:
		_work_at = minf(_work_at + delta, _anim.current_animation_length)
	else:
		if _anim.assigned_animation != _hold_clip:
			_anim.play(_hold_clip)
			_anim.seek(0.0, true)
			_anim.pause()
		return
	if _anim.assigned_animation != _work:
		_anim.play(_work)
		_anim.pause()
	_anim.seek(_work_at, true)


## Shows the arms on their hold, or hides them (`on` false) keeping it, for when they're holding something else.
func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	if _model != null:
		_model.visible = on and _on != &""


## Takes the hold on now as the one a throw starts from, the pin's ring's middle at `ring` (the model's frame: the
## hold's mark at `mark`'s place, as GrenadeView draws the bomb). Call after `hold`.
func ready_throw(ring: Vector3) -> void:
	if _throw != null and _on != &"":
		_throw.capture(_skeleton, ring)


## The arms `share` of the way through a throw (ArmsThrow; 0: the hold): the left arm shown while it pulls the pin.
func throw_pose(share: float) -> void:
	if _throw == null or _on == &"":
		return
	_throw.pose(_skeleton, share)
	if _left != null:
		_left.visible = ArmsThrow.left_shown(share, _cfg) or not _cfg.one_hand.has(_on)


## How the right hand (and the bomb in its fist) has moved from the hold, in the model's frame.
func bomb_moved() -> Transform3D:
	return _throw.bomb_moved(_skeleton) if _throw != null else Transform3D.IDENTITY


## How the pin has moved from the hold `share` of the way through the throw, in the model's frame.
func pin_moved(share: float) -> Transform3D:
	return _throw.pin_moved(_skeleton, share) if _throw != null else Transform3D.IDENTITY


## The model's place under the node it rides (its hold's mark on that node's origin).
func model_transform() -> Transform3D:
	return _model.transform if _model != null else Transform3D.IDENTITY


## The replica the arms hold now (empty when none is shown).
func holding() -> StringName:
	return _on


## Every material the arms can wear (each kind's, depth pressed), for ShaderPrewarm: none without the model.
func materials() -> Array[Material]:
	var out: Array[Material] = []
	for worn: Array in _worn.values():
		for m: Material in worn:
			out.append(m)
	return out


## Dresses the arms as `kind` (FigureMix.HUMAN or FigureMix.ROBOT).
func set_kind(kind: int) -> void:
	if kind == _kind:
		return
	_kind = kind
	_dress()


## The mark's transform in the model's own space.
func _to_root(mark: Node3D) -> Transform3D:
	var t := mark.transform
	var node := mark.get_parent() as Node3D
	while node != null and node != _model:
		t = node.transform * t
		node = node.get_parent() as Node3D
	return t


func _dress() -> void:
	var robot := 1 if _kind == FigureMix.ROBOT else 0
	for mesh_node in _meshes:
		for i in mesh_node.mesh.get_surface_count():
			var own := mesh_node.mesh.surface_get_material(i)
			if own == null:
				continue
			if not _worn.has(own):
				_worn[own] = [_pressed(own, false), _pressed(own, true)]
			mesh_node.set_surface_override_material(i, _worn[own][robot])


## A copy of `own` with its depth pressed towards the eye (ViewModelConfig.depth_scale) and no shadow falling on it, in
## the robot's colour if `robot` and robot_arms names it.
func _pressed(own: Material, robot: bool) -> Material:
	var copy := own.duplicate() as Material
	var base := copy as BaseMaterial3D
	if base == null:
		return copy
	base.disable_receive_shadows = true
	if _cfg.depth_scale < 1.0:
		base.use_z_clip_scale = true
		base.z_clip_scale = _cfg.depth_scale
	if robot and _cfg.robot_arms.has(StringName(own.resource_name)):
		base.albedo_color = _cfg.robot_arms[StringName(own.resource_name)]
		base.roughness = _cfg.robot_arms_roughness
	return copy
