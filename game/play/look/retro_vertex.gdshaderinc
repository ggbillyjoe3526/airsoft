// Dev › Retro filter's geometry (RF1, RetroFilter): while it is on, the field drawn as a 1990s console drew it. A
// spatial shader opts in with `#include "res://game/play/look/retro_vertex.gdshaderinc"` and, in vertex(),
// `POSITION = retro_position(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), IN_SHADOW_PASS);` after any
// change to VERTEX: each corner snapped to the retro screen's pixels (whole pixels, as the console's), so the field's
// edges wobble against each other as the view moves (not a big face laid a few cm over another: a corner tens of
// metres off moves more than that, and the face under shows through). Shadows are cast from the true shape. A surface pattern laid in
// world space can swim as the console's textures did: retro_affine_in() in vertex() keeps the point for fragment(),
// where retro_affine_out() gives it interpolated straight across the screen instead of in perspective, at most w m from
// the true point (the console's games cut big faces small, so their swim stayed local; a field's floor is one face, so
// an unbounded swim smears it into long streaks). Off (x 0), both are the true values, for a branch on a global.

global uniform vec4 retro_snap; // x, y: the retro screen in pixels (0: off); z: how far patterns swim (0 to 1); w: m

vec4 retro_position(vec4 clip, bool shadow) {
	if (retro_snap.x <= 0.0 || shadow || clip.w <= 0.0) {
		return clip;
	}
	vec2 half_screen = retro_snap.xy * 0.5;
	clip.xy = round(clip.xy / clip.w * half_screen) / half_screen * clip.w;
	return clip;
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
