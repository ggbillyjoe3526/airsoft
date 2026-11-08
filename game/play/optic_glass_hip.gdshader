// A scope's glass in your hands at the hip (OpticGlass, BP8, the owner): clear glass you see through. The glass's camera
// draws the field behind the disc at the main view's own scale (no magnification, your replica left out), so the lens
// shows what really lies behind it, lined up with the view round it; lightly tinted, with a soft reflection across it
// and the sheen at its edge, so it reads as glass. No reticle, and no screen copy (as optic_glass.gdshader).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// The view behind the glass: a square picture centred on the glass, `span` screen heights across.
uniform sampler2D glass : filter_linear, repeat_disable;
uniform vec2 centre_uv = vec2(0.5);
uniform float span = 0.25;
// The screen's width over its height.
uniform float aspect = 1.7778;
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
	vec2 from_centre = (SCREEN_UV - centre_uv) * vec2(aspect, 1.0);
	vec3 behind = texture(glass, vec2(0.5) + from_centre / span).rgb;
	float along = (UV.x + UV.y - BAND_AT) * BAND_SHARP;
	vec3 col = mix(behind * hip_tint, sheen_colour, exp(-along * along) * hip_shine);
	float rim = clamp((r - (1.0 - sheen_px * edge)) / (sheen_px * edge), 0.0, 1.0) * sheen;
	ALBEDO = mix(col, sheen_colour, rim);
	ALPHA = inside;
}
