class_name RoofView
extends Node3D
## An indoor field's roof (DR1; MapData.roof_height): the ceiling over the whole field, the steel trusses under it
## (one mesh in one material, one draw call) and its lamp panels (MapData.roof_lamps, one MultiMesh, one draw call),
## none of it casting a shadow, so the preset's overhead sun keeps lighting the hall as the roof lamps would. Look only:
## the BB ceiling is MapLevel's; nothing here is read by the simulation. Built once, nothing per frame.

var _mesh: MeshInstance3D = null
var _lamps: MultiMeshInstance3D = null
var _materials: Array[Material] = []


## The roof of `map` as `cfg` draws it, or null on a field open to the sky.
static func build(map: MapData, cfg: RoofConfig) -> RoofView:
	if map.roof_height <= 0.0:
		return null
	var view := RoofView.new()
	view.name = "Roof"
	var area := map.footprint().grow(cfg.ceiling_overhang)
	var y := map.roof_height
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(cfg.ceiling_colour.srgb_to_linear())
	_box(st, Vector3(area.position.x, y, area.position.y), Vector3(area.end.x, y + 0.2, area.end.y))
	st.set_color(cfg.truss_colour.srgb_to_linear())
	var x := ceilf(area.position.x / cfg.truss_step) * cfg.truss_step
	while x <= area.end.x:
		_box(st, Vector3(x - cfg.truss_width * 0.5, y - cfg.truss_depth, area.position.y),
				Vector3(x + cfg.truss_width * 0.5, y, area.end.y))
		x += cfg.truss_step
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
	if not map.roof_lamps.is_empty():
		view._lamps = _lamp_panels(map, cfg)
		view._materials.append(view._lamps.material_override)
		view.add_child(view._lamps)
	return view


## The materials to draw once before play, so the first look up doesn't hitch.
func materials() -> Array[Material]:
	return _materials


## How many lamp panels hang under it (for tests).
func lamp_count() -> int:
	return _lamps.multimesh.instance_count if _lamps != null else 0


static func _lamp_panels(map: MapData, cfg: RoofConfig) -> MultiMeshInstance3D:
	var panel := BoxMesh.new()
	panel.size = Vector3(cfg.lamp_size.x, 0.08, cfg.lamp_size.y)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = panel
	mm.instance_count = map.roof_lamps.size()
	var y := map.roof_height - cfg.lamp_drop
	for i in map.roof_lamps.size():
		var at := map.roof_lamps[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(at.x, y, at.y)))
	var inst := MultiMeshInstance3D.new()
	inst.name = "Lamps"
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = cfg.lamp_colour * cfg.lamp_energy
	inst.material_override = glow
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
