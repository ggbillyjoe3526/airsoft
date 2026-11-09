class_name LightingConfig
extends Resource
## One lighting preset (docs/ART.md › Light). The day (play_tuning.tres): a sunny weekend at the site, one warm sun with
## soft, short shadows, a cool sky fill and the game's own sky as the environment. The night (night_lighting.tres, WL3;
## the browser game's LIGHTING_PRESETS.night as first guesses): a cool moon low over the field, a dark sky with stars
## and the moon's disc, haze, a dim fill, and the map's fires and lanterns as light pools (LightPools). A map plays the
## presets it offers (MapData.lighting_presets); `for_map` makes the one it plays, with the map's own overrides. Read
## by PlaySession's world. Colours are sRGB.

## The presets a map can name, and the one a map naming none plays.
const DAY := &"day"
const NIGHT := &"night"
const PRESETS: Array[StringName] = [DAY, NIGHT]

## Which preset this is (`DAY` or `NIGHT`), as maps name it.
@export var id: StringName = DAY
## The sun (the moon at night): how high (degrees above the horizon), which way its light travels (degrees, 0 along
## -Z, turning left as yaw does; a map's moonOver turns it), colour, strength, and how far its shadows reach (m) and
## how soft they are.
@export var sun_elevation: float = 52.0
@export var sun_heading: float = 35.0
@export var sun_colour: Color = Color(1.0, 0.95, 0.86)
@export var sun_energy: float = 1.25
@export var shadow_distance: float = 70.0
@export var shadow_blur: float = 1.5
## The sky: top, horizon, and the ground's colour below the horizon.
@export var sky_top: Color = Color(0.36, 0.56, 0.84)
@export var sky_horizon: Color = Color(0.74, 0.8, 0.86)
@export var ground_horizon: Color = Color(0.62, 0.6, 0.54)
@export var ground_bottom: Color = Color(0.36, 0.34, 0.3)
## The fill on shaded sides: part sky, part a warm ground bounce, so they stay warm grey, never black or blue.
@export var ambient_colour: Color = Color(0.86, 0.8, 0.7)
@export var ambient_energy: float = 0.9
@export var sky_contribution: float = 0.45
## Contact shade in corners (screen-space ambient occlusion).
@export var ssao: bool = true
@export var ssao_radius: float = 1.0
@export var ssao_intensity: float = 1.4
## Exposure for the AgX tonemapper.
@export var exposure: float = 1.0
## A night preset: the one flag every night system reads (the ambience's night set, the figures' paint without its
## glow (TeamColours.resolve), the light pools, the skyline's lamps, a bake's sky share alone).
@export var night: bool = false

@export_group("Haze")
## Haze from `fog_from` to `fog_to` m from the eye, in `fog_colour`, over `fog_sky` of the sky. Off by day.
@export var fog: bool = false
@export var fog_colour: Color = Color(0.11, 0.17, 0.27)
@export var fog_from: float = 20.0
@export var fog_to: float = 140.0
@export var fog_sky: float = 0.0

@export_group("Night sky")
## The night sky, drawn on every quality preset when `stars` or `moon_size` is above 0 (else the day's procedural sky):
## the sky colours above as a gradient, `stars` stars `star_size` radians across at most, and the moon's disc
## `moon_size` radians across where the moon is, in `moon_colour`, inside a halo `moon_halo` times as wide at
## `moon_halo_alpha` at its middle.
@export var stars: int = 0
@export var star_size: float = 0.004
@export var star_brightness: float = 0.9
@export var moon_size: float = 0.0
@export var moon_colour: Color = Color(0.95, 0.96, 1.0)
@export var moon_halo: float = 4.5
@export var moon_halo_alpha: float = 0.22

@export_group("Map overrides")
## The browser preset's own strengths a map's `lighting.overrides` are written against: an override's key, fill or
## exposureScale scales this preset's sun energy, ambient energy or exposure by its ratio to these.
@export var override_key: float = 1.0
@export var override_fill: float = 1.0
@export var override_exposure: float = 1.0
## The browser preset's own hemisphere fill (sky and ground, sRGB) a map's `hemi` colours are read against: the fill
## colour takes their ratio, channel by channel on linear RGB, at its own brightness (the ratio's luminance taken
## out), so a map's colours tint the tuned fill and only its `intensity` (`fill`) brightens it. Alpha 0: a map's
## colours replace the fill colour outright.
@export var override_fill_sky: Color = Color(0, 0, 0, 0)
@export var override_fill_ground: Color = Color(0, 0, 0, 0)

@export_group("Light pools")
## A map's lights (MapData.lights) under a night preset (LightPools). Fires and lanterns take these colours, whatever
## the map says, kept at least 20° of hue from every team colour; a light of no kind keeps its own.
@export var fire_colour: Color = Color8(255, 228, 160)
@export var lantern_colour: Color = Color8(255, 232, 180)
## Real lights by Mesh detail (Low, Medium, High, Ultra): the nearest pools to the eye get one each, the rest are drawn.
@export var real_lights: PackedInt32Array = PackedInt32Array([0, 2, 4, 4])
## With Graphics › Lamp light on (Near, Far) the real lights cast shadows, as a roof's lamps do (every map's lamps
## and fires alike); on Far the nearest `real_lights_far` pools get one, if that is more than Mesh detail's.
@export var real_lights_far: int = 8
## A real light reaches `real_reach` times its pool's radius at `real_energy` (its shadow, with Lamp light, blurred
## `real_shadow_blur`); it moves to another pool only when that one is `real_hysteresis` m nearer, fading out and in
## over `real_fade` s.
@export var real_reach: float = 1.5
@export var real_energy: float = 1.6
@export var real_hysteresis: float = 3.0
@export var real_fade: float = 0.3
@export var real_shadow_blur: float = 1.5
## The drawn pool on the ground: a disc of `pool_rings` × `pool_segments` following the ground `pool_lift` m above it,
## `pool_strength` of its colour at the middle fading to nothing at its radius, added to what is under it.
@export var pool_rings: int = 6
@export var pool_segments: int = 16
@export var pool_strength: float = 0.18
@export var pool_lift: float = 0.04
## The glow round each light itself: a billboard `glow_size` times its radius, `glow_strength` of its colour at its
## middle, `glow_white` of the way to white.
@export var glow_size: float = 0.22
@export var glow_strength: float = 0.9
@export var glow_white: float = 0.5
## Fires flicker by up to `flicker` of their light, about `flicker_rate` times a second; still under Reduced motion.
@export var flicker: float = 0.18
@export var flicker_rate: float = 7.0


## One map's tweak of a preset (MapData.lighting_overrides, the browser's `lighting.overrides`): a strength left NAN
## and a colour left with alpha 0, or stars below 0, keep the preset's.
class Override:
	extends RefCounted
	var key: float = NAN
	## The sun's height and heading (degrees, as sun_elevation and sun_heading): an indoor field's roof lamps light
	## from nearly straight over it (DR1).
	var sun_elevation: float = NAN
	var sun_heading: float = NAN
	var fill: float = NAN
	var exposure_scale: float = NAN
	var sky_horizon: Color = Color(0, 0, 0, 0)
	var fog_colour: Color = Color(0, 0, 0, 0)
	var fill_sky: Color = Color(0, 0, 0, 0)
	var fill_ground: Color = Color(0, 0, 0, 0)
	var stars: int = -1


## The preset `preset` as `m` plays it: `night_preset` when that is its id, else `day`, with the map's overrides of it
## and, by night, its moon turned toward the map's moonOver (the day's sun keeps its heading), on a copy. Neither
## config is changed; with nothing to change, the preset itself.
static func for_map(day: LightingConfig, night_preset: LightingConfig, m: MapData, preset: StringName) -> LightingConfig:
	var base := night_preset if night_preset != null and preset == night_preset.id else day
	var o: Override = m.lighting_overrides.get(base.id) if m != null else null
	var turned := m != null and m.has_moon_over and base.night
	if o == null and not turned:
		return base
	var out := base.duplicate() as LightingConfig
	if turned:
		out.sun_heading = heading_toward(m.middle(), m.moon_over)
	if o != null:
		out._override(o)
	return out


## The heading (degrees, as `sun_heading`) of light travelling from over `toward` to `middle` (x, z): the moon hangs
## over that point and lights its side of the field.
static func heading_toward(middle: Vector2, toward: Vector2) -> float:
	var travel := middle - toward
	if travel.length_squared() < 1e-6:
		return 0.0
	return rad_to_deg(atan2(-travel.x, -travel.y))


## The real lights the graphics with Mesh detail `detail` (GraphicsQuality.MeshDetail) give the pools.
func real_lights_for(detail: int) -> int:
	if real_lights.is_empty():
		return 0
	return maxi(0, real_lights[clampi(detail, 0, real_lights.size() - 1)])


## The colour a light of `kind` with its own `colour` shines.
func pool_colour(kind: StringName, colour: Color) -> Color:
	match kind:
		&"fire":
			return fire_colour
		&"lantern":
			return lantern_colour
	return colour


## The mean of a hemisphere fill's sky and ground colours (sRGB), on linear RGB: Godot's ambient has one colour.
static func _hemi_mean(sky: Color, ground: Color) -> Color:
	return sky.srgb_to_linear().lerp(ground.srgb_to_linear(), 0.5)


## Whether it draws the night sky (stars and the moon) instead of the day's.
func night_sky() -> bool:
	return stars > 0 or moon_size > 0.0


func _override(o: Override) -> void:
	if not is_nan(o.sun_elevation):
		sun_elevation = clampf(o.sun_elevation, 1.0, 90.0)
	if not is_nan(o.sun_heading):
		sun_heading = o.sun_heading
	if not is_nan(o.key) and override_key > 0.0:
		sun_energy *= o.key / override_key
	if not is_nan(o.fill) and override_fill > 0.0:
		ambient_energy *= o.fill / override_fill
	if not is_nan(o.exposure_scale) and override_exposure > 0.0:
		exposure *= o.exposure_scale / override_exposure
	if o.sky_horizon.a > 0.0:
		sky_horizon = o.sky_horizon
	if o.fog_colour.a > 0.0:
		fog_colour = o.fog_colour
	if o.fill_sky.a > 0.0:
		var ground := o.fill_ground if o.fill_ground.a > 0.0 else o.fill_sky
		var base_ground := override_fill_ground if o.fill_ground.a > 0.0 else override_fill_sky
		var tint := _hemi_mean(o.fill_sky, ground)
		if override_fill_sky.a > 0.0 and base_ground.a > 0.0:
			var base := _hemi_mean(override_fill_sky, base_ground)
			var ratio := Color(tint.r / maxf(base.r, 1e-4), tint.g / maxf(base.g, 1e-4), tint.b / maxf(base.b, 1e-4))
			ratio /= maxf(ratio.get_luminance(), 1e-4)
			var fill := ambient_colour.srgb_to_linear()
			ambient_colour = Color(fill.r * ratio.r, fill.g * ratio.g, fill.b * ratio.b).linear_to_srgb()
		else:
			ambient_colour = tint.linear_to_srgb()
	if o.stars >= 0:
		stars = o.stars
