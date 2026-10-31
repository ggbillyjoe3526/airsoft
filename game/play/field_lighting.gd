class_name FieldLighting
extends Node3D
## The field's light and sky from a LightingConfig (docs/ART.md › Light): a WorldEnvironment with its sky (which also
## gives polymer and steel their sheen) and one DirectionalLight3D, the sun or the moon, with soft, short shadows. By
## day the sky is Godot's procedural one; a night preset draws its own (NIGHT_SKY: the sky's gradient, stars and the
## moon's disc with its halo where the moon is, on every quality preset) and adds its haze. The game's look (LookConfig,
## docs/ART.md) grades the picture on every preset and sets the dearer effects, which start off: the graphics settings
## then switch the sun's shadows, their range, ambient occlusion, global illumination (SSIL, SDFGI), reflections (the
## area probes, SSR), glow and volumetric fog in place (GraphicsApply.apply_field, `set_effects`).

## The night sky. Stars sit on a grid of directions (`star_grid` cells round), one in `star_share` of the cells lit,
## each a soft dot up to `star_size` radians across; the moon is LIGHT0's direction. The radiance pass (the fill and
## the sheen) takes the gradient alone.
const NIGHT_SKY := """
shader_type sky;

uniform vec3 top : source_color;
uniform vec3 horizon : source_color;
uniform vec3 below : source_color;
uniform float star_grid = 160.0;
uniform float star_share = 0.01;
uniform float star_size = 0.004;
uniform float star_brightness = 0.9;
uniform vec3 moon_colour : source_color;
uniform float moon_size = 0.05;
uniform float halo = 4.5;
uniform float halo_alpha = 0.22;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col = d.y >= 0.0 ? mix(horizon, top, sqrt(d.y)) : mix(horizon, below, clamp(-d.y * 4.0, 0.0, 1.0));
	if (!AT_CUBEMAP_PASS) {
		if (d.y > 0.0) {
			vec3 cell = floor(d * star_grid);
			if (hash(cell) < star_share) {
				vec3 jitter = vec3(hash(cell + 1.7), hash(cell + 3.1), hash(cell + 5.3)) * 0.7 + 0.15;
				vec3 star = normalize((cell + jitter) / star_grid);
				float size = star_size * (0.4 + 0.6 * hash(cell + 7.9));
				col += vec3(star_brightness) * smoothstep(size, 0.0, distance(star, d)) * smoothstep(0.0, 0.15, d.y);
			}
		}
		if (LIGHT0_ENABLED) {
			float a = acos(clamp(dot(d, LIGHT0_DIRECTION), -1.0, 1.0));
			float r = moon_size * 0.5;
			col = mix(col, moon_colour, smoothstep(r, r * 0.85, a));
			float glow = 1.0 - smoothstep(r, r * halo, a);
			col += moon_colour * halo_alpha * glow * glow;
		}
	}
	COLOR = col;
}
"""
## The night sky's star grid: cells round each face of the cube of directions.
const STAR_GRID := 160.0

var sun: DirectionalLight3D = null
var environment: Environment = null
var _ssao: bool = false
var _look: LookConfig = null
## The map's reflection probes (`add_probes`), shown while Reflections draw them.
var _probes: Node3D = null


## A node holding the environment and the sun, graded and its effects set up by `look` (the built-in look when null).
static func build(cfg: LightingConfig, look: LookConfig = null) -> FieldLighting:
	var root := FieldLighting.new()
	root.name = "Lighting"
	root._ssao = cfg.ssao
	root._look = look if look != null else LookConfig.new()
	var sky := Sky.new()
	sky.sky_material = night_sky_material(cfg) if cfg.night_sky() else day_sky_material(cfg)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = cfg.ambient_colour
	env.ambient_light_energy = cfg.ambient_energy
	env.ambient_light_sky_contribution = cfg.sky_contribution
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = cfg.exposure
	env.ssao_enabled = cfg.ssao
	env.ssao_radius = cfg.ssao_radius
	env.ssao_intensity = cfg.ssao_intensity
	if cfg.fog:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = cfg.fog_colour
		env.fog_density = 1.0
		env.fog_depth_begin = cfg.fog_from
		env.fog_depth_end = cfg.fog_to
		env.fog_sky_affect = cfg.fog_sky
	_grade(env, root._look)
	root.environment = env
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = env
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-cfg.sun_elevation, cfg.sun_heading, 0.0)
	sun.light_color = cfg.sun_colour
	sun.light_energy = cfg.sun_energy
	sun.shadow_enabled = true
	sun.shadow_blur = cfg.shadow_blur
	sun.directional_shadow_max_distance = cfg.shadow_distance
	root.add_child(sun)
	root.sun = sun
	return root


## The day's procedural sky in `cfg`'s colours.
static func day_sky_material(cfg: LightingConfig) -> ProceduralSkyMaterial:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = cfg.sky_top
	sky_mat.sky_horizon_color = cfg.sky_horizon
	sky_mat.ground_horizon_color = cfg.ground_horizon
	sky_mat.ground_bottom_color = cfg.ground_bottom
	return sky_mat


## The night sky (NIGHT_SKY) in `cfg`'s colours, its stars spread over the upper sky's cells (about 2π grid² of them).
static func night_sky_material(cfg: LightingConfig) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = NIGHT_SKY
	mat.set_shader_parameter(&"top", cfg.sky_top)
	mat.set_shader_parameter(&"horizon", cfg.sky_horizon)
	mat.set_shader_parameter(&"below", cfg.ground_bottom)
	mat.set_shader_parameter(&"star_grid", STAR_GRID)
	mat.set_shader_parameter(&"star_share", clampf(cfg.stars / (TAU * STAR_GRID * STAR_GRID), 0.0, 1.0))
	mat.set_shader_parameter(&"star_size", cfg.star_size)
	mat.set_shader_parameter(&"star_brightness", cfg.star_brightness)
	mat.set_shader_parameter(&"moon_colour", cfg.moon_colour)
	mat.set_shader_parameter(&"moon_size", cfg.moon_size)
	mat.set_shader_parameter(&"halo", cfg.moon_halo)
	mat.set_shader_parameter(&"halo_alpha", cfg.moon_halo_alpha)
	return mat


## True if the config draws ambient occlusion at all; the graphics settings turn it off, never on against it.
func ssao_allowed() -> bool:
	return _ssao


## The look this field is drawn in.
func look() -> LookConfig:
	return _look


## The map's reflection probes (AreaProbes), shown while Reflections draw them; none on a map with no named areas.
func add_probes(map: MapData) -> void:
	_probes = AreaProbes.build(map, _look)
	if _probes != null:
		add_child(_probes)


## How many reflection probes it holds (for tests).
func probe_count() -> int:
	return _probes.get_child_count() if _probes != null else 0


## Switches the dearer effects (GraphicsQuality's rows): global illumination (screen: SSIL; scene: SSIL and SDFGI),
## reflections (probes: the area probes; screen: and SSR), glow, volumetric fog, and the sun's contact-hardening soft
## shadows (`soft_sun`). Only properties that change are set, so a repeat is free; never per frame.
func set_effects(gi: GraphicsQuality.GlobalIllumination, reflections: GraphicsQuality.Reflections, glow: bool,
		fog: bool, soft_sun: bool) -> void:
	var env := environment
	var ssil := gi != GraphicsQuality.GlobalIllumination.OFF
	if env.ssil_enabled != ssil:
		env.ssil_enabled = ssil
	var sdfgi := gi == GraphicsQuality.GlobalIllumination.SCENE
	if env.sdfgi_enabled != sdfgi:
		env.sdfgi_enabled = sdfgi
	var ssr := reflections == GraphicsQuality.Reflections.SCREEN
	if env.ssr_enabled != ssr:
		env.ssr_enabled = ssr
	if _probes != null:
		var probes := reflections != GraphicsQuality.Reflections.OFF
		if _probes.visible != probes:
			_probes.visible = probes
	if env.glow_enabled != glow:
		env.glow_enabled = glow
	if env.volumetric_fog_enabled != fog:
		env.volumetric_fog_enabled = fog
	var size := _look.sun_size if soft_sun else 0.0
	if not is_equal_approx(sun.light_angular_distance, size):
		sun.light_angular_distance = size


## The look's grade and its effects' settings on `env`, every effect left off for `set_effects`.
static func _grade(env: Environment, look: LookConfig) -> void:
	env.tonemap_agx_contrast = look.agx_contrast
	env.adjustment_enabled = true
	env.adjustment_saturation = look.saturation
	env.adjustment_contrast = look.contrast
	env.adjustment_brightness = look.brightness
	env.glow_intensity = look.glow_intensity
	env.glow_strength = look.glow_strength
	env.glow_bloom = look.glow_bloom
	env.glow_hdr_threshold = look.glow_threshold
	env.ssil_radius = look.ssil_radius
	env.ssil_intensity = look.ssil_intensity
	env.ssil_sharpness = look.ssil_sharpness
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = look.sdfgi_cascades
	env.sdfgi_min_cell_size = look.sdfgi_min_cell
	env.sdfgi_energy = look.sdfgi_energy
	env.sdfgi_bounce_feedback = look.sdfgi_bounce
	env.ssr_max_steps = look.ssr_steps
	env.ssr_fade_in = look.ssr_fade_in
	env.ssr_fade_out = look.ssr_fade_out
	env.ssr_depth_tolerance = look.ssr_depth_tolerance
	env.volumetric_fog_density = look.fog_density
	env.volumetric_fog_albedo = look.fog_albedo
	env.volumetric_fog_anisotropy = look.fog_anisotropy
	env.volumetric_fog_length = look.fog_length
	env.volumetric_fog_gi_inject = look.fog_gi_inject
	env.volumetric_fog_sky_affect = 0.0
	env.glow_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.ssr_enabled = false
	env.volumetric_fog_enabled = false
