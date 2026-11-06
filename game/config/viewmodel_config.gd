class_name ViewModelConfig
extends Resource
## The replica in your hands (the browser game's config/renderView.ts VIEWMODEL, tuned by play there). Metres in the
## camera's space (x right, y up, -z forward), seconds, radians. Read by ReplicaView.

## Where each replica's origin (above the trigger) sits at the hip, by replica id; others use `hip_default`.
@export var hip: Dictionary[StringName, Vector3] = {
	&"aeg": Vector3(0.12, -0.19, -0.26),
	&"pistol": Vector3(0.12, -0.15, -0.34),
	&"cyber": Vector3(0.12, -0.15, -0.34),
	&"sniper": Vector3(0.12, -0.19, -0.26),
}
@export var hip_default: Vector3 = Vector3(0.13, -0.16, -0.32)
## Aimed, the sight line (rear to front sight) runs through the eye; the replica sits this far forward of it.
@export var aim_forward: Dictionary[StringName, float] = {&"aeg": -0.2, &"pistol": -0.36, &"cyber": -0.36,
		&"sniper": -0.2}
@export var aim_forward_default: float = -0.25
## Looking through an optic, by its part Key (ReplicaView, OpticGlass): its glass's centre (z in the part's own space,
## -z forward, on the sight line) and radius (m), measured from the part models; how far behind the glass the eye sits
## aimed (m, so the glass shows as the approved sight concepts do); and the mark on the glass (dot: a lit red dot;
## cross: a scope's reticle). An optic not listed is aimed along its sight line with no glass drawn.
@export var optic_glass_z: Dictionary[StringName, float] = {&"redDot": -0.013, &"scope2x": 0.0286,
		&"scopeVar": 0.0646}
@export var optic_glass_radius: Dictionary[StringName, float] = {&"redDot": 0.0075, &"scope2x": 0.015,
		&"scopeVar": 0.0122}
@export var optic_eye_back: Dictionary[StringName, float] = {&"redDot": 0.15, &"scope2x": 0.1728, &"scopeVar": 0.1728}
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
## of 2026-11-05: two-handed pistol holds clipped or bent the wrist), and a robot's arms' colours (sRGB) by the arms
## model's material name, with their roughness (satin, as the robot figure's plates).
@export var one_hand: Array[StringName] = [&"pistol", &"cyber"]
@export var robot_arms: Dictionary[StringName, Color] = {
	&"Glove": Color(0.80, 0.81, 0.82),
	&"GloveArmour": Color(0.16, 0.17, 0.18),
	&"Sleeve": Color(0.62, 0.63, 0.65),
	&"SleeveTrim": Color(0.22, 0.23, 0.24),
}
@export var robot_arms_roughness: float = 0.45
