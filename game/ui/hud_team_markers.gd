class_name HudTeamMarkers
extends Control
## Teammate markers (concept `hud-feed.png`): a chevron in your team's colour over each teammate still in the field,
## seen through cover too (hollow while the level hides their head and chest), grey under a raised hand once they're
## out and walking off; gone once they reach the dead zone. Never over an enemy, never a name. One drawn node per
## teammate, made once; each teammate's line of sight is checked against the level every few frames, staggered. A
## magazine glyph by the chevron of a teammate asking you for one or bringing you one (MH3, HudMagLine.marks).

const SIZE := Vector2(38.0, 29.0)
const HAND := 22.0
const HAND_GAP := 2.0
const OUT_GREY := Color("c9d0db")
## Where the sight checks aim: the eye, and this share of the way up from the feet to it (the chest).
const CHEST_SHARE := 0.65

var _cfg: HudConfig = null
var _body: BodyConfig = null
var _query: WorldQuery = null
var _ids := PackedInt32Array()
var _markers: Array[HudTeamMarker] = []
var _hit := RayHit.new()
var _frame: int = 0
## The HUD's size (Hud.set_hud_size): the view's screen points are divided by it, as the HUD's root is scaled by it.
var hud_size: float = 1.0


## A marker for each of `you`'s teammates in `characters`, checked against `query` with `body`'s heights.
func setup(cfg: HudConfig, body: BodyConfig, query: WorldQuery, characters: Array[Character], you: Character) -> void:
	name = "HudTeamMarkers"
	_cfg = cfg
	_body = body
	_query = query
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c in characters:
		if c.team != you.team or c.id == you.id:
			continue
		var m := HudTeamMarker.new(SIZE, HAND, HAND_GAP)
		m.fit_mag(cfg.mag_glyph, cfg.mag_glyph_gap, cfg.mag_glyph_lean)
		m.visible = false
		add_child(m)
		_markers.append(m)
		_ids.append(c.id)


## Places the markers as `camera` sees them in `colour`, `fraction` of the way from the last tick to this one;
## `watched` (whose eyes the camera is) gets none, and `show` false hides them all (the scoreboard is up). A teammate
## whose id is 1 in `mags` gets the magazine glyph (empty: none do).
func place(camera: Camera3D, characters: Array[Character], watched: Character, colour: Color, fraction: float,
		show: bool, mags: PackedByteArray = PackedByteArray()) -> void:
	_frame += 1
	var eye := camera.global_position
	for i in _markers.size():
		var m := _markers[i]
		var c := characters[_ids[i]]
		var shown := show and c.id != watched.id and c.status != Character.Status.OUT
		var at := c.prev_position.lerp(c.position, fraction)
		var head := Character.eye_height(c.crouch_amount, _body)
		var top := at + Vector3.UP * (head + _cfg.team_marker_lift)
		shown = shown and not camera.is_position_behind(top)
		m.visible = shown
		if not shown:
			continue
		if (_frame + i) % maxi(1, _cfg.team_marker_check) == 0:
			m.hollow = _query.sight_ray(eye, at + Vector3.UP * head, _hit) \
					and _query.sight_ray(eye, at + Vector3.UP * (head * CHEST_SHARE), _hit)
		var out := not Elimination.is_in_play(c)
		m.set_look(OUT_GREY if out else colour, out)
		m.mag = not out and c.id < mags.size() and mags[c.id] == 1
		var p := camera.unproject_position(top) / hud_size
		m.position = Vector2(p.x - m.size.x * 0.5, p.y - m.size.y)


## Whether character `id`'s marker shows, hollow, and out (grey with the hand): for tests.
func is_shown(id: int) -> bool:
	var i := _ids.find(id)
	return i >= 0 and _markers[i].visible


func is_hollow(id: int) -> bool:
	return is_shown(id) and _markers[_ids.find(id)].hollow


func is_out(id: int) -> bool:
	return is_shown(id) and _markers[_ids.find(id)].out


## Whether character `id`'s marker shows with the magazine glyph: for tests.
func has_mag(id: int) -> bool:
	return is_shown(id) and _markers[_ids.find(id)].mag


## How many markers there are (one per teammate).
func count() -> int:
	return _markers.size()
