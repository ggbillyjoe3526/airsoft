// A see-through surface painted in sRGB vertex colours (Woodland's puddles and mud), in the shared light
// (look_light.gdshaderinc): the colour's alpha its opacity, its roughness per material.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

#include "res://game/play/look/look_light.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec3 own = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) {
		own = mix(pow((own + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), own * (1.0 / 12.92), lessThan(own, vec3(0.04045)));
	}
	ALBEDO = own;
	ALPHA = COLOR.a;
	ROUGHNESS = roughness;
}
