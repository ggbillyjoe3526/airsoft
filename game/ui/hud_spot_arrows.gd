class_name HudSpotArrows
extends Control
## Spotted's arrows (CW1, owner 2026-11-15): a small yellow arrow pointing down over the head of each enemy your team
## spotted (Spots), seen through walls and cover, following them as they move, for as long as they stay marked; it
## fades over the last HudConfig.spot_fade of it. Only arrows in front of the camera and on the screen are drawn. One
## canvas item for all of them; a frame allocates nothing (the points are kept in arrays made once a match).

## The arrow's dark edge (px) and its alpha.
const EDGE := 2.0
const EDGE_ALPHA := 0.85

## The HUD's size (Hud.set_hud_size): the view's screen points are divided by it, as the HUD's root is scaled by it.
var hud_size: float = 1.0
var _cfg: HudConfig = null
var _sim: SimTuning = null
var _characters: Array[Character] = []
var _team: int = 0
## The arrows to draw this frame: their tips (px) and alphas, the first `_count` of each.
var _tips := PackedVector2Array()
var _alphas := PackedFloat32Array()
var _count: int = 0
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _ring := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


## Arrows over `characters` spotted by `player`'s team, placed with `sim`'s bodies and `cfg`'s numbers.
func setup(cfg: HudConfig, sim: SimTuning, characters: Array[Character], player: Character) -> void:
	_cfg = cfg
	_sim = sim
	_characters = characters
	_team = player.team
	name = "HudSpotArrows"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tips.resize(characters.size())
	_alphas.resize(characters.size())


## Each frame: the enemies `spots` marks for your team at `now` (s of match time), as `camera` sees them `fraction` of
## the way from the last tick to this one (as their figures are drawn: an arrow placed by the tick alone shook over a
## running head, BP9), on an `area` the HUD's size; none when `show` is false.
func place(camera: Camera3D, spots: Spots, now: float, show: bool, area: Vector2, fraction: float = 1.0) -> void:
	var was := _count
	_count = 0
	if show and spots != null and camera != null and _cfg != null:
		for c in _characters:
			if c.team == _team or spots.spotted_by(c.id) != _team or not spots.is_spotted(c.id, now) \
					or not Elimination.is_in_play(c):
				continue
			var head := Lean.eye(c, _sim.body, _sim.hits) + Vector3.UP * _cfg.spot_arrow_lift \
					+ (c.prev_position.lerp(c.position, fraction) - c.position)
			if camera.is_position_behind(head):
				continue
			var at := camera.unproject_position(head) / hud_size
			if at.x < 0.0 or at.y < 0.0 or at.x > area.x or at.y > area.y or _count >= _tips.size():
				continue
			_tips[_count] = at
			_alphas[_count] = clampf(spots.time_left(c.id, now) / maxf(_cfg.spot_fade, 0.001), 0.0, 1.0)
			_count += 1
	if _count > 0 or was > 0:
		queue_redraw()


## How many arrows are drawn now, and the tip of arrow `i` (px), for tests.
func count() -> int:
	return _count


func tip(i: int) -> Vector2:
	return _tips[i] if i >= 0 and i < _count else Vector2.ZERO


func _draw() -> void:
	if _cfg == null:
		return
	var half := _cfg.spot_arrow_size.x * 0.5
	var tall := _cfg.spot_arrow_size.y
	for i in _count:
		var tip_at := _tips[i]
		_tri[0] = tip_at + Vector2(-half, -tall)
		_tri[1] = tip_at + Vector2(half, -tall)
		_tri[2] = tip_at
		_ring[0] = _tri[0]
		_ring[1] = _tri[1]
		_ring[2] = _tri[2]
		_ring[3] = _tri[0]
		var a := _alphas[i]
		draw_colored_polygon(_tri, Color(_cfg.spot_colour, _cfg.spot_colour.a * a))
		draw_polyline(_ring, Color(GameTheme.BG, EDGE_ALPHA * a), EDGE, true)
