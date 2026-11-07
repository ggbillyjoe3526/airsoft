class_name ViewModelConfig
extends Resource
## The replica in your hands (the browser game's config/renderView.ts VIEWMODEL, tuned by play there). Metres in the
## camera's space (x right, y up, -z forward), seconds, radians. Read by ReplicaView.

## Where each replica's origin (above the trigger) sits at the hip, by replica id; others use `hip_default`. The
## pistols sit nearer the middle and higher, their hand and wrist in view but not the forearm (owner, 2026-11-06); the
## arms model (tools/blender/arms/arms.py HOLDS) is built for these places.
@export var hip: Dictionary[StringName, Vector3] = {
	&"aeg": Vector3(0.12, -0.19, -0.26),
	&"pistol": Vector3(0.05, -0.07, -0.34),
	&"cyber": Vector3(0.05, -0.07, -0.34),
	&"sniper": Vector3(0.12, -0.19, -0.26),
}
@export var hip_default: Vector3 = Vector3(0.13, -0.16, -0.32)
## Aimed, the sight line (rear to front sight) runs through the eye; the replica sits this far forward of it (the
## pistols near enough that the forearm drops out of view under the hand).
@export var aim_forward: Dictionary[StringName, float] = {&"aeg": -0.2, &"pistol": -0.25, &"cyber": -0.25,
		&"sniper": -0.2}
@export var aim_forward_default: float = -0.25
## Looking through an optic, by its part Key (ReplicaView, OpticGlass): its glass's centre (z in the part's own space,
## -z forward, on the sight line) and radius (m), measured from the part models; how far behind the glass the eye sits
## aimed (m, so the glass shows as the approved sight concepts do); and the mark on the glass (dot: a lit red dot;
## cross: a scope's reticle). An optic not listed is aimed along its sight line with no glass drawn.
@export var optic_glass_z: Dictionary[StringName, float] = {&"redDot": -0.013, &"scope2x": 0.0286,
		&"scopeVar": 0.0581}
@export var optic_glass_radius: Dictionary[StringName, float] = {&"redDot": 0.0075, &"scope2x": 0.015,
		&"scopeVar": 0.011}
@export var optic_eye_back: Dictionary[StringName, float] = {&"redDot": 0.15, &"scope2x": 0.1728, &"scopeVar": 0.1555}
@export var optic_mark: Dictionary[StringName, StringName] = {&"redDot": &"dot", &"scope2x": &"cross", &"scopeVar": &"cross"}
## The view through the glass is drawn this much wider than the glass shows on screen (room for sway), into a square
## picture this share of the screen's height on a side.
@export var glass_margin: float = 1.15
@export var glass_share: float = 0.25
## How far the replica lags behind a turn (m per rad of turn), at most sway_max, springing back at return_rate (1/s).
@export var sway_per_radian: float = 0.05
@export var sway_max: float = 0.035
@export var return_rate: float = 14.0
## Each shot's kick: back and up (m), never more than kick_max shots' worth. A lift, not a tilt, so the barrel stays in
## line with the BBs leaving it.
@export var kick_back: float = 0.028
@export var kick_lift: float = 0.012
@export var kick_max: float = 1.5
## With the sight raised, the share of sway and kick left.
@export var aim_steady: float = 0.25
## Drawing drops it this far and brings it back up; sprinting carries it this far down and this tilted (rad).
@export var draw_drop: float = 0.22
@export var sprint_drop: float = 0.06
@export var sprint_tilt: float = 0.5
## Seconds to move into and out of the sprint carry.
@export var carry_time: float = 0.2
## Firing on the run (each shot) brings it up out of the carry, square to the view, in
## sprint_fire_raise seconds, and it stays up sprint_fire_hold seconds after the last shot before the carry takes it
## again (the browser game's renderView.ts sprintFireRaise and sprintFireHold; the owner's 0.1 Dev 1 note 5).
@export var sprint_fire_raise: float = 0.06
@export var sprint_fire_hold: float = 0.35
## The holster (the browser game's renderView.ts holster): put away it drops this far (out of view) and tips this much
## (rad) over holster_time seconds; drawn from the holster it rises from there over the whole draw.
@export var holster_drop: float = 0.5
@export var holster_tilt: float = 0.9
@export var holster_time: float = 0.2
## Your own hit (FI5; the browser game's renderView.ts hitJolt and hitDrop): the replica jolts `hit_jolt` shots' kicks
## and drops `hit_drop` (m) out of view over `hit_drop_time` seconds, then hides. Reduced motion leaves both as they are:
## neither moves the camera.
@export var hit_jolt: float = 1.5
@export var hit_drop: float = 0.5
@export var hit_drop_time: float = 0.25
## A reload lifts and cants it (rad at the middle of the reload: muzzle up, roll, turn) and brings it inwards.
@export var reload_tilt: float = 0.3
@export var reload_roll: float = -0.55
@export var reload_turn: float = 0.35
@export var reload_lift: float = 0.14
@export var reload_inward: float = 0.1
## Working a bolt at the hip (BP7, row 17): while the arms' bolt clip runs, the replica is canted toward the eye
## so the right hand stays on screen (rad at the clip's middle: muzzle up, roll, turn; m: lift, inward), eased in and out
## over the clip as a bell and drawn less as the sight comes up (none aimed); Reduced motion draws its reload_cant share.
@export var bolt_tilt: float = 0.0
@export var bolt_roll: float = 0.3
@export var bolt_turn: float = 0.0
@export var bolt_lift: float = 0.0
@export var bolt_inward: float = 0.035
## A bolt-action replica's Fire clip has its bolt home and turned down this far in (s: sniper.py's keys); a shot plays
## the clip stretched so that moment lands as the replica can fire again (its fire rate with its parts: the Sniper
## Rifle's 1.25 s, 1.39 s with the M150), and the arms' bolt clip with it (BP7, row 19).
@export var bolt_cycle_end: float = 0.88
## A gas pistol's slide locks back this long (s) into its last shot's Fire clip, when the slide is fully back, and closes
## this far (share) through the reload that follows.
@export var slide_lock_after: float = 0.05
@export var slide_release_at: float = 0.85
## Near a wall the replica is pulled back towards you: it is this long (m) from the eye.
@export var reach: float = 0.75
@export var pull_back_max: float = 0.3
## Whatever the pull-back leaves in a wall is drawn over it, never into it (the owner's 0.1 Dev 1 note 7): the replica's
## materials and its optic's glass press its depth towards the eye to this share (Godot's z clip scale, the same on
## both renderers; light and shadows unchanged, no extra pass). 1 draws it at its true depth.
@export var depth_scale: float = 0.25
## Where the selector sits along its clip in each fire mode (semi, burst, auto), as a share of the clip.
@export var selector_at: PackedFloat32Array = PackedFloat32Array([0.5, 0.75, 1.0])
## Your arms (ArmsView): replicas held in the right hand alone, the left arm hidden (a pistol, as the owner's default
## of 2026-11-05: two-handed pistol holds clipped or bent the wrist; a smoke or flash bomb in hand, GT1), and a robot's
## arms' colours (sRGB) by the arms model's material name, with their roughness (satin, as the robot figure's plates).
@export var one_hand: Array[StringName] = [&"pistol", &"cyber", &"smoke", &"flash"]
## A bomb taken in hand comes up into view with your hand from this far below (m) over this long (s), eased as a draw,
## while the replica goes down (holster_time); the empty hand goes back down the same way once the bomb has left it.
@export var bomb_raise_drop: float = 0.3
@export var bomb_raise_time: float = 0.2
## A throw cut off in its windup (a hit, the round's end, other eyes) eases your arms back from where they were to its
## start (the right hand on the hold, the left down out of view) over this long (s), easing out, while the hand goes
## down; at most bomb_raise_time, or the hand is gone before the arms are back.
@export var bomb_unwind_time: float = 0.15
@export var robot_arms: Dictionary[StringName, Color] = {
	&"Glove": Color(0.80, 0.81, 0.82),
	&"GloveArmour": Color(0.16, 0.17, 0.18),
	&"Sleeve": Color(0.62, 0.63, 0.65),
	&"SleeveTrim": Color(0.22, 0.23, 0.24),
}
@export var robot_arms_roughness: float = 0.45
## Your arms' throw (GT3, ArmsThrow), `share` running 0..1 over the windup (GrenadeConfig.windup) and 1..2 over the
## recovery. Each key is a wrist's place in the eyes' frame (m: x right, y up, -z ahead), each pole the way its elbow
## bends. The left hand comes up from bomb_left_in to the pin's ring (its wrist bomb_left_ring off it) by bomb_pin_grab,
## its fingers curling bomb_pin_curl (rad a joint) round it, then draws the pin out to bomb_left_pulled off the ring
## (the pin slipping to hang bomb_pin_hang from the fist) by bomb_pull_at and takes it away to bomb_left_away by
## bomb_pin_out, where it is hidden; its shoulder is drawn at bomb_left_shoulder meanwhile. From bomb_pin_grab the right
## hand goes out aside to bomb_aside (bomb_aside_at of the way) and up to bomb_cocked by bomb_cock (both at the view's
## right edge, so the bomb stays in sight), its wrist cocked back bomb_wrist_cocked (rad); then, quickening, over the
## top to bomb_over (bomb_over_at of the way on) and ahead to bomb_release at the release, the wrist snapping forward to
## bomb_wrist_release; then its fingers open bomb_let_go (rad a joint) off the bomb by bomb_let_go_by and it follows
## through down across to bomb_follow by bomb_follow_by, out of view. Its shoulder goes back bomb_shoulder_back as it
## cocks and forward bomb_shoulder_ahead at the release, as the body turns into the throw.
@export var bomb_pin_grab: float = 0.3
@export var bomb_pin_out: float = 0.6
@export var bomb_pull_at: float = 0.45
@export var bomb_pin_curl: float = 1.0
@export var bomb_left_shoulder: Vector3 = Vector3(-0.15, -0.16, 0.1)
@export var bomb_left_in: Vector3 = Vector3(-0.04, -0.4, -0.3)
@export var bomb_left_ring: Vector3 = Vector3(-0.085, -0.045, 0.07)
@export var bomb_left_palm: Vector3 = Vector3(0.0, -0.7, -0.7)
@export var bomb_pin_hang: Vector3 = Vector3(0.015, -0.035, 0.0)
@export var bomb_left_pulled: Vector3 = Vector3(-0.09, 0.01, 0.0)
@export var bomb_left_away: Vector3 = Vector3(-0.2, -0.42, -0.12)
@export var bomb_left_pole: Vector3 = Vector3(-1.0, -1.0, 0.3)
@export var bomb_cock: float = 0.72
@export var bomb_aside: Vector3 = Vector3(0.28, -0.06, -0.26)
@export var bomb_aside_at: float = 0.4
@export var bomb_cocked: Vector3 = Vector3(0.25, 0.11, -0.24)
@export var bomb_over: Vector3 = Vector3(0.2, 0.14, -0.28)
@export var bomb_over_at: float = 0.5
@export var bomb_release: Vector3 = Vector3(0.18, 0.02, -0.32)
@export var bomb_let_go: float = 0.5
@export var bomb_let_go_by: float = 1.15
@export var bomb_follow_by: float = 1.4
@export var bomb_wrist_cocked: float = -0.4
@export var bomb_wrist_release: float = 0.5
@export var bomb_follow: Vector3 = Vector3(-0.12, -0.45, -0.3)
@export var bomb_right_pole: Vector3 = Vector3(1.0, -1.0, 0.3)
@export var bomb_over_pole: Vector3 = Vector3(0.5, -1.0, -0.4)
@export var bomb_shoulder_back: Vector3 = Vector3(0.0, 0.0, 0.04)
@export var bomb_shoulder_ahead: Vector3 = Vector3(-0.04, 0.03, -0.14)

## Inspecting the replica in hand (IN1, the Inspect key; the browser game's renderView.ts inspect, RM2): it is turned
## in the hands to show itself, by its replica id's pose (others take `inspect_pose_default`), while its model's Inspect
## clip works its parts (the AEG's charging handle, dust cover and hop dial, the gas pistol's slide, the Cyber Pistol's
## battery, the sniper's bolt). A shot, a hit, a reload, a draw, a switch, the holster, a sprint or raising the sight
## (past `inspect_aim_cancel` of the way) ends it: the pose eases back over `inspect_cancel_time` seconds and the parts
## are at rest at once.
@export var inspect_poses: Dictionary[StringName, InspectPose] = {
	# Side on, the right side to the eye: the charging handle back, the dust cover open on the hop dial, set a notch.
	&"aeg": InspectPose.make(3.0, PackedFloat32Array([0.0, 0.17, 0.5, 0.82, 1.0]), RIFLE_TURN, RIFLE_SHIFT,
			PackedFloat32Array([0.06, 0.13, 0.27, 0.36, 0.65, 0.83]),
			[&"selector", &"torchClick", &"selector", &"selector", &"dryFire", &"torchClick"]),
	# Side on, the top a little to the eye; nothing moves, the slide only ever back firing or locked empty (GS2).
	&"pistol": InspectPose.make(2.0, PackedFloat32Array([0.0, 0.22, 0.72, 1.0]),
			[Vector3.ZERO, Vector3(0.05, -0.95, 0.1), Vector3(0.08, -1.0, 0.2), Vector3.ZERO],
			PISTOL_SHIFT, PackedFloat32Array(), []),
	# Side on, the butt of the grip to the eye: the battery eased out of the grip and pushed home.
	&"cyber": InspectPose.make(2.0, PackedFloat32Array([0.0, 0.22, 0.72, 1.0]),
			[Vector3.ZERO, Vector3(-0.15, -0.95, 0.1), Vector3(-0.35, -1.0, 0.15), Vector3.ZERO],
			PISTOL_SHIFT, PackedFloat32Array([0.17, 0.75]), [&"torchClick", &"magIn"]),
	# Side on as the AEG, held further off (a longer rifle): the bolt lifted, drawn back, held and closed.
	&"sniper": InspectPose.make(3.0, PackedFloat32Array([0.0, 0.17, 0.5, 0.82, 1.0]), RIFLE_TURN, LONG_SHIFT,
			PackedFloat32Array([0.1, 0.28, 0.77, 0.83]), [&"selector", &"dryFire", &"dryFire", &"selector"]),
}
@export var inspect_pose_default: InspectPose = InspectPose.make(2.0, PackedFloat32Array([0.0, 0.17, 0.5, 0.82, 1.0]),
		RIFLE_TURN, RIFLE_SHIFT, PackedFloat32Array(), [])
@export var inspect_cancel_time: float = 0.15
@export var inspect_aim_cancel: float = 0.05

## The rifles' inspect keys (the browser game's rifle pose): turns, and shifts inwards, up and forward.
const RIFLE_TURN: Array[Vector3] = [Vector3.ZERO, Vector3(0.08, -1.15, 0.12), Vector3(0.12, -1.2, 0.18),
		Vector3(0.06, -1.1, 0.1), Vector3.ZERO]
const RIFLE_SHIFT: Array[Vector3] = [Vector3.ZERO, Vector3(-0.2, 0.07, -0.18), Vector3(-0.21, 0.08, -0.18),
		Vector3(-0.19, 0.07, -0.17), Vector3.ZERO]
## The sniper rifle's inspect shifts: the rifles' further out, so its long stock stays in view.
const LONG_SHIFT: Array[Vector3] = [Vector3.ZERO, Vector3(-0.22, 0.08, -0.3), Vector3(-0.23, 0.09, -0.3),
		Vector3(-0.21, 0.08, -0.29), Vector3.ZERO]
## The pistols' inspect shifts (the browser game's pistol and Cyber poses, to the same place from their higher, more
## central hip).
const PISTOL_SHIFT: Array[Vector3] = [Vector3.ZERO, Vector3(-0.06, 0.0, -0.04), Vector3(-0.065, 0.005, -0.04),
		Vector3.ZERO]
