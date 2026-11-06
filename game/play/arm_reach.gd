class_name ArmReach
extends RefCounted
## Two-bone IK for an arm (GT1, GT3): the upper arm, forearm and hand of a skeleton reaching for a wrist's place, the
## elbow bent towards a pole. FigureThrow (a figure's throw) and ArmsThrow (your arms' throw in first person) share it.
## Presentation only; allocation-free.

## Below this (m) a length counts as none.
const EPSILON := 0.0001


## The arm `upper`, `fore`, `hand` (bones of `skeleton`) reaching `w` of the way from its pose to its wrist at `target`
## (the skeleton's frame) by two-bone IK, its elbow towards `pole` as far. The upper arm points at the elbow turned
## the shortest way from its pose; `rest_roll` of the way (0..1) from its rest pose carried by `frame` instead: from a
## figure's hanging arm, the shortest way up over the shoulder rolls the arm about itself and drags the side of the
## chest with it. The forearm then points the wrist at its place, and the hand turns as the forearm turned.
static func reach(skeleton: Skeleton3D, upper: int, fore: int, hand: int, target: Vector3, pole: Vector3, w: float,
		frame: Basis, rest_roll: float) -> void:
	var upper_pose := skeleton.get_bone_global_pose(upper)
	var shoulder := upper_pose.origin
	var was_fore := skeleton.get_bone_global_pose(fore)
	var was_hand := skeleton.get_bone_global_pose(hand)
	var to_reach := was_hand.origin.lerp(target, w)
	var a := shoulder.distance_to(was_fore.origin)
	var b := was_fore.origin.distance_to(was_hand.origin)
	var to := to_reach - shoulder
	if to.length() < EPSILON or a < EPSILON or b < EPSILON:
		return
	var way := to.normalized()
	var d := clampf(to.length(), absf(a - b) + EPSILON, a + b - EPSILON)
	var side := was_fore.origin - shoulder
	side -= way * way.dot(side)
	var bend := pole - way * way.dot(pole)
	if side.length() > EPSILON and bend.length() > EPSILON:
		side = side.normalized().lerp(bend.normalized(), w)
	elif bend.length() > EPSILON:
		side = bend
	side = side.normalized() if side.length() > EPSILON else Vector3.DOWN
	var along := (a * a + d * d - b * b) / (2.0 * d)
	var elbow := shoulder + way * along + side * sqrt(maxf(a * a - along * along, 0.0))
	var aim := (elbow - shoulder).normalized()
	var turned := Basis(Quaternion((was_fore.origin - shoulder).normalized(), aim)) * upper_pose.basis
	if rest_roll > 0.0:
		var rest := skeleton.get_bone_global_rest(upper)
		var rest_way := frame * (skeleton.get_bone_global_rest(fore).origin - rest.origin).normalized()
		var from_rest := Basis(Quaternion(rest_way, aim)) * frame * rest.basis
		# Both point the upper arm at the elbow; between them only its roll about itself differs.
		turned = turned.slerp(from_rest, rest_roll)
	skeleton.set_bone_global_pose(upper, Transform3D(turned, shoulder))
	var fore_pose := skeleton.get_bone_global_pose(fore)
	var wrist := skeleton.get_bone_global_pose(hand).origin
	var forearm := Basis(Quaternion((wrist - fore_pose.origin).normalized(), (to_reach - fore_pose.origin).normalized()))
	skeleton.set_bone_global_pose(fore, Transform3D(forearm * fore_pose.basis, fore_pose.origin))
	var turn := (skeleton.get_bone_global_pose(fore).basis * was_fore.basis.inverse()).orthonormalized()
	skeleton.set_bone_global_pose(hand, Transform3D(turn * was_hand.basis, to_reach))
