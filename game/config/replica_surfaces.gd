class_name ReplicaSurfaces
extends RefCounted
## What the replicas, their parts and the accessories are made of (MQ1, owner 2026-11-12: "made out of metal
## (steel/aluminium), polymer, wood"): the surface kinds a model's faces name and how each is drawn under whatever paint
## the part wears (game/play/replica_surface.gdshaderinc). A paint picks the colour, the surface says how that colour
## behaves in the light: a steel slide and an anodised receiver reflect, a polymer frame is matte with a moulded grain,
## a wood stock shows its figure in a walnut stain the paint tints. Presentation only: nothing in the simulation
## reads it. A replica says each face's kind in its vertex colour's alpha, `index / SLOTS`
## (tools/blender/replicas/surface.py writes them, in this order: never reorder KINDS, the model files hold the index).
## A part or an accessory (MQ2: an attachment, a magazine, a barrel) is one kind a material, so its mesh carries a small
## table instead, material name to kind's name (the glb's mesh extras, kept by Godot as the mesh's `extras` metadata;
## `named` reads it): no colour a vertex in files that sit near their size cap.

## The kinds, by index.
const KINDS: Array[StringName] = [
	&"polymer", &"steel", &"aluminium", &"wood", &"rubber", &"bare", &"coated", &"polished",
]
## How many kinds the shader's tables hold (the vertex colour's step is 1 / SLOTS).
const SLOTS := 16
## The kind a face with no vertex colours is drawn as, by the paint's part: the metal part steel, the rest polymer.
const PART_KIND: Dictionary[StringName, StringName] = {&"Metal": &"steel"}
const DEFAULT_KIND := &"polymer"
## The stain a wood part is drawn in (sRGB: walnut), and how far it takes the colour over from the paint, which tints
## the rest: a wood stock is wood in any paint.
const WOOD_STAIN := Color("7a4a26")
const WOOD_STAIN_SHARE := 0.8
## The metadata Godot keeps a glb mesh's extras in, and the key of a part's table of kinds there (surface.py EXTRA).
const EXTRAS_META := &"extras"
const NAMED_KEY := "surfaces"
## The shared grain texture (tools/textures/replica_grain.py).
const GRAIN := preload("res://assets/textures/replica/replica_grain.png")

## Each kind's finish. `metallic` and `roughness` as a material's; `sheen` how far the slow cloud moves the roughness
## either way; `bares` how far wear cuts through to bare metal (0 a coat that only scuffs, 1 bright metal). `tile` the
## grain's repeat (m), `stretch` how many times longer it is drawn along the bore (a brushed finish, a wood grain),
## `relief` how deep it reads, `figure` how much of the wood figure (and the wood stain) the colour takes, between
## `dark` and `light` times it. `cloud` is the cloud's repeat (m) and `gain` scales the paint's colour (bare steel is
## brighter than any coat). `specular` as a material's (a coat over metal shines harder than a moulding), `light_keeps`
## the share of the metallic a light paint keeps (a dark finish is an oxide or an anodise, metal to look at; a light
## one a baked coat in the paint's own colour) and `floor` the least a metal face reflects (linear: gunmetal).
## `bold_keeps` is how far a bold paint escapes `gain` (1: only greys, black and white take it; owner, 2026-11-12:
## black polymer darker, but lighter than black metal, and white polymer less bright).
const LOOKS: Dictionary[StringName, Dictionary] = {
	# A moulding: matte, a pebbled grain, a dull highlight.
	&"polymer": {
		"metallic": 0.0, "roughness": 0.66, "sheen": 0.05, "bares": 0.0,
		"tile": 0.02, "stretch": 1.0, "relief": 0.3, "figure": 0.0,
		"cloud": 0.13, "dark": 1.0, "light": 1.0, "gain": 0.72,
		"specular": 0.25, "light_keeps": 1.0, "floor": 0.0, "bold_keeps": 1.0,
	},
	# Coated steel (nitride, parkerising, a baked coat): smooth and satin, a tight highlight, gunmetal when dark.
	&"steel": {
		"metallic": 0.8, "roughness": 0.36, "sheen": 0.08, "bares": 0.45,
		"tile": 0.012, "stretch": 1.0, "relief": 0.05, "figure": 0.0,
		"cloud": 0.11, "dark": 1.0, "light": 1.0, "gain": 0.64,
		"specular": 1.0, "light_keeps": 0.3, "floor": 0.1, "bold_keeps": 0.0,
	},
	# Anodised aluminium: the colour is in the metal, a finer blasted grain, a brighter sheen than steel's.
	&"aluminium": {
		"metallic": 0.85, "roughness": 0.3, "sheen": 0.06, "bares": 0.5,
		"tile": 0.014, "stretch": 1.0, "relief": 0.1, "figure": 0.0,
		"cloud": 0.15, "dark": 1.0, "light": 1.0, "gain": 0.68,
		"specular": 1.0, "light_keeps": 0.6, "floor": 0.12, "bold_keeps": 0.0,
	},
	&"wood": {
		"metallic": 0.0, "roughness": 0.46, "sheen": 0.07, "bares": 0.0,
		"tile": 0.11, "stretch": 9.0, "relief": 0.22, "figure": 1.0,
		"cloud": 0.2, "dark": 0.6, "light": 1.12, "gain": 1.0,
		"specular": 0.5, "light_keeps": 1.0, "floor": 0.0, "bold_keeps": 0.0,
	},
	&"rubber": {
		"metallic": 0.0, "roughness": 0.86, "sheen": 0.03, "bares": 0.0,
		"tile": 0.03, "stretch": 1.0, "relief": 0.7, "figure": 0.0,
		"cloud": 0.12, "dark": 1.0, "light": 1.0, "gain": 1.0,
		"specular": 0.3, "light_keeps": 1.0, "floor": 0.0, "bold_keeps": 0.0,
	},
	# Bright unpainted steel, brushed along the bore.
	&"bare": {
		"metallic": 0.95, "roughness": 0.28, "sheen": 0.08, "bares": 1.0,
		"tile": 0.03, "stretch": 8.0, "relief": 0.12, "figure": 0.0,
		"cloud": 0.1, "dark": 1.0, "light": 1.0, "gain": 2.2,
		"specular": 0.5, "light_keeps": 1.0, "floor": 0.0, "bold_keeps": 0.0,
	},
	# Metal under a thick baked coat (a ceramic or powder coat): the coat's colour in any light, smooth, a soft shine.
	&"coated": {
		"metallic": 0.1, "roughness": 0.3, "sheen": 0.06, "bares": 0.5,
		"tile": 0.014, "stretch": 1.0, "relief": 0.05, "figure": 0.0,
		"cloud": 0.15, "dark": 1.0, "light": 1.0, "gain": 0.78,
		"specular": 1.0, "light_keeps": 1.0, "floor": 0.0, "bold_keeps": 0.0,
	},
	# Bright metal in its own colour (a brass or polished steel barrel's crown): smooth, unbrushed, all metal, with no
	# grain or clouding at all, so its highlight is one clean band; its colour lifted (gain) as bare metal's is, or all
	# metal reads dark wherever the sky it mirrors is dull.
	&"polished": {
		"metallic": 1.0, "roughness": 0.22, "sheen": 0.05, "bares": 1.0,
		"tile": 0.02, "stretch": 1.0, "relief": 0.0, "figure": 0.0,
		"cloud": 0.0, "dark": 1.0, "light": 1.0, "gain": 1.8,
		"specular": 0.5, "light_keeps": 1.0, "floor": 0.0, "bold_keeps": 0.0,
	},
}

## The shader's tables, built once: the kinds' finish, grain, tone and shine rows (SLOTS each).
static var _finish: Array[Vector4] = []
static var _grain: Array[Vector4] = []
static var _tone: Array[Vector4] = []
static var _shine: Array[Vector4] = []


## The index of `kind` (the vertex colour's alpha times SLOTS); the default kind's for a name it doesn't know.
static func index(kind: StringName) -> int:
	var at := KINDS.find(kind)
	return at if at >= 0 else KINDS.find(DEFAULT_KIND)


## The kind a face with no vertex colours is drawn as on the paint's `part`.
static func part_index(part: StringName) -> int:
	return index(PART_KIND.get(part, DEFAULT_KIND))


## The kinds `mesh` names for its materials (MQ2: a part's table, see the top), material name to kind's index; empty
## for a mesh that names none (a replica: its faces say theirs). A kind this build doesn't know is left out.
static func named(mesh: Mesh) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if mesh == null or not mesh.has_meta(EXTRAS_META):
		return out
	var extras: Variant = mesh.get_meta(EXTRAS_META)
	var table: Variant = (extras as Dictionary).get(NAMED_KEY) if extras is Dictionary else null
	if table is Dictionary:
		for material_name: Variant in table as Dictionary:
			var at := KINDS.find(StringName(str((table as Dictionary)[material_name])))
			if at >= 0:
				out[StringName(str(material_name))] = at
	return out


## Sets the kinds' tables and the grain on `material` (one drawn by replica_surface.gdshader).
static func dress(material: ShaderMaterial) -> void:
	if _finish.is_empty():
		_build()
	material.set_shader_parameter(&"kind_finish", _finish)
	material.set_shader_parameter(&"kind_grain", _grain)
	material.set_shader_parameter(&"kind_tone", _tone)
	material.set_shader_parameter(&"kind_shine", _shine)
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
		_shine.append(Vector4(look["specular"], look["light_keeps"], look["floor"], look["bold_keeps"]))
