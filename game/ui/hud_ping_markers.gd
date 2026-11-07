class_name HudPingMarkers
extends Control
## Your team's ping markers on the HUD (PN2; concept `step27/ping.png`): one HudPingMarker for each character of your
## team, you included, made once a session and refilled from the ping book (Pings) each frame. A spot's ring sits
## HudConfig.ping_spot_height over its floor spot, a contact's diamond HudConfig.ping_contact_lift over the enemy's chest
## where they were seen (so over their head; it never follows them). Off the screen's side or behind you a marker is
## pinned inside the edge as the flag marker is: on the left under the minimap and whatever is pinned there already
## (Stack), going to the right when the left would reach the feed. Over the field, markers that meet each other or Hold
## here's plate step apart up and down, eased (HudConfig.ping_clear_gap and ping_clear_rate). Reads the book; owns no
## rule. A frame with no ping up allocates nothing.

## Where markers pinned at a side go (Hud fills it after the flag and Hold here's markers): `left` the top left of the
## left stack's next plate, `floor_y` how low it may reach, `right_top` the top of the right stack's next plate and
## `right_x` a right plate's gap from the screen's right edge; `avoid` Hold here's plate (no size: none), which markers
## over the field step clear of.
class Stack:
	extends RefCounted

	var left := Vector2.ZERO
	var floor_y: float = INF
	var right_top: float = 0.0
	var right_x: float = 0.0
	var avoid := Rect2()

## Rounds of pushing overlapping markers apart each frame: enough for a team's few to settle.
const CLEAR_PASSES := 4


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
## Per marker, made once: over the field this frame (1) or not (0) and the frame before; where put_on_field put it
## (top left, px); how far it is nudged up (-) or down (px) now and is to go; when it was last placed (s).
var _on_field := PackedByteArray()
var _was_on_field := PackedByteArray()
var _base := PackedVector2Array()
var _nudge := PackedFloat32Array()
var _goal := PackedFloat32Array()
var _last_now: float = -1.0


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
	var n := _markers.size()
	_on_field.resize(n)
	_was_on_field.resize(n)
	_base.resize(n)
	_nudge.resize(n)
	_goal.resize(n)
	_on_field.fill(0)
	_was_on_field.fill(0)
	_nudge.fill(0.0)


## Places the pings in `book` up at `now` (s of match time) as `camera` sees them inside `area` (the HUD's size), the
## pinned ones in `stack`; all hidden when `show` is false.
func place(camera: Camera3D, book: Pings, now: float, show: bool, area: Vector2, stack: Stack) -> void:
	if not show or book == null:
		hide_all()
		return
	var eye := camera.global_position
	var left_y := stack.left.y
	var right_y := stack.right_top
	_on_field.fill(0)
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
			_on_field[i] = 1
			_base[i] = m.position
			continue
		var to_left := camera.global_basis.x.dot(anchor - eye) < 0.0 if behind else at.x < 0.0
		var plate := m.plate_size()
		if to_left and left_y + plate.y <= stack.floor_y:
			m.put_on_edge(Vector2(stack.left.x, left_y), true)
			left_y += plate.y + _cfg.ping_stack_gap
		else:
			m.put_on_edge(Vector2(area.x - stack.right_x - plate.x, right_y), to_left)
			right_y += plate.y + _cfg.ping_stack_gap
	_clear(area, stack.avoid, now)


## Steps the markers over the field clear of each other and of `avoid` (Hold here's plate) up and down: each pair that
## meets is pushed apart by half what they overlap (the plate by all of it), a few rounds, then each eases to where that
## puts it (at once on its first frame over the field, or with no pop: Reduced motion). Kept inside `area` as it is
## pushed: one against the screen's top or bottom leaves the whole step to the other, and a marker with no room above
## the plate goes under it.
func _clear(area: Vector2, avoid: Rect2, now: float) -> void:
	var n := _markers.size()
	var gap := _cfg.ping_clear_gap
	var dodge := avoid.has_area()
	_goal.fill(0.0)
	for pass_i in CLEAR_PASSES:
		var moved := false
		for i in n:
			if _on_field[i] == 0:
				continue
			var a := _rect(i)
			for j in range(i + 1, n):
				if _on_field[j] == 0:
					continue
				var b := _rect(j)
				if a.position.x >= b.end.x + gap or b.position.x >= a.end.x + gap:
					continue
				var a_up := a.get_center().y <= b.get_center().y
				var need := (a.end.y + gap - b.position.y) if a_up else (b.end.y + gap - a.position.y)
				if need <= 0.0:
					continue
				# the upper one goes up, the lower down, each by half, as far as the screen lets it
				var top := i if a_up else j
				var low := j if a_up else i
				var up_room := maxf(_base[top].y + _goal[top], 0.0)
				var down_room := maxf(area.y - _markers[low].size.y - _base[low].y - _goal[low], 0.0)
				var up := minf(need * 0.5, up_room)
				var down := minf(need - up, down_room)
				up = minf(need - down, up_room)
				_goal[top] -= up
				_goal[low] += down
				a = _rect(i)
				moved = moved or up + down > 0.0
			if dodge and a.position.x < avoid.end.x + gap and avoid.position.x < a.end.x + gap:
				var above := a.get_center().y <= avoid.get_center().y
				if above and a.end.y + gap - avoid.position.y > a.position.y:
					above = false # no room over the plate: under it
				var need := (a.end.y + gap - avoid.position.y) if above else (avoid.end.y + gap - a.position.y)
				if need > 0.0:
					_goal[i] += -need if above else need
					moved = true
		if not moved:
			break
	var dt := maxf(now - _last_now, 0.0) if _last_now >= 0.0 else 0.0
	_last_now = now
	var k := 1.0 - exp(-_cfg.ping_clear_rate * dt)
	for i in n:
		if _on_field[i] == 0:
			_nudge[i] = 0.0
			_was_on_field[i] = 0
			continue
		var m := _markers[i]
		var goal := clampf(_base[i].y + _goal[i], 0.0, maxf(area.y - m.size.y, 0.0)) - _base[i].y
		_nudge[i] = goal if _was_on_field[i] == 0 or not pops else lerpf(_nudge[i], goal, k)
		_was_on_field[i] = 1
		if _nudge[i] != 0.0:
			m.position.y = _base[i].y + _nudge[i]


## Marker `i`'s rect over the field where it is to go this frame.
func _rect(i: int) -> Rect2:
	return Rect2(_base[i] + Vector2(0.0, _goal[i]), _markers[i].size)


## How far marker `i` is nudged up (-) or down (px) clear of the others now: for tests.
func nudge_of(i: int) -> float:
	return _nudge[i]


## Hides every marker (a pause, the scoreboard, someone else's eyes).
func hide_all() -> void:
	for m in _markers:
		m.visible = false
	_was_on_field.fill(0)


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
