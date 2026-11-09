class_name RoofView
extends Node3D
## An indoor field's roof (DR1; MapData.roof_height): the ceiling over the whole field, the roof's bays under it (Dev 3:
## RoofConfig.bay_model, a truss, purlins, the sheet and services a bay, on the trusses' grid, a MultiMesh every
## RoofConfig.bay_chunk truss lines; plain truss beams in one mesh without it) and its lamps (MapData.roof_lamps, one
## MultiMesh: the high-bay model with its glowing lens, or a glowing panel without it), and a real light under each lamp
## (RoofLamps) that Graphics › Lamp light switches on. The roof and lamps themselves cast no shadow, so the preset's
## overhead sun lights the hall through them where the lamps aren't real lights (Low, Medium); on Far a shadow-only
## sun shade over the bays (`sun_shade`) lets it in at the rooflights alone. Look only: the BB ceiling is MapLevel's;
## nothing here is read by the simulation. Built once, nothing per frame.

## How far (m) over the roof's underside the ceiling slab starts when the bays' sheet is drawn under it.
const CEILING_LIFT := 0.01
## The sun shade's slabs (m over the roof's underside): over the ceiling slab, so they never shade its own top.
const SHADE_FROM := 0.2
const SHADE_TO := 0.3

var _mesh: MeshInstance3D = null
var _lamps: MultiMeshInstance3D = null
## The lamps as real lights (Graphics › Lamp light), or null on a roof with none.
var _lights: RoofLamps = null
var _bays: Array[MultiMeshInstance3D] = []
## The roof's shadow over the hall but at its rooflights (Lamp light Far), or null without the bays or lamps.
var _shade: MeshInstance3D = null
## The hall's thicker haze while the roof shades the sun (Lamp light Far), so the rooflights' sun shows in shafts.
var _haze: FogVolume = null
var _materials: Array[Material] = []


## The roof of `map` as `cfg` draws it, or null on a field open to the sky.
static func build(map: MapData, cfg: RoofConfig) -> RoofView:
	if map.roof_height <= 0.0:
		return null
	var view := RoofView.new()
	view.name = "Roof"
	var area := map.footprint().grow(cfg.ceiling_overhang)
	var y := map.roof_height
	var bay := PropDressConfig.load_mesh(cfg.bay_model)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(cfg.ceiling_colour.srgb_to_linear())
	var lift := CEILING_LIFT if bay != null else 0.0
	_box(st, Vector3(area.position.x, y + lift, area.position.y), Vector3(area.end.x, y + 0.2, area.end.y))
	if bay == null:
		st.set_color(cfg.truss_colour.srgb_to_linear())
		for x in truss_lines(area, cfg.truss_step):
			_box(st, Vector3(x - cfg.truss_width * 0.5, y - cfg.truss_depth, area.position.y),
					Vector3(x + cfg.truss_width * 0.5, y, area.end.y))
	view._mesh = MeshInstance3D.new()
	view._mesh.name = "Ceiling"
	view._mesh.mesh = st.commit()
	view._mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Out of the bounce light too, so the sky's light still reaches the hall as the roof lamps' would.
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
		var shaded: Array[Node3D] = []
		if bay != null:
			view._shade = _sun_shade(area, y, cfg)
			view._haze = _hall_haze(area, y, cfg)
			shaded = [view._shade, view._haze]
			for node in shaded:
				view.add_child(node)
		view._lights = RoofLamps.build(spots, cfg, shaded)
		view.add_child(view._lights)
	return view


## The materials to draw once before play, so the first look up doesn't hitch.
func materials() -> Array[Material]:
	return _materials


## The lamps' real lights, or null on a roof with none.
func lamp_lights() -> RoofLamps:
	return _lights


## The sun shade (Lamp light Far shows it), or null on a roof without bays or lamps (for tests).
func sun_shade() -> MeshInstance3D:
	return _shade


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


## The x spans over `area` the sun shade covers: all of it but a rooflight `rooflight_half` m either side of each line
## halfway between two trusses (the bays' edges, where the bay model's rooflight strips lie), in order.
static func shade_spans(area: Rect2, cfg: RoofConfig) -> PackedVector2Array:
	var out := PackedVector2Array()
	var step := cfg.truss_step
	var x := area.position.x
	var gap := (floorf(x / step - 0.5) + 0.5) * step
	while x < area.end.x:
		var lo := gap - cfg.rooflight_half
		if lo > x:
			out.append(Vector2(x, minf(lo, area.end.x)))
		x = maxf(x, gap + cfg.rooflight_half)
		gap += step
	return out


## The sun shade over `area`, the roof's underside at `y`: a slab a shade span (shade_spans), casting the shadow alone,
## hidden until Lamp light Far shows it (RoofLamps.set_mode); out of the bounce light, as the roof is.
static func _sun_shade(area: Rect2, y: float, cfg: RoofConfig) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for span in shade_spans(area, cfg):
		_box(st, Vector3(span.x, y + SHADE_FROM, area.position.y), Vector3(span.y, y + SHADE_TO, area.end.y))
	var shade := MeshInstance3D.new()
	shade.name = "SunShade"
	shade.mesh = st.commit()
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shade.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	shade.visible = false
	return shade


## The hall's haze under the roof over `area`, the roof's underside at `y`: `shade_haze` more density on the volumetric
## fog (Graphics › Volumetric fog; nothing without it), hidden until the sun shade shows.
static func _hall_haze(area: Rect2, y: float, cfg: RoofConfig) -> FogVolume:
	var haze := FogVolume.new()
	haze.name = "HallHaze"
	haze.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	haze.size = Vector3(area.size.x, y, area.size.y)
	haze.position = Vector3(area.get_center().x, y * 0.5, area.get_center().y)
	var mat := FogMaterial.new()
	mat.density = cfg.shade_haze
	mat.albedo = cfg.lamp_colour
	haze.material = mat
	haze.visible = false
	return haze


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


## The lamps: the high-bay model, its body in the shared light and its lens glowing, its top at the roof's underside;
## or a glowing panel `lamp_drop` under it without the model; with the roof's `bays`, each clear of the trusses
## (lamp_spot). Each lamp's lowest point (under its lens) is added to `spots`, for its real light.
func _lamp_view(map: MapData, cfg: RoofConfig, bays: bool, spots: Array[Vector3]) -> MultiMeshInstance3D:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = cfg.lamp_colour * cfg.lamp_energy
	_materials.append(glow)
	var lamp: Mesh = null
	var own := PropDressConfig.load_mesh(cfg.lamp_model) as ArrayMesh
	var drop := cfg.lamp_drop
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
	mm.mesh = lamp
	mm.instance_count = map.roof_lamps.size()
	# the model hangs from its top (its own y 0 at the roof's underside); a panel's middle `lamp_drop` under it
	var y := map.roof_height - drop
	var under := y + lamp.get_aabb().position.y
	for i in map.roof_lamps.size():
		var at := lamp_spot(map.roof_lamps[i], cfg) if bays else map.roof_lamps[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(at.x, y, at.y)))
		spots.append(Vector3(at.x, under, at.y))
	var inst := MultiMeshInstance3D.new()
	inst.name = "Lamps"
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return inst


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
