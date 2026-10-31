class_name BodyConfig
extends Resource
## A character's collision body (the browser game's config/movement.ts BODY). Heights are from the character's position,
## the capsule's bottom, which rests rest_gap above the floor.

## Capsule radius and height (m).
@export var radius: float = 0.32
@export var height: float = 1.8
## The body's height crouched (m): it stays crouched under anything lower than `height` over its feet, and goes through
## anything at least this high (CT1: Woodland's 1.4 m tunnels; the crouched figure's head tops out at 1.13 m).
@export var crouch_height: float = 1.25
## Eye height standing and fully crouched (m).
@export var stand_eye_height: float = 1.62
@export var crouch_eye_height: float = 1.05
## How far above the floor a standing character rests (m), the physics' skin.
@export var rest_gap: float = 0.04
## The highest step a character walks up without jumping (m).
@export var max_step: float = 0.15
