class_name GrenadeGlyph
extends Control
## A bomb's icon, drawn as its canister (GrenadeView's colours): a rounded can with a cap and its spoon, a smoke's with
## two bands round it and a flash's with a row of vents. Drawn to the control's size, kept in shape and centred; the
## Loadout's Grenades panel shows one a bomb, the HUD can share it.

## The can's shape as shares of the glyph's height: its width, the cap's height and width, the spoon's length out from
## the cap, the corner's radius, and the line width (px at a 48 px glyph).
const CAN_WIDTH := 0.5
const CAP_HEIGHT := 0.14
const CAP_WIDTH := 0.34
const SPOON := 0.22
const CORNER := 0.12
const LINE := 2.0
const LINE_AT := 48.0
## A smoke's bands (centre heights as shares of the can) and their thickness; a flash's vents (how many, their size).
const BANDS: Array[float] = [0.38, 0.62]
const BAND := 0.07
const VENTS := 3
const VENT := 0.07
## The cap's and the marks' colours.
const CAP := Color("c9ccd2")
const MARK := Color(0.0, 0.0, 0.0, 0.35)

## The can's face, kept: a draw sets its colour and corners.
var _face := StyleBoxFlat.new()
var kind: int = Grenade.Kind.SMOKE:
	set(value):
		kind = value
		queue_redraw()


func _init(kind_in: int = Grenade.Kind.SMOKE, side: float = 48.0) -> void:
	kind = kind_in
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var h := minf(size.x, size.y)
	var origin := (size - Vector2(h, h)) * 0.5
	var line := LINE * h / LINE_AT
	var body_colour: Color = GrenadeView.BODY_COLOURS[kind]
	var cap := Rect2(origin + Vector2((h - CAP_WIDTH * h) * 0.5, 0.0), Vector2(CAP_WIDTH * h, CAP_HEIGHT * h))
	draw_rect(cap, CAP)
	# the spoon down the can's side from the cap
	var spoon_top := cap.position + Vector2(cap.size.x, cap.size.y * 0.5)
	draw_line(spoon_top, spoon_top + Vector2(0.0, SPOON * h), CAP, line)
	var can := Rect2(origin + Vector2((h - CAN_WIDTH * h) * 0.5, CAP_HEIGHT * h), Vector2(CAN_WIDTH * h,
			(1.0 - CAP_HEIGHT) * h))
	_face.bg_color = body_colour
	_face.set_corner_radius_all(int(CORNER * h))
	draw_style_box(_face, can)
	if kind == Grenade.Kind.SMOKE:
		for at: float in BANDS:
			var y := can.position.y + can.size.y * at
			draw_rect(Rect2(can.position.x, y - BAND * h * 0.5, can.size.x, BAND * h), MARK)
	else:
		var step := can.size.x / float(VENTS + 1)
		for i in VENTS:
			var c := Vector2(can.position.x + step * (i + 1), can.position.y + can.size.y * 0.42)
			draw_circle(c, VENT * h * 0.5, MARK)
