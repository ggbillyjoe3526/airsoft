class_name StudioSky
extends RefCounted
## What the metal on the menus' pictures reflects (MQ1): a small photo studio drawn as a sky, a dim grey room with a
## bright box of light overhead and tall soft panels standing round it, so a steel slide or an anodised receiver shows
## a broad highlight, bright streaks along its edges and a dark underside instead of the flat black a picture with
## nothing round it gives. Never drawn as a
## background (the pictures stay see-through): it only lights the reflections of the viewports that name it
## (ReplicaPictures, ReplicaTurntable, tools/model_studio.gd). One Sky, made once and shared.

## The room's colour overhead, at eye height and underfoot.
const TOP := Color(0.62, 0.64, 0.68)
const WALL := Color(0.24, 0.245, 0.26)
const FLOOR := Color(0.16, 0.16, 0.17)
## The box overhead: how bright, and how wide and deep it reads (the tangent of its half angles).
const BOX_ENERGY := 3.2
const BOX_HALF := Vector2(0.9, 0.55)
## The panels standing round the room: how many, how bright, the share of the way round each one fills, and how high
## they reach (the direction's y, from just under eye height).
const PANELS := 4
const PANEL_ENERGY := 2.2
const PANEL_FILL := 0.42
const PANEL_TOP := 0.55
const PANEL_FOOT := -0.12
## The reflections' cube map (px a side): small, the reflections are soft.
const RADIANCE := Sky.RADIANCE_SIZE_128

const SHADER_CODE := """
shader_type sky;

uniform vec3 top : source_color;
uniform vec3 wall : source_color;
uniform vec3 floor_colour : source_color;
uniform float box_energy;
uniform vec2 box_half;
uniform float panels;
uniform float panel_energy;
uniform float panel_fill;
uniform float panel_top;
uniform float panel_foot;

void sky() {
	vec3 d = EYEDIR;
	vec3 room = mix(wall, top, smoothstep(0.0, 0.9, d.y));
	room = mix(room, floor_colour, smoothstep(0.0, -0.5, d.y));
	// The box overhead: where the ray meets the ceiling's plane.
	vec2 at = d.xz / max(d.y, 0.001);
	float box = d.y > 0.0 ? (1.0 - smoothstep(box_half.x * 0.8, box_half.x, abs(at.x)))
			* (1.0 - smoothstep(box_half.y * 0.8, box_half.y, abs(at.y))) : 0.0;
	// The panels: the way round the room in turns, each one's middle on a diagonal (a side or end view looks between
	// two), soft at its edges, standing from the floor to above eye height.
	float turn = fract(atan(d.z, d.x) / TAU * panels + 0.5);
	float across = 1.0 - smoothstep(panel_fill * 0.5, panel_fill, abs(turn - 0.5) * 2.0);
	float up = smoothstep(panel_foot - 0.08, panel_foot, d.y) * (1.0 - smoothstep(panel_top, panel_top + 0.15, d.y));
	COLOR = room + vec3(box * box_energy + across * up * panel_energy);
}
"""

static var _sky: Sky = null


## The studio, as a Sky for an Environment's reflections.
static func sky() -> Sky:
	if _sky == null:
		var shader := Shader.new()
		shader.code = SHADER_CODE
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(&"top", TOP)
		material.set_shader_parameter(&"wall", WALL)
		material.set_shader_parameter(&"floor_colour", FLOOR)
		material.set_shader_parameter(&"box_energy", BOX_ENERGY)
		material.set_shader_parameter(&"box_half", BOX_HALF)
		material.set_shader_parameter(&"panels", float(PANELS))
		material.set_shader_parameter(&"panel_energy", PANEL_ENERGY)
		material.set_shader_parameter(&"panel_fill", PANEL_FILL)
		material.set_shader_parameter(&"panel_top", PANEL_TOP)
		material.set_shader_parameter(&"panel_foot", PANEL_FOOT)
		_sky = Sky.new()
		_sky.sky_material = material
		_sky.radiance_size = RADIANCE
		_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	return _sky


## Makes `env` reflect the studio: its background and its ambient light stay as they are.
static func light(env: Environment) -> void:
	env.sky = sky()
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
