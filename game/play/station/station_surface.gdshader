// A station dress's surfaces (MT3, StationSurface): every block face in one of the CC0 photo sets, all the sets one
// layer each of two texture arrays, so the whole station is one material and one draw. Each vertex carries its face's
// set (CUSTOM0.x), metalness (y), roughness scale (z) and the floor of the room it faces (w); UV is the face's own
// plane in the world over its finish's size, so the sets line up from block to block; COLOR its tint (linear). On top,
// in the shared light (look_light.gdshaderinc): broad blotches that break the sets' repeats and grime up a wall's foot
// in the look's grime colour. `low` (Mesh detail Low) draws no relief and keeps one texture read a pixel.
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_light.gdshaderinc"

uniform sampler2DArray colour_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// x, y: the OpenGL normal's x and y; z: roughness.
uniform sampler2DArray surface_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool low = false;
// The arch fill (StationLook.arch_fill, set while no lamp lights it): a face whose colour's alpha is 0 glows this much
// of its own colour.
uniform float arch_fill = 0.0;
uniform float variation : hint_range(0.0, 0.5) = 0.16;
uniform float variation_size = 3.0;
uniform float grime_height = 0.8;
uniform float grime_strength : hint_range(0.0, 1.0) = 0.5;
// A face's roughness on Low, without the set's own.
uniform float flat_roughness : hint_range(0.0, 1.0) = 0.8;

global uniform vec4 look_grime;

varying vec4 info;
varying vec3 world;

// A smooth value noise in 0..1, a cell a unit (as look_vertex.gdshader's wear).
float station_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float station_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(station_hash(i), station_hash(i + vec2(1.0, 0.0)), f.x),
			mix(station_hash(i + vec2(0.0, 1.0)), station_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	info = CUSTOM0;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 at = vec3(UV, floor(info.x + 0.5));
	vec3 col = texture(colour_tex, at).rgb * COLOR.rgb;
	float rough = flat_roughness;
	if (!low) {
		vec3 s = texture(surface_tex, at).rgb;
		NORMAL_MAP = vec3(s.xy, 1.0);
		rough = s.z;
	}
	// The face's plane in the world: a side's across and up, a top's x and z (as look_vertex's wear).
	vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float facing_x = n.x * n.x / max(n.x * n.x + n.z * n.z, 1e-4);
	float side = 1.0 - smoothstep(0.4, 0.7, abs(n.y));
	vec2 plane = mix(world.xz, vec2(mix(world.x, world.z, facing_x), world.y), side) / variation_size;
	float blotch = station_noise(plane) * 0.65 + station_noise(plane * 2.7 + 7.1) * 0.35;
	col *= 1.0 + variation * (blotch * 2.0 - 1.0);
	float over = world.y - info.w;
	float foot = (1.0 - smoothstep(0.0, grime_height * (0.4 + 0.6 * blotch), over)) * side * step(-0.05, over);
	col = mix(col, look_grime.rgb, foot * grime_strength);
	ALBEDO = look_paint(col);
	ROUGHNESS = clamp(rough * info.z + foot * 0.2, 0.0, 1.0);
	METALLIC = info.y;
	EMISSION = ALBEDO * arch_fill * (1.0 - COLOR.a);
}
