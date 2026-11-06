class_name ReplicaParts
extends RefCounted
## Fits a replica's parts to its model, the one way the hands, the figures and the menu pictures all do it, so a part
## always looks like its model (owner, 2026-10-19). The part models are assets/models/replicaParts/<replica>.glb, one
## top-level object per part named <slot>_<key>, placed where it sits on the replica, with its figures' cut-down copy
## (<slot>_<key>_Figure) beside it or under it. A magazine part takes the standard magazine's place and follows it
## through a reload; a muzzle part takes the flash hider's; a barrel with an end point carries the muzzle device and the
## muzzle out to it; an optic hides the iron sights whole (IronSights). `unfit` undoes it all. What a part puts inside
## the replica (a barrel's inner barrel and hop-up unit) is in its own file, assets/models/replicaParts/inside/<replica>.glb,
## as <slot>_<key>_Inside: only the part's own picture draws it (`inside`), so fitting never loads it.

const PART_DIR := "res://assets/models/replicaParts/"
const INSIDE_DIR := "res://assets/models/replicaParts/inside/"
const FIGURE_SUFFIX := "_Figure"
const SIGHT_LINE_SUFFIX := "_SightLine"
const MUZZLE_SUFFIX := "_Muzzle"
const BARREL_END_SUFFIX := "_BarrelEnd"
const INSIDE_SUFFIX := "_Inside"
## The replica's own nodes the parts work with: its magazine mesh(es) and the bone attachment that carries them through
## the clips, its flash hider and its muzzle point.
const MAGAZINE_NODE := "Magazine"
const MAGAZINE_ATTACHMENT := "magazine"
const FLASH_HIDER_NODE := "FlashHider"
const MUZZLE_NODE := "Muzzle"
const OPTIC_SLOT := &"optic"
const MAGAZINE_SLOT := &"magazine"
const MUZZLE_SLOT := &"muzzle"
const BARREL_SLOT := &"barrel"


## What fitting did to one model, so it can be undone, and what the views need from it.
class Fit:
	extends RefCounted
	var model: Node3D = null
	## The part nodes added; the replica's own nodes they hid; those they moved, and from where.
	var nodes: Array[Node3D] = []
	var hidden: Array[Node3D] = []
	var moved: Array[Node3D] = []
	var moved_from: Array[Vector3] = []
	## The optic fitted (null: the iron sights), its Key, and its sight line's place in the model's space.
	var optic: Node3D = null
	var optic_key: StringName = &""
	var sight_line: Vector3 = Vector3.ZERO
	## Where BBs leave the replica now: the muzzle part's end, else its own muzzle point (null if the model has none).
	var muzzle: Node3D = null


## Fits `parts` (part slot -> part Key, as Kit.parts has them) to `model`, replica `key`'s model. A part the models
## lack is left out.
static func fit(model: Node3D, key: StringName, parts: Dictionary) -> Fit:
	var f := Fit.new()
	f.model = model
	f.muzzle = model.find_child(MUZZLE_NODE, true, false) as Node3D
	var taken := take(key, parts, false)
	if taken.is_empty():
		return f
	# A longer barrel carries whatever sits on its end, and the muzzle point, out with it.
	var shift := Vector3.ZERO
	var barrel := taken.get(BARREL_SLOT) as Node3D
	if barrel != null:
		var end := barrel.find_child("*" + BARREL_END_SUFFIX, false, false) as Node3D
		if end != null:
			shift = barrel.basis * end.position
	var flash_hider := model.find_child(FLASH_HIDER_NODE, true, false) as Node3D
	if flash_hider != null:
		_move(f, flash_hider, shift)
	if f.muzzle != null:
		_move(f, f.muzzle, shift)
	for slot: StringName in taken:
		var node := taken[slot]
		match slot:
			MAGAZINE_SLOT:
				for mag in model.find_children(MAGAZINE_NODE, "Node3D", true, false):
					_hide(f, mag as Node3D)
				var attachment := model.find_child(MAGAZINE_ATTACHMENT, true, false) as Node3D
				if attachment != null:
					node.transform = _in_model(attachment, model).affine_inverse() * node.transform
					attachment.add_child(node)
				else:
					model.add_child(node)
			MUZZLE_SLOT:
				if flash_hider != null:
					_hide(f, flash_hider)
				node.position += shift
				model.add_child(node)
				var end := node.find_child("*" + MUZZLE_SUFFIX, false, false) as Node3D
				if end != null:
					f.muzzle = end
			OPTIC_SLOT:
				model.add_child(node)
				f.optic = node
				f.optic_key = StringName(parts[slot])
				var line := node.find_child("*" + SIGHT_LINE_SUFFIX, false, false) as Node3D
				f.sight_line = node.transform * (line.position if line != null else Vector3.ZERO)
			_:
				model.add_child(node)
		f.nodes.append(node)
	if f.optic != null:
		for sight in IronSights.of(model):
			_hide(f, sight)
	return f


## Takes the parts off again: frees them and puts back what they hid (the iron sights too) and moved.
static func unfit(f: Fit) -> void:
	for node in f.nodes:
		node.get_parent().remove_child(node)
		node.free()
	f.nodes.clear()
	for node in f.hidden:
		node.visible = true
	f.hidden.clear()
	for i in f.moved.size():
		f.moved[i].position = f.moved_from[i]
	f.moved.clear()
	f.moved_from.clear()
	f.optic = null
	f.optic_key = &""
	f.muzzle = f.model.find_child(MUZZLE_NODE, true, false) as Node3D


## The figures' cut-down copies of `parts` for replica `key`, each placed in the replica's space (the figure version of
## the replica shares its origin).
static func figure_meshes(key: StringName, parts: Dictionary) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var taken := take(key, parts, true)
	for slot: StringName in taken:
		var mesh := taken[slot] as MeshInstance3D
		if mesh != null:
			out.append(mesh)
		else:
			taken[slot].free()
	return out


## The part nodes for `parts` out of the replica's part models (a menu's part picture takes one alone), owned by nothing: the parts themselves without their
## figure copies, or (`figure`) just the figure copies, placed in the replica's space. Slot -> node.
static func take(key: StringName, parts: Dictionary, figure: bool) -> Dictionary[StringName, Node3D]:
	var taken: Dictionary[StringName, Node3D] = {}
	var path := "%s%s.glb" % [PART_DIR, key]
	if parts.is_empty() or not ResourceLoader.exists(path):
		return taken
	var scene := load(path) as PackedScene
	if scene == null:
		return taken
	var holder := scene.instantiate() as Node3D
	for slot: Variant in parts:
		var part_name := "%s_%s" % [slot, parts[slot]]
		var node := holder.get_node_or_null(part_name) as Node3D
		if node == null:
			continue
		var copy := holder.get_node_or_null(part_name + FIGURE_SUFFIX) as Node3D
		var inner := node.get_node_or_null(part_name + FIGURE_SUFFIX) as Node3D
		if figure:
			if copy == null and inner != null:
				inner.transform = node.transform * inner.transform
				copy = inner
			if copy == null:
				continue
			node = copy
		elif inner != null:
			node.remove_child(inner)
			inner.free()
		node.get_parent().remove_child(node)
		node.owner = null
		for child in node.find_children("*", "", true, false):
			child.owner = null
		taken[StringName(slot)] = node
	holder.free()
	return taken


## What part `part` for `slot` of replica `key` puts inside the replica, placed in the replica's space, owned by nothing;
## null if it puts nothing there. The part's own picture draws it beside the part.
static func inside(key: StringName, slot: StringName, part: StringName) -> Node3D:
	var path := "%s%s.glb" % [INSIDE_DIR, key]
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var holder := scene.instantiate() as Node3D
	var node := holder.get_node_or_null("%s_%s%s" % [slot, part, INSIDE_SUFFIX]) as Node3D
	if node != null:
		holder.remove_child(node)
		node.owner = null
		for child in node.find_children("*", "", true, false):
			child.owner = null
	holder.free()
	return node


static func _hide(f: Fit, node: Node3D) -> void:
	if node.visible:
		node.visible = false
		f.hidden.append(node)


## Moves `node` by `shift` in the model's space, noting where it was.
static func _move(f: Fit, node: Node3D, shift: Vector3) -> void:
	if shift == Vector3.ZERO:
		return
	f.moved.append(node)
	f.moved_from.append(node.position)
	var parent := node.get_parent() as Node3D
	node.position += _in_model(parent, f.model).basis.inverse() * shift if parent != null else shift


## `node`'s transform in `model`'s space, from the transforms between them (no tree needed).
static func _in_model(node: Node3D, model: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != model and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
