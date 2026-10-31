class_name PracticeSpot
extends RefCounted
## Where you stood on the range when you opened the Loadout from practice, so the range built again puts you back there:
## your place and view, standing or crouched, the replica in hand (or holstered), and the Timed challenge's switch. Plain
## data; `PlaySession.practice_spot` takes it and `restore` gives it back to a new Character. A challenge run under way
## is not part of it: the new range starts the challenge afresh, ready, and the run is dropped.

## Feet, as `Character.position`.
var position: Vector3 = Vector3.ZERO
## The view (rad): `PlayerInput`'s, which the character follows.
var yaw: float = 0.0
var pitch: float = 0.0
## Crouched (past half way down) when it was taken.
var crouched: bool = false
## The slot in hand (an index into the kit's replicas), and whether the replica is holstered.
var slot: int = 0
var holstered: bool = false
## The Timed challenge's switch, which the range comes back with.
var challenge_on: bool = false
## The range's seed, so its breeze and its pop-ups' draw stay as they were.
var match_seed: int = 0


## The spot of `c`, looking along (`view_yaw`, `view_pitch`), crouched if you chose to be (`crouched`).
static func of(c: Character, view_yaw: float, view_pitch: float, crouched: bool, challenge: bool,
		seed_used: int) -> PracticeSpot:
	var s := PracticeSpot.new()
	s.position = c.position
	s.yaw = view_yaw
	s.pitch = view_pitch
	s.crouched = crouched
	s.slot = c.armament.active
	s.holstered = c.armament.holstered
	s.challenge_on = challenge
	s.match_seed = seed_used
	return s


## Puts `c` back on the spot: placed (drawn there at once, not walked in), standing or crouched, with the same slot in
## hand. A slot the new kit has no replica for falls back to the first.
func restore(c: Character) -> void:
	c.position = position
	c.prev_position = position
	c.yaw = yaw
	c.prev_yaw = yaw
	c.pitch = pitch
	c.prev_pitch = pitch
	c.crouch_amount = 1.0 if crouched else 0.0
	c.prev_crouch_amount = c.crouch_amount
	c.low = crouched  # the crouched body from the first tick (CT1)
	var a := c.armament
	a.active = slot if slot >= 0 and slot < a.replicas.size() else 0
	a.holstered = holstered
