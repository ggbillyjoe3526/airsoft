class_name RangeTargetsView
extends Node3D
## The practice range's targets (the browser game's RANGE_VISUALS, M21 and M93; their Blender models RM1, RangeModels),
## drawn from GameState.targets between the last two ticks: white steel plates hung on a pin from a timber post in an
## H-stand, swinging back and settling when hit; flat plywood cut-outs in a peg figure's outline, the size of a player's
## hit volume, on a hinge plate, falling back on their hinge when hit and standing up at the end of their time down;
## a mover's rails, end stops and trolley, a pop-up's motor box, a swinger's frame and arm. The timed challenge's lit
## targets glow orange and its START plate stands only while the challenge waits for it. Scenery only: BBs meet the
## targets in the simulation (RangeTargets), never these nodes. Built once a session; a frame only moves nodes and swaps
## a lit target's paint when it changes, allocating nothing.


## One target's nodes.
class Drawn:
	extends RefCounted
	## At its home on the floor, turned by its yaw: hidden with the target.
	var root: Node3D = null
	## A mover's trolley and figure, slid along its track; else still at the root.
	var carrier: Node3D = null
	## What turns: a plate's hanger (its swing when hit), a swinger's arm pivot, a figure's hinge.
	var pivot: Node3D = null
	## The painted faces that light in the timed challenge, and their paint when not lit.
	var faces: Array[MeshInstance3D] = []
	var paint: Material = null
	var lit: bool = false
	## Seconds since a still plate was hit (its swing); INF when it hangs still.
	var hit_age: float = INF


var _cfg: RangeViewConfig = null
var _range: RangeConfig = null
var _drawn: Array[Drawn] = []
var _steel_parts: RangeModels = null
var _figure_parts: RangeModels = null
## The models' vertex colours, the challenge's lit paint and the START plate's.
var _paint: ShaderMaterial = null
var _lit: StandardMaterial3D = null
var _start: StandardMaterial3D = null
## The plate's radius as modelled (the models' Face; a target's own radius scales it).
var _model_radius: float = 0.0


## Builds `targets` as laid out (`tuning`: their sizes and a figure's hit volume), the START plate's word in `font`.
func setup(targets: Array[RangeTarget], cfg: RangeViewConfig, tuning: SimTuning, font: Font) -> void:
	name = "RangeTargets"
	_cfg = cfg
	_range = tuning.targets
	_steel_parts = RangeModels.read(cfg.steel_model)
	_figure_parts = RangeModels.read(cfg.figure_model)
	_model_radius = _steel_parts.bounds(&"Face").size.x * 0.5
	_paint = LookMaterials.vertex_colour(cfg.model_roughness, 0.0)
	_start = _flat(cfg.start_paint, cfg.start_roughness)
	_lit = _flat(cfg.lit_colour, cfg.lit_roughness)
	_lit.emission_enabled = true
	_lit.emission = cfg.lit_colour
	_lit.emission_energy_multiplier = cfg.lit_glow
	for t in targets:
		var d := Drawn.new()
		d.root = Node3D.new()
		d.root.name = "Target_%d" % t.id
		d.root.position = Vector3(t.home.x, t.floor_y, t.home.z)
		d.root.rotation.y = t.yaw
		add_child(d.root)
		d.carrier = Node3D.new()
		d.root.add_child(d.carrier)
		if t.kind == RangeTarget.Kind.FIGURE:
			_build_figure(t, d, tuning)
		elif t.motion == RangeTarget.Motion.SWINGER:
			_build_swinger(t, d)
		else:
			_build_plate(t, d, font)
		_drawn.append(d)


## The materials drawn first (ShaderPrewarm), so a target's first light never hitches.
func materials() -> Array[Material]:
	return [_paint, _lit, _start]


## The tick's events: a still plate that's hit starts its swing.
func on_tick(state: GameState) -> void:
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		if e.kind == GameEvent.Kind.TARGET_HIT and e.target >= 0 and e.target < _drawn.size() \
				and e.value == RangeTarget.Kind.STEEL:
			_drawn[e.target].hit_age = 0.0


## Draws `targets` `fraction` of the way from the last tick to this one, `delta` seconds after the last frame.
func update(targets: Array[RangeTarget], fraction: float, delta: float) -> void:
	for i in mini(targets.size(), _drawn.size()):
		var t := targets[i]
		var d := _drawn[i]
		d.root.visible = not t.hidden
		if t.hidden:
			continue
		var lit := t.lit > 0.0
		if lit != d.lit:
			d.lit = lit
			for face in d.faces:
				face.material_override = _lit if lit else d.paint
		match t.motion:
			RangeTarget.Motion.MOVER:
				# Along its own x: the world offset from home turned back by its yaw.
				var at := t.prev_position.lerp(t.position, fraction) - t.home
				d.carrier.position.x = at.x * t.face_z - at.z * t.face_x
			RangeTarget.Motion.SWINGER:
				d.pivot.rotation.z = RangeTargets.swing_angle(lerpf(t.prev_clock, t.clock, fraction), _range)
		if t.kind != RangeTarget.Kind.FIGURE and t.motion == RangeTarget.Motion.SWINGER:
			continue
		var tilt := -fall_angle(t, _cfg, _range) if t.kind == RangeTarget.Kind.FIGURE else _swing(d, delta)
		# Written only when it changes: a still target's children aren't sent to the renderer again every frame.
		if d.pivot.rotation.x != tilt:
			d.pivot.rotation.x = tilt


## How far a figure lies back on its hinge (rad): falling over fall_time from the start of its time down, flat
## (down_angle) until the last rise_time, then rising; 0 standing.
static func fall_angle(t: RangeTarget, cfg: RangeViewConfig, range_cfg: RangeConfig) -> float:
	if t.down <= 0.0:
		return 0.0
	var fallen := t.down_for - t.down
	if fallen < cfg.fall_time:
		return cfg.down_angle * fallen / cfg.fall_time
	if t.down < range_cfg.rise_time:
		return cfg.down_angle * t.down / range_cfg.rise_time
	return cfg.down_angle


## A plate's swing back on its hanger since it was hit (rad), dying away; 0 once it hangs still again.
func _swing(d: Drawn, delta: float) -> float:
	if is_inf(d.hit_age):
		return 0.0
	d.hit_age += delta
	var size := exp(-_cfg.swing_damping * d.hit_age)
	if size < _cfg.swing_still:
		d.hit_age = INF
		return 0.0
	return _cfg.swing_angle * size * sin(_cfg.swing_rate * d.hit_age)


## A still plate (the START plate too): its post in its H-stand behind it, the bracket on the post's top with the pin
## the plate hangs from by its hooked neck, swinging back on it when hit.
func _build_plate(t: RangeTarget, d: Drawn, font: Font) -> void:
	var centre := t.home.y - t.floor_y
	var post_top := t.posts[0].y - t.floor_y
	var post := Vector3(0.0, 0.0, -_range.post_behind)
	_steel_parts.add(d.root, &"Base", post, _paint)
	_steel_parts.add(d.root, &"Post", post, _paint, Vector3(1.0, post_top, 1.0))
	_steel_parts.add(d.root, &"Bracket", post + Vector3(0.0, post_top, 0.0), _paint)
	d.pivot = Node3D.new()
	d.pivot.position = Vector3(0.0, post_top, 0.0)
	d.root.add_child(d.pivot)
	_steel_parts.add(d.pivot, &"Hanger", Vector3.ZERO, _paint)
	var plate := _face(d.pivot, t.radius, Vector3(0.0, centre - post_top, 0.0))
	if t.start:
		plate.material_override = _start
		d.paint = _start
		var word := RangeView.painted_words(tr("RANGE_START_PLATE"), _cfg.start_text_share * t.radius * 2.0,
				_cfg.start_ink, font, _cfg.text_font_size)
		word.position = Vector3(0.0, centre - post_top, _cfg.start_text_lift)
		d.pivot.add_child(word)
	else:
		d.paint = _paint
		d.faces.append(plate)


## A swinger: its frame's two legs on their splayed feet and the bar across their tops, the bearing at the bar's
## middle, and the plate on its arm swinging from the pin there.
func _build_swinger(t: RangeTarget, d: Drawn) -> void:
	var w := _range.swinger_frame_width
	var top := t.posts[0].y - t.floor_y
	for p in t.posts:
		_steel_parts.add(d.root, &"SwingLeg", Vector3(p.x, 0.0, p.z), _paint, Vector3(1.0, top, 1.0))
		_steel_parts.add(d.root, &"SwingFoot", Vector3(p.x, 0.0, p.z), _paint)
	var span := absf(t.posts[1].x - t.posts[0].x) + w
	_steel_parts.add(d.root, &"SwingBar", Vector3(-span * 0.5, top - w * 0.5, t.posts[0].z), _paint,
			Vector3(span, 1.0, 1.0))
	var arm := _range.swinger_arm
	var pivot_at := Vector3(0.0, t.home.y - t.floor_y + arm, 0.0)
	_steel_parts.add(d.root, &"SwingPivot", pivot_at, _paint)
	d.pivot = Node3D.new()
	d.pivot.position = pivot_at
	d.root.add_child(d.pivot)
	_steel_parts.add(d.pivot, &"SwingArm", Vector3.ZERO, _paint, Vector3(1.0, arm, 1.0))
	d.paint = _paint
	d.faces.append(_face(d.pivot, t.radius, Vector3(0.0, -arm, 0.0)))


## A flat cut-out figure on its hinge plate, crouched (the cone peg's outline) or not, the size of its hit volume; a
## mover's rails, end stops and trolley under it, a pop-up's motor box beside it. It falls back about its hinge, just
## behind the board.
func _build_figure(t: RangeTarget, d: Drawn, tuning: SimTuning) -> void:
	var cfg := _cfg
	var feet := t.home.y - t.floor_y
	d.carrier.position.y = feet
	if t.motion == RangeTarget.Motion.MOVER:
		_build_rails(t, d)
	elif t.motion == RangeTarget.Motion.POPUP:
		var b := cfg.popup_box
		_figure_parts.add(d.root, &"MotorBox",
				Vector3(tuning.hits.body_radius + cfg.popup_gap + b.x * 0.5, b.y * 0.5, -b.z * 0.5), _paint)
	_figure_parts.add(d.carrier, &"PegBase", Vector3.ZERO, _paint)
	d.pivot = Node3D.new()
	d.pivot.position = Vector3(0.0, tuning.body.rest_gap, -cfg.hinge_behind)
	d.carrier.add_child(d.pivot)
	d.faces.append(_figure_parts.add(d.pivot, &"PegCrouched" if t.crouched else &"Peg", Vector3.ZERO, _paint))
	d.paint = _paint


## A mover's two rails along its track with a stop at each end, and its trolley riding them (on the carrier, under
## the figure's feet).
func _build_rails(t: RangeTarget, d: Drawn) -> void:
	var cfg := _cfg
	var half := t.track + _figure_parts.bounds(&"Trolley").size.x * 0.5
	for side: float in [-1.0, 1.0]:
		_figure_parts.add(d.root, &"Rail", Vector3(0.0, 0.0, side * cfg.rail_gauge * 0.5), _paint,
				Vector3(half * 2.0, 1.0, 1.0))
		var stop := _figure_parts.add(d.root, &"RailStop", Vector3(side * (half + cfg.stop_size.x * 0.5), 0.0, 0.0),
				_paint)
		# Its buffer faces the trolley: modelled for the far (+x) end, turned round for the near one.
		stop.rotation.y = 0.0 if side > 0.0 else PI
	_figure_parts.add(d.carrier, &"Trolley", Vector3.ZERO, _paint)


## A plate's face of `radius` hanging under `parent`, its front face's middle at `at` (where the simulation tests it).
func _face(parent: Node3D, radius: float, at: Vector3) -> MeshInstance3D:
	var k := radius / _model_radius if _model_radius > 0.0 else 1.0
	return _steel_parts.add(parent, &"Face", at, _paint, Vector3(k, k, 1.0))


static func _flat(colour: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	return m
