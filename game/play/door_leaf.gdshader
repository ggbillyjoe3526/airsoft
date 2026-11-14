// A door's leaves (DoorView): the leaf model's vertex colours times a paint (white for the timber model, DM1; the
// door colour on a plain box) in the shared light (look_light.gdshaderinc), each face in the baked light of its own
// side of the wall (BP7, BakedLightNear): the instance colour is the light on the faces looking down the model's z (its
// thickness), the instance's custom data the other side's light as a share of it, mixed across the leaf's edges.
// White both ways (no bake drawn) leaves the colours as they are. With `wear` (SL2, look_wear.gdshaderinc) the leaf is
// worn as the props are, on the leaf itself rather than the world (a leaf swings): along it and through it as the
// leaf model's scaled axes, up it in the world (it turns about up only), its foot `wear_floor` up the model's y.
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_light.gdshaderinc"
#include "res://game/play/look/retro_vertex.gdshaderinc"
#include "res://game/play/look/look_wear.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying vec3 lit;
varying vec3 wear_at;
varying float wear_foot;
varying vec3 wear_normal;

// How far along the wear's noise one leaf stands from the next (m): no two leaves of a field wear alike.
const float LEAF_WEAR_STEP = 3.7;

void vertex() {
	// COLOR is the vertex colour times the instance colour (the light down the model's z)
	lit = COLOR.rgb * mix(vec3(1.0), INSTANCE_CUSTOM.rgb, clamp(0.5 + 0.5 * NORMAL.z, 0.0, 1.0));
	// Each leaf's wear its own: the leaves' places along the model's x set apart by their instance.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	float world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	wear_at = vec3(VERTEX.x * scale.x + float(INSTANCE_ID) * LEAF_WEAR_STEP, world_y, VERTEX.z * scale.z);
	wear_foot = world_y - (MODEL_MATRIX * vec4(0.0, wear_floor, 0.0, 1.0)).y;
	wear_normal = NORMAL;
	// Dev › Retro filter: corners on the retro screen's pixels while it is on (RF1).
	VERTEX = retro_vertex(MODEL_MATRIX, VERTEX, retro_snaps(IN_SHADOW_PASS, PROJECTION_MATRIX));
}

void fragment() {
	vec3 col = LOOK_LINEAR(tint.rgb) * lit;
	float rough = roughness;
	look_worn(col, rough, normalize(wear_normal), wear_at, wear_foot);
	ALBEDO = LOOK_ALBEDO(look_paint(col));
	ROUGHNESS = rough;
	METALLIC = metallic;
}
