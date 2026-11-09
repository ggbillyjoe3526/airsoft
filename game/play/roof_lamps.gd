class_name RoofLamps
extends Node3D
## An indoor field's roof lamps as real lights (Settings › Graphics › Lamp light, data/graphics.md): a SpotLight3D under
## each lamp RoofView hangs, shining straight down and casting a shadow, lit out to the row's reach from the eye by the
## engine's own distance fade (nothing here runs per frame). Off, the node is hidden and the preset's overhead sun
## lights the hall alone, as on Low and Medium; on Near, FieldLighting.set_key_share turns that sun down to
## RoofConfig.lamp_sun_share (`key_share`). On Far, with the roof's sun shade, the roof shades the sun but at its
## rooflights instead, the sun keeps RoofConfig.shade_sun_share and the lamps shine lamp_shaded_energy. Built once
## with the roof; `set_mode` only sets what changes. Look only.

var _cfg: RoofConfig = null
var _lights: Array[SpotLight3D] = []
## RoofView's sun shade and hall haze, shown on Far; empty on a roof without them.
var _shaded_nodes: Array[Node3D] = []
var _mode: GraphicsQuality.LampLights = GraphicsQuality.LampLights.OFF
var _soft: bool = false
## Whether the sun casts shadows, as last set (the sun shade is a shadow and nothing else).
var _sun_shadows: bool = false
## How far (m) the roof reaches from any point under it (its area's diagonal and height): on Far, shaded, every lamp
## is lit and the sun's shadows reach that far, so no part of the hall is left shaded and unlit or unshaded.
var _cover: float = 0.0


## A light under each of `spots` (each lamp's lowest point), as `cfg` sets them, all off; `shaded` (may be empty) are
## the roof's sun shade and its haze, shown on Far, and `cover` how far the roof reaches from any point under it.
static func build(spots: Array[Vector3], cfg: RoofConfig, shaded: Array[Node3D] = [], cover: float = 0.0) -> RoofLamps:
	var lamps := RoofLamps.new()
	lamps.name = "LampLights"
	lamps._cfg = cfg
	lamps._shaded_nodes = shaded
	lamps._cover = cover
	lamps.visible = false
	var down := Basis(Vector3.RIGHT, -PI * 0.5)
	for i in spots.size():
		var spot := SpotLight3D.new()
		spot.name = "Lamp_%d" % i
		spot.transform = Transform3D(down, spots[i] + Vector3.DOWN * cfg.lamp_light_drop)
		spot.light_color = cfg.lamp_colour
		spot.light_energy = cfg.lamp_light_energy
		spot.light_volumetric_fog_energy = cfg.lamp_fog
		spot.spot_range = cfg.lamp_range
		spot.spot_attenuation = cfg.lamp_falloff
		spot.spot_angle = cfg.lamp_cone
		spot.spot_angle_attenuation = cfg.lamp_cone_falloff
		# Baked into the scene's bounce light (SDFGI) as it is built, never updated per frame: the lamps don't move.
		spot.light_bake_mode = Light3D.BAKE_STATIC
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


## The mode in force.
func mode() -> GraphicsQuality.LampLights:
	return _mode


## The share of its strength the overhead sun keeps with `wanted`: all of it with the lamps off, shade_sun_share
## shaded (Far with the roof's sun shade), else lamp_sun_share.
func key_share(wanted: GraphicsQuality.LampLights) -> float:
	if wanted == GraphicsQuality.LampLights.OFF or _lights.is_empty():
		return 1.0
	return _cfg.shade_sun_share if _shaded(wanted) else _cfg.lamp_sun_share


## Whether the roof shades the sun with `wanted`: on Far, with a sun shade, while the sun casts shadows (with Sun
## shadows off a shadow-only shade blocks nothing).
func _shaded(wanted: GraphicsQuality.LampLights) -> bool:
	return not _shaded_nodes.is_empty() and wanted == GraphicsQuality.LampLights.FAR and _sun_shadows


## Whether the roof shades the sun now (the mode in force).
func shaded() -> bool:
	return _shaded(_mode)


## How far (m) the sun's shadows must reach while the roof shades it: the whole roof from any point under it.
func shade_reach() -> float:
	return _cover


## Lights the lamps out to `wanted`'s reach (off: hidden), their shadows contact-hardening when `soft` (Softest), and
## on Far while the sun casts shadows (`sun_shadows`) shows the sun shade and lights every lamp under the roof
## (`_shaded`; GraphicsApply.apply_field stretches the sun's shadows to `shade_reach`). Only what changes is set;
## never per frame.
func set_mode(wanted: GraphicsQuality.LampLights, soft: bool, sun_shadows: bool = false) -> void:
	var was_shaded := _shaded(_mode)
	_sun_shadows = sun_shadows
	var on := wanted != GraphicsQuality.LampLights.OFF
	if visible != on:
		visible = on
	var shade_on := _shaded(wanted)
	for node in _shaded_nodes:
		if node.visible != shade_on:
			node.visible = shade_on
	if not on or (wanted == _mode and soft == _soft and shade_on == was_shaded):
		_mode = wanted
		return
	_mode = wanted
	_soft = soft
	var reach := _cfg.lamp_near if wanted == GraphicsQuality.LampLights.NEAR else _cfg.lamp_far
	if shade_on:
		reach = maxf(reach, _cover + _cfg.lamp_fade)
	var size := _cfg.lamp_lens_size if soft else 0.0
	var energy := _cfg.lamp_shaded_energy if shade_on else _cfg.lamp_light_energy
	for spot in _lights:
		spot.light_energy = energy
		spot.distance_fade_begin = maxf(0.0, reach - _cfg.lamp_fade)
		spot.distance_fade_shadow = reach
		spot.light_size = size
