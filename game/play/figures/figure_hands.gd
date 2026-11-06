class_name FigureHands
extends Node3D
## The replicas on a rigged figure (step 23, FI3): the figure's replicas (FigureView's figure versions, painted and with
## their parts) placed each time the skeleton is posed, after FigureBend, so they follow the drawn bones. The one in the
## hand sits on the grip bone by the sidecar's replicaOnGrip for its class (FigureModels.grip); out of the hand, the
## rifle rides on the carrier's back (FigureModels.on_back, its middle there) and the pistol sits in the belt holster
## (FigureModels.holster; none on a kind without one); calling the hit, the one in the hand hangs from the grip, its
## long axis FigureConfig.hang_tilt off straight down with the muzzle forward. In a reload (FI4) a copy of the replica
## model's magazine rides on the sidecar's bone (Hand_L): the old one pulled out from oldMagazine.from, thrown at its
## release into ThrownMagazines, then the new one from `from` to `to`; one copy a slot, so the hand never holds two, and
## the magazine in the replica's well hidden while the well is empty. A bomb thrown (GT1) shows in the right hand until
## it leaves: its model (GrenadeView's, shared) on the grip bone, turned as a pistol's grip sits there
## (FigureConfig.throw_bomb_turn, throw_bomb_shift). A child of the skeleton, so everything here is in the skeleton's
## frame (the file's, facing +Z). Presentation only: FigureBody says what shows.

## Which magazine the hand shows in a reload.
const MAG_NONE := 0
const MAG_OLD := 1
const MAG_NEW := 2


## One slot's reload, from the sidecar's magazineInHand for its class's clip, turned to Godot's axes once: the bone,
## the new magazine's place on it and its share of the clip (from, to), the old one's (from, release), its throw
## (velocity and spin in the skeleton's frame, gravity, lifetime).
class Reload:
	var bone: int = -1
	var new_on: Transform3D = Transform3D.IDENTITY
	var new_from: float = 0.0
	var new_to: float = 0.0
	var old_on: Transform3D = Transform3D.IDENTITY
	var old_from: float = 0.0
	var release: float = 0.0
	var velocity: Vector3 = Vector3.ZERO
	var spin: Vector3 = Vector3.ZERO
	var gravity: float = 0.0
	var lifetime: float = 0.0
	var throws: bool = false


var _skeleton: Skeleton3D = null
var _grip_bone: int = -1
var _chest_bone: int = -1
var _holster_bone: int = -1
var _follow_bone: int = -1
## The figure's replicas by slot (null where a slot has no model), each one's place on the grip bone, the point of it
## the grip holds (its frame), its place on the chest bone on the back and on the holster bones in the holster.
var _replicas: Array[MeshInstance3D] = []
var _on_grip: Array[Transform3D] = []
var _grip_points: PackedVector3Array = PackedVector3Array()
## Each replica's butt (the middle of its last FigureConfig.shoulder_butt_depth) in the grip bone's frame (TP2).
var _butts: PackedVector3Array = PackedVector3Array()
## Each slot's site class (`hold`'s `classes`).
var _classes: Array[StringName] = []
## Each slot's grip fit (FigureConfig.grip_fit, TP3) in the grip bone's frame, and whether both hands move with it.
var _fits: PackedVector3Array = PackedVector3Array()
var _fits_both: PackedByteArray = PackedByteArray()
## How each slot's replica is held as the first-person arms hold it (HG1; null: they don't).
var _held: Array[FigureHeld] = []
## How far the right hand holds the replica in hand as the arms do (0..1, FigureBody, eased): the replica hangs from
## the grip bone by that much of its held_on_grip.
var grasp: float = 0.0
## Whether this figure has the arms the fit moves (FigureReady's raise_arm_bones).
var _can_fit: bool = false
var _on_chest: Array[Transform3D] = []
var _in_holster: Array[Transform3D] = []
var _in_holster_follow: Array[Transform3D] = []
## Hanging from the hand: the replica's frame in the skeleton's (its muzzle down, tilted forward).
var _hang: Basis = Basis.IDENTITY
## Shown now: the slot in the hand, the slot on the back, the slot in the holster, and whether the one in the hand
## hangs.
var in_hand: int = -1
var on_back: int = -1
var in_holster: int = -1
var hanging: bool = false
var _models: FigureModels = null
var _kind: int = 0
var _config: FigureConfig = null
## The magazines' copies by slot (null where a replica has none) and each slot's reload (null without one); the slot
## whose copy shows, which magazine it shows, the reload's last share seen, a throw due at the next placing.
var _magazines: Array[MeshInstance3D] = []
## The magazine in each slot's well (the replica's piece the hand's copy is made from, null for none), and the slot
## whose well is empty now (-1: none).
var _wells: Array[MeshInstance3D] = []
var _empty_well: int = -1
var _reloads: Array[Reload] = []
var mag_slot: int = -1
var mag_shown: int = MAG_NONE
var _last_share: float = 0.0
var _throw_due: bool = false
## Where thrown magazines go (null: none thrown), and the figure's feet and velocity (the world's) for a throw.
var thrown: ThrownMagazines = null
var feet: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## The bomb in the hand (made by `set_bomb_meshes`; null: none drawn), each kind's mesh by Grenade.Kind, its place on
## the grip bone, and the kind shown (NONE: hidden).
var _bomb: MeshInstance3D = null
var _bomb_meshes: Array[Mesh] = []
var _bomb_on_grip: Transform3D = Transform3D.IDENTITY
var bomb_shown: int = Grenade.Kind.NONE


## Places replicas on `skeleton`'s bones as kind `kind` of `models` says, by `config`.
func setup(skeleton: Skeleton3D, models: FigureModels, kind: int, config: FigureConfig) -> void:
	name = "Hands"
	_skeleton = skeleton
	_models = models
	_kind = kind
	_config = config
	_grip_bone = skeleton.find_bone(config.grip_bone)
	_chest_bone = skeleton.find_bone(config.chest_bone)
	# The grip fit needs the arms FigureReady moves (TP3); without them the replica keeps the sidecar's place.
	_can_fit = config.raise_arm_bones.size() % 3 == 0 and not config.raise_arm_bones.is_empty()
	for bone_name in config.raise_arm_bones:
		_can_fit = _can_fit and skeleton.find_bone(bone_name) >= 0
	_holster_bone = skeleton.find_bone(config.holster_bone) if models.has_holster(kind) else -1
	_follow_bone = skeleton.find_bone(config.holster_follow_bone) if models.has_holster(kind) else -1
	if _follow_bone < 0:
		_holster_bone = -1
	# Its muzzle (-Z) down and tilted ahead (+Z in the file), its right side (+X) to the figure's right (-X).
	var muzzle := Vector3(0.0, -cos(config.hang_tilt), sin(config.hang_tilt))
	var right_side := Vector3(-1.0, 0.0, 0.0)
	_hang = Basis(right_side, (-muzzle).cross(right_side), -muzzle)
	skeleton.skeleton_updated.connect(_on_skeleton_updated)


## Takes `replicas` (by slot, null for a slot with no model; `classes` their site classes) and their magazines' copies
## (`magazines`, by slot, null for none) onto the figure, hidden until `show_hands` and `show_reload` say otherwise;
## each one's places worked out once here. `ids` (by slot) name the replicas, for the first-person arms' holds the
## hands take (HG1); `supports` (by slot, in each replica's frame; Vector3.INF or none: no handguard to hold) mark the
## handguard's front limit for the left hand (FigureView.support_mark): behind a fitted grip it moves back to it.
func hold(replicas: Array[MeshInstance3D], classes: Array[StringName],
		magazines: Array[MeshInstance3D] = [], supports: PackedVector3Array = PackedVector3Array(),
		ids: Array[StringName] = []) -> void:
	_replicas = replicas
	_classes = classes.duplicate()
	_magazines = magazines
	_reloads.clear()
	_wells.clear()
	_empty_well = -1
	for i in replicas.size():
		var site_class := classes[i] if i < classes.size() else &"rifle"
		_reloads.append(_reload(site_class))
		var m := magazine(i)
		_wells.append(_well(replicas[i], m))
		if m != null:
			m.get_parent().remove_child(m)
			m.visible = false
			add_child(m)
	mag_slot = -1
	mag_shown = MAG_NONE
	_throw_due = false
	_on_grip.clear()
	_on_chest.clear()
	_in_holster.clear()
	_in_holster_follow.clear()
	_grip_points.clear()
	_butts.clear()
	_fits.clear()
	_fits_both.clear()
	_held.clear()
	# The figure's grasp bone and knuckles in its hands' frames, at rest (HG1).
	var grip_r := _rest_in(_config.hold_grip + "_R", _config.hold_hand + "_R")
	var knuckle_r := _rest_in(_config.hold_knuckle + "_R", _config.hold_hand + "_R").origin
	var knuckle_l := _rest_in(_config.hold_knuckle + "_L", _config.hold_hand + "_L").origin
	var thumb_r := _rest_in(_config.hold_fingers[0] + "_R", _config.hold_hand + "_R").origin
	var thumb_l := _rest_in(_config.hold_fingers[0] + "_L", _config.hold_hand + "_L").origin
	var back := _models.on_back(_kind)
	var holster := _models.holster(_kind)
	var follow := _models.holster_follow(_kind)
	for i in replicas.size():
		var r := replicas[i]
		var site_class := classes[i] if i < classes.size() else &"rifle"
		var raw := _models.grip(_kind, site_class)
		# The hand reaches `fit` along the replica (FigureBend.grip_fit), so the replica sits that much the other way
		# in the hand, and stays where the clips put it.
		var fit: Vector3 = _config.grip_fit.get(site_class, Vector3.ZERO) if _can_fit else Vector3.ZERO
		var grip := raw * Transform3D(Basis.IDENTITY, -fit)
		_fits.append(raw.basis * fit)
		_fits_both.append(1 if _config.grip_fit_both.has(site_class) else 0)
		_on_grip.append(grip)
		_grip_points.append(grip.affine_inverse().origin)
		_butts.append(grip * _butt(r, _config.shoulder_butt_depth))
		# The arms' hold (HG1): each figure hand turned as the arms' is, its thumb's root where theirs is (hold_thumb_share),
		# the right turned hold_wrap round the grip; the left moved back to the support mark when that is behind it.
		var arms_hold := _models.arms_hold(ids[i]) if i < ids.size() else null
		var mark := supports[i] if i < supports.size() else Vector3.INF
		if arms_hold == null:
			_held.append(null)
		else:
			var right := Transform3D(arms_hold.right_hand.basis,
					arms_hold.right_knuckle.lerp(arms_hold.right_thumb, _config.hold_thumb_share)
					- arms_hold.right_hand.basis * knuckle_r.lerp(thumb_r, _config.hold_thumb_share))
			right = _wrapped(right, arms_hold.right_joints, _config.hold_wrap)
			var shift := Vector3(0.0, 0.0, maxf(0.0, mark.z - arms_hold.left_knuckle.z) if mark.is_finite() else 0.0)
			var left := Transform3D(arms_hold.left_hand.basis,
					arms_hold.left_knuckle.lerp(arms_hold.left_thumb, _config.hold_thumb_share_left)
					- arms_hold.left_hand.basis * knuckle_l.lerp(thumb_l, _config.hold_thumb_share_left) + shift)
			_held.append(FigureHeld.new(arms_hold, right, left, shift, grip, (right * grip_r).affine_inverse()))
		var middle := Vector3.ZERO
		var muzzle := Vector3.ZERO
		if r != null:
			var box := r.get_aabb()
			# Its middle along its length, on its left side (the side against the carrier or the pack).
			middle = Vector3(box.position.x, 0.0, box.get_center().z)
			# The slide's top over the muzzle's end, middle across.
			muzzle = Vector3(box.get_center().x, box.end.y, box.position.z)
			r.get_parent().remove_child(r)
			r.visible = false
			add_child(r)
		# Only a rifle goes on the back; a pistol's slot there is never shown.
		var rifle := r != null and site_class != &"pistol"
		var lift := _models.rest_on_back(_kind, r.mesh, middle) if rifle else 0.0
		_on_chest.append(back * Transform3D(Basis.IDENTITY, Vector3(lift, 0.0, 0.0) - middle))
		var seat := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -_config.holster_depth) - muzzle)
		_in_holster.append(holster * seat)
		_in_holster_follow.append(follow * seat)
	in_hand = -1
	on_back = -1
	in_holster = -1
	hanging = false


## Gives the replicas and the magazines' copies back to `to` (hidden; the caller places them), so they outlive this
## figure; a well emptied by a reload under way shows its magazine again.
func release(to: Node3D) -> void:
	_set_empty_well(-1)
	_wells.clear()
	for list: Array[MeshInstance3D] in [_replicas, _magazines]:
		for r in list:
			if r != null and r.get_parent() == self:
				remove_child(r)
				r.visible = false
				to.add_child(r)
	_replicas = []
	_magazines = []
	_reloads.clear()
	in_hand = -1
	on_back = -1
	in_holster = -1
	hanging = false
	mag_slot = -1
	mag_shown = MAG_NONE
	_throw_due = false


## The bombs' meshes by Grenade.Kind (GrenadeView.meshes, shared, never changed here); the hand holds one when
## `show_bomb` says. Made once a figure.
func set_bomb_meshes(meshes: Array[Mesh]) -> void:
	_bomb_meshes = meshes
	if _bomb == null:
		_bomb = MeshInstance3D.new()
		_bomb.name = "Bomb"
		_bomb.visible = false
		_bomb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_bomb)
		# Centred on the grip bone, turned as a pistol's grip is held there.
		var grip := _models.grip(_kind, &"pistol")
		_bomb_on_grip = Transform3D(grip.basis, Vector3.ZERO) \
				* Transform3D(Basis(Vector3.UP, _config.throw_bomb_turn), _config.throw_bomb_shift)
	# Given anew: nothing in the hand until `show_bomb` says, from the new meshes.
	_bomb.mesh = null
	_bomb.visible = false
	bomb_shown = Grenade.Kind.NONE


## Shows bomb `kind` in the right hand (Grenade.Kind; NONE hides it).
func show_bomb(kind: int) -> void:
	if _bomb == null or kind == bomb_shown:
		return
	bomb_shown = kind
	var mesh: Mesh = _bomb_meshes[kind] if kind > Grenade.Kind.NONE and kind < _bomb_meshes.size() else null
	_bomb.mesh = mesh
	_bomb.visible = mesh != null


## The bomb in the hand as drawn, or null (for tests).
func bomb() -> MeshInstance3D:
	return _bomb


## Shows replica `hand` in the hand (hanging from it when `hang`), `back` on the carrier's back and `holster`
## in the holster (-1: none; a kind without a holster shows none there).
func show_hands(hand: int, back: int, hang: bool, holster: int = -1) -> void:
	hanging = hang
	if _holster_bone < 0:
		holster = -1
	if hand == in_hand and back == on_back and holster == in_holster:
		return
	_set_shown(in_hand, false)
	_set_shown(on_back, false)
	_set_shown(in_holster, false)
	in_hand = hand
	on_back = back
	in_holster = holster
	_set_shown(in_hand, true)
	_set_shown(on_back, true)
	_set_shown(in_holster, true)


## The reload in slot `slot` at `share` of it (-1: none under way): the magazine its share shows on the hand, and its
## old one thrown once the share passes its release since the last call. `fresh` (the pose snapped: the figure was
## hidden) takes the share as it is, throwing nothing for what happened meanwhile.
func show_reload(slot: int, share: float, fresh: bool) -> void:
	var r := _reloads[slot] if slot >= 0 and slot < _reloads.size() else null
	if r == null or magazine(slot) == null:
		_set_magazine(-1, MAG_NONE)
		_set_empty_well(-1)
		_last_share = 0.0
		_throw_due = false
		return
	if slot != mag_slot or share < _last_share:
		_last_share = 0.0
	if fresh:
		_last_share = share
	if r.throws and _last_share < r.release and share >= r.release:
		_throw_due = true
	_last_share = share
	var shown := MAG_NONE
	if share >= r.new_from and share < r.new_to:
		shown = MAG_NEW
	elif r.throws and share >= r.old_from and share < r.release:
		shown = MAG_OLD
	_set_magazine(slot, shown)
	# The well is empty from the old one's pull (the new one's, with nothing to pull) until the new one is home.
	var out := r.old_from if r.throws else r.new_from
	_set_empty_well(slot if share >= out and share < r.new_to else -1)


## The copy of slot `slot`'s magazine, or null.
func magazine(slot: int) -> MeshInstance3D:
	return _magazines[slot] if slot >= 0 and slot < _magazines.size() else null


## The replica in slot `slot` as drawn, or null.
func replica(slot: int) -> MeshInstance3D:
	return _replicas[slot] if slot >= 0 and slot < _replicas.size() else null


## Slot `slot`'s site class (&"" for none).
func site_class(slot: int) -> StringName:
	return _classes[slot] if slot >= 0 and slot < _classes.size() else &""


## How far the hand holding replica `slot` reaches along it to its grip (TP3), in the grip bone's frame.
func grip_fit(slot: int) -> Vector3:
	return _fits[slot] if slot >= 0 and slot < _fits.size() else Vector3.ZERO


## Whether both hands reach with it (a pistol's two-handed grip).
func grip_fit_both(slot: int) -> bool:
	return slot >= 0 and slot < _fits_both.size() and _fits_both[slot] != 0


## How replica `slot` is held as the first-person arms hold it (HG1), or null when they don't.
func held(slot: int) -> FigureHeld:
	return _held[slot] if slot >= 0 and slot < _held.size() else null


## Bone `bone`'s frame in bone `frame`'s, at rest, unscaled (identity when either is missing).
func _rest_in(bone: String, frame: String) -> Transform3D:
	var b := _skeleton.find_bone(bone)
	var f := _skeleton.find_bone(frame)
	if b < 0 or f < 0:
		return Transform3D.IDENTITY
	var of := _skeleton.get_bone_global_rest(f)
	var at := _skeleton.get_bone_global_rest(b)
	return Transform3D(of.basis.orthonormalized(), of.origin).affine_inverse() \
			* Transform3D(at.basis.orthonormalized(), at.origin)


## Replica `slot`'s butt in the grip bone's frame (the origin when it has none).
func butt_on_grip(slot: int) -> Vector3:
	return _butts[slot] if slot >= 0 and slot < _butts.size() else Vector3.ZERO


## The middle of `replica`'s last `depth` m towards its butt (+Z), in its own frame (the origin with no replica).
static func _butt(replica: MeshInstance3D, depth: float) -> Vector3:
	if replica == null or replica.mesh == null:
		return Vector3.ZERO
	var end := replica.get_aabb().end.z
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v: Vector3 in replica.mesh.get_faces():
		if v.z >= end - depth:
			lo = lo.min(v)
			hi = hi.max(v)
	return (lo + hi) * 0.5 if lo.x <= hi.x else Vector3(0.0, 0.0, end)


## The point of replica `slot` the grip holds, in the replica's own frame.
func grip_point(slot: int) -> Vector3:
	return _grip_points[slot] if slot >= 0 and slot < _grip_points.size() else Vector3.ZERO


## Moves the replicas shown onto `skeleton`'s bones as posed now.
func place(skeleton: Skeleton3D) -> void:
	var held := replica(in_hand)
	if held != null and _grip_bone >= 0:
		var grip := skeleton.get_bone_global_pose(_grip_bone)
		if hanging:
			held.transform = Transform3D(_hang, grip.origin - _hang * _grip_points[in_hand])
		else:
			var on := _on_grip[in_hand]
			var slot_held := _held[in_hand] if in_hand < _held.size() else null
			if grasp > 0.0 and slot_held != null:
				on = slot_held.held_on_grip if grasp >= 1.0 else on.interpolate_with(slot_held.held_on_grip, grasp)
			held.transform = grip * on
	if _bomb != null and _bomb.visible and _grip_bone >= 0:
		_bomb.transform = skeleton.get_bone_global_pose(_grip_bone) * _bomb_on_grip
	var carried := replica(on_back)
	if carried != null and _chest_bone >= 0:
		carried.transform = skeleton.get_bone_global_pose(_chest_bone) * _on_chest[on_back]
	var stowed := replica(in_holster)
	if stowed != null:
		# Carried as the holster's skin is, mostly by the hips with a share of the thigh's swing.
		var by_hips := skeleton.get_bone_global_pose(_holster_bone) * _in_holster[in_holster]
		var by_thigh := skeleton.get_bone_global_pose(_follow_bone) * _in_holster_follow[in_holster]
		stowed.transform = by_hips.interpolate_with(by_thigh, _config.holster_follow)
	var r := _reloads[mag_slot] if mag_slot >= 0 and mag_slot < _reloads.size() else null
	if r == null or r.bone < 0:
		_throw_due = false
		return
	var hand := skeleton.get_bone_global_pose(r.bone)
	if mag_shown != MAG_NONE:
		magazine(mag_slot).transform = hand * (r.new_on if mag_shown == MAG_NEW else r.old_on)
	if _throw_due:
		_throw_due = false
		if thrown != null:
			# Let go where the hand holds it, in the world: the throw's figure-space numbers turned with the figure,
			# plus the figure's own velocity; it lands at the feet.
			var to_world := global_transform
			var turn := to_world.basis.orthonormalized()
			thrown.throw(magazine(mag_slot), to_world * (hand * r.old_on), turn * r.velocity + velocity, turn * r.spin,
					feet.y, r.gravity, r.lifetime)


func _set_magazine(slot: int, shown: int) -> void:
	if slot == mag_slot and shown == mag_shown:
		return
	var was := magazine(mag_slot)
	if was != null:
		was.visible = false
	mag_slot = slot
	mag_shown = shown
	var now := magazine(slot)
	if now != null:
		now.visible = shown != MAG_NONE


func _set_empty_well(slot: int) -> void:
	if slot == _empty_well:
		return
	var was := _wells[_empty_well] if _empty_well >= 0 and _empty_well < _wells.size() else null
	if was != null:
		was.visible = true
	_empty_well = slot
	var now := _wells[slot] if slot >= 0 and slot < _wells.size() else null
	if now != null:
		now.visible = false


## The piece of `replica` that `copy` (the hand's magazine) is made from: the magazine in its well, or null.
static func _well(replica: MeshInstance3D, copy: MeshInstance3D) -> MeshInstance3D:
	if replica == null or copy == null:
		return null
	for c: Node in replica.get_children():
		var m := c as MeshInstance3D
		if m != null and m.mesh == copy.mesh:
			return m
	return null


## Class `site_class`'s reload from the sidecar (its class's clip), or null when the sidecar has none.
func _reload(site_class: StringName) -> Reload:
	var clip := _config.pistol_reload_clip if site_class == &"pistol" else _config.rifle_reload_clip
	var side := _models.sidecar(_kind)
	var m: FigureSidecar.Magazine = side.magazine_in_hand.get(clip) if side != null else null
	if m == null:
		return null
	var r := Reload.new()
	r.bone = _skeleton.find_bone(m.bone)
	r.new_on = FigureModels.grip_from_blender(m.on_bone)
	r.new_from = m.from
	r.new_to = m.to
	if m.old != null:
		r.throws = true
		r.old_on = FigureModels.grip_from_blender(m.old.on_bone)
		r.old_from = m.old.from
		r.release = m.old.release
		r.velocity = FigureModels.godot_from_blender(m.old.velocity)
		r.spin = FigureModels.godot_from_blender(m.old.spin)
		r.gravity = m.old.gravity
		r.lifetime = m.old.lifetime
	return r


func _set_shown(slot: int, shown: bool) -> void:
	var r := replica(slot)
	if r != null:
		r.visible = shown


func _on_skeleton_updated() -> void:
	place(_skeleton)


## `hand` turned `angle` (rad) round the grip its fingers close on (`joints`, FigureArmsHold's, the thumb's first):
## about the knuckle line (the first finger's root to the last's) through the middle of the fingers' joints, so the hand
## slides round the grip and its thumb's root comes round the back strap toward the grip's left side.
static func _wrapped(hand: Transform3D, joints: PackedVector3Array, angle: float) -> Transform3D:
	var bones := FigureGrasp.BONES
	if absf(angle) < FigureGrasp.EPSILON or joints.size() < bones * 3:
		return hand
	var middle := Vector3.ZERO
	for i in range(bones, joints.size()):
		middle += joints[i]
	middle /= float(joints.size() - bones)
	var axis := (joints[joints.size() - bones] - joints[bones]).normalized()
	var turn := Transform3D(Basis(axis, angle), Vector3.ZERO)
	var about := Transform3D(Basis.IDENTITY, middle)
	return about * turn * about.affine_inverse() * hand
