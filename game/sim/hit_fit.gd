class_name HitFit
extends Resource
## The hit area fitted to the drawn figure (HV1; DECISIONS, the hit area fitted to each rigged figure): the figure's own
## skeleton posed by its own animation graph, baked by tools/hit_fit_bake.gd into game/config/hit_fit.tres and read
## back here, so the simulation never touches a scene. Hitbox.build_volume blends the samples for a character's state
## as the graph blends its clips, poses the legs from them and hangs its capsules on the joints. Everything is in the
## figure's frame (feet on the origin, facing -Z, x to its right), before FigureBend's crouch limit, lean and aim lean,
## which Hitbox applies as the drawn figure does. Re-bake when a figure or its clips change: test_hit_fit.gd fails while
## this file is stale.
##
## A lower body sample (SAMPLE floats): the Hips bone's place and turn, then each leg bone's turn on its parent
## (LEG_BONES; quaternions x, y, z, w), the bones' offsets on their parents being `leg_offsets`. Samples: standing still
## and crouched still, then each clip of the gait blend space (`gait_points`, triangulated as `gait_triangles`) and of
## the crouch blend space (`crouch_points`) at each of `phases` steps of the walk cycle; in the air, jump_samples from
## jump_from to jump_to s into the Jump clip; vaulting, vault_samples over the Vault clip's share. An upper body sample
## (UPPER points) is in the Hips bone's frame: the aim clips down, level and up for the rifle and the pistol,
## holstered standing and holstered sprinting, and each vault sample.

## A lower body sample's floats: the hips' place (3) and turn (4), then each leg bone's turn (4).
const HIPS_AT := 0
const HIPS_TURN := 3
const LEG_TURNS := 7
## Each leg's bones turned, left then right: thigh, shin, foot.
const LEG_BONES := 6
const SAMPLE := LEG_TURNS + 4 * LEG_BONES
## `leg_offsets`: each leg's thigh on the hips, shin on the thigh, foot on the shin and toe on the foot, left then right.
const OFFSETS := 8
## The lower body's points as Hitbox poses them (Hitbox._low): the Hips bone's place and axes, then each leg's joints.
const HIPS := 0
const HIPS_X := 1
const HIPS_Y := 2
const HIPS_Z := 3
const THIGH_L := 4
const KNEE_L := 5
const ANKLE_L := 6
const TOE_L := 7
const THIGH_R := 8
const KNEE_R := 9
const ANKLE_R := 10
const TOE_R := 11
const LOWER := 12
## The upper body's points.
const SPINE := 0
const SPINE1 := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const HEAD_TOP := 5
const SHOULDER_L := 6
const SHOULDER_R := 7
const UPPER := 8
## Aim samples a hold: down, level, up (the aim clips' blend at -1, 0, 1).
const AIMS := 3

@export var phases: int = 24
@export var leg_offsets: PackedVector3Array = PackedVector3Array()
## Each turn's rest (the hips' in the figure's frame, then each leg bone's on its parent, as a sample's turns): the
## animation graph blends each turn as weighted steps away from its rest, as Hitbox does.
@export var rests: PackedFloat32Array = PackedFloat32Array()
## Standing and crouched still (the clips running free, not stepped).
@export var stand_still: PackedFloat32Array = PackedFloat32Array()
@export var crouch_still: PackedFloat32Array = PackedFloat32Array()
## The gait blend space's points (the step in the figure's frame, m/s: x to its right, y ahead) and its triangles (three
## point indices each), and each point's clip at each phase.
@export var gait_points: PackedVector2Array = PackedVector2Array()
@export var gait_triangles: PackedInt32Array = PackedInt32Array()
@export var gait: PackedFloat32Array = PackedFloat32Array()
## The crouch blend space's points (the speed, m/s, ascending) and each one's clip at each phase.
@export var crouch_points: PackedFloat32Array = PackedFloat32Array()
@export var crouch: PackedFloat32Array = PackedFloat32Array()
## A crouched step backwards plays the crouched walk mirrored about `forward_phase` (FigureGraph.FORWARD_PHASE): going
## back more than back_share of the speed, crouched more than back_crouched (FigureConfig).
@export var forward_phase: float = PI * 0.5
@export var back_share: float = 0.1
@export var back_crouched: float = 0.5
@export var jump_samples: int = 7
@export var jump_from: float = 0.25
@export var jump_to: float = 0.55
@export var jump: PackedFloat32Array = PackedFloat32Array()
@export var vault_samples: int = 12
## The share of the Vault clip that covers the rise onto the top (FigureConfig.vault_top).
@export var vault_top: float = 0.4
@export var vault_lower: PackedFloat32Array = PackedFloat32Array()
@export var vault_upper: PackedVector3Array = PackedVector3Array()
## AIMS samples each (UPPER points each), then one each.
@export var aim_rifle: PackedVector3Array = PackedVector3Array()
@export var aim_pistol: PackedVector3Array = PackedVector3Array()
@export var holster: PackedVector3Array = PackedVector3Array()
@export var sprint: PackedVector3Array = PackedVector3Array()
## The aim clips' reach (FigureConfig): the pitch (rad) at which the blend is full, and the share of it they turn; the
## spine leans the rest (FigurePose.aim_lean).
@export var aim_pitch: float = PI / 3.0
@export var aim_reach: float = 0.55
## The highest a fully crouched head's top is drawn (m, FigureConfig.crouch_top_max).
@export var crouch_top_max: float = 1.15
## What it was baked from, for whoever reads the file.
@export var source: String = ""


## Whether every table holds the samples its counts call for.
func is_complete() -> bool:
	return phases > 0 and leg_offsets.size() == OFFSETS and rests.size() == SAMPLE - HIPS_TURN \
			and stand_still.size() == SAMPLE \
			and crouch_still.size() == SAMPLE and gait_points.size() > 2 and not gait_triangles.is_empty() \
			and gait_triangles.size() % 3 == 0 and gait.size() == SAMPLE * phases * gait_points.size() \
			and crouch_points.size() > 1 and crouch.size() == SAMPLE * phases * crouch_points.size() \
			and jump_samples > 1 and jump.size() == SAMPLE * jump_samples \
			and vault_samples > 1 and vault_lower.size() == SAMPLE * vault_samples \
			and vault_upper.size() == UPPER * vault_samples \
			and aim_rifle.size() == UPPER * AIMS and aim_pistol.size() == UPPER * AIMS \
			and holster.size() == UPPER and sprint.size() == UPPER


## Blend point `point`'s sample at `phase` in `gait` or `crouch`.
func clip_at(point: int, phase: int) -> int:
	return point * phases + phase


## A lower body table ready to blend (`table`): each sample's hips place, and each of its turns as its step from the
## rest (normalised; the file holds them to 1 mm's worth of decimals).
class Table:
	extends RefCounted
	var places: PackedVector3Array = PackedVector3Array()
	var steps: Array[Quaternion] = []


## The rests (HitFit.rests) as turns, and the tables ready to blend: built once, on first use.
var _rests: Array[Quaternion] = []
var _tables: Dictionary[StringName, Table] = {}


## Turn `j`'s rest (0: the hips', then each leg bone's).
func rest(j: int) -> Quaternion:
	if _rests.is_empty():
		for i in range(0, rests.size(), 4):
			_rests.append(Quaternion(rests[i], rests[i + 1], rests[i + 2], rests[i + 3]).normalized())
	return _rests[j]


## The lower body table `field` (stand_still, crouch_still, gait, crouch, jump or vault_lower) ready to blend.
func table(field: StringName) -> Table:
	var t: Table = _tables.get(field)
	if t != null:
		return t
	t = Table.new()
	var floats: PackedFloat32Array = get(field)
	var turns := (SAMPLE - HIPS_TURN) / 4
	for at in range(0, floats.size(), SAMPLE):
		t.places.append(Vector3(floats[at], floats[at + 1], floats[at + 2]))
		for j in turns:
			var i := at + HIPS_TURN + 4 * j
			var q := Quaternion(floats[i], floats[i + 1], floats[i + 2], floats[i + 3]).normalized()
			t.steps.append((rest(j).inverse() * q).normalized())
	_tables[field] = t
	return t
