class_name FigureConfig
extends Resource
## The rigged figures as drawn (step 23; the browser game's config/figureRig.ts and config/look.ts): which files, which
## head a human wears, where the levels of detail change, the team paint and who is drawn as a robot. Read by
## FigureModels, FigureBody and FigureMix. Presentation only: none of it moves a hit, a sight line or a roll.

## Where the figures live: `<models_dir><kind>.glb` and its sidecar `<models_dir><kind>.json`, one pair a kind, in the
## kinds' order (FigureMix.HUMAN, FigureMix.ROBOT).
@export var models_dir: String = "res://assets/models/characters/"
@export var kinds: PackedStringArray = PackedStringArray(["human", "robot"])
## The human's heads in the browser game's order: figure `id` wears heads[id % heads.size()] (the owner's RM9 ruling).
## A kind with none of these (the robot) keeps the head it has.
@export var heads: PackedStringArray = PackedStringArray(["Head_HighCut", "Head_Cap", "Head_Boonie", "Head_FullCut"])
## A part's coarser levels are separate meshes named `<part><lod_suffix><level>` (Body_LOD1, Body_LOD2).
@export var lod_suffix: String = "_LOD"
## Distances (m) beyond which a figure draws its LOD1 and its LOD2 meshes: on Mesh detail High and Ultra, and on Low
## and Medium (Medium is Low since the browser's BD1), each line crossed only `lod_margin` past it so a figure standing
## on one doesn't flicker.
@export var lod_high: Vector2 = Vector2(12.0, 28.0)
@export var lod_low: Vector2 = Vector2(6.0, 16.0)
@export var lod_margin: float = 0.5
## The level the shadow twin is made from: one cheap shadow a figure at every range (BD1).
@export var shadow_level: int = 2
## Materials whose name starts with this (any case) are painted in the team's colour (Team, TeamColour, TeamPaint,
## TeamGlow); every other material stays as modelled.
@export var team_material_prefix: String = "team"
## Materials whose name starts with this (any case) are the face in the balaclava's eye opening (FA1): its looks (skin
## tone, brows and eyes) are painted side by side in the heads' atlas, and a figure wears look face_look(id), its
## material's UVs offset by face_offsets[look] (Godot's UV space, v down). Presentation only.
@export var face_material_prefix: String = "face"
@export var face_offsets: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.125, 0.0),
		Vector2(0.0, -0.0625), Vector2(0.125, -0.0625)])
## The files face +Z, the figures -Z: the model is turned this far about +Y (radians).
@export var model_yaw: float = PI
## The legs' clips (FI2): standing still, the gait clips by the way each steps (x to the figure's right, y ahead; placed
## at the pace the sidecar gives it: walk 2.3, run 4.2, sprint 6.3 m/s), crouched still and walking, the jump, the
## vault and the climb (CL1), the hit call and the walk-off; running up and down stairs (CL1), each in step with Run_F.
@export var idle_clip: StringName = &"Idle"
@export var gait_clips: PackedStringArray = PackedStringArray(["Walk_F", "Run_F", "Run_B", "Run_L", "Run_R", "Sprint"])
@export var gait_ways: PackedVector2Array = PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.0, 1.0),
		Vector2(0.0, -1.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0)])
@export var crouch_idle_clip: StringName = &"CrouchIdle"
@export var crouch_walk_clip: StringName = &"CrouchWalk"
@export var jump_clip: StringName = &"Jump"
@export var vault_clip: StringName = &"Vault"
@export var climb_clip: StringName = &"Climb"
@export var stairs_up_clip: StringName = &"Stairs_Up"
@export var stairs_down_clip: StringName = &"Stairs_Down"
@export var call_clip: StringName = &"HitCall"
@export var walk_off_clip: StringName = &"WalkOff"
## The leg whose swing keeps step with the hit volume's left leg: the line from `swing_hip` to `swing_ankle`, measured
## at `swing_samples` points of each stepping clip at load; the sample furthest forward meets Hitbox's forward peak.
@export var swing_hip: StringName = &"Thigh_L"
@export var swing_ankle: StringName = &"Foot_L"
@export var swing_samples: int = 60
## A crouched step goes backwards (the crouched walk, made walking ahead, played in reverse) when its backward part is
## more than `back_share` of its speed and the crouch more than `back_crouched` of the way down (the browser's
## FIGURE_RIG.backStep).
@export var back_share: float = 0.1
@export var back_crouched: float = 0.5
## The Jump clip's span (s) played over the time in the air: the take-off skipped, the landing the clip's.
@export var jump_from: float = 0.25
@export var jump_to: float = 0.55
## The Vault clip's share played over the rise onto the top; the rest across it (the browser's FIGURE_RIG.vault.top).
@export var vault_top: float = 0.4
## The Climb clip's share played over the rise onto the top (hands on the edge, a knee up); the rest stepping on and
## standing (tools/blender/bot-figure/gait/climb.py TOP).
@export var climb_top: float = 0.55
## How fast each blend settles (s to about two thirds of the way, 1 - 1/e): standing and moving, the step's way, the
## hit call and the walk-off, a jump, a vault (the browser's FIGURE_RIG.blend).
@export var settle_move: float = 0.12
@export var settle_direction: float = 0.1
@export var settle_mode: float = 0.12
@export var settle_jump: float = 0.06
@export var settle_vault: float = 0.03
## The head's top above the Head bone, along it (m), and the highest a fully crouched head's top is drawn (m; crouch
## cover is 1.2 m, DECISIONS 2026-09-30). Between standing and crouched the line runs from the standing hit top.
@export var head_top: float = 0.24
## The bones FigureBend moves: the pelvis it lowers, the first of the upper chain it leans, the head it measures.
@export var hips_bone: StringName = &"Hips"
@export var lean_bone: StringName = &"Spine"
@export var head_bone: StringName = &"Head"
@export var crouch_top_max: float = 1.15
## The hit flinch (FI5; the browser game's CHARACTERS.flinch): on a hit the upper body jolts the way the BB flew,
## `flinch_lean` radians about the hip pivot (FigureBend), in over `flinch_rise` seconds and
## eased back over `flinch_time`, while the hand goes up for the call.
@export var flinch_lean: float = 0.32
@export var flinch_rise: float = 0.05
@export var flinch_time: float = 0.4
## Beyond the far line (LOD2) a figure's legs are posed every `far_stride`-th frame with the time gathered (0: held
## still out there); a hidden figure's not at all.
@export var far_stride: int = 4
## The bones the figure code reads, each looked up by name (the two files order them differently).
@export var bones: PackedStringArray = PackedStringArray(["Hips", "Spine", "Chest", "Head", "Grip_R", "Hand_L"])
## The upper body (FI3; the browser's FIGURE_RIG): the bones the legs' clips drive. Every other bone is the upper body,
## which the aim, switch, holster and fire clips (upperBodyOnly, made over a still pelvis) take over from the legs.
@export var lower_bones: PackedStringArray = PackedStringArray(["Root", "Hips", "Thigh_L", "Shin_L", "Foot_L", "Toe_L",
		"Thigh_R", "Shin_R", "Foot_R", "Toe_R"])
## The aim clips, down, level and up, for the rifle and the pistol: AimUp and AimDown are posed at ±aim_pitch (rad) and
## turn the replica aim_reach of it (bot11.py clip_aim: the hands at pitch × 0.55); FigureBend's spine leans the rest.
@export var rifle_aim_clips: PackedStringArray = PackedStringArray(["Rifle_AimDown", "Rifle_Aim", "Rifle_AimUp"])
@export var pistol_aim_clips: PackedStringArray = PackedStringArray(["Pistol_AimDown", "Pistol_Aim", "Pistol_AimUp"])
@export var aim_pitch: float = PI / 3.0
@export var aim_reach: float = 0.55
## Muzzle up at a wall (FB5): armed, the rifle reaches about 0.72 m ahead (a pistol 0.6 m) of the 0.32 m body, so with
## level geometry within raise_reach_rifle (raise_reach_pistol) along the aim, from raise_drop below the eyes, the
## drawn upper body blends to a high ready by how close it is, fully raised at raise_full (m): the aim clips to level,
## the spine leant raise_lean (rad) back, and the replica (FigureReady) turned raise_angle (rad) muzzle up about the
## grip, canted raise_cant (rad, the magazine out to the right) and drawn raise_back and raise_down (m) in to the chest,
## the arms (raise_arm_bones: upper arm, forearm, hand, an arm at a time, the right arm first) reaching for it. The ray
## looks raise_lead (s) ahead at the figure's speed, once every raise_stride poses; the blend settles in settle_raise
## (s); a shot keeps the replica level for raise_fire_hold (s). Drawn only: the aim, the hit volume and the routes never
## move.
@export var raise_reach_rifle: float = 1.25
@export var raise_reach_pistol: float = 0.7
@export var raise_full: float = 0.35
@export var raise_drop: float = 0.2
@export var raise_lead: float = 0.1
@export var raise_stride: int = 2
@export var settle_raise: float = 0.08
## Below this the raise (and the shoulder and the cheek, TP2), easing back to none, is none (so the arms' IK and the
## head's bow stop running at once).
@export var raise_rest: float = 0.001
@export var raise_fire_hold: float = 0.35
## Through that hold, near cover the replica is still lifted up to this share of the raise (BP7, row 55): a few
## degrees muzzle up (0.12 of raise_angle is about 9 degrees, canted as much), so a bot firing just over a 1.5 m stack
## keeps its barrel over the top with the muzzle near the aim, never the high ready.
@export var raise_fire_most: float = 0.12
@export var raise_lean: float = 0.05
@export var raise_angle: float = 1.35
@export var raise_cant: float = 1.3
@export var raise_back: float = 0.2
@export var raise_down: float = 0.205
@export var raise_arm_bones: PackedStringArray = PackedStringArray(["UpperArm_R", "Forearm_R", "Hand_R", "UpperArm_L",
		"Forearm_L", "Hand_L"])
## The rifle in the shoulder (TP2, owner 2026-11-05: "the buttstock should rest at the figure's armpit"): while a rifle
## is held, its butt (the middle of the replica's last shoulder_butt_depth m) is drawn shoulder_rifle (0..1) of the way
## to the shoulder pocket, shoulder_pocket (m; x to the figure's left, y up, z ahead, in the skeleton's frame) from
## shoulder_bone's joint; the replica keeps its aim and the arms (raise_arm_bones) reach for it. It gives way to the
## high ready as that rises, and to a switch; it eases in and out over settle_shoulder (s).
@export var shoulder_rifle: float = 1.0
@export var settle_shoulder: float = 0.06
@export var shoulder_bone: StringName = &"UpperArm_R"
@export var shoulder_pocket: Vector3 = Vector3(0.04, 0.0, 0.08)
@export var shoulder_butt_depth: float = 0.02
## The cheek on the stock (TP2, HitFit.cheek_turn): the head turned about the first bone's joint (the neck), its sideways
## line from the third bone's joint to the second's (the right shoulder to the left), as the hit volume's.
@export var cheek_bones: PackedStringArray = PackedStringArray(["Neck", "UpperArm_L", "UpperArm_R"])
## The right fist closed on the rebuilt replicas' grips (TP3): human.json's replicaOnGrip was set for the first models,
## so the hand reaches grip_fit (m, by site class, in the replica's own frame: y up, z towards the butt) along the replica
## from where the clips put it, the replica staying where they put it. A class in grip_fit_both moves both hands (a
## pistol's two-handed grip); otherwise the left stays on the handguard.
@export var grip_fit: Dictionary[StringName, Vector3] = {
	&"rifle": Vector3(0.0, 0.035, 0.02),
	&"pistol": Vector3(0.0, 0.022, 0.0),
}
@export var grip_fit_both: PackedStringArray = PackedStringArray(["pistol"])
## The hands closed on the replica as the first-person arms hold it (HG1): arms_model's hold for each replica (its clip
## `<id>_Hold` and empty `Hold_<id>`, FigureArmsHold) gives each hand's place on the replica (hold_hand's frame, turned
## as the arms' is, set hold_thumb_share of the way from its knuckles, hold_knuckle's root, to its thumb's root, where
## the arms' are) and where its fingers go (hold_fingers, each with `_R` or `_L`, parents first): each finger bone
## turned as the arms' is, then aimed at the arms' next joint. The figures' hands are a little smaller and their thumbs
## shorter, so the right hand's place is set by its thumb's root (hold_thumb_share 1) and turned hold_wrap (rad) round
## the grip (about its knuckle line) for its thumb to reach round the grip's left side, each thumb's tip reaching as far
## along the arms' last thumb bone as it can; the left's by its knuckles (hold_thumb_share_left 0), so its fingers
## reach up the handguard's side.
## The right hand takes it while the replica is held, the left too (a pistol's one-handed: the arms' left lowered);
## behind a grip fitted at a rifle's support_mount the left moves back support_behind_grip (m) (FigureView.support_mark).
## Both eased in over settle_support (s) and out over settle_support_off (quicker: a reload's clip reaches for the
## magazine at once); not in a reload (the left), a switch, a throw or calling the hit.
@export var arms_model: String = "res://assets/models/arms/arms.glb"
@export var hold_hand: String = "Hand"
@export var hold_grip: String = "Grip"
@export var hold_knuckle: String = "Middle1"
@export var hold_thumb_share: float = 1.0
@export var hold_thumb_share_left: float = 0.0
@export var hold_wrap: float = 0.35
@export var hold_fingers: PackedStringArray = PackedStringArray(["Thumb1", "Thumb2", "Thumb3", "Index1", "Index2",
		"Index3", "Middle1", "Middle2", "Middle3", "Ring1", "Ring2", "Ring3", "Pinky1", "Pinky2", "Pinky3"])
## The hands hold the replica so only while a ball `hold_view_radius` (m) round the point `hold_view_height` (m) over
## the figure's feet, where its hands and replica are, is in the camera's view (a cone round the view's corners); out
## of it the clips' hands are kept, unseen. The view is looked at every `hold_view_stride`-th frame (figures staggered
## by id; the ball's margin covers the frames between), and at once when the camera has turned more than
## `hold_view_turn` (degrees) or moved more than `hold_view_radius` since, or is another camera (a fast turn, a cut).
@export var hold_view_height: float = 1.2
@export var hold_view_radius: float = 1.0
@export var hold_view_stride: int = 4
@export var hold_view_turn: float = 2.0
@export var support_mount: String = "GripMount"
@export var support_behind_grip: float = 0.045
@export var settle_support: float = 0.08
@export var settle_support_off: float = 0.025
## The draw from one replica to another, time-scaled to the replica's draw time (the sidecar's fitTo). Made rifle to
## pistol, the pistol in the hand from switch_pistol_from of it; to a rifle it plays backwards, the rifle in the hand
## from 1 - switch_pistol_from.
@export var switch_clip: StringName = &"Switch"
@export var switch_pistol_from: float = 0.35
## One trigger press each, played additively over the aim per shot: made additive once at load, against its first frame
## (the sidecar's fireClips), kept in the kind's library under the clip's name and additive_suffix.
@export var rifle_fire_clip: StringName = &"Rifle_Fire"
@export var pistol_fire_clip: StringName = &"Pistol_Fire"
@export var additive_suffix: String = "_Add"
## Holstered, the arms hang (Holster; in a sprint Holster_Sprint's pumping arms, in step with the Sprint clip's legs).
## How a draw from the holster brings the replica to the hand and the arms to the aim, and how fast the arms ease in and
## out of the holster and the sprint, are HitConfig's (holster_swap, settle_holster, settle_sprint): the hit volume
## follows them too.
@export var holster_clip: StringName = &"Holster"
@export var holster_sprint_clip: StringName = &"Holster_Sprint"
@export var holster_sprint_pace_clip: StringName = &"Sprint"
## How fast the upper body settles (s, as the legs' settle times): between the rifle's and the pistol's aim (hold); the
## switch and the trigger press faded in (overlay).
@export var settle_hold: float = 0.06
@export var settle_overlay: float = 0.08
## An upper-body branch eased under this weight (the whole upper body calling the hit, the holster's arms, the aim under
## a full holster) isn't evaluated: gate_clip (one frame long) stands in and its weight is drawn as 0. The hit volume
## gates the holster's arms the same (HitPose.GATE).
@export var gate_below: float = HitPose.GATE
@export var gate_clip: StringName = &"Holster"
## The reloads (FI4): Rifle_Reload or Pistol_Reload by the replica's class, played over the holster and under the
## switch, placed by the reload's share of the replica's reload time (the sidecar's fitTo). The magazine in the hand and
## the old one thrown are copies of the magazine in the figure version's well (ReplicaParts.fit_figure: its own, or a
## magazine part's figure copy when one is fitted), placed by the sidecar's magazineInHand; at most thrown_max lie on
## the field (the oldest goes first), from one shared pool of that many. magazine_node names the figure version's own
## magazine for the hand-off's toss (FigureModels.magazine_mesh, MagTossView).
@export var rifle_reload_clip: StringName = &"Rifle_Reload"
@export var pistol_reload_clip: StringName = &"Pistol_Reload"
@export var magazine_node: String = "Figure_Magazine"
@export var thrown_max: int = 12
## How far under the thrower's feet (m) the thrown magazine's landing ray reaches for a floor below (BP7: a ledge's
## foot; ThrownMagazines.set_world).
@export var thrown_drop: float = 6.0
## The ray starts this far over the feet (m): a floor at their height or under is found, a table or crate top over them
## never is.
@export var thrown_land_above: float = 0.05
## Out of the hand, the rifle lies on the figure's back from the Chest bone (stowed, HS1): its middle
## back_middle.x to the figure's right of the spine and back_middle.y above the feet, its left side (against the kit)
## back_depth_human behind the chest bone (back_depth_pack with a human's pack, back_pack_part; back_depth_robot on a
## robot), its long axis back_tilt (rad) from upright with the muzzle down to the left, leaning back_lean (rad, the butt
## toward the body, as the pack's back slopes), its right side facing out. Placed against the Holster clip's chest,
## standing. Then each rifle is moved straight out or in until it rests back_rest_gap (m) off the kit behind it: the
## triangles of back_rest_parts rigged at least back_rest_share to the chest bone (so they move with it), looked at in
## squares of back_rest_cell (m) across and along it (none on a robot, which keeps its depth).
@export var chest_bone: StringName = &"Chest"
@export var back_middle: Vector2 = Vector2(0.0, 1.28)
@export var back_tilt: float = 0.3
@export var back_lean: float = 0.3
@export var back_depth_human: float = 0.19
@export var back_depth_pack: float = 0.317
@export var back_depth_robot: float = 0.17
@export var back_pack_part: String = "Kit_Pack"
@export var back_rest_parts: PackedStringArray = PackedStringArray(["Kit_Pack", "Kit"])
@export var back_rest_cell: float = 0.015
@export var back_rest_gap: float = 0.003
@export var back_rest_share: float = 0.5
## Out of the hand, a pistol sits in the belt holster: its frame is the kind's model's empty holster_node (the replica's
## axes: +Z up out of the mouth toward the grip, +Y the slide's top, toward the figure's front; its origin at the mouth
## on the slide's line), carried by holster_bone with holster_follow of holster_follow_bone's swing (the holster's own
## skin is weighted the same, 0.9 Hips and 0.1 Thigh_R all over (gear.py HOLSTER_THIGH, BP7), so the two move as one); the pistol's muzzle holster_depth (m) below the mouth (both pistols' figure meshes clear the
## pocket's walls standing from 0.10 to 0.13 m; 0.11 sits the muzzle clear of the foot's bend). A kind without the
## empty (the robot) shows no pistol out of the hand.
@export var holster_node: String = "PistolHolster"
@export var holster_bone: StringName = &"Hips"
@export var holster_follow_bone: StringName = &"Thigh_R"
@export var holster_follow: float = 0.1
@export var holster_depth: float = 0.11
## The replica in the hand sits on this bone by the sidecar's replicaOnGrip for its class (rifle, pistol).
@export var grip_bone: StringName = &"Grip_R"
## Calling the hit (the left hand up), the replica hangs from the right hand's grip, its long axis this far (rad) off
## straight down with the muzzle forward. Straight down (FB5): tilted 0.25 rad, a rifle reached 0.52 m ahead, through
## a wall the figure stood at; hanging straight, 0.36 m, about the body's 0.32 m.
@export var hang_tilt: float = 0.0
## A bomb thrown (SF1; GT1): the bomb's model in the right hand (on grip_bone, turned as a pistol's grip there,
## throw_bomb_turn (rad, about its own up) further and throw_bomb_shift (m, its frame) off the grip's point), and the
## arms reaching for each throw_* key by two-bone IK (FigureThrow) over the holster's hanging arms. The keys are each
## hand's wrist from its own shoulder, in the figure's frame (x right, y up, z ahead) turned with its chest. The right
## hand goes from throw_ready (the bomb at the chest; a bomb held in hand, MC1, stays there) out to the side by
## throw_lift and back to throw_cocked (by the ear, the elbow out under the shoulder) by throw_cock of the windup
## (throw_lift_at of the way to it); then, quickening, up beside the head to throw_over (throw_over_at of the way on, so
## the hand never crosses the face) and out to throw_release (high ahead) at the release; then down to throw_follow
## (across the body) over the recovery. The left hand meets the right at throw_pin over the first throw_pin_until of the
## windup (pulling the pin), points out at the target (throw_point) by throw_cock and tucks in to the chest (throw_tuck)
## as the right comes over. The arms take the pose over the first throw_in of the windup (all of it at once after a bomb
## held in hand) and give it back over the last throw_out of the recovery; the upper chain turns throw_twist (rad) away
## about the spine as the arm cocks and as far back across as it follows through. Each elbow bends towards its pole (the
## figure's frame): the right elbow stays low and out while the arm cocks and swings ahead to throw_over_pole as it
## comes over, as the body's skin drags at the armpit with the upper arm out above level. Drawn only: the bomb still
## leaves the eyes (Grenades).
@export var throw_bomb_turn: float = 0.0
@export var throw_bomb_shift: Vector3 = Vector3.ZERO
@export var throw_ready: Vector3 = Vector3(-0.1, -0.22, 0.3)
@export var throw_lift: Vector3 = Vector3(0.3, -0.18, 0.12)
@export var throw_lift_at: float = 0.45
@export var throw_cocked: Vector3 = Vector3(0.17, 0.06, -0.12)
@export var throw_over: Vector3 = Vector3(0.16, 0.18, 0.16)
@export var throw_over_at: float = 0.45
@export var throw_release: Vector3 = Vector3(0.1, 0.07, 0.5)
@export var throw_follow: Vector3 = Vector3(-0.24, -0.3, 0.36)
@export var throw_pin: Vector3 = Vector3(0.24, -0.22, 0.3)
@export var throw_pin_until: float = 0.2
@export var throw_point: Vector3 = Vector3(0.04, 0.02, 0.52)
@export var throw_tuck: Vector3 = Vector3(0.14, -0.26, 0.2)
@export var throw_cock: float = 0.6
@export var throw_in: float = 0.3
@export var throw_out: float = 0.5
@export var throw_twist: float = 0.35
@export var throw_right_pole: Vector3 = Vector3(0.7, -1.0, -0.2)
@export var throw_over_pole: Vector3 = Vector3(0.1, -0.7, 1.0)
@export var throw_left_pole: Vector3 = Vector3(-1.0, -0.8, 0.0)
@export var throw_arm_bones: PackedStringArray = PackedStringArray(["UpperArm_R", "Forearm_R", "Hand_R", "UpperArm_L",
		"Forearm_L", "Hand_L"])
## Robots (Settings › Dev › Robots, the Easter egg, off by default; RB1) are picked from the match seed XOR this salt so
## no gameplay stream moves (the browser's ROBOT_SEED_SALT).
@export var robot_salt: int = 0x5f3759df


## The face look figure `figure_id` wears: the next look for each round of the heads, so the figures sharing a head
## (id, id + heads, id + 2 heads ...) never share a look until every look is used.
func face_look(figure_id: int) -> int:
	if face_offsets.is_empty():
		return 0
	var id := absi(figure_id)  # INT_MIN stays negative: posmod keeps the look in range
	var h := maxi(heads.size(), 1)
	# id = head + lap * h: the look moves on one per lap, whatever the count of heads.
	return posmod(posmod(id, h) + id / h, face_offsets.size())


## The two lines (m) for the Mesh detail drawn.
func lod_lines(detail: GraphicsQuality.MeshDetail) -> Vector2:
	if detail == GraphicsQuality.MeshDetail.HIGH or detail == GraphicsQuality.MeshDetail.ULTRA:
		return lod_high
	return lod_low


## The lines (m) drawn for `detail` seen at `zoom` (the eye's magnification, 1 unzoomed): scaled by it, so a figure
## through a 6x scope changes level where it looks as big as one unzoomed at its line (BP6).
func zoomed_lines(detail: GraphicsQuality.MeshDetail, zoom: float) -> Vector2:
	return lod_lines(detail) * maxf(zoom, 1.0)


## Through a zoomed scope only the figures its glass shows take the zoomed lines (BP7): a ball `zoom_view_radius` (m)
## round the point `zoom_view_height` (m) over a figure's feet reaching into the glass camera's cone; the rest keep the
## eye's own lines, as the optic's disc hides them (FigureView.fit_zoomed_lines).
@export var zoom_view_height: float = 0.9
@export var zoom_view_radius: float = 1.0
## A figure already on the zoomed lines keeps them until its ball, this much wider (m), leaves the cone, so one at the
## glass's edge doesn't flip detail every frame as the scope sways (BP7).
@export var zoom_view_margin: float = 0.75
