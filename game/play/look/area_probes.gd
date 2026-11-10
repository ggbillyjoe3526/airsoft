class_name AreaProbes
extends Node3D
## A map's reflection probes (docs/ART.md › Light; Graphics › Reflections): one over the whole field, then one per
## named area (MapData.areas) of at least LookConfig.probe_area m², the largest first, up to probe_most in all. Each is
## box-projected over its area from eye height and captured once at the start (UPDATE_ONCE), so a shiny surface
## reflects the hall it stands in, not the sky; on a roofed field they are interiors and reach the roof. On sloping
## ground (MapData.terrain) each box stands on the ground under it, from its lowest corner to `height` over its
## highest, and captures from eye height over the ground at its middle, never from inside a hill (BP2); each of its views
## reaches at least `probe_reach` m, so none stops in the hill or the trees close round it (GL1). Nothing per
## frame. FieldLighting shows or hides them all with the Reflections row. A map built in storeys (MT1: Subway) has no
## one floor for a probe over the whole field, so it has none: each area holding its own band of feet heights is an
## interior from its band's floor to its top, captured from eye height over that floor, never from inside a slab.

## The visual layer the probes sit on, which a scope's glass camera (OpticGlass) leaves out: while that second camera
## saw them, the field's own reflections broke up into patches on the floor round a scope at the hip (BP8, seen in
## tools/render_replica_view.gd's pictures). It sets only which cameras see a probe, not what it captures or lights.
const LAYER := 1 << 18


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
	if map.storeys.is_empty():
		probes._add(whole, height, interior, look, "Field", map.terrain)
	for a in probed_areas(map, look):
		if probes.get_child_count() >= look.probe_most:
			break
		probes._add(_plan(a), height, interior, look, "Area", map.terrain, Vector2(a.floor_from, a.floor_to))
	return probes


## The ground's height under `box` (x, z) on `terrain`: x the lowest and y the highest of its corners and middle, z at
## its middle; all 0 with no terrain, and a point off the terrain counts as 0 (flat ground at the field's level).
static func ground_under(box: Rect2, terrain: TerrainGrid) -> Vector3:
	if terrain == null:
		return Vector3.ZERO
	var middle := box.get_center()
	var at_middle := _ground(terrain, middle)
	var lo := at_middle
	var hi := at_middle
	for corner: Vector2 in [box.position, box.position + Vector2(box.size.x, 0.0), box.end,
			box.position + Vector2(0.0, box.size.y)]:
		var h := _ground(terrain, corner)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return Vector3(lo, hi, at_middle)


static func _ground(terrain: TerrainGrid, at: Vector2) -> float:
	var h := terrain.height_at(at.x, at.y)
	return 0.0 if is_nan(h) else h


## The named areas' boxes (x, z) a probe goes in: those of `look.probe_area` m² or more, the largest first.
static func boxes(map: MapData, look: LookConfig) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for a in probed_areas(map, look):
		out.append(_plan(a))
	return out


## The named areas a probe goes in: those of `look.probe_area` m² or more on the plan, the largest first.
static func probed_areas(map: MapData, look: LookConfig) -> Array[MapAreas.Area]:
	var out: Array[MapAreas.Area] = []
	for a in map.areas:
		if _plan(a).get_area() >= look.probe_area:
			out.append(a)
	out.sort_custom(func(p: MapAreas.Area, q: MapAreas.Area) -> bool:
		return _plan(p).get_area() > _plan(q).get_area())
	return out


static func _plan(a: MapAreas.Area) -> Rect2:
	return Rect2(a.x0, a.z0, a.x1 - a.x0, a.z1 - a.z0).abs()


## A probe over `box`; with a finite `band` (an area's feet heights, x from and y to) it spans that band, from its floor
## up to its top (`height` over its floor without one), and is an interior.
func _add(box: Rect2, height: float, interior: bool, look: LookConfig, kind: String, terrain: TerrainGrid,
		band: Vector2 = Vector2(-INF, INF)) -> void:
	var probe := ReflectionProbe.new()
	probe.name = "%s%d" % [kind, get_child_count()]
	var middle := box.get_center()
	var ground := ground_under(box, terrain)
	var tall := ground.y - ground.x + height
	if is_finite(band.x):
		var top := band.y if is_finite(band.y) else band.x + height
		ground = Vector3(band.x, band.x, band.x)
		tall = maxf(top - band.x, look.probe_eye * 2.0)
		interior = true
	var centre_y := ground.x + tall * 0.5
	probe.position = Vector3(middle.x, centre_y, middle.y)
	probe.size = Vector3(box.size.x + look.probe_margin * 2.0, tall, box.size.y + look.probe_margin * 2.0)
	probe.origin_offset = Vector3(0.0, ground.z + look.probe_eye - centre_y, 0.0)
	probe.max_distance = look.probe_reach
	probe.box_projection = true
	probe.interior = interior
	probe.blend_distance = look.probe_margin
	probe.intensity = look.probe_intensity
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.layers = LAYER
	add_child(probe)
