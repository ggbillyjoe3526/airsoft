class_name FigureHeld
extends RefCounted
## How a figure holds one replica as the first-person arms do (HG1; FigureHands makes one a slot, FigureGrasp poses
## the hands from it): the arms' hold, each hand's place in the replica's frame (the left moved `left_shift` from the
## arms', back behind a fitted grip), and the replica on the grip bone as the clips hold it and once the right hand
## holds it so. Every replica the arms hold has one; the left hand takes it on a rifle's handguard and, lowered, on a
## pistol (held one-handed).

var arms: FigureArmsHold = null
var right: Transform3D = Transform3D.IDENTITY
var left: Transform3D = Transform3D.IDENTITY
var left_shift: Vector3 = Vector3.ZERO
var on_grip: Transform3D = Transform3D.IDENTITY
var held_on_grip: Transform3D = Transform3D.IDENTITY
## Whether it is held in one hand (a pistol): the left hand is lowered from the aim, not on the replica.
var one_handed: bool = false


func _init(hold: FigureArmsHold, right_on: Transform3D, left_on: Transform3D, shift: Vector3, clips_on_grip: Transform3D,
		on_grip_held: Transform3D, in_one_hand: bool) -> void:
	arms = hold
	right = right_on
	left = left_on
	left_shift = shift
	on_grip = clips_on_grip
	held_on_grip = on_grip_held
	one_handed = in_one_hand
