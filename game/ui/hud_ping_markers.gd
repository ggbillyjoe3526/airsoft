class_name HudPingMarkers
extends Control
## Your team's ping markers on the HUD (PN2; concept `step27/ping.png`): one HudPingMarker for each character of your
## team, you included, made once a session and refilled from the ping book (Pings) each frame. A spot's ring sits
## HudConfig.ping_spot_height over its floor spot, a contact's diamond HudConfig.ping_contact_lift over the enemy's chest
## where they were seen (so over their head; it never follows them). Off the screen's side or behind you a marker is
## pinned inside the edge as the flag marker is: on the left under the minimap and whatever is pinned there already
## (Stack), going to the right when the left would reach the feed. Reads the book; owns no rule. A frame with no ping
## up allocates nothing.

## Where markers pinned at a side go (Hud fills it after the flag and Hold here's markers): `left` the top left of the
## left stack's next plate, `floor_y` how low it may reach, `right_top` the top of the right stack's next plate and
## `right_x` a right plate's gap from the screen's right edge.
class Stack:
	extends RefCounted

	var left := Vector2.ZERO
	var floor_y: float = INF
	var right_top: float = 0.0
	var right_x: float = 0.0


## The HUD's size (Hud.set_hud_size): the view's screen points are divided by it, as the HUD's root is scaled by it.
var hud_size: float = 1.0
## Whether markers pop in (false under Reduced motion: whole at once).
var pops: bool = true

var _cfg: HudConfig = null
var _life: float = 0.0
var _own := Color.WHITE
var _other := Color.WHITE
var _team: int = -1
var _ids := PackedInt32Array()
var _markers: Array[HudPingMarker] = []


## A marker for each of `you`'s team in `characters`, a ping showing `life` s (PingConfig.lifetime); spots in `own`
## (your team's colour), contacts in `other` (the other team's).
func setup(cfg: HudConfig, life: float, characters: Array[Character], you: Character, own: Color,
		other: Color) -> void:
	name = "HudPingMarkers"
	_cfg = cfg
	_life = life
	_own = own
	_other = other
	_team = you.team
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c in characters:
		if c.team != you.team:
			continue
		var m := HudPingMarker.new()
		add_child(m)
		m.setup(cfg)
		_markers.append(m)
		_ids.append(c.id)


## Places the pings in `book` up at `now` (s of match time) as `camera` sees them inside `area` (the HUD's size), the
## pinned ones in `stack`; all hidden when `show` is false.
func place(camera: Camera3D, book: Pings, now: float, show: bool, area: Vector2, stack: Stack) -> void:
	if not show or book == null:
		hide_all()
		return
	var eye := camera.global_position
	var left_y := stack.left.y
	var right_y := stack.right_top
	for i in _markers.size():
		var m := _markers[i]
		var p := book.of(_ids[i])
		var up := p != null and p.team == _team and book.is_up(p, now)
		m.visible = up
		if not up:
			continue
		var contact := p.kind == Pings.Kind.CONTACT
		var anchor := p.point + Vector3.UP * _cfg.ping_contact_lift if contact \
				else p.spot + Vector3.UP * _cfg.ping_spot_height
		m.set_ping(p.kind, _other if contact else _own, roundi(Vector2(anchor.x - eye.x, anchor.z - eye.z).length()),
				p.ask)
		m.set_age(now - p.at, _life, pops)
		var behind := camera.is_position_behind(anchor)
		var at := Vector2.ZERO if behind else camera.unproject_position(anchor) / hud_size
		if not behind and at.x >= 0.0 and at.x <= area.x:
			var edge := _cfg.ping_marker_edge
			m.put_on_field(Vector2(at.x, clampf(at.y, edge, area.y - edge)))
			continue
		var to_left := camera.global_basis.x.dot(anchor - eye) < 0.0 if behind else at.x < 0.0
		var plate := m.plate_size()
		if to_left and left_y + plate.y <= stack.floor_y:
			m.put_on_edge(Vector2(stack.left.x, left_y), true)
			left_y += plate.y + _cfg.ping_stack_gap
		else:
			m.put_on_edge(Vector2(area.x - stack.right_x - plate.x, right_y), to_left)
			right_y += plate.y + _cfg.ping_stack_gap


## Hides every marker (a pause, the scoreboard, someone else's eyes).
func hide_all() -> void:
	for m in _markers:
		m.visible = false


## How many markers show, and how many there are (one per character of your team): for tests.
func shown() -> int:
	var n := 0
	for m in _markers:
		if m.visible:
			n += 1
	return n


func count() -> int:
	return _markers.size()


## Character `id`'s marker (null for one not of your team).
func marker_of(id: int) -> HudPingMarker:
	var i := _ids.find(id)
	return _markers[i] if i >= 0 else null
