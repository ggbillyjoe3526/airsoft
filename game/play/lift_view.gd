class_name LiftView
extends Node3D
## The lifts (MT2; MapData.lifts), greybox: each car a painted steel box (floor, roof, back and side walls, its front
## beside the door, a ceiling strip, its lamp and an interior reflection probe, as the shafts lie outside the areas'
## probes), drawn between ticks where the car rides; two steel leaves sliding apart in each landing's doorway (into the
## wall) and two in the car's front; a call button beside each landing door and the car's panel, a button and its
## stop's name a stop, lit white while that stop is called. The leaves are one MultiMesh and the buttons another (one
## draw call each), each car one mesh of its own. Reads GameState.lifts each frame and moves only what changed;
## nothing here is read by the simulation (the colliders are MapLevel's). Built once; a frame allocates nothing.

## MapStyle's colours: the car's steel, the doors' darker steel, a button unlit and lit, the car's ceiling strip.
const CAR_KIND := &"lift_car"
const DOOR_KIND := &"lift_door"
const BUTTON_KIND := &"lift_button"
const LIT_KIND := &"lift_lit"
const STRIP_KIND := &"lift_strip"

var _cfg: LiftViewConfig = null
var _lift_cfg: LiftConfig = null
var _specs: Array[LiftSpec] = []
## Each car's node (its origin the middle of its floor's top) and lamp.
var _cars: Array[Node3D] = []
var _lamps: Array[OmniLight3D] = []
var _probes: Array[ReflectionProbe] = []
var _leaves: MultiMeshInstance3D = null
var _buttons: MultiMeshInstance3D = null
var _leaf_material: ShaderMaterial = null
var _car_material: ShaderMaterial = null
var _button_material: StandardMaterial3D = null
## The models' material (SM2): their own linear colours, with the sills' ribs and the displays' dots.
var _model_material: ShaderMaterial = null
## The car and landing models, null when unread (LiftViewConfig.car_model); whether each lift is drawn in them.
var _car_mesh: Mesh = null
var _landing_mesh: Mesh = null
var _modelled: Array[bool] = []
var _landings: MultiMeshInstance3D = null
## The landings' lit arrows (SM2), at the landings' transforms, in the buttons' unshaded material.
var _landing_lights: MultiMeshInstance3D = null
## Per lift: its first leaf's instance (each stop's two landing leaves, then the car's two) and its first button's
## (each stop's call button, then its panel's); what was last drawn: the car's height, the doors' opening, the stop
## they open at and the calls.
var _first_leaf: PackedInt32Array = PackedInt32Array()
var _first_button: PackedInt32Array = PackedInt32Array()
var _drawn_y: PackedFloat32Array = PackedFloat32Array()
var _drawn_doors: PackedFloat32Array = PackedFloat32Array()
var _drawn_stop: PackedInt32Array = PackedInt32Array()
var _drawn_calls: PackedInt32Array = PackedInt32Array()
## Each leaf's transform and each button's colour as last placed (the MultiMeshes' copies, which a headless run
## doesn't keep).
var _leaf_xforms: Array[Transform3D] = []
var _button_colours: PackedColorArray = PackedColorArray()
var _unlit: Color = Color.BLACK
var _lit: Color = Color.WHITE


## The lifts of `map` in `style`'s colours, sized by `lifts` (the simulation's) and drawn by `cfg`; null on a map
## without lifts.
static func build(map: MapData, style: MapStyle, lifts: LiftConfig, cfg: LiftViewConfig) -> LiftView:
	if map.lifts.is_empty():
		return null
	var view := LiftView.new()
	view.name = "Lifts"
	view._cfg = cfg
	view._lift_cfg = lifts
	view._specs = map.lifts
	view._unlit = style.colour_of(BUTTON_KIND, 0)
	view._lit = style.colour_of(LIT_KIND, 0)
	view._model_material = LookMaterials.vertex_colour(cfg.roughness, cfg.metallic)
	view._model_material.set_shader_parameter(&"perforations", true)
	var leaf_mesh := PropDressConfig.load_mesh(cfg.leaf_model)
	view._leaf_material = view._model_material if leaf_mesh != null else LookMaterials.paint(
			style.colour_of(DOOR_KIND, 0), cfg.roughness, cfg.metallic)
	view._car_material = LookMaterials.vertex_colour(cfg.roughness, cfg.metallic, Color.WHITE, true)
	view._car_mesh = PropDressConfig.load_mesh(cfg.car_model)
	view._landing_mesh = PropDressConfig.load_mesh(cfg.landing_model)
	view._button_material = StandardMaterial3D.new()
	view._button_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view._button_material.vertex_color_use_as_albedo = true
	var leaves := 0
	var buttons := 0
	for spec in map.lifts:
		view._first_leaf.append(leaves)
		view._first_button.append(buttons)
		leaves += spec.stop_count() * 2 + 2
		buttons += spec.stop_count() * 2
	view._leaves = view._multimesh("Leaves", leaf_mesh if leaf_mesh != null else BoxMesh.new(), leaves, false,
			view._leaf_material)
	view._leaf_xforms.resize(leaves)
	view._button_colours.resize(buttons)
	var knob := _scaled(PropDressConfig.load_mesh(cfg.button_model), cfg.button_size)
	if knob == null:
		var box := BoxMesh.new()
		box.size = cfg.button_size
		knob = box
	view._buttons = view._multimesh("Buttons", knob, buttons, true, view._button_material)
	var landings := 0
	for spec in map.lifts:
		var fits := view._fits(spec)
		view._modelled.append(fits)
		landings += spec.stop_count() if fits and view._landing_mesh != null else 0
	if landings > 0:
		view._landings = view._multimesh("Landings", view._landing_mesh, landings, false, view._model_material)
		var lit := PropDressConfig.load_mesh(cfg.landing_lit_model)
		if lit != null:
			view._landing_lights = view._multimesh("LandingLights", lit, landings, true, view._button_material)
		var g := cfg.landing_lit_gain
		var glow := Color(view._lit.r * g, view._lit.g * g, view._lit.b * g, 1.0)
		var j := 0
		for i in map.lifts.size():
			if not view._modelled[i]:
				continue
			var spec := map.lifts[i]
			var mid := (spec.door_from + spec.door_to) * 0.5
			for k in spec.stop_count():
				var at := Transform3D(_turn(spec.out), spec.on_face(mid, spec.door_depth, spec.stops[k]))
				view._landings.multimesh.set_instance_transform(j, at)
				if view._landing_lights != null:
					view._landing_lights.multimesh.set_instance_transform(j, at)
					view._landing_lights.multimesh.set_instance_color(j, glow)
				j += 1
	for i in map.lifts.size():
		view._add_car(i, style)
	var n := map.lifts.size()
	view._drawn_y.resize(n)
	view._drawn_doors.resize(n)
	view._drawn_stop.resize(n)
	view._drawn_calls.resize(n)
	view._drawn_y.fill(NAN)
	view._drawn_calls.fill(-1)
	for i in n:
		var spec := map.lifts[i]
		var k := clampi(spec.start, 0, spec.stop_count() - 1)
		view._place(i, spec.stops[k], k, 1.0, 0)
	return view


## Draws `lifts` (GameState.lifts) `fraction` of the way from the last tick to this one: each car where it rides, its
## doors as open as they stand, its stops' buttons lit while called.
func refresh(lifts: LiftState, fraction: float) -> void:
	for i in mini(lifts.count(), _specs.size()):
		var y := lerpf(lifts.prev_y[i], lifts.y[i], fraction)
		var moving := lifts.phase[i] == LiftState.Phase.MOVING
		var doors := 0.0 if moving else lifts.doors[i]
		_place(i, y, lifts.stop[i], doors, lifts.calls[i])


## Turns the cars' lamps on (the station's lamps light: Settings › Graphics › Lamp lights) or off.
func set_lamps(on: bool) -> void:
	for l in _lamps:
		l.visible = on


## Shows the cars' reflection probes (Settings › Graphics › Reflections on) or hides them.
func set_probes(on: bool) -> void:
	for p in _probes:
		p.visible = on


## The car `i`'s height as last drawn (its floor's top), for tests.
func drawn_y(i: int) -> float:
	return _drawn_y[i]


## Leaf `j`'s transform as last placed (for tests): lift i's leaves from its first, two a stop, then the car's two.
func leaf_at(j: int) -> Transform3D:
	return _leaf_xforms[j]


## The colour button `j` is drawn in (for tests): lift i's from its first, each stop's call button, then its panel's.
func button_colour(j: int) -> Color:
	return _button_colours[j]


## The materials drawn, to warm their shaders before play.
func materials() -> Array[Material]:
	return [_leaf_material, _car_material, _button_material, _model_material]


## Whether lift `spec` is drawn in the car and landing models: its well, door and wall as they were built for, its door
## in the face's middle and its far jamb on the model's right (LiftViewConfig.model_well).
func _fits(spec: LiftSpec) -> bool:
	if _car_mesh == null:
		return false
	var tol := _cfg.model_fit
	var along := spec.well.size.x if spec.along_x() else spec.well.size.y
	var out := spec.well.size.y if spec.along_x() else spec.well.size.x
	var middle := spec.well.get_center().x if spec.along_x() else spec.well.get_center().y
	var right := _turn(spec.out) * Vector3.RIGHT
	return (absf(along - _cfg.model_well.x) <= tol and absf(out - _cfg.model_well.y) <= tol
			and absf(spec.door_to - spec.door_from - _cfg.model_door.x) <= tol
			and absf(spec.door_height - _cfg.model_door.y) <= tol
			and absf((spec.door_from + spec.door_to) * 0.5 - middle) <= tol
			and absf(spec.door_depth - _cfg.model_depth) <= tol
			and absf(_lift_cfg.car_height - _cfg.model_car_height) <= tol
			and right.is_equal_approx(_side_of(spec)))


## The turn about the upright that brings a model built facing -z (its landing, or its car's door) to face `out`.
static func _turn(out: Vector2) -> Basis:
	return Basis(Vector3.UP, atan2(-out.x, -out.y))


## A copy of `mesh` (built in a 1 m cube round its middle) scaled to `size`; null without one.
static func _scaled(mesh: Mesh, size: Vector3) -> Mesh:
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] *= size
	var inv := Vector3(1.0 / size.x, 1.0 / size.y, 1.0 / size.z)
	for i in normals.size():
		normals[i] = (normals[i] * inv).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func _multimesh(node_name: String, mesh: Mesh, count: int, colours: bool, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colours
	mm.mesh = mesh
	mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = material
	add_child(mi)
	return mi


## Car `i`'s node: its body (the car model, SM2, turned to its door; or plain boxes), its panel's stop names, its lamp
## and its probe.
func _add_car(i: int, style: MapStyle) -> void:
	var spec := _specs[i]
	var car := Node3D.new()
	car.name = "Car%d" % i
	add_child(car)
	_cars.append(car)
	var w := spec.well.size
	var h := _lift_cfg.car_height
	var face := spec.out
	var strip := _cfg.strip_size
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	if _modelled[i]:
		mi.mesh = _car_mesh
		mi.basis = _turn(face)
		mi.material_override = _model_material
	else:
		mi.mesh = _box_body(spec, style)
		mi.material_override = _car_material
	car.add_child(mi)
	_add_fittings(car, spec, w, h, face, strip)


## A car's plain body: its walls, floor, roof and ceiling strip one mesh, in `style`'s colours.
func _box_body(spec: LiftSpec, style: MapStyle) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steel := style.colour_of(CAR_KIND, 0)
	var w := spec.well.size
	var h := _lift_cfg.car_height
	var t := _cfg.wall_thickness
	var half := Vector2(w.x * 0.5, w.y * 0.5)
	var middle := spec.well.get_center()
	var face := spec.out
	var back := -face
	# The back wall, the two sides, the floor's top and the roof's underside.
	_box(st, _local(spec, middle + back * (half.dot(back.abs()) - t * 0.5), h * 0.5),
			_across(spec, w, t, h), steel)
	var side := Vector2(face.y, face.x).abs()
	for s: float in [-1.0, 1.0]:
		_box(st, _local(spec, middle + side * s * (half.dot(side) - t * 0.5), h * 0.5), _along(spec, w, t, h), steel)
	_box(st, Vector3(0.0, -_lift_cfg.floor_thickness * 0.5, 0.0), spec.slab_size(_lift_cfg.floor_thickness), steel)
	_box(st, Vector3(0.0, h + _lift_cfg.roof_thickness * 0.5, 0.0), spec.slab_size(_lift_cfg.roof_thickness), steel)
	# The front beside the door, and over it.
	var lo := spec.well.position.x if spec.along_x() else spec.well.position.y
	var hi := spec.well.end.x if spec.along_x() else spec.well.end.y
	for span: Vector2 in [Vector2(lo, spec.door_from), Vector2(spec.door_to, hi)]:
		_front(st, spec, span, 0.0, h, steel)
	_front(st, spec, Vector2(spec.door_from, spec.door_to), spec.door_height, h, steel)
	var strip := _cfg.strip_size
	_box(st, Vector3(0.0, h - strip.y * 0.5, 0.0), Vector3(strip.x, strip.y, strip.z), style.colour_of(STRIP_KIND, 0))
	st.generate_normals()
	return st.commit()


## A car's panel stop names, lamp and probe, on `car`.
func _add_fittings(car: Node3D, spec: LiftSpec, w: Vector2, h: float, face: Vector2, strip: Vector3) -> void:
	for k in spec.stop_count():
		var label := Label3D.new()
		label.name = "Stop%d" % k
		label.text = spec.stop_names[k]
		label.pixel_size = _cfg.label_pixel_size
		label.font_size = _cfg.label_font_size
		label.modulate = _cfg.label_colour
		label.outline_size = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var at := spec.panel_button(k, 0.0, _lift_cfg) - spec.car_point(0.0)
		var into := Vector3(-face.x, 0.0, -face.y)
		label.position = at + into * (_cfg.wall_thickness + _cfg.label_off) + _side_of(spec) * _cfg.label_beside
		label.rotation.y = atan2(into.x, into.z)
		car.add_child(label)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(0.0, h - strip.y - _cfg.lamp_drop, 0.0)
	lamp.omni_range = _cfg.lamp_range
	lamp.light_energy = _cfg.lamp_energy
	lamp.light_color = _cfg.lamp_colour
	lamp.shadow_enabled = false
	car.add_child(lamp)
	_lamps.append(lamp)
	var probe := ReflectionProbe.new()
	probe.name = "Probe"
	probe.position = Vector3(0.0, h * 0.5, 0.0)
	probe.size = Vector3(w.x, h, w.y)
	probe.box_projection = true
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = _cfg.probe_ambient
	probe.ambient_color_energy = _cfg.probe_ambient_energy
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.layers = AreaProbes.LAYER
	car.add_child(probe)
	_probes.append(probe)


## A box in the car's local space (its origin the middle of its floor's top) for a point `at` on the ground and `y` up.
static func _local(spec: LiftSpec, at: Vector2, y: float) -> Vector3:
	var c := spec.well.get_center()
	return Vector3(at.x - c.x, y, at.y - c.y)


## A wall across the door's face (the back) and one along it (a side), `t` thick and `h` high in a well `w`.
static func _across(spec: LiftSpec, w: Vector2, t: float, h: float) -> Vector3:
	return Vector3(w.x, h, t) if spec.along_x() else Vector3(t, h, w.y)


static func _along(spec: LiftSpec, w: Vector2, t: float, h: float) -> Vector3:
	return Vector3(t, h, w.y) if spec.along_x() else Vector3(w.x, h, t)


## The way along the door's face from its near jamb to its far one, level.
static func _side_of(spec: LiftSpec) -> Vector3:
	return Vector3(1.0, 0.0, 0.0) if spec.along_x() else Vector3(0.0, 0.0, 1.0)


## A piece of the car's front over `span` along the door's face, from `y0` to `y1`, just inside the well's edge.
func _front(st: SurfaceTool, spec: LiftSpec, span: Vector2, y0: float, y1: float, colour: Color) -> void:
	if span.y - span.x <= 0.0 or y1 - y0 <= 0.0:
		return
	var t := _cfg.wall_thickness
	var at := spec.on_face((span.x + span.y) * 0.5, -t * 0.5, (y0 + y1) * 0.5) - spec.car_point(0.0)
	var length := span.y - span.x
	_box(st, at, Vector3(length, y1 - y0, t) if spec.along_x() else Vector3(t, y1 - y0, length), colour)


## A box's six faces into `st`, centred at `c` measuring `size`, in `colour`.
static func _box(st: SurfaceTool, c: Vector3, size: Vector3, colour: Color) -> void:
	var h := size * 0.5
	st.set_color(colour)
	for axis in 3:
		for s: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = s
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := n.cross(u)
			var o := c + n * h[axis]
			var du := u * h[(axis + 1) % 3]
			var dv := v * absf(v.dot(h))
			var a := o - du - dv
			var b := o + du - dv
			var cc := o + du + dv
			var d := o - du + dv
			# Wound so the face looks along n.
			st.add_vertex(a)
			st.add_vertex(cc)
			st.add_vertex(b)
			st.add_vertex(a)
			st.add_vertex(d)
			st.add_vertex(cc)


## Draws lift `i` with its car's floor at `y`, its doors `doors` open at `stop` and `calls` called, where any changed.
func _place(i: int, y: float, stop: int, doors: float, calls: int) -> void:
	var spec := _specs[i]
	if y != _drawn_y[i]:
		_cars[i].position = spec.car_point(y)
	if y != _drawn_y[i] or doors != _drawn_doors[i] or stop != _drawn_stop[i]:
		_place_leaves(i, y, stop, doors)
	if calls != _drawn_calls[i] or y != _drawn_y[i]:
		_place_buttons(i, y, calls, calls != _drawn_calls[i])
	_drawn_y[i] = y
	_drawn_doors[i] = doors
	_drawn_stop[i] = stop
	_drawn_calls[i] = calls


## Lift `i`'s leaves: each landing's two in its doorway's wall, apart by `doors` at `stop`, shut elsewhere; the car's
## two inside its front's thickness (open, they slide into it out of sight), with the car.
func _place_leaves(i: int, y: float, stop: int, doors: float) -> void:
	var spec := _specs[i]
	var mm := _leaves.multimesh
	var j := _first_leaf[i]
	var w := spec.door_to - spec.door_from
	var t := _cfg.leaf_thickness
	for k in spec.stop_count():
		var open := doors if k == stop else 0.0
		for s: float in [-1.0, 1.0]:
			_leaf_xforms[j] = _leaf(spec, s, open, w, spec.door_depth * 0.5, spec.stops[k], t)
			mm.set_instance_transform(j, _leaf_xforms[j])
			j += 1
	for s: float in [-1.0, 1.0]:
		_leaf_xforms[j] = _leaf(spec, s, doors, w, -_cfg.wall_thickness * 0.5, y, _cfg.wall_thickness * 0.5)
		mm.set_instance_transform(j, _leaf_xforms[j])
		j += 1


## One leaf of a door `w` wide, on side `s` (-1 the near jamb's, 1 the far one's), `open` of the way apart (each leaf
## slides its own width), `off` out from the well's edge, its foot at `y`, `t` thick.
func _leaf(spec: LiftSpec, s: float, open: float, w: float, off: float, y: float, t: float) -> Transform3D:
	var mid := (spec.door_from + spec.door_to) * 0.5
	var along := mid + s * (w * 0.25 + open * w * 0.5)
	var h := spec.door_height
	var at := spec.on_face(along, off, y + h * 0.5)
	var leaf := w * 0.5 - _cfg.leaf_gap
	# Built wide along x and thin along z (the model's, or a box): turned to lie along the door's face, its +x edge (the
	# model's half of the vision panel) toward the door's middle, so the two halves meet as one panel.
	var turn := _turn(spec.out)
	var axis := Vector3.RIGHT if spec.along_x() else Vector3.BACK
	if turn.x.dot(axis) * s > 0.0:
		turn = turn * Basis(Vector3.UP, PI)
	return Transform3D(turn * Basis.from_scale(Vector3(leaf, h, t)), at)


## Lift `i`'s buttons: its panel's in the car at `y`, and with `recolour` (the calls changed) each stop's call button on
## its landing and both lit while called.
func _place_buttons(i: int, y: float, calls: int, recolour: bool) -> void:
	var spec := _specs[i]
	var mm := _buttons.multimesh
	var j := _first_button[i]
	var n := spec.stop_count()
	var out := Vector3(spec.out.x, 0.0, spec.out.y)
	var depth := _cfg.button_size.z * 0.5
	for k in n:
		if recolour:
			var colour := _lit if (calls >> k) & 1 != 0 else _unlit
			_button_colours[j] = colour
			_button_colours[j + n] = colour
			mm.set_instance_transform(j, Transform3D(_turn(spec.out), spec.call_button(k, _lift_cfg) + out * depth))
			mm.set_instance_color(j, colour)
			mm.set_instance_color(j + n, colour)
		mm.set_instance_transform(j + n, Transform3D(_turn(-spec.out),
				spec.panel_button(k, y, _lift_cfg) - out * (_cfg.wall_thickness + depth)))
		j += 1
