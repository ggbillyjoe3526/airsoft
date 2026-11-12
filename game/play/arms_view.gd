class_name ArmsView
extends Node3D
## Your arms in first person (BL4): the gloved arms model (assets/models/arms/arms.glb, built by
## tools/blender/arms/arms.py) holding the replica in hand. The model carries one hold per replica: a clip `<id>_Hold`
## posing both arms on it and an empty `Hold_<id>` where that replica's origin sits, so the arms ride the replica's
## node (ReplicaView's Held.root) and follow its sway, kick, cant and drop. A replica the model has no hold for shows no
## arms. One-handed replicas (ViewModelConfig.one_hand: a bomb) hide the left arm; a pistol is held in both (HA1). A
## robot's arms (FigureMix.ROBOT) wear ViewModelConfig.robot_arms. Holding a bomb, they can throw it (ArmsThrow, GT3:
## `ready_throw`, `throw_pose`; cut off,
## `cut_throw` and `unwind_throw`). The materials press their depth as the replica's do, cast no shadow, take none (the
## sun's shadow on pressed depth breaks into hard patches over the sleeve) and stay out of an optic's view. A child of
## ReplicaView.
##
## BP8 (the owner's playtest notes 6, 9 and 11): with a foregrip fitted the left hand holds it (the model's
## `<id>_grip_<key>_Hold`, and its `_Fire` and `_Reload`, where it has them; else the replica's own); through a reload
## the left hand changes the magazine (`<id>_Reload`, played at the reload's share, so the left arm shows on a
## one-handed replica while it does); and the arms can be shown skin only (Dev › Skin-only arms), a human's arms only:
## the glove's kit (GloveKit_<side>) hidden, the fingernails (Nails_<side>) shown and the hand's surface
## (HandSurface_<side>, the glove's cloth) in the model's painted skin (HA1: the nails' own material, whose maps share
## the glove's layout).
##
## HA1 (the owner): aimed, a rifle's hands are out of view, never faded: the replica hides them, and as the sight comes
## up (`aim`) the left arm is drawn in under it and its hand slides back behind the receiver (ArmsTuck,
## ViewModelConfig.aim_tuck and aim_slide), so forearm and hand lie behind it too.
## A replica in ViewModelConfig.aim_hands_hint (a pistol) keeps the tops of its hands: what lies further under the
## sight line fades (ArmsFade's copies of the materials, worn only while the sight is raised at all).

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
## The hand's surface: the glove's cloth, or skin only the painted skin.
const HAND_PREFIX := "HandSurface_"
## A grip part's name in the clips' (ReplicaParts: <slot>_<key>).
const GRIP_PART := "grip_"
## A pistol's hold in both hands (HA1: `<id>_two_Hold` and its `_Reload`). Yours alone: the bots copy `<id>_Hold`, the
## right hand's (FigureArmsHold).
const TWO_HANDS := "_two"

## What each mesh shows on: both looks, the gloves only, or skin only.
enum Look { BOTH, GLOVES, SKIN }
## Whose arms are worn: a human's or a robot's (each model material's copies in _worn, in this order).
enum Worn { HUMAN, ROBOT }

var _cfg: ViewModelConfig = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _left: MeshInstance3D = null
var _meshes: Array[MeshInstance3D] = []
## Each mesh's Look, and whether it is a left one (as _meshes).
var _looks: PackedInt32Array = PackedInt32Array()
var _lefts: Array[bool] = []
## Whether each is a hand's surface (as _meshes), and the model's skin material (the nails'; null without them).
var _hands: Array[bool] = []
var _skin_own: Material = null
## Each Worn's material, by the model's material (indexed by Worn), the depth pressed in all.
var _worn: Dictionary[Material, Array] = {}
## Each Worn's fading copy (ArmsFade; null where the model's material is no BaseMaterial3D), as _worn.
var _fading: Dictionary[Material, Array] = {}
## The fading copies of the look worn now, one each (what `aim` fades).
var _fade_now: Array[ShaderMaterial] = []
## How far what lies below the sight line is faded out (0..1), and whether the arms wear the fading copies now.
var _hint: float = 0.0
var _faded: bool = false
## The left arm drawn in as the sight comes up, and whether the bones carry it now.
var _tuck: ArmsTuck = null
var _tucked: bool = false
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
		_tuck = ArmsTuck.new(_skeleton)
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
			if _skin_own == null and mesh_node.mesh.get_surface_count() > 0:
				_skin_own = mesh_node.mesh.surface_get_material(0)
		_looks.append(look)
		_lefts.append(mesh_name.ends_with(LEFT_SUFFIX))
		_hands.append(mesh_name.begins_with(HAND_PREFIX))
	_dress()


## Puts the arms on replica `id`, drawn under `root` (its origin the replica's): posed by the model's hold for it,
## hidden where it has none. With a grip fitted (`grip`, its part's Key), the hold round that grip where the model
## has one.
func hold(id: StringName, root: Node3D, grip: StringName = &"") -> void:
	if _model == null:
		return
	# A hold starts from its clip alone: no clip keys the shoulder's place, so the last hold's drawn-in arm goes here.
	if _tucked:
		_tuck.clear(_skeleton)
		_tucked = false
	var mark := _model.find_child(HOLD_PREFIX + id, true, false) as Node3D
	var base := clip_base(id, grip)
	var clip := StringName(base + CLIP_SUFFIX)
	if mark == null or _anim == null or not _anim.has_animation(clip):
		_on = &""
		_work = &""
		_reload = &""
		_show_model()
		return
	if _model.get_parent() != root:
		_model.reparent(root, false)
	_model.transform = _to_root(mark).affine_inverse()
	_anim.play(clip)
	_anim.seek(0.0, true)
	_anim.pause()
	_on = id
	_set_left(not _cfg.one_hand.has(id))
	_show_model()
	_hold_clip = clip
	var work := StringName(base + WORK_SUFFIX)
	_work = work if _anim.has_animation(work) else &""
	var reload := StringName(base + RELOAD_SUFFIX)
	_reload = reload if _anim.has_animation(reload) else &""


## The name the model's clips for replica `id` with grip part Key `grip` fitted begin with: `<id>_grip_<grip>` where
## the model has a hold round that grip, else `<id>_two` where it has one in both hands (a pistol), else `<id>`.
func clip_base(id: StringName, grip: StringName) -> String:
	if _anim == null:
		return String(id)
	if grip != &"":
		var with_grip := "%s_%s%s" % [id, GRIP_PART, grip]
		if _anim.has_animation(StringName(with_grip + CLIP_SUFFIX)):
			return with_grip
	var in_both := String(id) + TWO_HANDS
	if _anim.has_animation(StringName(in_both + CLIP_SUFFIX)):
		return in_both
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
	_show_model()


## Poses and dresses the arms for the sight raised `raise` (0 at the hip, 1 up, as drawn): the left arm drawn in
## under the replica and its hand slid back behind it (ViewModelConfig.aim_tuck, aim_slide); on a replica in
## aim_hands_hint, what lies below the sight line faded out over aim_hint_span's span of the raise (aim_hint_below),
## the tops of the hands left. Call each frame, after `follow`.
func aim(raise: float) -> void:
	if _model == null or _on == &"":
		return
	_draw_in(raise)
	var hint := 0.0
	if _cfg.aim_hands_hint.has(_on):
		hint = smoothstep(_cfg.aim_hint_span.x, _cfg.aim_hint_span.y, raise)
	if is_equal_approx(hint, _hint):
		return
	_hint = hint
	if (hint > 0.0) != _faded:
		_faded = hint > 0.0
		_dress()
	for material in _fade_now:
		ArmsFade.fade(material, hint)


## How far what lies below the sight line is faded out (0: the arms whole; 1: only the tops of the hands).
func hinted() -> float:
	return _hint


## The left arm drawn in under the replica for the sight raised `raise`, its hand slid back over aim_slide_span's
## span of the raise, over the pose the clip gives: the clip's pose is put back first, since the last frame's is
## still in the bones.
func _draw_in(raise: float) -> void:
	if _tuck == null or _anim == null or _anim.assigned_animation == "":
		return
	var shift: Vector3 = _cfg.aim_tuck.get(_on, Vector3.ZERO) * raise
	var slide: Vector3 = _cfg.aim_slide.get(_on, Vector3.ZERO) \
			* smoothstep(_cfg.aim_slide_span.x, _cfg.aim_slide_span.y, raise)
	var moved := not (shift.is_zero_approx() and slide.is_zero_approx())
	if not moved and not _tucked:
		return
	_tuck.clear(_skeleton)
	_anim.seek(_anim.current_animation_position, true)
	_tucked = moved
	if _tucked:
		# The replica's axes (x right, y up), in the skeleton's.
		var to_bones := _skeleton.global_basis.inverse() * (_model.get_parent() as Node3D).global_basis
		_tuck.draw_in(_skeleton, to_bones * shift, to_bones * slide, to_bones * Vector3.DOWN, raise)


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
	for fading: Array in _fading.values():
		for m: Material in fading:
			if m != null:
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


## The model shown when it holds something and isn't put away (`set_shown`).
func _show_model() -> void:
	if _model != null:
		_model.visible = _shown and _on != &""


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


## Every surface in the look worn (a human's arms or a robot's; skin only, a hand's surface in the model's skin): its
## pressed material, or that one's fading copy while the sight is raised at all.
func _dress() -> void:
	var look: Worn = Worn.ROBOT if _kind == FigureMix.ROBOT else Worn.HUMAN
	var bare := skin_worn() and _skin_own != null
	_fade_now.clear()
	for k in _meshes.size():
		var mesh_node := _meshes[k]
		for i in mesh_node.mesh.get_surface_count():
			var own := _skin_own if bare and _hands[k] else mesh_node.mesh.surface_get_material(i)
			if own == null:
				continue
			if not _worn.has(own):
				_worn[own] = [_pressed(own, false), _pressed(own, true)]
				_fading[own] = _worn[own].map(_fading_copy)
			var fading := _fading[own][look] as ShaderMaterial
			if fading != null and not _fade_now.has(fading):
				ArmsFade.fade(fading, _hint)
				_fade_now.append(fading)
			mesh_node.set_surface_override_material(i, fading if _faded and fading != null else _worn[own][look])
	_show_looks()


## `worn`'s fading copy (null when it is no BaseMaterial3D: it then never fades, and hides with the rest).
func _fading_copy(worn: Material) -> ShaderMaterial:
	var base := worn as BaseMaterial3D
	return ArmsFade.of(base, _cfg.aim_hint_below) if base != null else null


## A copy of `own` with its depth pressed towards the eye (ViewModelConfig.depth_scale) and no shadow falling on it; if
## `robot` and robot_arms names it, in the robot's plain colour, its painted cloth taken off.
func _pressed(own: Material, robot: bool) -> Material:
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
		base.albedo_texture = null
		base.normal_enabled = false
		base.roughness_texture = null
		base.metallic_texture = null
		base.ao_enabled = false
		base.metallic = 0.0
		base.roughness = _cfg.robot_arms_roughness
	return copy
