// A door's leaves (DoorView): the leaf model's vertex colours times a paint (white for the timber model, DM1; the
// door colour on a plain box) in the shared light (look_light.gdshaderinc), each face in the baked light of its own
// side of the wall (BP7, BakedLightNear): the instance colour is the light on the faces looking down the model's z (its
// thickness), the instance's custom data the other side's light as a share of it, mixed across the leaf's edges.
// White both ways (no bake drawn) leaves the colours as they are.
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying vec3 lit;

void vertex() {
	// COLOR is the vertex colour times the instance colour (the light down the model's z)
	lit = COLOR.rgb * mix(vec3(1.0), INSTANCE_CUSTOM.rgb, clamp(0.5 + 0.5 * NORMAL.z, 0.0, 1.0));
}

void fragment() {
	ALBEDO = look_paint(tint.rgb * lit);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
