// The Compatibility renderer (OUTPUT_IS_SRGB) takes ALBEDO as sRGB and hands source_color uniforms and textures over as
// written (sRGB), where Forward+ takes and hands over linear colours. Its own conversions (Godot's gles3 tonemap_inc,
// Chilliant's approximations), so a linear colour put through LOOK_ALBEDO comes out of its srgb_to_linear as it went in.
vec3 look_srgb_to_linear(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 look_linear_to_srgb(vec3 c) {
	return max(vec3(1.055) * pow(max(c, vec3(0.0)), vec3(0.416666667)) - vec3(0.055), vec3(0.0));
}

// A linear colour as ALBEDO (or EMISSION) on either renderer, and a source_color uniform's or texture's colour as linear
// on either.
#define LOOK_ALBEDO(c) (OUTPUT_IS_SRGB ? look_linear_to_srgb(c) : (c))
#define LOOK_LINEAR(c) (OUTPUT_IS_SRGB ? look_srgb_to_linear(c) : (c))
