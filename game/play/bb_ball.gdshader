// A white BB in flight (BBView): its own colour where it faces you, a darker rim round its edge, so a BB a few pixels
// across reads against a pale wall or sky as well as a dark one. Lit by nothing (it never goes dark in shade).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

#include "res://game/play/look/retro_vertex.gdshaderinc"

uniform vec3 colour : source_color = vec3(1.0, 0.98, 0.92);
uniform vec3 rim : source_color = vec3(0.35, 0.34, 0.32);
// How square to the view a point must face (the cosine) to take the BB's colour; the rim blends in below it.
uniform float rim_from = 0.55;
uniform float rim_blend = 0.2;

void vertex() {
	// Dev › Retro filter: corners on the retro screen's pixels while it is on (RF1).
	VERTEX = retro_vertex(MODEL_MATRIX, VERTEX, retro_snaps(IN_SHADOW_PASS, PROJECTION_MATRIX));
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(rim, colour, smoothstep(rim_from - rim_blend, rim_from + rim_blend, facing));
}
