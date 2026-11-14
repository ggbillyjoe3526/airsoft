class_name HopArc
extends Control
## The hop-up's flight on the Customise page (concept `.arc`): a level shot's height against the aim line (dashed) out to the
## readout's range, drawn in yellow, with a line where it leaves the "on target" band and the words "on target to 44 m".
## The path is flown by Ballistics when the settings change (`show_shot`), never per frame.

const HEIGHT := 120.0
const PAD := Vector2(20.0, 14.0)
## The window of heights drawn (m): how far above and below the aim line.
const RISE := 2.5
const FALL := 3.0
const STEP := 1.0
const PATH_WIDTH := 4.0
const AIM_WIDTH := 2.0
const MARK_WIDTH := 2.0
const DASH := 6.0
const LABEL_SIZE := 16
const LABEL_GAP := 10.0
const LABEL_TOP := 6.0
## The space between the lines in the box's lower corner (px).
const LABEL_LEADING := 4.0

var _heights: PackedFloat32Array = PackedFloat32Array()
var _range: float = 1.0
var _on_target: float = 0.0
var _label: String = ""


func _init() -> void:
	name = "HopArc"
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The words drawn beside the marker (a line each, split at "\n").
func label() -> String:
	return _label


## The path's heights (m, one a metre from the muzzle); empty until shown.
func heights() -> PackedFloat32Array:
	return _heights


## Flies a level shot from `replica` with its dial at `dial` and `grams` BBs, for `range_limit` m, and marks `on_target`
## m (the reach `Ballistics.hop_up_reach` found). `words` is the label ("on target to 44 m"); `field_air` the field's air
## the reach was found in (FieldAir, AUD2), or null for the rated.
func show_shot(replica: ReplicaConfig, dial: float, grams: float, tuning: SimTuning, range_limit: float,
		on_target: float, words: String, field_air: AirModel = null) -> void:
	_range = range_limit
	_on_target = on_target
	_label = words
	_heights = PackedFloat32Array()
	var rules := tuning.replica_rules
	var cfg := tuning.ballistics
	var bb := BBPool.new(1).spawn(0, Vector3.ZERO, Vector3.FORWARD, Ballistics.muzzle_velocity(replica, rules, grams),
			Ballistics.hop_up_lift(replica, dial, rules), Ballistics.bb_mass(replica, grams), cfg.spin_per_hop)
	var air := field_air if field_air != null else AirModel.of(cfg)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var next := 0.0
	while bb.age < cfg.max_lifetime and next <= range_limit:
		Ballistics.step_flight(bb, air, dt)
		while -bb.position.z >= next and next <= range_limit:
			_heights.append(bb.position.y)
			next += STEP
	queue_redraw()


func _draw() -> void:
	var box := GameTheme.box(GameTheme.PANEL, GameTheme.LINE, 0, 0)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var left := PAD.x
	var width := size.x - PAD.x * 2.0
	var top := PAD.y
	var span := size.y - PAD.y * 2.0
	var aim_y := top + span * RISE / (RISE + FALL)
	var scale_y := span / (RISE + FALL)
	draw_dashed_line(Vector2(left, aim_y), Vector2(left + width, aim_y), GameTheme.DIM, AIM_WIDTH, DASH)
	if _heights.size() >= 2:
		var points := PackedVector2Array()
		for i in _heights.size():
			var h := clampf(_heights[i], -FALL, RISE)
			points.append(Vector2(left + width * float(i) * STEP / _range, aim_y - h * scale_y))
		draw_polyline(points, GameTheme.ACCENT, PATH_WIDTH, true)
	var mark_x := left + width * clampf(_on_target / _range, 0.0, 1.0)
	draw_line(Vector2(mark_x, top), Vector2(mark_x, size.y - PAD.y), GameTheme.MUTED, MARK_WIDTH)
	# The words beside the marker, kept inside the box; a second line (the field's air, AUD2) sits in the box's lower
	# left corner, under the flight's level part, clear of the aim line the first one stands over.
	var font := GameTheme.font(800)
	var lines := _label.split("\n")
	var words_width := font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var at_x := mark_x + LABEL_GAP
	if at_x + words_width > size.x - PAD.x:
		at_x = maxf(PAD.x, mark_x - LABEL_GAP - words_width)
	draw_string(font, Vector2(at_x, top + LABEL_TOP + LABEL_SIZE), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
			LABEL_SIZE, GameTheme.TEXT)
	for i in range(1, lines.size()):
		var up := lines.size() - 1 - i
		draw_string(font, Vector2(PAD.x, size.y - PAD.y - (LABEL_SIZE + LABEL_LEADING) * up), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, GameTheme.MUTED)
