// An optic's glass in your hands (OpticGlass): a disc over the glass showing the view through it, drawn by a second
// camera without your replica (so the optic's inside never darkens it), magnified for a scope, with the red dot or the
// reticle on it. The view round the optic stays the main camera's: nothing dark round the glass (owner, 2026-10-19).
// At the hip (`hip`) a scope's glass is plain tinted glass instead (BP8, the owner): the main view ahead along its sight
// line, as it is, with a soft reflection across it, no reticle and no second camera.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// The view through the glass: a square picture centred on the glass, `span` screen heights across.
uniform sampler2D glass : filter_linear, repeat_disable;
uniform vec2 centre_uv = vec2(0.5);
uniform float span = 0.25;
// The screen's width over its height, and its height in pixels (the marks are sized for a 1080-high screen).
uniform float aspect = 1.7778;
uniform float screen_h = 1080.0;
// Where the optic aims on screen (a point far along its sight line), and its mark: 0 a lit dot, 1 a reticle.
uniform vec2 mark_uv = vec2(0.5);
uniform int mark = 0;
uniform vec3 dot_colour : source_color = vec3(1.0, 0.16, 0.12);
uniform float dot_energy = 1.0;
uniform float dot_core = 4.5;
uniform float dot_glow = 13.0;
uniform vec3 reticle_colour : source_color = vec3(0.04);
uniform float reticle_gap = 14.0;
uniform float reticle_half = 1.0;
uniform float reticle_dot = 2.2;
// A faint sheen round the glass's edge (pixels, share).
uniform float sheen_px = 3.0;
uniform float sheen = 0.3;
uniform vec3 sheen_colour : source_color = vec3(0.85, 0.9, 1.0);
// At the hip: the main view (drawn before the glass) round where the sight line points, tinted `hip_tint`, under a
// reflection band `hip_shine` strong at its brightest.
uniform bool hip = false;
uniform sampler2D screen_view : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 hip_tint : source_color = vec3(0.8, 0.87, 0.92);
uniform float hip_shine = 0.22;
// The reflection band: across the glass from its top left, this far along the diagonal and this sharp.
const float BAND_AT = 0.8;
const float BAND_SHARP = 3.0;

// The replica in your hands draws its depth pressed towards the eye to this share (ViewModelConfig.depth_scale, as its
// materials' z clip scale do), so the glass sits in it as it does unpressed.
uniform float z_clip_scale = 1.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.w, POSITION.z, z_clip_scale);
}

// The view through the raised sight: the second camera's picture with the dot or the reticle on it.
vec3 sighted(vec2 screen_uv) {
	vec2 from_centre = (screen_uv - centre_uv) * vec2(aspect, 1.0);
	vec3 col = texture(glass, vec2(0.5) + from_centre / span).rgb;
	float px = screen_h / 1080.0;
	vec2 m = (screen_uv - mark_uv) * vec2(aspect, 1.0) * screen_h / px;
	if (mark == 0) {
		float d = length(m);
		float core = clamp(dot_core - d, 0.0, 1.0);
		float glow = clamp(1.0 - d / dot_glow, 0.0, 1.0) * 0.45;
		return mix(col, dot_colour * dot_energy, max(core, glow * glow));
	}
	vec2 a = abs(m);
	float line_x = step(a.x, reticle_half) * step(reticle_gap, a.y);
	float line_y = step(a.y, reticle_half) * step(reticle_gap, a.x);
	float centre = step(length(m), reticle_dot);
	return mix(col, reticle_colour, max(max(line_x, line_y), centre));
}

// The glass at the hip: what lies along the sight line, as big as round the optic, tinted under the reflection.
vec3 plain_glass(vec2 screen_uv, vec2 uv) {
	vec3 ahead = texture(screen_view, clamp(mark_uv + screen_uv - centre_uv, vec2(0.0), vec2(1.0))).rgb;
	float along = (uv.x + uv.y - BAND_AT) * BAND_SHARP;
	return mix(ahead * hip_tint, sheen_colour, exp(-along * along) * hip_shine);
}

void fragment() {
	// The disc: UV's centre out to its edge, softened over a pixel.
	float r = length(UV - 0.5) * 2.0;
	float edge = max(fwidth(r), 0.0001);
	float inside = 1.0 - smoothstep(1.0 - edge, 1.0, r);
	if (inside <= 0.0) {
		discard;
	}
	vec3 col = hip ? plain_glass(SCREEN_UV, UV) : sighted(SCREEN_UV);
	float rim = clamp((r - (1.0 - sheen_px * edge)) / (sheen_px * edge), 0.0, 1.0) * sheen;
	ALBEDO = mix(col, sheen_colour, rim);
	ALPHA = inside;
}
