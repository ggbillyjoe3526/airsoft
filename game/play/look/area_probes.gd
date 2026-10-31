class_name AreaProbes
extends Node3D
## A map's reflection probes (docs/ART.md › Light; Graphics › Reflections): one over the whole field, then one per
## named area (MapData.areas) of at least LookConfig.probe_area m², the largest first, up to probe_most in all. Each is
## box-projected over its area from eye height and captured once at the start (UPDATE_ONCE), so a shiny surface
## reflects the hall it stands in, not the sky; on a roofed field they are interiors and reach the roof. Nothing per
## frame. FieldLighting shows or hides them all with the Reflections row.


## The probes for `map` in `look`, or null for a map with no blocks.
static func build(map: MapData, look: LookConfig) -> AreaProbes:
	var whole := map.footprint()
	if whole.size == Vector2.ZERO:
		return null
	var probes := AreaProbes.new()
	probes.name = "ReflectionProbes"
	# hidden until the Reflections row shows them, so Low never captures them at all
	probes.visible = false
	var height := map.roof_height if map.roof_height > 0.0 else look.probe_height
	var interior := map.roof_height > 0.0
	probes._add(whole, height, interior, look, "Field")
	for box in boxes(map, look):
		if probes.get_child_count() >= look.probe_most:
			break
		probes._add(box, height, interior, look, "Area")
	return probes


## The named areas' boxes (x, z) a probe goes in: those of `look.probe_area` m² or more, the largest first.
static func boxes(map: MapData, look: LookConfig) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for a in map.areas:
		var r := Rect2(a.x0, a.z0, a.x1 - a.x0, a.z1 - a.z0).abs()
		if r.get_area() >= look.probe_area:
			out.append(r)
	out.sort_custom(func(p: Rect2, q: Rect2) -> bool: return p.get_area() > q.get_area())
	return out


func _add(box: Rect2, height: float, interior: bool, look: LookConfig, kind: String) -> void:
	var probe := ReflectionProbe.new()
	probe.name = "%s%d" % [kind, get_child_count()]
	var middle := box.get_center()
	probe.position = Vector3(middle.x, height * 0.5, middle.y)
	probe.size = Vector3(box.size.x + look.probe_margin * 2.0, height, box.size.y + look.probe_margin * 2.0)
	probe.origin_offset = Vector3(0.0, look.probe_eye - height * 0.5, 0.0)
	probe.box_projection = true
	probe.interior = interior
	probe.blend_distance = look.probe_margin
	probe.intensity = look.probe_intensity
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
