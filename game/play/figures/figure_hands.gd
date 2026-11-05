class_name FigureHands
extends Node3D
## The replicas on a rigged figure (step 23, FI3): the figure's replicas (FigureView's figure versions, painted and with
## their parts) placed each time the skeleton is posed, after FigureBend, so they follow the drawn bones. The one in the
## hand sits on the grip bone by the sidecar's replicaOnGrip for its class (FigureModels.grip); out of the hand, the
## rifle rides on the carrier's back (FigureModels.on_back, its middle there) and the pistol sits in the belt holster
## (FigureModels.holster; none on a kind without one); calling the hit, the one in the hand hangs from the grip, its
## long axis FigureConfig.hang_tilt off straight down with the muzzle forward. In a reload (FI4) a copy of the replica
## model's magazine rides on the sidecar's bone (Hand_L): the old one pulled out from oldMagazine.from, thrown at its
## release into ThrownMagazines, then the new one from `from` to `to`; one copy a slot, so the hand never holds two. A
## child of the skeleton, so everything here is in the skeleton's frame (the file's, facing +Z). Presentation only:
## FigureBody says what shows.

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
var _reloads: Array[Reload] = []
var mag_slot: int = -1
var mag_shown: int = MAG_NONE
var _last_share: float = 0.0
var _throw_due: bool = false
## Where thrown magazines go (null: none thrown), and the figure's feet and velocity (the world's) for a throw.
var thrown: ThrownMagazines = null
var feet: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO


## Places replicas on `skeleton`'s bones as kind `kind` of `models` says, by `config`.
func setup(skeleton: Skeleton3D, models: FigureModels, kind: int, config: FigureConfig) -> void:
	name = "Hands"
	_skeleton = skeleton
	_models = models
	_kind = kind
	_config = config
	_grip_bone = skeleton.find_bone(config.grip_bone)
	_chest_bone = skeleton.find_bone(config.chest_bone)
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
## each one's places worked out once here.
func hold(replicas: Array[MeshInstance3D], classes: Array[StringName],
		magazines: Array[MeshInstance3D] = []) -> void:
	_replicas = replicas
	_magazines = magazines
	_reloads.clear()
	for i in replicas.size():
		var site_class := classes[i] if i < classes.size() else &"rifle"
		_reloads.append(_reload(site_class))
		var m := magazine(i)
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
	var back := _models.on_back(_kind)
	var holster := _models.holster(_kind)
	var follow := _models.holster_follow(_kind)
	for i in replicas.size():
		var r := replicas[i]
		var grip := _models.grip(_kind, classes[i] if i < classes.size() else &"rifle")
		_on_grip.append(grip)
		_grip_points.append(grip.affine_inverse().origin)
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
		var rifle := r != null and (classes[i] if i < classes.size() else &"rifle") != &"pistol"
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
## figure.
func release(to: Node3D) -> void:
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


## The copy of slot `slot`'s magazine, or null.
func magazine(slot: int) -> MeshInstance3D:
	return _magazines[slot] if slot >= 0 and slot < _magazines.size() else null


## The replica in slot `slot` as drawn, or null.
func replica(slot: int) -> MeshInstance3D:
	return _replicas[slot] if slot >= 0 and slot < _replicas.size() else null


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
			held.transform = grip * _on_grip[in_hand]
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
