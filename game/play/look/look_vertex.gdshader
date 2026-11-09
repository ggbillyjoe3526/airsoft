// A model painted in vertex colours (the CC0 props, the roof's steel), in the shared light (look_light.gdshaderinc).
// Its roughness and metalness per material; ALBEDO is the vertex colour as the model stores it, times `tint`: linear
// (a glTF's), or sRGB with `srgb_colours` (a mesh or MultiMesh built in code: Woodland's greybox, woods and bushes).
// With `paint_by_custom` (PropDress's MultiMeshes), each instance's custom data is a paint (linear) over the parts whose
// vertex alpha is 1; a part with alpha 0 (a container's bare steel, tools/blender/maps' kit.bare) keeps its colour.
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform bool srgb_colours = false;
uniform bool paint_by_custom = false;

varying vec3 paint;

void vertex() {
	paint = paint_by_custom ? mix(vec3(1.0), INSTANCE_CUSTOM.rgb, COLOR.a) : vec3(1.0);
}

void fragment() {
	vec3 own = COLOR.rgb;
	if (srgb_colours && !OUTPUT_IS_SRGB) {
		own = mix(pow((own + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), own * (1.0 / 12.92), lessThan(own, vec3(0.04045)));
	}
	ALBEDO = own * paint * tint.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
