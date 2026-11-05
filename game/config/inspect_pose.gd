class_name InspectPose
extends Resource
## How the replica in hand is turned over to look at while you inspect it (IN1; the browser game's renderView.ts
## VIEWMODEL.inspect.poses, RM2): keys at shares of the inspect, eased between, each a turn and a shift from the hold;
## and the sounds its parts make, each at a share of the inspect. Read by ReplicaView, which plays the model's own
## Inspect clip under the pose.

## The inspect's length (s) for a model with no Inspect clip; a model's clip's own length wins.
@export var duration: float = 2.0
## Each key's share of the inspect (0 to 1, rising; the first at 0 and the last at 1, both the hold).
@export var at: PackedFloat32Array = PackedFloat32Array()
## Each key's turn (rad, applied as the replica's rotation is): x tilts the muzzle up, y turns it left, z rolls the
## right side up.
@export var turn: PackedVector3Array = PackedVector3Array()
## Each key's shift (m, in the camera's space): x right (negative: inwards, towards the centre of view), y up, z
## towards the eye.
@export var shift: PackedVector3Array = PackedVector3Array()
## The parts' sounds: each at a share of the inspect, a SimAudio.inspect_sound cue (the replica's own dryFire, magIn
## and magOut, or a shared cue such as selector or torchClick).
@export var sound_at: PackedFloat32Array = PackedFloat32Array()
@export var sound_cue: Array[StringName] = []


## A pose from its parts (ViewModelConfig's defaults).
static func make(length: float, keys_at: PackedFloat32Array, turns: Array[Vector3], shifts: Array[Vector3],
		sounds_at: PackedFloat32Array, cues: Array[StringName]) -> InspectPose:
	var p := InspectPose.new()
	p.duration = length
	p.at = keys_at
	p.turn = PackedVector3Array(turns)
	p.shift = PackedVector3Array(shifts)
	p.sound_at = sounds_at
	p.sound_cue = cues
	return p


## The turn at `share` of the inspect (0 to 1), eased between the keys either side.
func turn_at(share: float) -> Vector3:
	return _sample(turn, share)


## The shift at `share` of the inspect (0 to 1), eased between the keys either side.
func shift_at(share: float) -> Vector3:
	return _sample(shift, share)


## Whether the keys can be sampled: as many turns and shifts as keys, at least two, rising from 0 to 1; and a cue for
## every sound share. ViewModelConfig's test checks every pose.
func valid() -> bool:
	var n := at.size()
	if n < 2 or turn.size() != n or shift.size() != n or not is_zero_approx(at[0]) or not is_equal_approx(at[n - 1], 1.0):
		return false
	for i in range(1, n):
		if at[i] <= at[i - 1]:
			return false
	return sound_at.size() == sound_cue.size() and duration > 0.0


func _sample(values: PackedVector3Array, share: float) -> Vector3:
	var n := mini(at.size(), values.size())
	if n == 0:
		return Vector3.ZERO
	if share <= at[0]:
		return values[0]
	for i in range(1, n):
		if share <= at[i]:
			var span := at[i] - at[i - 1]
			var t := (share - at[i - 1]) / span if span > 0.0 else 1.0
			return values[i - 1].lerp(values[i], smoothstep(0.0, 1.0, t))
	return values[n - 1]
