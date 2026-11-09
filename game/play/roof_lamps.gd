class_name RoofLamps
extends Node3D
## An indoor field's roof lamps as real lights (Settings › Graphics › Lamp light, data/graphics.md): a SpotLight3D under
## each lamp RoofView hangs, shining straight down and casting a shadow, lit out to the row's reach from the eye by the
## engine's own distance fade (nothing here runs per frame). Off, the node is hidden and the preset's overhead sun
## lights the hall alone, as on Low and Medium; while it shines, FieldLighting.set_key_share turns that sun down to
## RoofConfig.lamp_sun_share (`key_share`). Built once with the roof; `set_mode` only sets what changes. Look only.

var _cfg: RoofConfig = null
var _lights: Array[SpotLight3D] = []
var _mode: GraphicsQuality.LampLights = GraphicsQuality.LampLights.OFF
var _soft: bool = false


## A light under each of `spots` (each lamp's lowest point), as `cfg` sets them, all off.
static func build(spots: Array[Vector3], cfg: RoofConfig) -> RoofLamps:
	var lamps := RoofLamps.new()
	lamps.name = "LampLights"
	lamps._cfg = cfg
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


## The share of its strength the overhead sun keeps with `wanted`: all of it with the lamps off.
func key_share(wanted: GraphicsQuality.LampLights) -> float:
	return 1.0 if wanted == GraphicsQuality.LampLights.OFF or _lights.is_empty() else _cfg.lamp_sun_share


## Lights the lamps out to `wanted`'s reach (off: hidden), their shadows contact-hardening when `soft` (Softest). Only
## what changes is set; never per frame.
func set_mode(wanted: GraphicsQuality.LampLights, soft: bool) -> void:
	var on := wanted != GraphicsQuality.LampLights.OFF
	if visible != on:
		visible = on
	if not on or (wanted == _mode and soft == _soft):
		_mode = wanted
		return
	_mode = wanted
	_soft = soft
	var reach := _cfg.lamp_near if wanted == GraphicsQuality.LampLights.NEAR else _cfg.lamp_far
	var size := _cfg.lamp_lens_size if soft else 0.0
	for spot in _lights:
		spot.distance_fade_begin = maxf(0.0, reach - _cfg.lamp_fade)
		spot.distance_fade_shadow = reach
		spot.light_size = size
