class_name ReplicaSurfaces
extends RefCounted
## What the replicas, their parts and the accessories are made of (MQ1, owner 2026-11-12: "made out of metal
## (steel/aluminium), polymer, wood"): the surface kinds a model's faces name and how each is drawn under whatever paint
## the part wears (game/play/replica_surface.gdshaderinc). A paint picks the colour, the surface says how that colour
## behaves in the light: a steel slide and an anodised receiver reflect, a polymer frame is matte with a moulded grain,
## a wood stock shows its figure in a walnut stain the paint tints. Presentation only: nothing in the simulation
## reads it. A model says each face's kind in its vertex colour's alpha, `index / SLOTS`
## (tools/blender/replicas/surface.py writes them, in this order: never reorder KINDS, the model files hold the index).

## The kinds, by index.
const KINDS: Array[StringName] = [&"polymer", &"steel", &"aluminium", &"wood", &"rubber", &"bare", &"coated"]
## How many kinds the shader's tables hold (the vertex colour's step is 1 / SLOTS).
const SLOTS := 8
## The kind a face with no vertex colours is drawn as, by the paint's part: the metal part steel, the rest polymer.
const PART_KIND: Dictionary[StringName, StringName] = {&"Metal": &"steel"}
const DEFAULT_KIND := &"polymer"
## The stain a wood part is drawn in (sRGB: walnut), and how far it takes the colour over from the paint, which tints
## the rest: a wood stock is wood in any paint.
const WOOD_STAIN := Color("7a4a26")
const WOOD_STAIN_SHARE := 0.8
## The shared grain texture (tools/textures/replica_grain.py).
const GRAIN := preload("res://assets/textures/replica/replica_grain.png")

## Each kind's finish. `metallic` and `roughness` as a material's; `sheen` how far the slow cloud moves the roughness
## either way; `bares` how far wear cuts through to bare metal (0 a coat that only scuffs, 1 bright metal). `tile` the grain's repeat (m), `stretch` how many times
## longer it is drawn along the bore (a brushed finish, a wood grain), `relief` how deep it reads, `figure` how much of
## the wood figure (and the wood stain) the colour takes, between `dark` and `light` times it. `cloud` is the cloud's repeat (m) and
## `gain` scales the paint's colour (bare steel is brighter than any coat).
const LOOKS: Dictionary[StringName, Dictionary] = {
	&"polymer": {
		"metallic": 0.0, "roughness": 0.62, "sheen": 0.05, "bares": 0.0,
		"tile": 0.02, "stretch": 1.0, "relief": 0.3, "figure": 0.0,
		"cloud": 0.13, "dark": 1.0, "light": 1.0, "gain": 1.0,
	},
	&"steel": {
		"metallic": 0.75, "roughness": 0.44, "sheen": 0.09, "bares": 0.45,
		"tile": 0.024, "stretch": 10.0, "relief": 0.07, "figure": 0.0,
		"cloud": 0.11, "dark": 1.0, "light": 1.0, "gain": 1.0,
	},
	&"aluminium": {
		"metallic": 0.7, "roughness": 0.52, "sheen": 0.05, "bares": 0.5,
		"tile": 0.014, "stretch": 1.0, "relief": 0.16, "figure": 0.0,
		"cloud": 0.15, "dark": 1.0, "light": 1.0, "gain": 1.0,
	},
	&"wood": {
		"metallic": 0.0, "roughness": 0.46, "sheen": 0.07, "bares": 0.0,
		"tile": 0.11, "stretch": 9.0, "relief": 0.22, "figure": 1.0,
		"cloud": 0.2, "dark": 0.6, "light": 1.12, "gain": 1.0,
	},
	&"rubber": {
		"metallic": 0.0, "roughness": 0.86, "sheen": 0.03, "bares": 0.0,
		"tile": 0.03, "stretch": 1.0, "relief": 0.7, "figure": 0.0,
		"cloud": 0.12, "dark": 1.0, "light": 1.0, "gain": 1.0,
	},
	&"bare": {
		"metallic": 0.95, "roughness": 0.28, "sheen": 0.08, "bares": 1.0,
		"tile": 0.03, "stretch": 18.0, "relief": 0.14, "figure": 0.0,
		"cloud": 0.1, "dark": 1.0, "light": 1.0, "gain": 2.2,
	},
	# Metal under a thick baked coat (a ceramic or powder coat): the coat's colour in any light, smooth, a soft shine.
	&"coated": {
		"metallic": 0.1, "roughness": 0.4, "sheen": 0.06, "bares": 0.5,
		"tile": 0.014, "stretch": 1.0, "relief": 0.05, "figure": 0.0,
		"cloud": 0.15, "dark": 1.0, "light": 1.0, "gain": 1.0,
	},
}

## The shader's tables, built once: the kinds' finish, grain and tone rows (SLOTS each).
static var _finish: Array[Vector4] = []
static var _grain: Array[Vector4] = []
static var _tone: Array[Vector4] = []


## The index of `kind` (the vertex colour's alpha times SLOTS); the default kind's for a name it doesn't know.
static func index(kind: StringName) -> int:
	var at := KINDS.find(kind)
	return at if at >= 0 else KINDS.find(DEFAULT_KIND)


## The kind a face with no vertex colours is drawn as on the paint's `part`.
static func part_index(part: StringName) -> int:
	return index(PART_KIND.get(part, DEFAULT_KIND))


## Sets the kinds' tables and the grain on `material` (one drawn by replica_surface.gdshader).
static func dress(material: ShaderMaterial) -> void:
	if _finish.is_empty():
		_build()
	material.set_shader_parameter(&"kind_finish", _finish)
	material.set_shader_parameter(&"kind_grain", _grain)
	material.set_shader_parameter(&"kind_tone", _tone)
	material.set_shader_parameter(&"grain", GRAIN)
	material.set_shader_parameter(&"wood_stain", WOOD_STAIN)
	material.set_shader_parameter(&"wood_stain_share", WOOD_STAIN_SHARE)


static func _build() -> void:
	var fallback: Dictionary = LOOKS[DEFAULT_KIND]
	for i in SLOTS:
		var look: Dictionary = LOOKS.get(KINDS[i], fallback) if i < KINDS.size() else fallback
		_finish.append(Vector4(look["metallic"], look["roughness"], look["sheen"], look["bares"]))
		_grain.append(Vector4(look["tile"], look["stretch"], look["relief"], look["figure"]))
		_tone.append(Vector4(look["cloud"], look["dark"], look["light"], look["gain"]))
