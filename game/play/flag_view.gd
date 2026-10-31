class_name FlagView
extends Node3D
## Attack / Defend's flagpole in the world (concept `pole.png`; the browser game's FLAG_VISUALS): the pole and its base,
## the rope, the attacking team's flag at the height the rules have it, and the ring on the floor at the rope's reach,
## coloured by who is working it. Scenery only: no collider, so BBs pass through. Reads the round state; owns no rule.
## Built once a match; `refresh` changes only what moved (the cloth's height, the ring's and cloth's colours).

const CLOTH_SHADER := preload("res://game/play/flag_cloth.gdshader")
## Segments of the ring and of the cloth's mesh (along and up).
const RING_SEGMENTS := 96
const POLE_SEGMENTS := 20
const BASE_SEGMENTS := 28
const ROPE_SEGMENTS := 6
const CLOTH_GRID := Vector2i(14, 6)
## The ring and its edge sit this far over the floor (m), the edge just under the ring.
const RING_LIFT := 0.025
const EDGE_LIFT := 0.024
const FITTINGS_ROUGHNESS := 0.7
const ROPE_ROUGHNESS := 0.9

var _cfg: FlagViewConfig = null
var _teams: TeamConfig = null
var _cloth: MeshInstance3D = null
var _cloth_mat: ShaderMaterial = null
var _ring_mat: StandardMaterial3D = null
var _height: float = -1.0
var _attackers: int = -1
var _status: int = -1
var _letter: Label3D = null


## Builds the pole at `foot` with the rope's reach `reach` (m), the team colours from `teams`; with a `letter` (a map
## with two poles, AB1) that letter stands over its top.
func setup(cfg: FlagViewConfig, teams: TeamConfig, foot: Vector3, reach: float, letter: String = "") -> void:
	_cfg = cfg
	_teams = teams
	name = "Flagpole" + letter
	position = foot
	if not letter.is_empty():
		_add_letter(letter)
	var alu := StandardMaterial3D.new()
	alu.albedo_color = cfg.pole_colour
	alu.metallic = cfg.pole_metallic
	alu.roughness = cfg.pole_roughness
	var dark := StandardMaterial3D.new()
	dark.albedo_color = cfg.fittings_colour
	dark.roughness = FITTINGS_ROUGHNESS
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = cfg.rope_colour
	rope_mat.roughness = ROPE_ROUGHNESS
	var h := cfg.pole_height
	_add(cylinder(cfg.pole_radius, cfg.pole_radius, h, POLE_SEGMENTS), alu, Vector3(0.0, h * 0.5, 0.0))
	_add(cylinder(cfg.base_radius.y, cfg.base_radius.x, cfg.base_height, BASE_SEGMENTS), dark,
			Vector3(0.0, cfg.base_height * 0.5, 0.0))
	var ball := SphereMesh.new()
	ball.radius = cfg.finial_radius
	ball.height = cfg.finial_radius * 2.0
	_add(ball, alu, Vector3(0.0, h + cfg.finial_radius * 0.5, 0.0))
	var rope_h := h - cfg.cloth_low
	for side: float in [-1.0, 1.0]:
		# The ropes and the cleat are too thin to shade anything: no shadow pass for them.
		var rope := _add(cylinder(cfg.rope_radius, cfg.rope_radius, rope_h, ROPE_SEGMENTS), rope_mat,
				Vector3(0.0, cfg.cloth_low + rope_h * 0.5, side * cfg.rope_offset))
		rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cleat := BoxMesh.new()
	cleat.size = cfg.cleat_size
	_add(cleat, dark, Vector3(0.0, cfg.cleat_height, cfg.rope_offset)).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloth_mat = ShaderMaterial.new()
	_cloth_mat.shader = CLOTH_SHADER
	_cloth_mat.set_shader_parameter(&"pale", cfg.cloth_pale)
	_cloth_mat.set_shader_parameter(&"cloth_size", cfg.cloth_size)
	_cloth_mat.set_shader_parameter(&"wave", cfg.cloth_wave)
	_cloth_mat.set_shader_parameter(&"waves", cfg.cloth_waves)
	_cloth_mat.set_shader_parameter(&"wave_speed", cfg.cloth_wave_speed)
	_cloth = _add(cloth_mesh(cfg.cloth_size, cfg.cloth_droop), _cloth_mat, Vector3(cfg.pole_radius, cfg.cloth_low, 0.0))
	_cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_ring_mat = flat(cfg.ring_idle)
	var ring := _add(ring_mesh(reach - cfg.ring_width, reach), _ring_mat, Vector3(0.0, RING_LIFT, 0.0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var edge := MeshInstance3D.new()
	edge.mesh = ring_edge_mesh(reach, cfg.ring_width, cfg.ring_edge_width)
	edge.material_override = flat(cfg.ring_edge)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edge.position.y = EDGE_LIFT
	add_child(edge)


## The flag at `flag`'s height for a round attacked by `attackers` (-1: none, the cloth hidden).
func refresh(flag: FlagState, attackers: int) -> void:
	var y := lerpf(_cfg.cloth_low, _cfg.cloth_high, clampf(flag.progress, 0.0, 1.0))
	if y != _height:
		_height = y
		_cloth.position.y = y
	if attackers != _attackers:
		_attackers = attackers
		_cloth.visible = attackers >= 0
		if attackers >= 0:
			_cloth_mat.set_shader_parameter(&"team_colour", _teams.colours[attackers])
		_status = -1
	if flag.status != _status:
		_status = flag.status
		var c := _cfg.ring_idle
		match flag.status:
			FlagState.Status.RAISING:
				c = _teams.colours[attackers] if attackers >= 0 else c
			FlagState.Status.LOWERING:
				c = _teams.colours[1 - attackers] if attackers >= 0 else c
			FlagState.Status.CONTESTED:
				c = _cfg.ring_contested
		_ring_mat.albedo_color = Color(c, _cfg.ring_alpha)


## The materials drawn first in a match (ShaderPrewarm), so the flag's first sight never hitches.
func materials() -> Array[Material]:
	return [_cloth_mat, _ring_mat]


## The letter over the pole (AB1), "" without one: for tests.
func letter() -> String:
	return _letter.text if _letter != null else ""


## The cloth's height over the foot of the pole (m), for tests.
func cloth_height() -> float:
	return _cloth.position.y


## The ring's colour, for tests.
func ring_colour() -> Color:
	return _ring_mat.albedo_color


func _add(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position = at
	add_child(m)
	return m


## An unlit, see-through material in `colour`, both faces drawn (the rings).
static func flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = colour
	return m


## A cylinder `height` (m) tall, radius `top` and `bottom` (m), with `segments` round it and one ring.
static func cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


## A flat ring from `inner` to `outer` (m) on the floor.
static func ring_mesh(inner: float, outer: float) -> ArrayMesh:
	return ring_tool(inner, outer).commit()


## The thin dark edges either side of a ring `width` (m) wide inside `reach` (m), each `edge_width` (m).
static func ring_edge_mesh(reach: float, width: float, edge_width: float) -> ArrayMesh:
	var st := ring_tool(reach, reach + edge_width)
	ring_into(st, reach - width - edge_width, reach - width)
	return st.commit()


static func ring_tool(inner: float, outer: float) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	ring_into(st, inner, outer)
	return st


static func ring_into(st: SurfaceTool, inner: float, outer: float) -> void:
	for i in RING_SEGMENTS:
		var a := Vector3(cos(TAU * i / RING_SEGMENTS), 0.0, sin(TAU * i / RING_SEGMENTS))
		var b := Vector3(cos(TAU * (i + 1) / RING_SEGMENTS), 0.0, sin(TAU * (i + 1) / RING_SEGMENTS))
		for p: Vector3 in [a * outer, a * inner, b * outer, b * outer, a * inner, b * inner]:
			st.add_vertex(p)


## The cloth as a grid `size` (m) from the pole outwards, its foot at 0, its free edge `droop` (m) lower; UV.x 0 at the
## pole, UV.y 0 at the top.
static func cloth_mesh(size: Vector2, droop: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	var nx := CLOTH_GRID.x
	var ny := CLOTH_GRID.y
	for j in ny:
		for i in nx:
			for k: Vector2i in [Vector2i(i, j), Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j),
					Vector2i(i, j + 1), Vector2i(i + 1, j + 1)]:
				var u := float(k.x) / nx
				var v := float(k.y) / ny
				st.set_uv(Vector2(u, 1.0 - v))
				st.add_vertex(Vector3(u * size.x, v * size.y - droop * u * u, 0.0))
	return st.commit()


func _add_letter(letter: String) -> void:
	_letter = Label3D.new()
	_letter.name = "Letter"
	_letter.text = letter
	_letter.font_size = _cfg.letter_size
	_letter.pixel_size = _cfg.letter_pixel
	_letter.outline_size = _cfg.letter_outline
	_letter.modulate = _cfg.cloth_pale
	_letter.outline_modulate = _cfg.fittings_colour
	# Billboarded as the "HIT!" sign is (FigureView.make_sign), so it shares the shader the prewarm compiles with it.
	_letter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_letter.position.y = _cfg.pole_height + _cfg.letter_rise
	_letter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_letter)
