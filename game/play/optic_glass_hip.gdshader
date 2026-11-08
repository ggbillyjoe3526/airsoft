// A scope's glass in your hands at the hip (OpticGlass, BP8, the owner): plain tinted glass you see through, the main
// view (drawn before the glass) round where the sight line points, as it is, with a soft reflection across it; no
// magnification, no reticle and no second camera. Its own shader, swapped in only while a scope is at the hip, so only
// then does the frame pay the screen copy that hint_screen_texture takes (optic_glass.gdshader takes none).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D screen_view : hint_screen_texture, filter_linear, repeat_disable;
// Where the glass's centre is on screen, and where the optic aims (a point far along its sight line).
uniform vec2 centre_uv = vec2(0.5);
uniform vec2 mark_uv = vec2(0.5);
// The view's tint, and the reflection band's strength at its brightest.
uniform vec3 hip_tint : source_color = vec3(0.8, 0.87, 0.92);
uniform float hip_shine = 0.22;
// A faint sheen round the glass's edge (pixels, share), as optic_glass.gdshader's.
uniform float sheen_px = 3.0;
uniform float sheen = 0.3;
uniform vec3 sheen_colour : source_color = vec3(0.85, 0.9, 1.0);
// The reflection band: across the glass from its top left, this far along the diagonal and this sharp.
const float BAND_AT = 0.8;
const float BAND_SHARP = 3.0;

// The replica in your hands draws its depth pressed towards the eye to this share (ViewModelConfig.depth_scale).
uniform float z_clip_scale = 1.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.w, POSITION.z, z_clip_scale);
}

void fragment() {
	// The disc: UV's centre out to its edge, softened over a pixel.
	float r = length(UV - 0.5) * 2.0;
	float edge = max(fwidth(r), 0.0001);
	float inside = 1.0 - smoothstep(1.0 - edge, 1.0, r);
	if (inside <= 0.0) {
		discard;
	}
	vec3 ahead = texture(screen_view, clamp(mark_uv + SCREEN_UV - centre_uv, vec2(0.0), vec2(1.0))).rgb;
	float along = (UV.x + UV.y - BAND_AT) * BAND_SHARP;
	vec3 col = mix(ahead * hip_tint, sheen_colour, exp(-along * along) * hip_shine);
	float rim = clamp((r - (1.0 - sheen_px * edge)) / (sheen_px * edge), 0.0, 1.0) * sheen;
	ALBEDO = mix(col, sheen_colour, rim);
	ALPHA = inside;
}
