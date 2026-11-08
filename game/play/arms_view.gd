class_name ArmsView
extends Node3D
## Your arms in first person (BL4): the gloved arms model (assets/models/arms/arms.glb, built by
## tools/blender/arms/arms.py) holding the replica in hand. The model carries one hold per replica: a clip `<id>_Hold`
## posing both arms on it and an empty `Hold_<id>` where that replica's origin sits, so the arms ride the replica's
## node (ReplicaView's Held.root) and follow its sway, kick, cant and drop. A replica the model has no hold for shows no
## arms. One-handed replicas (ViewModelConfig.one_hand) hide the left arm. A robot's arms (FigureMix.ROBOT) wear
## ViewModelConfig.robot_arms. Holding a bomb, they can throw it (ArmsThrow, GT3: `ready_throw`, `throw_pose`; cut off,
## `cut_throw` and `unwind_throw`). The materials press their depth as the replica's do, cast no shadow, take none (the
## sun's shadow on pressed depth breaks into hard patches over the sleeve) and stay out of an optic's view. A child of
## ReplicaView.
##
## BP8 (the owner's playtest notes 6, 9 and 11): with a foregrip fitted the left hand holds it (the model's
## `<id>_grip_<key>_Hold`, and its `_Fire` and `_Reload`, where it has them; else the replica's own); through a reload
## the left hand changes the magazine (`<id>_Reload`, played at the reload's share, so the left arm shows on a
## one-handed replica while it does); and the arms can be shown skin only (Dev › Skin-only arms): the glove's kit
## (GloveKit_<side>) hidden, the fingernails (Nails_<side>) shown and the glove's surface in skin
## (ViewModelConfig.skin_arms), a human's arms only.

const MODEL := "res://assets/models/arms/arms.glb"
## The model's names (tools/blender/arms/arms.py).
const HOLD_PREFIX := "Hold_"
const CLIP_SUFFIX := "_Hold"
## The replica's clip a shot plays (ReplicaView.FIRE_CLIP), and the suffix of the arms' clip that works it with the
## right hand (`<id>_Fire`: a bolt-action replica's bolt, cycle.py), played in step with it.
const FIRE_CLIP := &"Fire"
const WORK_SUFFIX := "_Fire"
const RELOAD_SUFFIX := "_Reload"
const LEFT_ARM := "Arm_L"
## The model's left meshes end so; the glove's kit and the fingernails begin so (tools/blender/arms/arms.py).
const LEFT_SUFFIX := "_L"
## Your left hand's bone, which carries the magazine through a reload.
const LEFT_HAND := "Hand_L"
const KIT_PREFIX := "GloveKit_"
const NAILS_PREFIX := "Nails_"
## A grip part's name in the clips' (ReplicaParts: <slot>_<key>).
const GRIP_PART := "grip_"

## What each mesh shows on: both looks, the gloves only, or skin only.
enum Look { BOTH, GLOVES, SKIN }
## The arms worn: a human's gloves, a robot's, or skin only (each model material's copies in _worn, in this order).
enum Worn { HUMAN, ROBOT, SKIN }

var _cfg: ViewModelConfig = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _left: MeshInstance3D = null
var _meshes: Array[MeshInstance3D] = []
## Each mesh's Look, and whether it is a left one (as _meshes).
var _looks: PackedInt32Array = PackedInt32Array()
var _lefts: Array[bool] = []
## Each Worn's material, by the model's material (indexed by Worn), the depth pressed in all.
var _worn: Dictionary[Material, Array] = {}
var _kind: int = FigureMix.HUMAN
## Skin-only arms (Dev), worn by a human's arms.
var _skin: bool = false
## Whether the left arm shows now (a one-handed replica's only through a reload or a throw).
var _left_on: bool = true
var _on: StringName = &""
## False while the arms are elsewhere (a bomb in hand: GrenadeView), the hold kept.
var _shown: bool = true
var _skeleton: Skeleton3D = null
## The left hand's bone (-1 without the model's skeleton).
var _hand: int = -1
## The throw drawn over a bomb's hold (none without the model's skeleton).
var _throw: ArmsThrow = null
## Whether the left arm showed when the throw was cut off (`cut_throw`), so it shows while the arms ease back.
var _cut_left := false
## The hold's clip, and the clip that works the replica's Fire clip (empty when the model has none for it).
var _hold_clip: StringName = &""
var _work: StringName = &""
## The clip changing the magazine (empty when the model has none for the replica).
var _reload: StringName = &""
## How far into the working clip the arms are (s).
var _work_at: float = 0.0
## The pace the replica's Fire clip last played at, which the run-on keeps.
var _work_speed: float = 1.0


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
		_hand = _skeleton.find_bone(LEFT_HAND)
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.layers = OpticGlass.HANDS_LAYER
		_meshes.append(mesh_node)
		var mesh_name := String(mesh_node.name)
		var look := Look.BOTH
		if mesh_name.begins_with(KIT_PREFIX):
			look = Look.GLOVES
		elif mesh_name.begins_with(NAILS_PREFIX):
			look = Look.SKIN
		_looks.append(look)
		_lefts.append(mesh_name.ends_with(LEFT_SUFFIX))
	_dress()


## Puts the arms on replica `id`, drawn under `root` (its origin the replica's): posed by the model's hold for it,
## hidden where it has none. With a grip fitted (`grip`, its part's Key), the hold round that grip where the model
## has one.
func hold(id: StringName, root: Node3D, grip: StringName = &"") -> void:
	if _model == null:
		return
	var mark := _model.find_child(HOLD_PREFIX + id, true, false) as Node3D
	var base := clip_base(id, grip)
	var clip := StringName(base + CLIP_SUFFIX)
	if mark == null or _anim == null or not _anim.has_animation(clip):
		_model.visible = false
		_on = &""
		_work = &""
		_reload = &""
		return
	if _model.get_parent() != root:
		_model.reparent(root, false)
	_model.transform = _to_root(mark).affine_inverse()
	_anim.play(clip)
	_anim.seek(0.0, true)
	_anim.pause()
	_on = id
	_set_left(not _cfg.one_hand.has(id))
	_model.visible = _shown
	_hold_clip = clip
	var work := StringName(base + WORK_SUFFIX)
	_work = work if _anim.has_animation(work) else &""
	var reload := StringName(base + RELOAD_SUFFIX)
	_reload = reload if _anim.has_animation(reload) else &""


## The name the model's clips for replica `id` with grip part Key `grip` fitted begin with: `<id>_grip_<grip>` where
## the model has a hold round that grip, else `<id>`.
func clip_base(id: StringName, grip: StringName) -> String:
	if grip != &"" and _anim != null:
		var with_grip := "%s_%s%s" % [id, GRIP_PART, grip]
		if _anim.has_animation(StringName(with_grip + CLIP_SUFFIX)):
			return with_grip
	return String(id)


## Keeps the arms in step with the replica in hand's AnimationPlayer `anim`, each frame (`delta` s): through a reload
## (`reload`: the share of it done, 0..1; below 0, none) the left hand changes the magazine at that share, shown even
## on a one-handed replica; while the replica plays its Fire clip, the arms play their clip working it at the same
## point; once that clip has ended, theirs runs on to its own end (the hand back on the grip); otherwise (another clip
## cut in) they keep the hold. Nothing for a replica the model has no such clip for.
func follow(anim: AnimationPlayer, delta: float, reload: float = -1.0) -> void:
	if _reload != &"" and reload >= 0.0:
		if _anim.assigned_animation != _reload:
			_anim.play(_reload)
			_anim.pause()
		_anim.seek(clampf(reload, 0.0, 1.0) * _anim.current_animation_length, true)
		_set_left(true)
		return
	if reloading():
		# The reload ended or was cut short: back on the hold.
		_set_left(not _cfg.one_hand.has(_on))
		_anim.play(_hold_clip)
		_anim.seek(0.0, true)
		_anim.pause()
	if _work == &"" or anim == null:
		return
	if anim.is_playing() and anim.current_animation == FIRE_CLIP:
		_work_at = anim.current_animation_position
		_work_speed = anim.get_playing_speed()
	elif _anim.assigned_animation == _work and anim.assigned_animation == FIRE_CLIP \
			and _work_at < _anim.current_animation_length:
		# Run on at the pace the replica's clip played (stretched to its ready time, row 19).
		_work_at = minf(_work_at + delta * _work_speed, _anim.current_animation_length)
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


## Whether the left hand is changing the magazine now (its clip posed).
func reloading() -> bool:
	return _reload != &"" and _anim != null and _anim.assigned_animation == _reload


## The clip changing the magazine on the replica in hand (empty when the model has none for it).
func reload_clip() -> StringName:
	return _reload


## Your left hand's pose as posed now, in `root`'s space (`root` an ancestor of the arms, as `hold` puts them).
func left_hand(root: Node3D) -> Transform3D:
	if _skeleton == null or _hand < 0:
		return Transform3D.IDENTITY
	_skeleton.force_update_all_bone_transforms()
	return root.global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand)


## Shows the arms skin only (`on`; Dev › Skin-only arms) or gloved, from now; a robot's arms stay as they are.
func set_skin(on: bool) -> void:
	if on == _skin:
		return
	_skin = on
	_dress()


## Whether the arms show skin only now (asked for, and a human's).
func skin_worn() -> bool:
	return _skin and _kind != FigureMix.ROBOT


## How far (0..1) through its bolt clip the right hand is (BP7, row 17); 0 on the hold or with no bolt to work.
func work_share() -> float:
	if _work == &"" or _anim == null or _anim.assigned_animation != _work:
		return 0.0
	return clampf(_work_at / maxf(_anim.current_animation_length, 0.001), 0.0, 1.0)


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
	_set_left(ArmsThrow.left_shown(share, _cfg) or not _cfg.one_hand.has(_on))


## Takes the throw's pose now, `share` of the way through, as cut off: `unwind_throw` eases the arms back from it.
func cut_throw(share: float) -> void:
	if _throw == null or _on == &"":
		return
	_throw.cut(_skeleton)
	_cut_left = ArmsThrow.left_shown(share, _cfg)


## The arms `w` (0..1) of the way back from a cut-off throw to its start (ArmsThrow.unwind), the left arm shown until
## they're back if it showed at the cut.
func unwind_throw(w: float) -> void:
	if _throw == null or _on == &"":
		return
	_throw.unwind(_skeleton, w)
	_set_left((_cut_left and w < 1.0) or not _cfg.one_hand.has(_on))


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


## Shows the left arm (`on`) or hides it, each of its meshes as the look worn asks.
func _set_left(on: bool) -> void:
	if on == _left_on:
		return
	_left_on = on
	_show_looks()


## Each mesh shown as its side and the look worn ask: the glove's kit with gloves on, the fingernails skin only.
func _show_looks() -> void:
	var skin := skin_worn()
	for i in _meshes.size():
		var look := _looks[i]
		var worn := look == Look.BOTH or (look == Look.SKIN) == skin
		_meshes[i].visible = worn and (_left_on or not _lefts[i])


func _dress() -> void:
	var look: Worn = Worn.SKIN if skin_worn() else (Worn.ROBOT if _kind == FigureMix.ROBOT else Worn.HUMAN)
	for mesh_node in _meshes:
		for i in mesh_node.mesh.get_surface_count():
			var own := mesh_node.mesh.surface_get_material(i)
			if own == null:
				continue
			if not _worn.has(own):
				_worn[own] = [_pressed(own, false, false), _pressed(own, true, false), _pressed(own, false, true)]
			mesh_node.set_surface_override_material(i, _worn[own][look])
	_show_looks()


## A copy of `own` with its depth pressed towards the eye (ViewModelConfig.depth_scale) and no shadow falling on it, in
## the robot's colour if `robot` and robot_arms names it, or in skin if `skin` and skin_arms names it (the cloth's
## weave taken off).
func _pressed(own: Material, robot: bool, skin: bool) -> Material:
	var copy := own.duplicate() as Material
	var base := copy as BaseMaterial3D
	if base == null:
		return copy
	base.disable_receive_shadows = true
	if _cfg.depth_scale < 1.0:
		base.use_z_clip_scale = true
		base.z_clip_scale = _cfg.depth_scale
	var key := StringName(own.resource_name)
	if robot and _cfg.robot_arms.has(key):
		base.albedo_color = _cfg.robot_arms[key]
		base.roughness = _cfg.robot_arms_roughness
	if skin and _cfg.skin_arms.has(key):
		base.albedo_color = _cfg.skin_arms[key]
		base.albedo_texture = null
		base.normal_enabled = false
		base.roughness = _cfg.skin_arms_roughness
	return copy
