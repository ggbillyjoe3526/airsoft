class_name MapPointer
extends RefCounted
## The full-screen map's own pointer (FM1): while the map's key is held the mouse moves this instead of the view, kept
## on the map's panel. The HUD hands PlayerInput the panel each frame (`frame`, or `frame_rect` for one that isn't
## square, FM2): where its middle is in the world, its pixels per metre, its half size and the floor of the storey it
## shows; a click there is a ping on that point of the field (`world`). Positions are px from the panel's middle, x right (the world's +x), y down (the world's +z: the map
## keeps north up). Plain state and math. Allocates nothing.

var open: bool = false
var at: Vector2 = Vector2.ZERO
## The panel: the world (x, z) at its middle, px per metre, half its width and height (px) and the floor shown (m). No
## panel (half 0: no map drawn, as on the range) holds the pointer in the middle.
var centre: Vector2 = Vector2.ZERO
var ppm: float = 1.0
var half: Vector2 = Vector2.ZERO
var floor_y: float = 0.0
## Where you are on it (px from the middle), where the pointer starts.
var you: Vector2 = Vector2.ZERO
## Opened since the last frame: the next frame puts it on you as that frame has you.
var _fresh: bool = false


## The map's square this frame (see the fields above).
func frame(world_centre: Vector2, px_per_m: float, half_side: float, shown_floor: float, you_at: Vector2) -> void:
	frame_rect(world_centre, px_per_m, Vector2(half_side, half_side), shown_floor, you_at)


## The map's panel this frame, `half_size` half its width and height (px).
func frame_rect(world_centre: Vector2, px_per_m: float, half_size: Vector2, shown_floor: float, you_at: Vector2) -> void:
	centre = world_centre
	ppm = maxf(px_per_m, 1e-6)
	half = half_size.max(Vector2.ZERO)
	floor_y = shown_floor
	you = you_at
	if _fresh:
		_fresh = false
		at = _kept(you)
	else:
		at = _kept(at) # a panel that shrank (the window resized) keeps it on


## Whether there is a panel to point on yet (a frame came, and its map has a side).
func framed() -> bool:
	return half.x > 0.0 and half.y > 0.0


## Opens on you (as the next frame has you).
func start() -> void:
	open = true
	_fresh = true
	at = _kept(you)


## Moves the pointer by `delta` px, kept on the panel.
func move(delta: Vector2) -> void:
	_fresh = false
	at = _kept(at + delta)


## The field's point under the pointer: x and z from the panel, y the floor shown.
func world() -> Vector3:
	return Vector3(centre.x + at.x / ppm, floor_y, centre.y + at.y / ppm)


## Closed.
func close() -> void:
	open = false
	_fresh = false


func _kept(p: Vector2) -> Vector2:
	return p.clamp(-half, half)
