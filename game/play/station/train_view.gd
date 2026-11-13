class_name TrainView
extends Node3D
## A station's trains (SM1; the map's `dressing.trains`, TrainDressing) in Subway's train models (TrainLook,
## tools/blender/maps/train.py): each car's body, a shut pair of leaves in every door hole but its open ones, its cab
## fronts and blank ends, and the open gangways between cars, one MultiMesh a model in the props' vertex-coloured
## material (its ceiling's cool white lamp strips and its ends' white LED lamps glowing in lamp materials of their own,
## the owner, 2026-11-12), and the platform side's window glass, see-through, in the clear material (the map's glass
## blocks in the holes, which MapLevel leaves to it). The models fill the train's walls, slabs and car ends exactly,
## which StationSurface leaves to them; the seats and tool carts are the props' (PropDress, their blocks name them).
## Scenery: no collider, no nav cell.
## Built once; per frame only a flickering half car's strips (under a flickering station lamp, stepped with its light by
## RoofView.flicker_level), set when they change.

var _views: Dictionary[String, MultiMeshInstance3D] = {}
var _boxes: Array[AABB] = []
var _placed: Dictionary[String, Array] = {}
var _material: ShaderMaterial = null
var _lamps: ShaderMaterial = null
var _leds: ShaderMaterial = null
var _glass: ShaderMaterial = null
## The flickering strips: each one's instance in the strips' MultiMesh, the station lamp it flickers with, its level as
## last set (64-bit, as RoofView keeps its own), and the roof that steps them.
var _flicker_strips: PackedInt32Array = PackedInt32Array()
var _flicker_lamps: PackedInt32Array = PackedInt32Array()
var _levels: PackedFloat64Array = PackedFloat64Array()
var _roof: RoofConfig = null
var _lights_path: String = ""


## The trains of `map` in `look`'s models, or null for a map with none or when a model won't load (the trains are then
## drawn as their boxes); `roof` steps the strips under the map's flickering lamps (none: they never flicker). Add it
## to the tree beside the level.
static func build(map: MapData, look: TrainLook, roof: RoofConfig = null) -> TrainView:
	if map == null or map.trains.is_empty() or look == null or not look.loads():
		return null
	var placed: Dictionary[String, Array] = {}
	for t in map.trains:
		for car in t.cars:
			_place_car(look, car, placed)
		for at in t.gangways:
			_put(placed, look.gangway, Transform3D(Basis.IDENTITY, at))
	var view := TrainView.new()
	view.name = "Trains"
	for t in map.trains:
		view._boxes.append(t.box)
	view._material = LookMaterials.vertex_colour(look.roughness, 0.0, Color.WHITE, false, look.wear)
	view._material.set_shader_parameter(&"paint_by_custom", true)
	view._lamps = _glow(look.lamp_colour * look.lamp_energy)
	view._leds = _glow(look.led_colour * look.led_energy)
	view._glass = LookMaterials.clear_colour(look.glass_roughness)
	view._glass.set_shader_parameter(&"opacity", look.glass_opacity)
	view._placed = placed
	view._lights_path = look.lights
	for path: String in placed:
		view._add(path, look.mesh(path), placed[path], view._material_of(look, path))
	if roof != null:
		view._roof = roof
		view._link_flickers(map, look.half_length, look.mesh(look.body).get_aabb().end.z)
	return view


## Model `path`'s material: the strips' and the LEDs' glow, the windows' glass, else the props'.
func _material_of(look: TrainLook, path: String) -> Material:
	if path == look.lights:
		return _lamps
	if look.leds.values().has(path):
		return _leds
	if path == look.windows or path == look.door_glass:
		return _glass
	return _material


## The strips' lamp material: unshaded, `glow` (sRGB, may pass 1) times each strip's own level (RoofView.LENS_SHADER).
static func _glow(glow: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CodeShaders.of(RoofView.LENS_SHADER)
	m.set_shader_parameter(&"glow", glow)
	return m


## Links each flickering station lamp to the half car's strips it hangs over (its x 0 to `half` in the half's own frame,
## within `side` of its middle line): the half whose middle is nearest, so a lamp on a boundary flickers one half only,
## and each half with one lamp at most.
func _link_flickers(map: MapData, half: float, side: float) -> void:
	var strips: Array = _placed.get(_lights_path, [])
	for lamp in mini(map.roof_lamps.size(), map.roof_lamp_states.size()):
		if map.roof_lamp_states[lamp] != MapData.LAMP_FLICKER:
			continue
		var best := -1
		var nearest := INF
		for i in strips.size():
			if _flicker_strips.has(i):
				continue
			var t: Transform3D = strips[i]
			var local := t.affine_inverse() * Vector3(map.roof_lamps[lamp].x, t.origin.y, map.roof_lamps[lamp].y)
			var off := absf(local.x - half * 0.5)
			if off <= half * 0.5 and absf(local.z) <= side and off < nearest:
				best = i
				nearest = off
		if best >= 0:
			_flicker_strips.append(best)
			_flicker_lamps.append(lamp)
			_levels.append(1.0)


func _ready() -> void:
	# Only trains with flickering strips run per frame (Godot turns _process on when the node enters the tree).
	set_process(not _flicker_strips.is_empty())


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var mm := _views[_lights_path].multimesh
	for k in _flicker_strips.size():
		var level := RoofView.flicker_level(now, _flicker_lamps[k], _roof)
		if level == _levels[k]:
			continue
		_levels[k] = level
		mm.set_instance_custom_data(_flicker_strips[k], Color(level, level, level))


## The half cars' strips that flicker (their instances in the strips' MultiMesh) and the lamp each flickers with.
func flicker_strips() -> PackedInt32Array:
	return _flicker_strips


func flicker_lamps() -> PackedInt32Array:
	return _flicker_lamps


## Model `path`'s view (the test's and the census's), or null when it isn't drawn.
func view_of(path: String) -> MultiMeshInstance3D:
	return _views.get(path, null)


## Where each of model `path` stands (the test's: a headless MultiMesh keeps no transforms).
func placed_of(path: String) -> Array:
	return _placed.get(path, [])


## How many of model `path` are drawn.
func count(path: String) -> int:
	var v := view_of(path)
	return v.multimesh.instance_count if v != null else 0


## The trains' boxes, the cars inside which the station's ceiling lamps are not drawn (their own lamp strips are).
func boxes() -> Array[AABB]:
	return _boxes


## The materials drawn, to warm their shaders before play.
func materials() -> Array[Material]:
	return [_material, _lamps, _leds, _glass]


## Where car `car`'s models stand: its middle on its floor, turned about up when it is.
static func car_at(car: TrainDressing.Car) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI) if car.turned else Basis.IDENTITY, car.middle)


## Where the model at car `car`'s end `k` (0 its own -x end, 1 its +x) stands: the end model's frame faces +x, out of
## the car, (half_length - end_depth) from its middle.
static func end_at(look: TrainLook, car: TrainDressing.Car, k: int) -> Transform3D:
	var reach := look.half_length - look.end_depth
	var end := Transform3D(Basis.IDENTITY, Vector3(reach, 0.0, 0.0)) if k == 1 \
			else Transform3D(Basis(Vector3.UP, PI), Vector3(-reach, 0.0, 0.0))
	return car_at(car) * end


static func _place_car(look: TrainLook, car: TrainDressing.Car, placed: Dictionary[String, Array]) -> void:
	var at := car_at(car)
	var half := Basis(Vector3.UP, PI)
	_put(placed, look.body, at)
	_put(placed, look.windows, at)
	_put(placed, look.lights, at)
	_put(placed, look.lights, at * Transform3D(half, Vector3.ZERO))
	for slot in TrainDressing.SLOTS:
		var x := look.door_slots[slot]
		# the far side's doors are all shut, dark glass; the platform side's but its open ones, their windows clear
		_put(placed, look.door, at * Transform3D(half, Vector3(x, 0.0, 0.0)))
		if not car.open.has(slot):
			_put(placed, look.door_glazed, at * Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)))
			_put(placed, look.door_glass, at * Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)))
	for k in 2:
		var kind := car.ends[k]
		if kind == TrainDressing.GANGWAY or not look.ends.has(kind):
			continue
		var end := end_at(look, car, k)
		_put(placed, look.ends[kind], end)
		if look.leds.has(kind):
			_put(placed, look.leds[kind], end)


static func _put(placed: Dictionary[String, Array], path: String, t: Transform3D) -> void:
	if not placed.has(path):
		placed[path] = []
	placed[path].append(t)


func _add(path: String, mesh: Mesh, transforms: Array, material: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, Color.WHITE)
		mm.set_instance_custom_data(i, Color.WHITE)
	var v := MultiMeshInstance3D.new()
	v.name = path.get_file().get_basename().capitalize().replace(" ", "")
	v.multimesh = mm
	v.material_override = material
	if material == _lamps or material == _leds or material == _glass:
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		# the grime climbs from each model's own foot (SL2): a car's floor, a cab's buffer beam
		v.set_instance_shader_parameter(&"wear_floor", mesh.get_aabb().position.y)
	add_child(v)
	_views[path] = v
