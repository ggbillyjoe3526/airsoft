// Dev › Retro filter's geometry (RF1, RetroFilter): while it is on, the field drawn as a 1990s console drew it. A
// spatial shader opts in with `#include "res://game/play/look/retro_vertex.gdshaderinc"` and, at the end of vertex(),
// `VERTEX = retro_vertex(MODEL_MATRIX, VERTEX, retro_snaps(IN_SHADOW_PASS, PROJECTION_MATRIX));`: each corner moved in
// the world so the main camera sees it on a corner of the filter's pixels (whole pixels from the screen's top left, as
// the console's), so the field's edges wobble against each other as the view moves. VERTEX, not POSITION, so the
// engine's own shadow bias and projections stay as they are, and off it costs a branch. The colour, depth and sun
// shadow passes move it alike, so a surface never shadows itself where its drawn shape left its true one; a lamp's
// shadow keeps the true shape (the engine keeps a still lamp's shadow map, which can't follow the camera's snap).
// A shader's own `false` keeps a big face true: one laid a few cm over another (a floor over the ground) would tilt
// through it, as a corner tens of metres off moves more than that. A surface pattern laid in world space can swim as
// the console's textures did: retro_affine_in() in vertex() keeps the point for fragment(), where retro_affine_out()
// gives it interpolated straight across the screen instead of in perspective, at most w m from the true point (the
// console's games cut big faces small, so their swim stayed local; an unbounded swim smears a floor into long streaks
// and breaks up lettering). Off (x 0), both are the true values, for a branch on a global.

global uniform vec4 retro_snap; // x, y: the retro screen in pixels (0: off); z: how far patterns swim (0 to 1); w: m
global uniform mat4 retro_view_projection; // the main camera's, as RetroFilter last set it
global uniform mat4 retro_view_projection_inverse;

// `world` moved so the main camera sees it on the nearest corner of the retro screen's pixels.
vec3 retro_world(vec3 world) {
	if (retro_snap.x <= 0.0) {
		return world;
	}
	vec4 clip = retro_view_projection * vec4(world, 1.0);
	if (clip.w <= 0.0) {
		return world;
	}
	vec2 ndc = clip.xy / clip.w;
	vec2 px = round(vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5) * retro_snap.xy);
	ndc = vec2(px.x / retro_snap.x * 2.0 - 1.0, 1.0 - px.y / retro_snap.y * 2.0);
	vec4 moved = retro_view_projection_inverse * vec4(ndc * clip.w, clip.z, clip.w);
	return moved.xyz / moved.w;
}

// Whether a pass moves its corners: every pass but a lamp's shadow (a perspective one; the sun's is orthographic).
bool retro_snaps(bool shadow_pass, mat4 projection) {
	return !shadow_pass || projection[3][3] > 0.5;
}

// `vertex` (model space) moved as retro_world moves its world point, while the filter is on and `wobble`.
vec3 retro_vertex(mat4 model, vec3 vertex, bool wobble) {
	if (!wobble || retro_snap.x <= 0.0) {
		return vertex;
	}
	vec3 world = (model * vec4(vertex, 1.0)).xyz;
	return vertex + inverse(mat3(model)) * (retro_world(world) - world);
}

// `p` times the clip w, and w: perspective-correct interpolation of both, divided, is straight across the screen.
vec4 retro_affine_in(vec3 p, vec4 clip) {
	return vec4(p * clip.w, clip.w);
}

vec3 retro_affine_out(vec3 p, vec4 affine) {
	if (retro_snap.x <= 0.0 || retro_snap.z <= 0.0 || affine.w <= 0.0) {
		return p;
	}
	return p + clamp((affine.xyz / affine.w - p) * retro_snap.z, -retro_snap.w, retro_snap.w);
}
