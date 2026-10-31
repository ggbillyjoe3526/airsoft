class_name JoltMover
extends CharacterMover
## The simulation's CharacterMover on a map's Jolt colliders (docs/ARCHITECTURE.md › Contracts 4), moving the same body
## BoxWorld does: a vertical cylinder of BodyConfig radius and height whose bottom is the feet, crouch_height tall while
## the character is low (CR1). Each move sweeps it with
## PhysicsServer3D.body_test_motion (its parameters and result reused, so nothing is allocated a call): vertically first,
## then level, sliding along what it meets, then a step up onto anything no taller than max_step. The ground probe sweeps
## a thin disc of the body's radius down from max_step above the feet. Both bodies belong to the MapLevel.

## Slides a level move may take round what it meets (a corner needs two).
const SLIDES := 4
## A move shorter than this (m) is no move.
const MIN_MOVE := 1e-5
## A contact at least this upright is ground (a ramp's is 0.89); anything steeper is a wall to step up or slide along.
const GROUND_NORMAL_Y := 0.7
## A stepped move must get this much further (m) than the plain one to be taken.
const STEP_GAIN := 1e-3

var _tall_rid: RID
var _low_rid: RID
var _probe_rid: RID
## The body moved now (the tall or the low one, set by each call) and half its height.
var _body_rid: RID
var _half: float = 0.0
var _body: BodyConfig = null
var _params: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
var _result: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
## Whether the last level slide was stopped by a wall (a contact steeper than ground).
var _met_wall: bool = false


func _init(tall_rid: RID, low_rid: RID, probe_rid: RID, body: BodyConfig) -> void:
	_tall_rid = tall_rid
	_low_rid = low_rid
	_probe_rid = probe_rid
	_body = body
	_use(false)


func move(c: Character, desired: Vector3) -> Vector3:
	_use(c.low)
	var p := c.position
	if absf(desired.y) > MIN_MOVE:
		p = _sweep(p, Vector3(0.0, desired.y, 0.0))
	var flat := Vector3(desired.x, 0.0, desired.z)
	if flat.length_squared() > MIN_MOVE * MIN_MOVE:
		var plain := _slide(p, flat)
		# Blocked on the ground: try the move again from max_step up, then back down; take it if it got further.
		if _met_wall and c.grounded and desired.y <= 0.0:
			var up := _sweep(p, Vector3(0.0, _body.max_step, 0.0))
			var over := _slide(up, flat)
			var down := _sweep(over, Vector3(0.0, p.y - up.y, 0.0))
			if _flat_gain(p, down) > _flat_gain(p, plain) + STEP_GAIN:
				plain = down
		p = plain
	return p - c.position


func room_to_stand(c: Character) -> bool:
	_use(true)
	var up := _body.height - _body.crouch_height
	return _sweep(c.position, Vector3(0.0, up, 0.0)).y >= c.position.y + up - MIN_MOVE


func probe_ground(c: Character, max_drop: float) -> float:
	var start := c.position.y + _body.max_step
	_params.from = Transform3D(Basis.IDENTITY, Vector3(c.position.x, start + MapLevel.PROBE_THICKNESS * 0.5,
			c.position.z))
	_params.motion = Vector3(0.0, -(_body.max_step + _body.rest_gap + max_drop), 0.0)
	if not PhysicsServer3D.body_test_motion(_probe_rid, _params, _result):
		return NAN
	if _result.get_collision_normal().y <= 0.0:
		return NAN
	return start + _result.get_travel().y + _body.rest_gap - c.position.y


## Where feet at `feet` end up moving by `motion` until something stops the body.
func _sweep(feet: Vector3, motion: Vector3) -> Vector3:
	_params.from = Transform3D(Basis.IDENTITY, feet + Vector3(0.0, _half, 0.0))
	_params.motion = motion
	PhysicsServer3D.body_test_motion(_body_rid, _params, _result)
	return feet + _result.get_travel()


## Where feet at `feet` end up moving level by `motion`, sliding along whatever stops them.
func _slide(feet: Vector3, motion: Vector3) -> Vector3:
	_met_wall = false
	var p := feet
	var left := motion
	for i in SLIDES:
		_params.from = Transform3D(Basis.IDENTITY, p + Vector3(0.0, _half, 0.0))
		_params.motion = left
		var hit := PhysicsServer3D.body_test_motion(_body_rid, _params, _result)
		p += _result.get_travel()
		if not hit:
			break
		var n := _result.get_collision_normal()
		if n.y < GROUND_NORMAL_Y:
			_met_wall = true
		left = _result.get_remainder().slide(n)
		if left.length_squared() < MIN_MOVE * MIN_MOVE:
			break
	return p


## Moves the low body (crouch_height tall) or the standing one from now on.
func _use(low: bool) -> void:
	_body_rid = _low_rid if low else _tall_rid
	_half = (_body.crouch_height if low else _body.height) * 0.5


static func _flat_gain(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()
