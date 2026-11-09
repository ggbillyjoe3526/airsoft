// A model painted in vertex colours (the CC0 props, the roof's steel), in the shared light (look_light.gdshaderinc).
// Its roughness and metalness per material; ALBEDO is the vertex colour as the model stores it, times `tint`: linear
// (a glTF's), or sRGB with `srgb_colours` (a mesh or MultiMesh built in code: Woodland's greybox, woods and bushes).
// With `paint_by_custom` (PropDress's MultiMeshes), each instance's custom data is a paint (linear) over the parts whose
// vertex alpha is 1; a part with alpha 0 (a container's bare steel, tools/blender/maps' kit.bare) keeps its colour.
// With `perforations` (PropDress's), a part whose UV x is over 1 (kit.perforated: x 2 plus metres across its row's
// middle, y metres along it) has a row of round holes punched down it, a crate's edge profiles' dense holes for no
// triangles; from far off, where a hole is under a pixel, they fade to the row's average shade so they never shimmer.
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform bool srgb_colours = false;
uniform bool paint_by_custom = false;
uniform bool perforations = false;
// kit.PERF_PITCH and kit.PERF_RADIUS (tools/blender/maps/map_kit.py) keep the same.
uniform float perforation_pitch = 0.045;
uniform float perforation_radius = 0.0045;
uniform float perforation_shade : hint_range(0.0, 1.0) = 0.22;

varying vec3 paint;
varying vec2 perforation;

void vertex() {
	paint = paint_by_custom ? mix(vec3(1.0), INSTANCE_CUSTOM.rgb, COLOR.a) : vec3(1.0);
	perforation = perforations ? UV : vec2(0.0);
}

void fragment() {
	vec3 own = COLOR.rgb;
	if (srgb_colours && !OUTPUT_IS_SRGB) {
		own = mix(pow((own + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), own * (1.0 / 12.92), lessThan(own, vec3(0.04045)));
	}
	if (perforation.x > 1.0) {
		vec2 off = vec2(perforation.x - 2.0, (fract(perforation.y / perforation_pitch) - 0.5) * perforation_pitch);
		float pixel = max(fwidth(perforation.y), 1e-5);
		float hole = 1.0 - smoothstep(perforation_radius - pixel, perforation_radius + pixel, length(off));
		// Far off: the row's average, PI r / (2 pitch) of it dark, across the holes' width.
		float row = step(abs(off.x), perforation_radius) * 1.5708 * perforation_radius / perforation_pitch;
		hole = mix(hole, row, smoothstep(0.5, 1.0, pixel / perforation_radius));
		own *= mix(1.0, perforation_shade, hole);
	}
	ALBEDO = own * paint * tint.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
