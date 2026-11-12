class_name StationLook
extends Resource
## How a map naming a station dress is drawn (MT3, Subway: `dressing.station`, StationDressing): its blocks in CC0
## photo materials (ambientCG, docs/ASSETS.md) instead of greybox paint, one material and one draw for the whole level
## (StationSurface). Each face takes a finish: a block a kind's own (a cabinet's painted steel, a crate's planks), else
## the finish its room's style gives a floor, a wall or a ceiling facing that room; a block inside a room that owns
## its blocks (a train) takes that room's. Look only: the blocks, colliders, nav and sight lines are the greybox's.
## Every paint is muted (look_paint) and kept off both team hues, yellow the only safety colour.

## The texture sets, ambientCG ids in the texture arrays' layer order: tools/textures/station_textures.gd bakes each
## set's colour, normal and roughness into `colour_array` and `surface_array` in this order.
@export var sets: Array[StringName] = [
	&"Tiles136B", &"Terrazzo002", &"Concrete029", &"Concrete035", &"Gravel035",
	&"CorrugatedSteel009", &"PaintedMetal012", &"Rust004", &"CorrugatedSteel005", &"Planks023A", &"PaintedPlaster011",
	&"Rubber004", &"TactilePaving003", &"Planks008", &"Tiles017", &"Concrete034",
]
## The colour array (sRGB) and the surface array (the OpenGL normal's x and y in red and green, roughness in blue),
## each a column of 512 px layers, imported as Texture2DArray.
@export_file("*.jpg", "*.png") var colour_array: String = "res://assets/textures/station/station_col.jpg"
@export_file("*.png") var surface_array: String = "res://assets/textures/station/station_srf.png"

## Each finish: its set, the metres one copy of the set covers, its tint (sRGB, times the set's colour; a painted
## block's own colour replaces it), and its roughness scale and metalness.
@export var finish_sets: Dictionary[StringName, StringName] = {
	&"wall_tile": &"Tiles136B", &"terrazzo": &"Terrazzo002", &"plaster": &"Concrete034",
	&"concrete": &"Concrete029", &"platform": &"Concrete035", &"ballast": &"Gravel035", &"tread": &"CorrugatedSteel009",
	&"steel": &"PaintedMetal012", &"rust": &"Rust004", &"shutter": &"CorrugatedSteel005", &"planks": &"Planks023A",
	&"plant": &"PaintedPlaster011", &"rubber": &"Rubber004", &"tactile": &"TactilePaving003", &"lining": &"Concrete029",
	&"boards": &"Planks008", &"quarry": &"Tiles017", &"painted": &"Concrete029", &"car": &"PaintedMetal012",
	&"coping": &"Concrete035", &"soot": &"Concrete029", &"rail": &"Rust004", &"sleeper": &"Concrete035",
	&"gap_line": &"PaintedMetal012", &"paint": &"PaintedMetal012", &"vault_tile": &"Tiles136B",
	&"platform_floor": &"Concrete034", &"vault_rib": &"Concrete034", &"frieze": &"Tiles136B", &"cable": &"Rubber004",
}
@export var finish_scales: Dictionary[StringName, float] = {
	&"wall_tile": 0.6, &"terrazzo": 2.0, &"plaster": 2.5, &"concrete": 3.0, &"platform": 2.5, &"ballast": 1.6,
	&"tread": 0.8, &"steel": 1.5, &"rust": 2.0, &"shutter": 1.6, &"planks": 1.5, &"plant": 2.5, &"rubber": 1.5,
	&"tactile": 0.8, &"lining": 2.4, &"boards": 1.8, &"quarry": 1.2, &"painted": 2.5, &"car": 1.5, &"coping": 1.0,
	&"soot": 3.0, &"rail": 0.5, &"sleeper": 1.0, &"gap_line": 2.0, &"paint": 2.0,
	&"vault_tile": 0.6, &"platform_floor": 4.0, &"vault_rib": 2.0, &"frieze": 0.6, &"cable": 1.0,
}
@export var finish_tints: Dictionary[StringName, Color] = {
	# TB1 (owner, 2026-11-12: "a more white/grey look"): white glazed tiles, faintly cool.
	&"wall_tile": Color8(0xf6, 0xf7, 0xf7), &"terrazzo": Color8(0xf0, 0xe6, 0xd6), &"plaster": Color8(0xf0, 0xec, 0xe4),
	&"concrete": Color8(0xc8, 0xc2, 0xb8), &"soot": Color8(0x6c, 0x68, 0x64),
	&"steel": Color8(0xc0, 0xbc, 0xb2), &"car": Color8(0xd8, 0xd4, 0xca), &"lining": Color8(0x9c, 0x98, 0x90),
	&"coping": Color8(0xe6, 0xe2, 0xd8), &"rail": Color8(0xb0, 0xaa, 0xa2), &"sleeper": Color8(0xb4, 0xb0, 0xa6),
	&"shutter": Color8(0xb4, 0xb0, 0xa8),
	# TB1: the platforms' painted yellow line (the one safety yellow, `safety_finishes`) and the words' white paint.
	&"gap_line": Color8(0xe0, 0xbc, 0x2a), &"paint": Color8(0xe8, 0xe6, 0xe0),
	# The platforms' floor: smooth, even grey concrete (owner, 2026-11-12: "more solid and clean looking").
	&"platform_floor": Color8(0xb8, 0xb8, 0xb6),
	# TB1's trims: the vault's ribs in grey concrete (facing down, they read as dark rings), the frieze in dark
	# green-grey tiles (a band of colour off both team hues), the cables black rubber.
	&"vault_rib": Color8(0xc8, 0xcb, 0xcc), &"frieze": Color8(0x3c, 0x48, 0x44), &"cable": Color8(0x60, 0x60, 0x60),
	# The track bed's ballast a dark grey, near black, under the rails (owner, 2026-11-12).
	&"ballast": Color8(0x4a, 0x4a, 0x4a),
	# The vault's tiles, the walls' faintly cooler: the warm light from below would turn a down-facing white tan.
	&"vault_tile": Color8(0xe4, 0xec, 0xf6),
}
## The finishes painted the one safety colour (yellow, off both team hues): their tints may be saturated.
@export var safety_finishes: Array[StringName] = [&"gap_line"]
@export var finish_pbr: Dictionary[StringName, Vector2] = {
	&"wall_tile": Vector2(0.7, 0.0), &"vault_tile": Vector2(0.7, 0.0), &"frieze": Vector2(0.6, 0.0),
	&"terrazzo": Vector2(0.8, 0.0),
	&"tread": Vector2(0.9, 0.6), &"steel": Vector2(1.0, 0.2), &"car": Vector2(0.9, 0.3),
	&"rust": Vector2(1.0, 0.3), &"shutter": Vector2(1.0, 0.4),
	&"rail": Vector2(0.8, 0.5), &"gap_line": Vector2(0.8, 0.0), &"paint": Vector2(0.8, 0.0),
}

## Each room style's finishes for a floor (a face looking up), a wall and a ceiling (looking down) facing its air.
@export var style_floors: Dictionary[StringName, StringName] = {
	&"hall": &"terrazzo", &"passage": &"quarry", &"escalator": &"tread", &"plant": &"platform", &"service": &"platform",
	&"platform": &"platform_floor", &"track": &"ballast", &"tunnel": &"ballast", &"train": &"rubber",
}
## The track's walls (the trackside wall across from a platform) wear the station's white tiles (owner, 2026-11-12:
## "should be white and almost match the rest of the station design").
@export var style_walls: Dictionary[StringName, StringName] = {
	&"hall": &"wall_tile", &"passage": &"wall_tile", &"escalator": &"wall_tile", &"plant": &"plant",
	&"service": &"concrete", &"platform": &"wall_tile", &"track": &"wall_tile", &"tunnel": &"lining", &"train": &"car",
}
@export var style_ceilings: Dictionary[StringName, StringName] = {
	&"hall": &"plaster", &"passage": &"plaster", &"escalator": &"plaster", &"plant": &"plaster", &"service": &"concrete",
	&"platform": &"plaster", &"track": &"plaster", &"tunnel": &"lining", &"train": &"car",
}
## The finish of a cover block's kind, all its faces (the station's shell, `wall`, `floor`, `ramp` and `pillar`, follows
## its rooms).
@export var kind_finishes: Dictionary[StringName, StringName] = {
	&"cabinet": &"steel", &"crate": &"planks", &"furniture": &"planks", &"hoarding": &"boards", &"shed": &"shutter",
	&"skip": &"rust", &"generator": &"steel", &"barrier": &"steel", &"container": &"shutter",
}
## The cover kinds a room that owns its blocks draws in its own finishes (a train's car ends), not their kind's.
@export var owned_kinds: Array[StringName] = [&"container"]
## A shell block with its own colour (the lift shafts) is plain paint in it where it faces no room (inside the wells);
## facing a room it wears that room's walls like any other shell.
@export var painted_shell: StringName = &"painted"
## A face that looks into no room (the station's outside, seen nowhere) and the ground beyond the walls.
@export var outside: StringName = &"soot"

## How far (m) a face's middle is looked past along its normal for the room it faces.
@export var probe: float = 0.05
## Grime up a wall's foot: up to this high (m) over its room's floor, at this much of the look's grime colour; and the
## broad blotches that break up a set's repeats, this much lighter or darker, about `variation_size` m across.
@export var grime_height: float = 0.8
@export_range(0.0, 1.0) var grime_strength: float = 0.5
@export_range(0.0, 0.5) var variation: float = 0.16
@export var variation_size: float = 3.0
## How far (m) a platform's edge strip lies over the floor, and its painted words (StationDressing.Words) over that.
@export var strip_lift: float = 0.01
@export var words_lift: float = 0.01
## The words' paint.
@export var words_finish: StringName = &"paint"
## A platform tunnel's vault (StationDressing.TunnelVault, TB1): its finish (the platform's tiles carried over the arc,
## a shade cooler), the pieces its arc is drawn in, and how far (m) its ends are drawn in front of the ends of the
## shell behind them.
@export var vault_finish: StringName = &"vault_tile"
@export var vault_steps: int = 32
@export var vault_proud: float = 0.01
## The vault's ribs (TB1: its lining rings): one `vault_rib_width` m wide every `vault_rib_every` m along it, standing
## `vault_rib_depth` m under the arc, in `vault_rib_finish` (look only: BBs meet the vault's colliders).
@export var vault_rib_every: float = 6.0
@export var vault_rib_width: float = 0.3
@export var vault_rib_depth: float = 0.05
@export var vault_rib_finish: StringName = &"vault_rib"
## The track: rails a standard gauge apart (m, between their middles), each a head this wide and tall; sleepers this
## long, wide and tall, one every `sleeper_pitch` m. Scenery: no collider (a rail stands lower than a step).
@export var gauge: float = 1.5
@export var rail_size: Vector2 = Vector2(0.07, 0.08)
@export var sleeper_size: Vector3 = Vector3(2.4, 0.06, 0.24)
@export var sleeper_pitch: float = 0.7


## The layer of finish `finish` in the texture arrays (its set's place in `sets`), `outside`'s for one it doesn't know.
func layer_of(finish: StringName) -> int:
	var at := sets.find(finish_sets.get(finish, finish_sets[outside]))
	return at if at >= 0 else 0


## The finish of the face of block `b` facing `normal` into a room of style `style` (&"" when it faces none); `own` is
## the style of a room that owns `b` (a train's), else &"".
func finish_of(b: MapData.Block, normal: Vector3, style: StringName, own: StringName) -> StringName:
	var room := own if own != &"" else style
	if kind_finishes.has(b.kind) and (own == &"" or not owned_kinds.has(b.kind)):
		return kind_finishes[b.kind]
	if room == &"" or not style_walls.has(room):
		return painted_shell if own == &"" and b.colour.a > 0.0 else outside
	var up := normal.y
	if up > 0.5 and (b.kind == &"floor" or b.kind == &"ramp" or own != &""):
		return style_floors[room]
	if up < -0.5:
		return style_ceilings[room]
	return style_walls[room]


## The tint finish `finish` draws block `b` in (sRGB): a painted shell's own colour (the lift shafts' plain paint),
## else the finish's (a cover block's greybox colour stays the greybox's: the photo sets carry their own).
func tint_of(finish: StringName, b: MapData.Block) -> Color:
	if b != null and b.colour.a > 0.0 and finish == painted_shell:
		return b.colour
	return finish_tints.get(finish, Color.WHITE)


## Finish `finish`'s roughness scale and metalness.
func pbr_of(finish: StringName) -> Vector2:
	return finish_pbr.get(finish, Vector2(1.0, 0.0))


## The metres one copy of finish `finish`'s set covers.
func scale_of(finish: StringName) -> float:
	return maxf(finish_scales.get(finish, 2.0), 0.05)
