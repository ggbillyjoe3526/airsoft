class_name ReplicaPictures
extends Node
## The replicas' pictures on the menus, drawn live from their models (assets/models/replicas/<key>.glb): each replica has
## one small viewport that looks at it from the right, flat (no perspective), in the paint it was last asked for, and every
## card showing that replica shows the same texture. The parts fitted to it are put on the model as they are in play
## (ReplicaParts: the standard magazine or flash hider they replace hidden, the iron sights folded under an optic); the
## picture is drawn again only when its paint or parts change, and the parts it replaces are freed. Each part also has a picture of its own, alone and in the same paint, for the Customise cards, kept
## only for the slot on show. A viewport draws once when the picture is made and once more for each repaint (not every
## frame). The paints' materials are ReplicaPaint's: built once each and shared with the match. The power sources have pictures of their own, from
## assets/models/powerSources (the Armory's). The figure copies in the models are left out. Everything it makes is its child and goes with it.

const MODEL_DIR := "res://assets/models/replicas/"
const POWER_DIR := "res://assets/models/powerSources/"
## The picture's longer side (px); the other follows the replica's shape. A part's picture is smaller.
const LONG_SIDE := 1024
const PART_LONG_SIDE := 384
## The room left round the replica in its picture (a share).
const MARGIN := 1.06
## The least a picture measures (m), so a model with nothing to show can't divide by nothing.
const MIN_EXTENT := 0.001
const CAMERA_DISTANCE := 3.0
## The light: its angle (degrees: pitch, yaw), energy, and the sky's ambient share.
const SUN_ANGLE := Vector2(-42.0, 35.0)
const SUN_ENERGY := 1.15
const AMBIENT_ENERGY := 0.75
const AMBIENT := Color("c8d4ea")
const MSAA := Viewport.MSAA_4X
const FIGURE_NODE := "Figure"
## The gas bottle's label material (one model for every gas, its colour set per power source), and the most metallic a
## power source's metal is drawn: the picture has no reflections, so full metal turns black.
const LABEL_MATERIAL := "Label"
const MAX_METALNESS := 0.35


class Shot:
	extends RefCounted
	var port: SubViewport = null
	var model: Node3D = null
	var camera: Camera3D = null
	var paint: StringName = &""
	var realistic: bool = false
	var painted: bool = false
	## The replica's size in metres in the picture (its length and height, with the picture's margin), and without parts.
	var extent: Vector2 = Vector2.ONE
	var bare_extent: Vector2 = Vector2.ONE
	var long_side: int = 0
	## The parts on the model now, as "slot=key" words in slot order, and what fitting them did.
	var parts_sig: String = ""
	var fit: ReplicaParts.Fit = null


var _shots: Dictionary[StringName, Shot] = {}
## The parts' own pictures, "<replica>/<slot>/<part>".
var _part_shots: Dictionary[String, Shot] = {}
## The power sources' pictures, "<file>/<label colour>/<tip>".
var _power_shots: Dictionary[String, Shot] = {}
## The longer side of a replica's picture (px): a page that shows replicas small asks for less.
var replica_side: int = LONG_SIDE


## The picture of replica `key` (a pool.md Key) in `paint`, with `parts` fitted (part slot -> part Key, as Kit.parts and
## LoadoutFacts.fitted_keys have them); null if it has no model. Draws again when the paint (or the Realistic colours
## switch) or the parts are not those last drawn. Needs to be in the tree.
func texture(key: StringName, paint: StringName, realistic: bool, parts: Dictionary = {}) -> Texture2D:
	var shot := _shot_of(key)
	if shot == null:
		return null
	var sig := signature(parts)
	var refit := sig != shot.parts_sig
	if refit:
		_fit(shot, key, parts)
		shot.parts_sig = sig
	if refit or not shot.painted or shot.paint != paint or shot.realistic != realistic:
		_paint(shot, paint, realistic)
	return shot.port.get_texture()


## The replica's length and height in metres as its picture holds them (with the margin and the parts last asked for), so
## a picture drawn at the same pixels per metre as another shows the replicas to scale; (1, 1) for a replica with no model.
func extent(key: StringName) -> Vector2:
	var shot := _shot_of(key)
	return shot.extent if shot != null else Vector2.ONE


## The same without any parts.
func bare_extent(key: StringName) -> Vector2:
	var shot := _shot_of(key)
	return shot.bare_extent if shot != null else Vector2.ONE


## The picture's width over its height (1 for a replica with no model).
func aspect(key: StringName) -> float:
	var shot := _shots.get(key) as Shot
	if shot == null:
		return 1.0
	return float(shot.port.size.x) / float(shot.port.size.y)


## How many replicas have a picture (a viewport each).
func count() -> int:
	return _shots.size()


## The picture of part `part` for `slot` of replica `key`, alone, in `paint`; null if the replica's part models don't
## have it. Needs to be in the tree.
func part_texture(key: StringName, slot: StringName, part: StringName, paint: StringName,
		realistic: bool) -> Texture2D:
	var shot := _part_shot(key, slot, part)
	if shot == null:
		return null
	if not shot.painted or shot.paint != paint or shot.realistic != realistic:
		_paint(shot, paint, realistic)
	return shot.port.get_texture()


## The part's length and height in metres as its picture holds them; (1, 1) for a part with no model.
func part_extent(key: StringName, slot: StringName, part: StringName) -> Vector2:
	var shot := _part_shot(key, slot, part)
	return shot.extent if shot != null else Vector2.ONE


## The picture of a power source drawn from `file` (assets/models/powerSources/<file>.glb) with the model's `Label`
## material in `label` (the gas bottle's; ignored by a file with none), tipped about X by `tip` rad (the stick batteries lie
## along the picture and are raised at their lead end to fill it); null if there is no such model. Needs to be in the tree.
func power_texture(file: StringName, label: Color, tip: float = 0.0) -> Texture2D:
	var id := "%s/%s/%s" % [file, label.to_html(), tip]
	var shot := _power_shots.get(id) as Shot
	if shot == null:
		shot = _make_power(file, label, tip)
		if shot == null:
			return null
		_power_shots[id] = shot
	return shot.port.get_texture()


## Lets go of the pictures of every part but those for `slot` of replica `key` (the tab on show keeps its own).
func keep_parts(key: StringName, slot: StringName) -> void:
	var prefix := "%s/%s/" % [key, slot]
	for id: String in _part_shots.keys():
		if not id.begins_with(prefix):
			_part_shots[id].port.queue_free()
			_part_shots.erase(id)


## Lets go of every part picture (no part tab on show).
func let_go_parts() -> void:
	for id: String in _part_shots.keys():
		_part_shots[id].port.queue_free()
	_part_shots.clear()


## How many part pictures are held (a viewport each).
func part_count() -> int:
	return _part_shots.size()


func _paint(shot: Shot, paint: StringName, realistic: bool) -> void:
	shot.paint = paint
	shot.realistic = realistic
	shot.painted = true
	ReplicaPaint.apply(shot.model, paint, realistic)
	shot.port.render_target_update_mode = SubViewport.UPDATE_ONCE


func _shot_of(key: StringName) -> Shot:
	var shot := _shots.get(key) as Shot
	if shot == null:
		shot = _make(key)
		if shot != null:
			_shots[key] = shot
	return shot


func _make(key: StringName) -> Shot:
	var scene := load("%s%s.glb" % [MODEL_DIR, key]) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var figure := model.find_child(FIGURE_NODE, true, false) as Node3D
	if figure != null:
		figure.visible = false
	var shot := _rig(model, replica_side, "Picture_%s" % key)
	shot.bare_extent = shot.extent
	return shot


func _make_power(file: StringName, label: Color, tip: float) -> Shot:
	var path := "%s%s.glb" % [POWER_DIR, file]
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		return null
	# The picture is framed on what sits inside its root, so the tip goes on a node under it.
	var holder := Node3D.new()
	holder.name = "Power"
	var tipped := Node3D.new()
	tipped.rotation.x = tip
	holder.add_child(tipped)
	var model := scene.instantiate() as Node3D
	tipped.add_child(model)
	# The file's materials are shared by every copy of it: each picture takes its own where it changes one.
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_restyle(node as MeshInstance3D, label)
	var shot := _rig(holder, PART_LONG_SIDE, "Power_%s_%s" % [file, label.to_html()])
	shot.bare_extent = shot.extent
	shot.port.render_target_update_mode = SubViewport.UPDATE_ONCE
	return shot


## Paints the `Label` material in `label` and holds metal back, on this mesh alone.
func _restyle(mesh: MeshInstance3D, label: Color) -> void:
	if mesh.mesh == null:
		return
	for i in mesh.mesh.get_surface_count():
		var m := mesh.get_active_material(i) as BaseMaterial3D
		if m == null:
			continue
		if m.resource_name == LABEL_MATERIAL:
			var painted := m.duplicate() as BaseMaterial3D
			painted.albedo_color = label
			mesh.set_surface_override_material(i, painted)
		elif m.metallic > MAX_METALNESS:
			var dull := m.duplicate() as BaseMaterial3D
			dull.metallic = MAX_METALNESS
			mesh.set_surface_override_material(i, dull)


func _part_shot(key: StringName, slot: StringName, part: StringName) -> Shot:
	var id := "%s/%s/%s" % [key, slot, part]
	var shot := _part_shots.get(id) as Shot
	if shot != null:
		return shot
	var taken := ReplicaParts.take(key, {slot: part}, false)
	if taken.is_empty():
		return null
	var node: Node3D = taken.values()[0]
	var model := Node3D.new()
	model.name = "Part"
	model.add_child(node)
	shot = _rig(model, PART_LONG_SIDE, "Part_%s_%s_%s" % [key, slot, part])
	shot.bare_extent = shot.extent
	_part_shots[id] = shot
	return shot


## The viewport, camera, light and sky round `model`, sized to it. Added to this node.
func _rig(model: Node3D, long_side: int, port_name: String) -> Shot:
	var shot := Shot.new()
	shot.long_side = long_side
	shot.model = model
	shot.port = SubViewport.new()
	shot.port.name = port_name
	shot.port.own_world_3d = true
	shot.port.transparent_bg = true
	shot.port.msaa_3d = MSAA
	shot.port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	shot.port.add_child(model)
	shot.camera = Camera3D.new()
	shot.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	shot.camera.near = 0.05
	shot.camera.far = CAMERA_DISTANCE * 2.0
	shot.camera.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	shot.port.add_child(shot.camera)
	_frame(shot)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(SUN_ANGLE.x, SUN_ANGLE.y, 0.0)
	sun.light_energy = SUN_ENERGY
	shot.port.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	var world := WorldEnvironment.new()
	world.environment = env
	shot.port.add_child(world)
	add_child(shot.port)
	return shot


## Fits the viewport and the camera to what the model shows now.
func _frame(shot: Shot) -> void:
	var box := bounds(shot.model)
	var wide := maxf(box.size.z * MARGIN, MIN_EXTENT)
	var high := maxf(box.size.y * MARGIN, MIN_EXTENT)
	shot.extent = Vector2(wide, high)
	var scale := float(shot.long_side) / maxf(wide, high)
	shot.port.size = Vector2i(maxi(1, roundi(wide * scale)), maxi(1, roundi(high * scale)))
	shot.camera.size = high
	shot.camera.position = box.get_center() + Vector3(CAMERA_DISTANCE, 0.0, 0.0)


## Puts `parts` on the shot's model in place of the ones there (ReplicaParts) and frames the picture to the result.
func _fit(shot: Shot, key: StringName, parts: Dictionary) -> void:
	if shot.fit != null:
		ReplicaParts.unfit(shot.fit)
	shot.fit = ReplicaParts.fit(shot.model, key, parts)
	_frame(shot)


## "slot=key" for each part, in slot order: what two calls must differ by to need a new picture (or a refit).
static func signature(parts: Dictionary) -> String:
	var words := PackedStringArray()
	for slot: StringName in parts:
		words.append("%s=%s" % [slot, parts[slot]])
	words.sort()
	return ",".join(words)


## The model's box (its own space) from its visible meshes, found without needing the tree: each mesh's box moved by the
## transforms between it and the model. ReplicaTurntable frames on it too.
static func bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.mesh == null or _hidden(m, model):
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != model and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _hidden(node: Node3D, model: Node3D) -> bool:
	var n: Node = node
	while n != model and n is Node3D:
		if not (n as Node3D).visible:
			return true
		n = n.get_parent()
	return false
