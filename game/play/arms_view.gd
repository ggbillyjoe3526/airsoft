class_name ArmsView
extends Node3D
## Your arms in first person (BL4): the gloved arms model (assets/models/arms/arms.glb, built by
## tools/blender/arms/arms.py) holding the replica in hand. The model carries one hold per replica: a clip `<id>_Hold`
## posing both arms on it and an empty `Hold_<id>` where that replica's origin sits, so the arms ride the replica's
## node (ReplicaView's Held.root) and follow its sway, kick, cant and drop. A replica the model has no hold for shows no
## arms. One-handed replicas (ViewModelConfig.one_hand) hide the left arm. A robot's arms (FigureMix.ROBOT) wear
## ViewModelConfig.robot_arms. The materials press their depth as the replica's do, cast no shadow and stay out of an
## optic's view. A child of ReplicaView.

const MODEL := "res://assets/models/arms/arms.glb"
## The model's names (tools/blender/arms/arms.py).
const HOLD_PREFIX := "Hold_"
const CLIP_SUFFIX := "_Hold"
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
		return
	if _model.get_parent() != root:
		_model.reparent(root, false)
	_model.transform = _to_root(mark).affine_inverse()
	_anim.play(clip)
	_anim.seek(0.0, true)
	_anim.pause()
	if _left != null:
		_left.visible = not _cfg.one_hand.has(id)
	_model.visible = true
	_on = id


## The replica the arms hold now (empty when none is shown).
func holding() -> StringName:
	return _on


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


## A copy of `own` with its depth pressed towards the eye (ViewModelConfig.depth_scale), in the robot's colour if
## `robot` and robot_arms names it.
func _pressed(own: Material, robot: bool) -> Material:
	var copy := own.duplicate() as Material
	var base := copy as BaseMaterial3D
	if base == null:
		return copy
	if _cfg.depth_scale < 1.0:
		base.use_z_clip_scale = true
		base.z_clip_scale = _cfg.depth_scale
	if robot and _cfg.robot_arms.has(StringName(own.resource_name)):
		base.albedo_color = _cfg.robot_arms[StringName(own.resource_name)]
		base.roughness = _cfg.robot_arms_roughness
	return copy
