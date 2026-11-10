// A stream's water (WS1, Woodland's stream; WaterView), in the shared light (look_light.gdshaderinc): see-through,
// clear where it is shallow and tinted toward `deep` the more water the eye looks through (the depth behind it), fading
// out where the ground behind it comes within `edge_soft` m of its surface (straight down, so the edge is as soft seen
// from far off as close by), so its edge follows the ground with no line; glossy, mirroring `specular` of the sky (a
// low share: Godot's grazing mirror follows it, and a wooded stream under trees shows little sky), with small
// ripples drifting downstream. Each vertex's colour (r, g) is its downstream way across the ground (x, z) packed into
// 0..1; the ripples flow that way at `flow` m/s in two half-cycle phases blended (a flow map), so they never stretch;
// `motion` 0 (Reduced motion) holds them still.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

#include "res://game/play/look/look_light.gdshaderinc"

uniform vec4 shallow : source_color = vec4(0.42, 0.5, 0.42, 0.25);
uniform vec4 deep : source_color = vec4(0.16, 0.24, 0.2, 0.78);
// How much water (m along the eye's line) reads as deep, and how far (m) the edge fades in.
uniform float deep_at = 0.9;
uniform float edge_soft = 0.08;
uniform float roughness : hint_range(0.0, 1.0) = 0.06;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
// The sheen of the wood and sky on its surface, toward the eye's glancing angle (the ripples move it, so it reads as
// water on every preset, with or without screen-space reflections): up to `sheen.a` of `sheen`'s colour.
uniform vec4 sheen : source_color = vec4(0.6, 0.66, 0.64, 0.45);
uniform float flow = 0.4;
// The ripples: their size (waves a metre), how much they tilt the surface, and how long (s) one flow phase lasts.
uniform float ripple_scale = 1.4;
uniform float ripple_tilt = 0.18;
uniform float ripple_cycle = 3.0;
uniform float motion = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 world;

// The ripples' slope (d height / dx, dz) at `p` (m): four crossing waves of the ripple scale.
vec2 ripple_slope(vec2 p) {
	vec2 g = vec2(0.0);
	vec2 k0 = vec2(0.83, 0.55) * ripple_scale * 6.2832;
	vec2 k1 = vec2(-0.47, 0.88) * ripple_scale * 1.71 * 6.2832;
	vec2 k2 = vec2(0.21, -0.98) * ripple_scale * 2.37 * 6.2832;
	vec2 k3 = vec2(-0.95, -0.3) * ripple_scale * 0.61 * 6.2832;
	g += k0 * cos(dot(k0, p) + 0.4) * 0.5;
	g += k1 * cos(dot(k1, p) + 2.1) * 0.25;
	g += k2 * cos(dot(k2, p) + 4.0) * 0.15;
	g += k3 * cos(dot(k3, p) + 5.3) * 0.6;
	return g / (ripple_scale * 6.2832);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The water under this pixel: from its surface to whatever the depth buffer holds behind it, along the eye's line.
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	behind.xyz /= behind.w;
	float through = max(0.0, length(behind.xyz) - length(VERTEX));
	float thick = clamp(through / deep_at, 0.0, 1.0);
	float under = world.y - (INV_VIEW_MATRIX * vec4(behind.xyz, 1.0)).y;
	// Downstream, and the two phases of the flow map, each fading out as it resets.
	vec2 way = COLOR.rg * 2.0 - 1.0;
	float t = TIME * motion / max(ripple_cycle, 0.01);
	float ph0 = fract(t);
	float ph1 = fract(t + 0.5);
	float w = abs(ph0 * 2.0 - 1.0);
	float shift = flow * ripple_cycle * motion;
	vec2 s0 = ripple_slope(world.xz - way * ph0 * shift);
	vec2 s1 = ripple_slope(world.xz - way * ph1 * shift + vec2(0.37, 0.71));
	vec2 slope = mix(s0, s1, w) * ripple_tilt;
	vec3 up = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = look_paint(mix(mix(shallow.rgb, deep.rgb, sqrt(thick)), sheen.rgb, glance * sheen.a));
	ALPHA = mix(shallow.a, deep.a, sqrt(thick)) * smoothstep(0.0, max(edge_soft, 1e-4), under);
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
