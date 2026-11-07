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
## The lower body's points as Hitbox poses them (HitPose.lower): the Hips bone's place and axes, then each leg's joints.
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

@export var phases: int = 32
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


## The hips' heading (rad, heading()) standing still, crouched still, and between them by `crouch` (0..1): what the
## upper body is turned back to over a stepping clip's hips (GA1, HitConfig.upper_steady).
func still_heading(crouch: float) -> float:
	if is_nan(_still_headings.x):
		_still_headings = Vector2(_sample_heading(stand_still), _sample_heading(crouch_still))
	return lerp_angle(_still_headings.x, _still_headings.y, clampf(crouch, 0.0, 1.0))


## How far (rad, about +Y) a bone's x axis `x_axis` is turned from +X: a hips' heading in any frame turned about +Y.
static func heading(x_axis: Vector3) -> float:
	return atan2(-x_axis.z, x_axis.x)


## The turn about +Y (rad, -PI..PI) that brings hips whose x axis is `x_axis` back to heading `still`.
static func steady_turn(still: float, x_axis: Vector3) -> float:
	return wrapf(still - heading(x_axis), -PI, PI)


static func _sample_heading(sample: PackedFloat32Array) -> float:
	if sample.size() < HIPS_TURN + 4:
		return 0.0
	var q := Quaternion(sample[HIPS_TURN], sample[HIPS_TURN + 1], sample[HIPS_TURN + 2], sample[HIPS_TURN + 3])
	return heading(Basis(q.normalized()).x)


## Blend point `point`'s sample at `phase` in `gait` or `crouch`.
func clip_at(point: int, phase: int) -> int:
	return point * phases + phase


## A lower body table ready to blend (`table`): each sample's hips place, and each of its turns as its step from the
## rest (normalised; the file holds them to 1 mm's worth of decimals).
class Table:
	extends RefCounted
	var places: PackedVector3Array = PackedVector3Array()
	var steps: Array[Quaternion] = []


## The lower body tables `table` makes, each from its sample field (FIELDS): asked for by these names only, so
## `prepare` makes every one a pose can ask for.
enum Lower { STAND_STILL, CROUCH_STILL, GAIT, CROUCH, JUMP, VAULT }
## Each Lower table's sample field, in Lower's order.
const FIELDS: Array[StringName] = [&"stand_still", &"crouch_still", &"gait", &"crouch", &"jump", &"vault_lower"]

## The rests (HitFit.rests) as turns, and the tables ready to blend: built once, on first use (or `prepare`).
var _rests: Array[Quaternion] = []
var _tables: Array[Table] = []
## The hips' heading standing still and crouched still (still_heading), read once.
var _still_headings: Vector2 = Vector2(NAN, NAN)


## Turn `j`'s rest (0: the hips', then each leg bone's).
func rest(j: int) -> Quaternion:
	if _rests.is_empty():
		for i in range(0, rests.size(), 4):
			_rests.append(Quaternion(rests[i], rests[i + 1], rests[i + 2], rests[i + 3]).normalized())
	return _rests[j]


## Every lower body table (`table`) made at once (BP6): a match warms them when it starts, so none is made mid-match
## the first time a pose needs it (a jump, a crouch, a vault) and a tick allocates nothing.
func prepare() -> void:
	for kind: Lower in Lower.values():
		table(kind)


## How many lower body tables are made so far.
func tables_made() -> int:
	return _tables.size() - _tables.count(null)


## The lower body table `kind` ready to blend.
func table(kind: Lower) -> Table:
	if _tables.is_empty():
		_tables.resize(Lower.size())
	var t := _tables[kind]
	if t != null:
		return t
	t = Table.new()
	var floats: PackedFloat32Array = get(FIELDS[kind])
	var turns := (SAMPLE - HIPS_TURN) / 4
	for at in range(0, floats.size(), SAMPLE):
		t.places.append(Vector3(floats[at], floats[at + 1], floats[at + 2]))
		for j in turns:
			var i := at + HIPS_TURN + 4 * j
			var q := Quaternion(floats[i], floats[i + 1], floats[i + 2], floats[i + 3]).normalized()
			t.steps.append((rest(j).inverse() * q).normalized())
	_tables[kind] = t
	return t


## The cheek on a rifle's stock (TP2), `amount` (0..1) of it: the head's turn about the neck's joint, bowed `bow`
## (rad, HitConfig.cheek_bow) forward about `side` (the right shoulder to the left), then tilted `cant` (cheek_cant) to
## the right about the way ahead (`side` across `up`, the neck to the head). Either frame (the hit volume's or the
## skeleton's): `side` is the figure's left in both. Identity when the two are in line or none. The angles come as
## numbers, not the HitConfig: HitConfig preloads hit_fit.tres, and naming it here made a cycle an export can't load.
static func cheek_turn(side: Vector3, up: Vector3, bow: float, cant: float, amount: float) -> Basis:
	var ahead := side.cross(up)
	if amount <= 0.0 or ahead.length_squared() <= 0.0:
		return Basis.IDENTITY
	return Basis(ahead.normalized(), cant * amount) * Basis(side.normalized(), bow * amount)
