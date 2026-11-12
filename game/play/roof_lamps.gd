class_name RoofLamps
extends Node3D
## An indoor field's roof lamps as real lights (Settings › Graphics › Lamp light, data/graphics.md): a SpotLight3D under
## each lamp RoofView hangs, shining straight down and casting a shadow, every one lit across the whole hall (the
## roof's reach from any point under it), by the engine's own distance fade (nothing here runs per frame). Off, the
## node is hidden and the preset's overhead light stands in for the lamps alone, as on Low and Medium. While they shine
## the hall is lit by its lamps only (owner, 2026-11-10: no sun gets indoors): FieldLighting.set_key_share puts the sun
## out (`key_share`, RoofConfig.lamp_sun_share) and set_ambient_share turns the sky's light under the roof down
## (`ambient_share`), so their shadows stay deep; the ceiling joins the scene's bounce light (Ultra's SDFGI), so the
## sky no longer lights the hall through it. Near (High) shadows the lamps within `lamp_near` m, Far (Ultra) all.
## A worn lamp (DW1, MapData.roof_lamp_states) shines at `lamp_dim_share` in `lamp_dim_colour` (dim), not at all (dead:
## no light) or as RoofView's flicker steps it (`set_flicker`; out of the baked bounce light, as it changes).
## Built once with the roof; `set_mode` only sets what changes. Look only.

var _cfg: RoofConfig = null
var _lights: Array[SpotLight3D] = []
var _mode: GraphicsQuality.LampLights = GraphicsQuality.LampLights.OFF
var _soft: bool = false
## How far (m) the roof reaches from any point under it (its area's diagonal and height): every lamp is lit that far
## from the eye, so no part of the hall goes unlit without the sun.
var _cover: float = 0.0
## The roof's ceiling: in the bounce light while the lamps shine, out of it (the sky's light falling through) while the
## overhead light stands in for them.
var _ceiling: GeometryInstance3D = null
## Each lamp's light's index in `_lights`, -1 for a dead lamp's (none).
var _by_lamp: PackedInt32Array = PackedInt32Array()
## A working lamp's light strength: RoofConfig.lamp_light_energy, or plain_lamp_energy under a plain roof.
var _energy: float = 0.0


## A light under each of `spots` (each lamp's lowest point), as `cfg` sets them, all off; `cover` is how far the roof
## reaches from any point under it; `ceiling` the roof's ceiling, put in the bounce light while they shine; `states`
## each lamp's MapData.LAMP_* (none: all working); `reaches` each light's range (m) under a plain roof
## (MapData.roof_plain: short, softer lights; none: the roof's own `lamp_range` and `lamp_light_energy`).
static func build(spots: Array[Vector3], cfg: RoofConfig, cover: float = 0.0,
		ceiling: GeometryInstance3D = null, states: PackedByteArray = PackedByteArray(),
		reaches: PackedFloat32Array = PackedFloat32Array()) -> RoofLamps:
	var plain := not reaches.is_empty()
	var lamps := RoofLamps.new()
	lamps._energy = cfg.plain_lamp_energy if plain else cfg.lamp_light_energy
	lamps.name = "LampLights"
	lamps._cfg = cfg
	lamps._cover = cover
	lamps._ceiling = ceiling
	lamps.visible = false
	var down := Basis(Vector3.RIGHT, -PI * 0.5)
	for i in spots.size():
		var state: int = states[i] if i < states.size() else MapData.LAMP_WORKING
		if state == MapData.LAMP_DEAD:
			lamps._by_lamp.append(-1)
			continue
		lamps._by_lamp.append(lamps._lights.size())
		var spot := SpotLight3D.new()
		spot.name = "Lamp_%d" % i
		spot.transform = Transform3D(down, spots[i] + Vector3.DOWN * cfg.lamp_light_drop)
		var dim := state == MapData.LAMP_DIM
		spot.light_color = cfg.lamp_dim_colour if dim else cfg.lamp_colour
		spot.light_energy = lamps._energy * (cfg.lamp_dim_share if dim else 1.0)
		spot.light_volumetric_fog_energy = cfg.lamp_fog
		if plain:
			spot.light_indirect_energy = cfg.plain_lamp_indirect
		spot.spot_range = reaches[i] if i < reaches.size() else cfg.lamp_range
		spot.spot_attenuation = cfg.lamp_falloff
		spot.spot_angle = cfg.lamp_cone
		spot.spot_angle_attenuation = cfg.lamp_cone_falloff
		# Baked into the scene's bounce light (SDFGI) as it is built, never updated per frame: the lamps don't move; a
		# flickering one is dynamic, as its strength steps.
		spot.light_bake_mode = Light3D.BAKE_DYNAMIC if state == MapData.LAMP_FLICKER else Light3D.BAKE_STATIC
		spot.shadow_enabled = true
		spot.shadow_blur = cfg.lamp_shadow_blur
		spot.distance_fade_enabled = true
		spot.distance_fade_length = cfg.lamp_fade
		lamps.add_child(spot)
		lamps._lights.append(spot)
	return lamps


## How many lights it holds (for tests).
func light_count() -> int:
	return _lights.size()


## The lights (for tests).
func lights() -> Array[SpotLight3D]:
	return _lights


## Lamp `lamp`'s light, or null for a dead lamp's (none).
func light_of(lamp: int) -> SpotLight3D:
	var at := _by_lamp[lamp] if lamp >= 0 and lamp < _by_lamp.size() else -1
	return _lights[at] if at >= 0 else null


## A flickering lamp's light at `level` (0 to 1) of its strength, as RoofView steps it (only when it changes).
func set_flicker(lamp: int, level: float) -> void:
	var spot := light_of(lamp)
	if spot != null:
		spot.light_energy = _energy * level


## The mode in force.
func mode() -> GraphicsQuality.LampLights:
	return _mode


## The share of its strength the sun keeps with `wanted`: all of it with the lamps off (it stands in for them), else
## RoofConfig.lamp_sun_share (none: no sun gets under the roof).
func key_share(wanted: GraphicsQuality.LampLights) -> float:
	return 1.0 if wanted == GraphicsQuality.LampLights.OFF or _lights.is_empty() else _cfg.lamp_sun_share


## The share of the sky's ambient light kept under the roof with `wanted`: all of it with the lamps off, else
## RoofConfig.lamp_ambient_share, so the lamps' shadows stay deep.
func ambient_share(wanted: GraphicsQuality.LampLights) -> float:
	return 1.0 if wanted == GraphicsQuality.LampLights.OFF or _lights.is_empty() else _cfg.lamp_ambient_share


## How far (m) from the eye every lamp is lit: the whole roof (`_cover`), Far's `lamp_far` at least.
func reach() -> float:
	return maxf(_cfg.lamp_far, _cover + _cfg.lamp_fade)


## Lights every lamp (off: hidden), shadowed out to `wanted`'s reach (Near: `lamp_near`; Far: all), their shadows
## contact-hardening when `soft` (Softest). Only what changes is set; never per frame.
func set_mode(wanted: GraphicsQuality.LampLights, soft: bool) -> void:
	var on := wanted != GraphicsQuality.LampLights.OFF
	if visible != on:
		visible = on
	var gi := GeometryInstance3D.GI_MODE_STATIC if on else GeometryInstance3D.GI_MODE_DISABLED
	if _ceiling != null and _ceiling.gi_mode != gi:
		_ceiling.gi_mode = gi
	if not on or (wanted == _mode and soft == _soft):
		_mode = wanted
		return
	_mode = wanted
	_soft = soft
	var lit := reach()
	var shadowed := _cfg.lamp_near if wanted == GraphicsQuality.LampLights.NEAR else lit
	var size := _cfg.lamp_lens_size if soft else 0.0
	for spot in _lights:
		spot.distance_fade_begin = maxf(0.0, lit - _cfg.lamp_fade)
		spot.distance_fade_shadow = shadowed
		spot.light_size = size
