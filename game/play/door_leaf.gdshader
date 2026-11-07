// A door's leaves (DoorView): a flat paint in the shared light (look_light.gdshaderinc), each face in the baked light
// of its own side of the wall (BP7, BakedLightNear): the instance colour is the light on the side of the leaf's thin
// axis it faces negatively, the instance's custom data the light on the other side, mixed across the leaf's edges.
// White both ways (no bake drawn) leaves the paint as it is.
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying vec3 lit;

void vertex() {
	// the leaf's thin axis is the unit box's x or z, whichever it is scaled less along
	bool thin_x = length(MODEL_MATRIX[0].xyz) < length(MODEL_MATRIX[2].xyz);
	float side = thin_x ? NORMAL.x : NORMAL.z;
	lit = mix(COLOR.rgb, INSTANCE_CUSTOM.rgb, clamp(0.5 + 0.5 * side, 0.0, 1.0));
}

void fragment() {
	ALBEDO = tint.rgb * lit;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
