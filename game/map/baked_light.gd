class_name BakedLight
extends Resource
## One map's baked light (DP2), written by `tools/bake_light.gd` to BakeConfig.DIR and drawn by MapLevel: for each vertex
## of the map's tiled mesh (GreyboxFaces.tile), in its order, the share of the sky it sees and the sun's one bounce reaching
## it, kept apart so a night can draw the sky's share alone. `source_hash` is the hash of what it was baked from
## (`hash_of`); a test fails a bake whose map has changed since.

## A stored byte's whole: 255 is all the sky, or the bounce at the sun's full light.
const FULL := 255.0

@export var source_hash: String = ""
## The tiled mesh's block vertices it covers (the ground beyond the walls is not baked).
@export var vertex_count: int = 0
## The sky each vertex sees, 0 to FULL.
@export var sky: PackedByteArray = PackedByteArray()
## The bounce reaching each vertex, red, green and blue (linear), 0 to FULL of the sun's light on a face square to it.
@export var bounce: PackedByteArray = PackedByteArray()


## Whether its arrays hold `vertex_count` vertices each.
func whole() -> bool:
	return vertex_count > 0 and sky.size() == vertex_count and bounce.size() == vertex_count * 3


## The hash of everything a bake of `m` reads: the bake's version and settings, the sun it is baked under (`lighting`:
## the day preset's, whatever preset plays, so a night never marks a bake stale), and each block's kind, place, size,
## slope, surface and colour, in the file's order, and its dim rooms (MapData.baked_dim_boxes).
static func hash_of(m: MapData, style: MapStyle, lighting: LightingConfig, cfg: BakeConfig) -> String:
	var parts := PackedStringArray()
	parts.append("v%d cell %.4f rays %d reach %.4f lift %.4f ground %.4f sun %.4f" % [BakeConfig.VERSION, cfg.cell,
			cfg.rays, cfg.reach, cfg.lift, cfg.ground_y, cfg.sun_reach])
	parts.append("sun %.4f %.4f %s" % [lighting.sun_elevation, lighting.sun_heading, lighting.sun_colour.to_html()])
	parts.append("ground %s %.4f %.4f" % [style.ground_colour.to_html(), style.ground_extent, style.ground_drop])
	for i in m.baked_dim_boxes.size():
		var r := m.baked_dim_boxes[i]
		parts.append("dim %.4f %.4f %.4f %.4f %.4f" % [r.position.x, r.position.y, r.size.x, r.size.y,
				m.baked_dim_light[i]])
	for b in m.blocks:
		parts.append("%s %.4f %.4f %.4f %.4f %.4f %.4f %d %d %s" % [b.kind, b.center.x, b.center.y, b.center.z, b.size.x,
				b.size.y, b.size.z, b.rise, b.surface, style.block_colour(b).to_html()])
	return "\n".join(parts).sha256_text()


## The bake `m` names (`bakedLight.file`), or null with a warning when it names one that is missing or broken; null and
## silent when it names none.
static func load_for(m: MapData) -> BakedLight:
	if m.baked_light_file.is_empty():
		return null
	var path := BakeConfig.path_for(m.baked_light_file)
	var bake: BakedLight = null
	if ResourceLoader.exists(path):
		bake = load(path) as BakedLight
	if bake == null or not bake.whole():
		push_warning(("BakedLight: %s is missing or broken; %s draws without its baked light (rebake with "
				+ "tools/bake_light.gd)") % [path, m.id])
		return null
	return bake
