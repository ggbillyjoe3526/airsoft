// A figure's contact shadow (FigureView.contact_mesh, BP7): the soft dark disc, one material shared by every figure,
// each fading it by its own `fade` (1 whole, 0 gone: as the feet rise off the floor and as the figure fades out). An
// instance uniform, not GeometryInstance3D.transparency, which the Compatibility renderer ignores.
shader_type spatial;
render_mode blend_mix, cull_back, unshaded;

uniform sampler2D disc : source_color, filter_linear_mipmap, repeat_enable;
instance uniform float fade = 1.0;

void fragment() {
	vec4 c = texture(disc, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a * fade;
}
