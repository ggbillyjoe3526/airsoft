class_name FigureBend
extends SkeletonModifier3D
## What a figure's clips can't do (step 23, FI2), applied after its AnimationTree each time the skeleton updates: a
## crouched figure lowered so its head's top stays under the line from the standing hit top to
## FigureConfig.crouch_top_max (1.15 m fully crouched: crouch cover is 1.2 m, DECISIONS 2026-09-30), then Hips' upper
## chain (Spine and all above it) tilted about the hip pivot by lean × lean_max_angle: the one lean geometry the hit
## volume and the eye use (Hitbox, Lean), and the hit flinch (FI5) on top. Before the lean, the upper chain is turned
## back to standing still's heading over the stepping hips (GA1, `steady`). The skeleton's frame is the file's (facing
## +Z), so a lean right, to the figure's right (-X there), is a positive roll about +Z. Presentation only: FigureView
## sets `lean`, `crouch` and `flinch`.
## Then (FI3, `aim`) the upper chain pitched about the spine's own joint by `aim_lean`: what the aim clips leave of the
## pitch (they turn the replica FigureConfig.aim_reach of it), so the replica points where the shot goes.
## Then (TP3, `grip_fit`) the right fist reaches along the replica to its grip (both hands, for a pistol); then (TP2,
## `shouldered`) a rifle's butt drawn into the shoulder pocket, its aim kept; then, at a wall (FB5,
## `high_ready`), the arms bring the replica to the high ready, muzzle up (FigureReady). Aiming a rifle (`cheek`), the
## head bows and tilts about the neck onto the stock, as the hit volume's does (HitPose, HitFit.cheek_turn). Last, a
## bomb thrown or held in hand (GT1, `throw_share`, `throw_held`): the arms throw it (FigureThrow).

## How much the upper body's own clips show (0..1, FigurePose.upper_weight): the upper chain is turned back to standing
## still's heading over the stepping hips by that much of HitConfig.upper_steady (GA1, as HitPose does).
var steady: float = 0.0
## Leaning (-1 left .. 1 right) and crouched (0..1), as drawn this frame.
var lean: float = 0.0
var crouch: float = 0.0
## The hit flinch drawn this frame (FI5): the way the upper chain's top goes, its length the angle (rad; the skeleton's
## frame, flat), tipped about the same pivot after the lean.
var flinch: Vector3 = Vector3.ZERO
## The hit volume's numbers (pivot, crouch drop, lean angle, standing top), set by FigureBody before each frame.
var hits: HitConfig = null
## The aim's pitch (rad, up positive) the spine leans beyond what the aim clips turn the replica.
var aim_lean: float = 0.0
## How far (0..1) the arms bring the replica to the high ready at a wall.
var high_ready: float = 0.0
## How far (0..1) the rifle in the hand is drawn into the shoulder, and its butt in the grip bone's frame (TP2).
var shouldered: float = 0.0
var butt_on_grip: Vector3 = Vector3.ZERO
## How far (0..1) the head is bowed onto a rifle's stock (TP2).
var cheek: float = 0.0
## How far the hand reaches along the replica to its grip (TP3; the grip bone's frame), and whether both hands do.
var grip_fit: Vector3 = Vector3.ZERO
var grip_fit_both: bool = false
## A bomb's throw: its share (0..1 the windup, 1..2 the recovery; below 0 none), a bomb held in hand (MC1), and a
## throw begun from one.
var throw_share: float = -1.0
var throw_held: bool = false
var throw_from_hand: bool = false
var _config: FigureConfig = null
## The files' turn from the figures' frame (FigureConfig.model_yaw): a heading here plus it is HitFit's.
var _model_yaw: float = 0.0
var _hips: int = -1
var _spine: int = -1
var _head: int = -1
var _ready: FigureReady = null
## FigureConfig.cheek_bones: the neck, the left and the right shoulder (-1 when missing).
var _cheek: PackedInt32Array = PackedInt32Array()
var _throw: FigureThrow = null


## Bends `skeleton`'s bones by `config`'s crouch line and the hit volume's lean geometry (`hits`).
func setup(skeleton: Skeleton3D, config: FigureConfig) -> void:
	name = "Bend"
	_config = config
	_model_yaw = config.model_yaw
	_hips = skeleton.find_bone(config.hips_bone)
	_spine = skeleton.find_bone(config.lean_bone)
	_head = skeleton.find_bone(config.head_bone)
	_ready = FigureReady.new(skeleton, config)
	_cheek.clear()
	for bone_name in config.cheek_bones:
		_cheek.append(skeleton.find_bone(bone_name))
	_throw = FigureThrow.new(skeleton, config)


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton != null:
		bend(skeleton)
		aim(skeleton)
		bow(skeleton)
		if _ready != null:
			_ready.fit_grip(skeleton, grip_fit, grip_fit_both)
			_ready.shoulder(skeleton, shouldered, butt_on_grip)
			_ready.hold(skeleton, high_ready)
		if _throw != null and (throw_share >= 0.0 or throw_held):
			_throw.pose(skeleton, throw_share, throw_held, throw_from_hand)


## Lowers and leans `skeleton` from the pose its clips gave it.
func bend(skeleton: Skeleton3D) -> void:
	if _hips < 0 or _spine < 0 or _head < 0 or hits == null:
		return
	var drop := maxf(0.0, head_top(skeleton) - top_limit())
	if drop > 0.0:
		var hips := skeleton.get_bone_global_pose(_hips)
		hips.origin.y -= drop
		skeleton.set_bone_global_pose(_hips, hips)
	steady_upper(skeleton)
	var roll := lean * hits.lean_max_angle
	if roll == 0.0 and flinch == Vector3.ZERO:
		return
	var pivot := Vector3(0.0, hits.pivot_height - hits.crouch_drop * crouch, 0.0)
	var turn := FigureFlinch.turn(flinch) * Basis(Vector3.BACK, roll)
	var about := Transform3D(turn, pivot - turn * pivot)
	skeleton.set_bone_global_pose(_spine, about * skeleton.get_bone_global_pose(_spine))


## Turns the upper chain (Spine and all above it) about the hips' joint, about +Y, back to standing still's heading
## (HitFit.still_heading at this crouch) by `steady` of HitConfig.upper_steady: the pelvis swings and turns into a step
## aside under it while the replica keeps its heading. HitPose turns the hit volume's upper body alike.
func steady_upper(skeleton: Skeleton3D) -> void:
	if steady <= 0.0 or hits.fit == null or hits.upper_steady == 0.0:
		return
	var hips := skeleton.get_bone_global_pose(_hips)
	var turn := HitFit.steady_turn(hits.fit.still_heading(crouch) - _model_yaw, hips.basis.x)
	turn *= hits.upper_steady * steady
	if turn == 0.0:
		return
	var basis := Basis(Vector3.UP, turn)
	var about := Transform3D(basis, hips.origin - basis * hips.origin)
	skeleton.set_bone_global_pose(_spine, about * skeleton.get_bone_global_pose(_spine))


## The drawn head's top (m above the feet): FigureConfig.head_top along the Head bone.
func head_top(skeleton: Skeleton3D) -> float:
	return (skeleton.get_bone_global_pose(_head) * Vector3(0.0, _config.head_top, 0.0)).y


## The highest the head's top is drawn at this crouch (m): the standing hit top to crouch_top_max, crouched fully.
func top_limit() -> float:
	return lerpf(Hitbox.hit_top(0.0, hits), _config.crouch_top_max, crouch)


## Pitches `skeleton`'s upper chain (Spine and all above it) by `aim_lean` about the spine's joint, about the figure's
## sideways axis: up is a turn of +Z (ahead in the file) towards +Y, a negative turn about +X.
func aim(skeleton: Skeleton3D) -> void:
	if _spine < 0 or aim_lean == 0.0:
		return
	var spine := skeleton.get_bone_global_pose(_spine)
	var turn := Basis(Vector3.RIGHT, -aim_lean)
	skeleton.set_bone_global_pose(_spine, Transform3D(turn * spine.basis, spine.origin))


## Bows and tilts `skeleton`'s head `cheek` of the way onto a rifle's stock about the neck's joint (HitFit.cheek_turn).
func bow(skeleton: Skeleton3D) -> void:
	if cheek <= 0.0 or hits == null or _head < 0 or _cheek.size() != 3 or _cheek.has(-1):
		return
	var neck := skeleton.get_bone_global_pose(_cheek[0])
	var side := skeleton.get_bone_global_pose(_cheek[1]).origin - skeleton.get_bone_global_pose(_cheek[2]).origin
	var up := skeleton.get_bone_global_pose(_head).origin - neck.origin
	var turn := HitFit.cheek_turn(side, up, hits, cheek)
	skeleton.set_bone_global_pose(_cheek[0], Transform3D(turn * neck.basis, neck.origin))
