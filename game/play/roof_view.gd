class_name RoofView
extends Node3D
## An indoor field's roof (DR1; MapData.roof_height): the ceiling over the whole field, the roof's bays under it (Dev 3:
## RoofConfig.bay_model, a truss, purlins, the sheet and services a bay, on the trusses' grid, a MultiMesh every
## RoofConfig.bay_chunk truss lines; plain truss beams in one mesh without it) and its lamps (MapData.roof_lamps, one
## MultiMesh: the high-bay model with its glowing lens, or a glowing panel without it), and a real light under each lamp
## (RoofLamps) that Graphics › Lamp light switches on, lighting the hall alone (no sun gets indoors). The roof and lamps
## themselves cast no shadow, so the preset's overhead light stands in for the lamps through them where they aren't
## real lights (Low, Medium). A map may wear some lamps out (DW1, MapData.roof_lamp_states): dim, dead or flickering,
## each lens glowing as its lamp shines (the MultiMesh's custom data). Look only: the BB ceiling is MapLevel's; nothing
## here is read by the simulation. Built once; per frame only a flickering lamp's step, set when it changes.

## How far (m) over the roof's underside the ceiling slab starts when the bays' sheet is drawn under it.
const CEILING_LIFT := 0.01
## The lamps' lenses: unshaded, `glow` (sRGB, may pass 1) times each lamp's own share and tint (INSTANCE_CUSTOM).
const LENS_SHADER := """shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 glow : source_color = vec4(1.0);
varying vec3 own;
void vertex() {
	own = INSTANCE_CUSTOM.rgb;
}
void fragment() {
	ALBEDO = glow.rgb * own;
}
"""

var _mesh: MeshInstance3D = null
var _lamps: MultiMeshInstance3D = null
## The lamps as real lights (Graphics › Lamp light), or null on a roof with none.
var _lights: RoofLamps = null
var _bays: Array[MultiMeshInstance3D] = []
var _materials: Array[Material] = []
var _cfg: RoofConfig = null
## The flickering lamps (their indices) and each one's level as last set.
var _flickers: PackedInt32Array = PackedInt32Array()
var _levels: PackedFloat32Array = PackedFloat32Array()


## The roof of `map` as `cfg` draws it, or null on a field open to the sky.
static func build(map: MapData, cfg: RoofConfig) -> RoofView:
	if map.roof_height <= 0.0:
		return null
	var view := RoofView.new()
	view.name = "Roof"
	var area := map.footprint().grow(cfg.ceiling_overhang)
	var y := map.roof_height
	# A plain roof (MT1, a station) is its ceiling alone: no bays, no trusses.
	var bay: Mesh = null if map.roof_plain else PropDressConfig.load_mesh(cfg.bay_model)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(cfg.ceiling_colour.srgb_to_linear())
	var lift := CEILING_LIFT if bay != null else 0.0
	_box(st, Vector3(area.position.x, y + lift, area.position.y), Vector3(area.end.x, y + 0.2, area.end.y))
	if bay == null and not map.roof_plain:
		st.set_color(cfg.truss_colour.srgb_to_linear())
		for x in truss_lines(area, cfg.truss_step):
			_box(st, Vector3(x - cfg.truss_width * 0.5, y - cfg.truss_depth, area.position.y),
					Vector3(x + cfg.truss_width * 0.5, y, area.end.y))
	view._mesh = MeshInstance3D.new()
	view._mesh.name = "Ceiling"
	view._mesh.mesh = st.commit()
	view._mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Out of the bounce light too, so the sky's light still reaches the hall as the roof lamps' would; RoofLamps puts it
	# in while the real lamps shine (no sky indoors).
	view._mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# In the shared light (docs/ART.md › Light): its underside takes the look's shade and the bounce off the floor.
	var mat := LookMaterials.vertex_colour(cfg.roughness, 0.0)
	view._mesh.material_override = mat
	view._materials.append(mat)
	view.add_child(view._mesh)
	if bay != null:
		view._add_bays(bay, area, y, cfg)
	if not map.roof_lamps.is_empty():
		var spots: Array[Vector3] = []
		view._lamps = view._lamp_view(map, cfg, bay != null, spots)
		view.add_child(view._lamps)
		view._lights = RoofLamps.build(spots, cfg, Vector3(area.size.x, y, area.size.y).length(), view._mesh,
				map.roof_lamp_states, plain_reaches(map, spots, cfg))
		view.add_child(view._lights)
		view._cfg = cfg
		for i in mini(map.roof_lamp_states.size(), map.roof_lamps.size()):
			if map.roof_lamp_states[i] == MapData.LAMP_FLICKER:
				view._flickers.append(i)
				view._levels.append(1.0)
	return view


func _ready() -> void:
	# Only a roof with flickering lamps runs per frame (Godot turns _process on when the node enters the tree).
	set_process(not _flickers.is_empty())


## How strongly (0 to 1) a flickering lamp `lamp` shines at `time` s, as `cfg` sets it: in full, but each
## `lamp_flicker_every` s (each lamp's own phase), all but `lamp_flicker_quiet` of the cycles, a burst of
## `lamp_flicker_shortest` to 1 of `lamp_flicker_burst` s, stepping each `lamp_flicker_step` s between full and
## `lamp_flicker_low` (off at `lamp_flicker_off` odds). Pure and the same every run.
static func flicker_level(time: float, lamp: int, cfg: RoofConfig) -> float:
	var phase := _unit(lamp, 7919) * cfg.lamp_flicker_every
	var cycle := floori((time + phase) / cfg.lamp_flicker_every)
	var into := time + phase - cycle * cfg.lamp_flicker_every
	if _unit(cycle, lamp) < cfg.lamp_flicker_quiet:
		return 1.0
	var shortest := cfg.lamp_flicker_shortest
	if into > cfg.lamp_flicker_burst * (shortest + (1.0 - shortest) * _unit(cycle, lamp + 101)):
		return 1.0
	var step := floori(into / cfg.lamp_flicker_step)
	return cfg.lamp_flicker_low if _unit(step + cycle * 977, lamp + 31) < cfg.lamp_flicker_off else 1.0


## A number in [0, 1) from two whole numbers, the same every run (a small integer hash).
static func _unit(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffffff) / float(0x1000000)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for k in _flickers.size():
		var level := flicker_level(now, _flickers[k], _cfg)
		if level == _levels[k]:
			continue
		_levels[k] = level
		_lamps.multimesh.set_instance_custom_data(_flickers[k], Color(level, level, level))
		if _lights != null:
			_lights.set_flicker(_flickers[k], level)


## The materials to draw once before play, so the first look up doesn't hitch.
func materials() -> Array[Material]:
	return _materials


## The lamps' real lights, or null on a roof with none.
func lamp_lights() -> RoofLamps:
	return _lights


## How many lamps hang under it (for tests).
func lamp_count() -> int:
	return _lamps.multimesh.instance_count if _lamps != null else 0


## The roof's bays' views (empty without the bay model), and how many bays they draw (for tests).
func bay_views() -> Array[MultiMeshInstance3D]:
	return _bays


func bay_count() -> int:
	var n := 0
	for v in _bays:
		n += v.multimesh.instance_count
	return n


## The x of every truss over `area` (x along the field, y its z): every `step` m from 0, inside it.
static func truss_lines(area: Rect2, step: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var x := ceilf(area.position.x / step) * step
	while x <= area.end.x:
		out.append(x)
		x += step
	return out


## The bays: one a truss line and cell across the field (bay_placings), truss lines `bay_chunk` a MultiMesh.
func _add_bays(bay: Mesh, area: Rect2, y: float, cfg: RoofConfig) -> void:
	var lines := bay_lines(area, cfg).size()
	var cells := bay_cells(area, cfg)
	var at := bay_placings(bay.get_aabb(), area, y, cfg)
	var mat := LookMaterials.vertex_colour(cfg.roughness, 0.0)
	_materials.append(mat)
	var chunk := maxi(1, cfg.bay_chunk)
	for first in range(0, lines, chunk):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bay
		var count := mini(chunk, lines - first) * cells
		mm.instance_count = count
		for i in count:
			mm.set_instance_transform(i, at[first * cells + i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Bays_%d" % (first / chunk)
		inst.multimesh = mm
		inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(inst)
		_bays.append(inst)


## The truss lines the bays stand on: every truss line over `area` and one more past each end where the end bays
## wouldn't reach it (their trusses outside the hall's end walls), so the roof's sheet runs to its walls.
static func bay_lines(area: Rect2, cfg: RoofConfig) -> PackedFloat32Array:
	var half := cfg.truss_step * 0.5
	return truss_lines(Rect2(area.position.x - half, area.position.y, area.size.x + 2.0 * half, area.size.y),
			cfg.truss_step)


## Where a lamp at `at` (x, z) hangs: off the nearest truss line by `lamp_clear` m when it would hang in the truss
## (only with the bay model: the plain beams are shallower than a lamp's drop).
static func lamp_spot(at: Vector2, cfg: RoofConfig) -> Vector2:
	var line := roundf(at.x / cfg.truss_step) * cfg.truss_step
	if absf(at.x - line) >= cfg.lamp_clear:
		return at
	return Vector2(line + (cfg.lamp_clear if at.x >= line else -cfg.lamp_clear), at.y)


## How many bays run across `area` (its y the field's z): cells about RoofConfig.bay_span m, as many as fit.
static func bay_cells(area: Rect2, cfg: RoofConfig) -> int:
	return maxi(1, roundi(area.size.y / cfg.bay_span))


## Each bay's transform over `area` for a bay model of bounds `box`: truss line by truss line, cell by cell across,
## each stretched to its truss step and cell, its top at the roof's underside `y`.
static func bay_placings(box: AABB, area: Rect2, y: float, cfg: RoofConfig) -> Array[Transform3D]:
	var cells := bay_cells(area, cfg)
	var cell := area.size.y / cells
	var out: Array[Transform3D] = []
	for x in bay_lines(area, cfg):
		for c in cells:
			var foot := Vector3(x, y - box.size.y, area.position.y + cell * (c + 0.5))
			out.append(PropLayout.fit(box, foot, Vector3(cfg.truss_step, box.size.y, cell), 0.0))
	return out


## How a lamp in `state` (MapData.LAMP_*) tints its lens's glow: a working or flickering one in full, a dim one at
## `lamp_dim_glow` in `lamp_dim_colour` (against the working colour), a dead one at `lamp_dead_glow`.
static func lens_tint(state: int, cfg: RoofConfig) -> Color:
	match state:
		MapData.LAMP_DIM:
			var c := cfg.lamp_dim_colour
			var w := cfg.lamp_colour
			return Color(c.r / w.r, c.g / w.g, c.b / w.b) * cfg.lamp_dim_glow
		MapData.LAMP_DEAD:
			return Color(cfg.lamp_dead_glow, cfg.lamp_dead_glow, cfg.lamp_dead_glow)
	return Color.WHITE


## The lamps: the high-bay model, its body in the shared light and its lens glowing, its top at the roof's underside;
## or a glowing panel `lamp_drop` under it without the model; with the roof's `bays`, each clear of the trusses
## (lamp_spot). Each lamp's lowest point (under its lens) is added to `spots`, for its real light.
func _lamp_view(map: MapData, cfg: RoofConfig, bays: bool, spots: Array[Vector3]) -> MultiMeshInstance3D:
	var glow := ShaderMaterial.new()
	glow.shader = CodeShaders.of(LENS_SHADER)
	glow.set_shader_parameter(&"glow", cfg.lamp_colour * cfg.lamp_energy)
	_materials.append(glow)
	var lamp: Mesh = null
	var own: ArrayMesh = null if map.roof_plain else PropDressConfig.load_mesh(cfg.lamp_model) as ArrayMesh
	var drop := cfg.plain_lamp_drop if map.roof_plain else cfg.lamp_drop
	if own != null:
		var body := LookMaterials.vertex_colour(cfg.roughness, 0.0)
		_materials.append(body)
		lamp = own.duplicate() as ArrayMesh
		for s in lamp.get_surface_count():
			var m := lamp.surface_get_material(s)
			lamp.surface_set_material(s, glow if m != null and m.resource_name == cfg.lamp_lens else body)
		drop = lamp.get_aabb().end.y
	else:
		var panel := BoxMesh.new()
		panel.size = Vector3(cfg.lamp_size.x, 0.08, cfg.lamp_size.y)
		panel.material = glow
		lamp = panel
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = lamp
	mm.instance_count = map.roof_lamps.size()
	# the model hangs from its top (its own y 0 at the ceiling's underside); a panel's middle `lamp_drop` under it, each
	# lamp from its own ceiling (MapData.roof_lamp_heights: the roof's, or a station level's)
	for i in map.roof_lamps.size():
		var at := lamp_spot(map.roof_lamps[i], cfg) if bays else map.roof_lamps[i]
		var top := map.roof_lamp_heights[i] if i < map.roof_lamp_heights.size() else map.roof_height
		var y := top - drop
		var under := y + lamp.get_aabb().position.y
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(at.x, y, at.y)))
		mm.set_instance_custom_data(i, lens_tint(map.roof_lamp_states[i] if i < map.roof_lamp_states.size()
				else MapData.LAMP_WORKING, cfg))
		spots.append(Vector3(at.x, under, at.y))
	var inst := MultiMeshInstance3D.new()
	inst.name = "Lamps"
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return inst


## Each lamp's light's range (m) under a plain roof (MT1): from its lowest point (`spots`) down to the floor under it
## (MapData.floor_under; the ground without) and `plain_lamp_reach` past it, so it never lights the level under that.
## None (the roof's own range) under a roof that is not plain.
static func plain_reaches(map: MapData, spots: Array[Vector3], cfg: RoofConfig) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not map.roof_plain:
		return out
	for at in spots:
		var under := map.floor_under(at.x, at.z, at.y)
		out.append(at.y - (under if is_finite(under) else 0.0) + cfg.plain_lamp_reach)
	return out


## A box from `lo` to `hi`, each face with its outward normal, wound to face out (Godot's front faces are clockwise).
static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
			Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	var faces := [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]
	var normals := [Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	for i in faces.size():
		var f: Array = faces[i]
		st.set_normal(normals[i])
		st.add_vertex(c[f[0]])
		st.add_vertex(c[f[2]])
		st.add_vertex(c[f[1]])
		st.add_vertex(c[f[0]])
		st.add_vertex(c[f[3]])
		st.add_vertex(c[f[2]])
