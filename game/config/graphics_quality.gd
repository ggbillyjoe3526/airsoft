class_name GraphicsQuality
extends RefCounted
## One set of graphics values, a field per row of data/graphics.md: a preset's column, or Custom (the preset you were on
## with your own rows over it). Plain state that nothing reads from the engine; GR2's GraphicsApply writes it into the
## viewport, the sun and the dust. A new one is all zeros: GraphicsTable.preset() gives a real one.
##
## Each row has a level, an int: a choice row's level is its choice's place in CHOICES (the enums below follow that
## order), a range row's is its number. Saved Custom rows hold a choice row's name ("msaa_4x") or a range row's number,
## so reordering the choices never changes what a save means.

enum Upscaler { BILINEAR, FSR1, FSR2 }
enum EdgeSmoothing { OFF, FXAA, SMAA, MSAA_2X, MSAA_4X }
## The sun's shadow filter, Hard to Softest (GR2 maps each to a RenderingServer.ShadowQuality).
enum ShadowSoftness { HARD, SOFT, SOFTER, SOFTEST }
enum AmbientOcclusion { OFF, HALF, FULL }
enum TextureFiltering { OFF, X2, X4, X8, X16 }
## Mesh level of detail (GR2 maps each to a mesh_lod_threshold).
enum MeshDetail { LOW, MEDIUM, HIGH, ULTRA }
## Light bounced off the field: none, screen-space (SSIL), or the whole scene's (SDFGI with SSIL).
enum GlobalIllumination { OFF, SCREEN, SCENE }
## Reflections: the sky's alone, the map's reflection probes, or the probes with screen-space reflections.
enum Reflections { OFF, PROBES, SCREEN }

## The choice that is a preset with your own rows over it.
const CUSTOM := &"custom"

const RENDER_SCALE := &"render_scale"
const UPSCALER := &"upscaler"
const EDGE_SMOOTHING := &"edge_smoothing"
const TEMPORAL_SMOOTHING := &"temporal_smoothing"
const SUN_SHADOWS := &"sun_shadows"
const SHADOW_DETAIL := &"shadow_detail"
const SHADOW_SOFTNESS := &"shadow_softness"
const SHADOW_RANGE := &"shadow_range"
const AMBIENT_OCCLUSION := &"ambient_occlusion"
const BAKED_LIGHT := &"baked_light"
const TEXTURE_FILTERING := &"texture_filtering"
const MESH_DETAIL := &"mesh_detail"
const WIND_DUST := &"wind_dust"
const GLOBAL_ILLUMINATION := &"global_illumination"
const REFLECTIONS := &"reflections"
const GLOW := &"glow"
const VOLUMETRIC_FOG := &"volumetric_fog"
## Every row, in the Graphics tab's order (data/graphics.md's).
const ROWS: Array[StringName] = [RENDER_SCALE, UPSCALER, EDGE_SMOOTHING, TEMPORAL_SMOOTHING, SUN_SHADOWS,
		SHADOW_DETAIL, SHADOW_SOFTNESS, SHADOW_RANGE, AMBIENT_OCCLUSION, BAKED_LIGHT, TEXTURE_FILTERING, MESH_DETAIL,
		WIND_DUST, GLOBAL_ILLUMINATION, REFLECTIONS, GLOW, VOLUMETRIC_FOG]
## Every choice the game knows for each choice row, by level. The file offers these, or some of them. (Values are Arrays:
## Godot 4.7 keeps a const typed dictionary's array values as Arrays, so a PackedStringArray value type misreads them.)
const CHOICES: Dictionary[StringName, Array] = {
	UPSCALER: ["bilinear", "fsr1", "fsr2"],
	EDGE_SMOOTHING: ["off", "fxaa", "smaa", "msaa_2x", "msaa_4x"],
	TEMPORAL_SMOOTHING: ["off", "on"],
	SUN_SHADOWS: ["off", "on"],
	SHADOW_DETAIL: ["1024", "2048", "4096", "8192"],
	SHADOW_SOFTNESS: ["hard", "soft", "softer", "softest"],
	AMBIENT_OCCLUSION: ["off", "half", "full"],
	BAKED_LIGHT: ["off", "on"],
	TEXTURE_FILTERING: ["off", "2x", "4x", "8x", "16x"],
	MESH_DETAIL: ["low", "medium", "high", "ultra"],
	GLOBAL_ILLUMINATION: ["off", "screen", "scene"],
	REFLECTIONS: ["off", "probes", "screen"],
	GLOW: ["off", "on"],
	VOLUMETRIC_FOG: ["off", "on"],
}
## The widest range the file may give a range row (a typo guard): the render scale within what the viewport takes, in
## percent; the shadow range in metres; the dust as a share of EffectsConfig.dust_count, in percent.
const LIMITS: Dictionary[StringName, Vector2i] = {
	RENDER_SCALE: Vector2i(10, 200),
	SHADOW_RANGE: Vector2i(10, 500),
	WIND_DUST: Vector2i(0, 100),
}

## The 3D render scale, in percent of the window.
var render_scale: int = 0
var upscaler: Upscaler = Upscaler.BILINEAR
var edge_smoothing: EdgeSmoothing = EdgeSmoothing.OFF
var temporal_smoothing: bool = false
var sun_shadows: bool = false
## The sun's shadow map, in pixels a side.
var shadow_detail: int = 0
var shadow_softness: ShadowSoftness = ShadowSoftness.HARD
## How far from the eye the sun's shadows reach, in metres.
var shadow_range: int = 0
var ambient_occlusion: AmbientOcclusion = AmbientOcclusion.OFF
## The map's baked sky shade and sun bounce drawn on its tiled mesh (MapLevel.set_baked_light).
var baked_light: bool = false
var texture_filtering: TextureFiltering = TextureFiltering.OFF
var mesh_detail: MeshDetail = MeshDetail.LOW
## The wind dust's specks, in percent of EffectsConfig.dust_count.
var wind_dust: int = 0
var global_illumination: GlobalIllumination = GlobalIllumination.OFF
var reflections: Reflections = Reflections.OFF
## Bright lamps and sky bloom softly.
var glow: bool = false
## A faint haze the light shines through (shafts and depth).
var volumetric_fog: bool = false


## True for a row that is a range of numbers, false for one with named choices.
static func is_range(row: StringName) -> bool:
	return LIMITS.has(row)


## The values `choice` names: a preset's column, or Custom = `base`'s column with the saved `custom` rows over it. A
## custom row of an unknown row, or a value the table doesn't offer, is dropped alone. An unknown choice or base reads
## as GraphicsTable.DEFAULT_PRESET. The automatic pick is the caller's: pass the preset GraphicsPick chose.
static func resolve(choice: StringName, base: StringName, custom: Dictionary, table: GraphicsTable = null) -> GraphicsQuality:
	var t := table if table != null else GraphicsTable.shared()
	if choice != CUSTOM:
		return t.preset(choice)
	var q := t.preset(base)
	for key: Variant in custom:
		if not (key is String or key is StringName):
			continue
		var row := StringName(key)
		if not ROWS.has(row):
			continue
		var level := t.level_of(row, custom[key])
		if level != GraphicsTable.NO_LEVEL:
			q.set_level(row, level)
	return q


## The preset `values` equal, else CUSTOM.
static func choice_of(values: GraphicsQuality, table: GraphicsTable = null) -> StringName:
	var t := table if table != null else GraphicsTable.shared()
	for p in GraphicsTable.PRESETS:
		if values.equals(t.preset(p)):
			return p
	return CUSTOM


## The rows where `values` differ from `base`'s column, as saved Custom rows: the inverse of resolve(CUSTOM, base, …).
static func overrides(values: GraphicsQuality, base: StringName, table: GraphicsTable = null) -> Dictionary[String, Variant]:
	var t := table if table != null else GraphicsTable.shared()
	var from := t.preset(base)
	var out: Dictionary[String, Variant] = {}
	for row in ROWS:
		if values.level(row) != from.level(row):
			out[String(row)] = t.saved_value(row, values.level(row))
	return out


## `row`'s level (see the class comment), or GraphicsTable.NO_LEVEL for an unknown row.
func level(row: StringName) -> int:
	match row:
		RENDER_SCALE:
			return render_scale
		UPSCALER:
			return upscaler
		EDGE_SMOOTHING:
			return edge_smoothing
		TEMPORAL_SMOOTHING:
			return int(temporal_smoothing)
		SUN_SHADOWS:
			return int(sun_shadows)
		SHADOW_DETAIL:
			return CHOICES[SHADOW_DETAIL].find(str(shadow_detail))
		SHADOW_SOFTNESS:
			return shadow_softness
		SHADOW_RANGE:
			return shadow_range
		AMBIENT_OCCLUSION:
			return ambient_occlusion
		BAKED_LIGHT:
			return int(baked_light)
		TEXTURE_FILTERING:
			return texture_filtering
		MESH_DETAIL:
			return mesh_detail
		WIND_DUST:
			return wind_dust
		GLOBAL_ILLUMINATION:
			return global_illumination
		REFLECTIONS:
			return reflections
		GLOW:
			return int(glow)
		VOLUMETRIC_FOG:
			return int(volumetric_fog)
	return GraphicsTable.NO_LEVEL


## Sets `row` to `value`, a level the caller has checked (GraphicsTable.valid); an unknown row is ignored.
func set_level(row: StringName, value: int) -> void:
	match row:
		RENDER_SCALE:
			render_scale = value
		UPSCALER:
			upscaler = value as Upscaler
		EDGE_SMOOTHING:
			edge_smoothing = value as EdgeSmoothing
		TEMPORAL_SMOOTHING:
			temporal_smoothing = value != 0
		SUN_SHADOWS:
			sun_shadows = value != 0
		SHADOW_DETAIL:
			if value >= 0 and value < CHOICES[SHADOW_DETAIL].size():
				shadow_detail = String(CHOICES[SHADOW_DETAIL][value]).to_int()
		SHADOW_SOFTNESS:
			shadow_softness = value as ShadowSoftness
		SHADOW_RANGE:
			shadow_range = value
		AMBIENT_OCCLUSION:
			ambient_occlusion = value as AmbientOcclusion
		BAKED_LIGHT:
			baked_light = value != 0
		TEXTURE_FILTERING:
			texture_filtering = value as TextureFiltering
		MESH_DETAIL:
			mesh_detail = value as MeshDetail
		WIND_DUST:
			wind_dust = value
		GLOBAL_ILLUMINATION:
			global_illumination = value as GlobalIllumination
		REFLECTIONS:
			reflections = value as Reflections
		GLOW:
			glow = value != 0
		VOLUMETRIC_FOG:
			volumetric_fog = value != 0


func equals(other: GraphicsQuality) -> bool:
	for row in ROWS:
		if level(row) != other.level(row):
			return false
	return true


func copy() -> GraphicsQuality:
	var q := GraphicsQuality.new()
	for row in ROWS:
		q.set_level(row, level(row))
	return q
