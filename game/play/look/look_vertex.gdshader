// A model painted in vertex colours (the CC0 props, the roof's steel), in the shared light (look_light.gdshaderinc).
// Its roughness and metalness per material; ALBEDO is the vertex colour as the model stores it, times `tint`: linear
// (a glTF's), or sRGB with `srgb_colours` (a mesh or MultiMesh built in code: Woodland's greybox, woods and bushes).
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform bool srgb_colours = false;

void fragment() {
	vec3 own = COLOR.rgb;
	if (srgb_colours && !OUTPUT_IS_SRGB) {
		own = mix(pow((own + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), own * (1.0 / 12.92), lessThan(own, vec3(0.04045)));
	}
	ALBEDO = own * tint.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
