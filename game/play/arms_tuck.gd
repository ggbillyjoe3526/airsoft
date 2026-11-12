class_name ArmsTuck
extends RefCounted
## Your left arm drawn in under the replica as the sight comes up (HA1, the owner: "the hands should not fade out of
## view. When the animation plays to ADS ... the hands are simply out of view"). At the hip the arm reaches across to
## the handguard from your left; aimed, your shoulder is behind the replica and your elbow under it, so the forearm
## lies behind the replica as the eye sees it. The shoulder moves, the elbow is found again below the line from it to
## the wrist (two bones of fixed length), and the hand is turned back, so it holds as it held. On a replica narrower
## than the hand (the Sniper Rifle's fore-end, the Compact SMG's) the hand slides back along it toward the receiver
## too, which hides it where the fore-end can't. ArmsView draws it over the pose its clip gave, each frame the sight
## is raised at all.

const UPPER := "UpperArm_L"
const FORE := "Forearm_L"
const HAND := "Hand_L"
## Lengths under this (m) leave nothing to turn.
const NO_LINE := 1e-4
## The arm is never drawn out quite straight (the share of its length it may span).
const REACH_MOST := 0.999

var _upper: int = -1
var _fore: int = -1
var _hand: int = -1


func _init(skeleton: Skeleton3D) -> void:
	_upper = skeleton.find_bone(UPPER)
	_fore = skeleton.find_bone(FORE)
	_hand = skeleton.find_bone(HAND)


## False for a skeleton without the left arm's bones: nothing moves.
func fits() -> bool:
	return _upper >= 0 and _fore >= 0 and _hand >= 0


## Puts the shoulder back where the skeleton rests it, for a clip that doesn't key it: call before the clip poses the
## skeleton again.
func clear(skeleton: Skeleton3D) -> void:
	if fits():
		skeleton.set_bone_pose_position(_upper, skeleton.get_bone_rest(_upper).origin)


## Draws the arm of `skeleton`, posed by its clip, in: the shoulder moved by `shift`, the hand by `slide` (turned as
## the clip turned it) and the elbow turned `share` (0..1) of the way from where the clip has it to straight along
## `down` (all in the skeleton's space).
func draw_in(skeleton: Skeleton3D, shift: Vector3, slide: Vector3, down: Vector3, share: float) -> void:
	if not fits():
		return
	skeleton.force_update_all_bone_transforms()
	var upper := skeleton.get_bone_global_pose(_upper)
	var fore := skeleton.get_bone_global_pose(_fore)
	var hand := skeleton.get_bone_global_pose(_hand)
	var first := upper.origin.distance_to(fore.origin)
	var second := fore.origin.distance_to(hand.origin)
	var shoulder := upper.origin + shift
	var reach := hand.origin + slide - shoulder
	var span := minf(reach.length(), (first + second) * REACH_MOST)
	if first < NO_LINE or second < NO_LINE or span < NO_LINE:
		return
	var line := reach.normalized()
	# The elbow stands off the line toward `pole`: where the clip had it, turned toward straight down.
	var pole := (fore.origin - upper.origin).slerp(down * first, share)
	pole -= line * pole.dot(line)
	if pole.length() < NO_LINE:
		return
	var along := (first * first + span * span - second * second) / (2.0 * span)
	var off := sqrt(maxf(first * first - along * along, 0.0))
	var elbow := shoulder + line * along + pole.normalized() * off
	var upper_turn := Basis(Quaternion(fore.origin - upper.origin, elbow - shoulder))
	skeleton.set_bone_global_pose(_upper, Transform3D(upper_turn * upper.basis, shoulder))
	skeleton.force_update_bone_child_transform(_upper)
	# The wrist ends the forearm, however far the hand was asked to go.
	var wrist := shoulder + line * span
	var fore_turn := Basis(Quaternion(hand.origin - fore.origin, wrist - elbow))
	skeleton.set_bone_global_pose(_fore, Transform3D(fore_turn * fore.basis, elbow))
	skeleton.force_update_bone_child_transform(_fore)
	skeleton.set_bone_global_pose(_hand, Transform3D(hand.basis, wrist))
	skeleton.force_update_bone_child_transform(_hand)
