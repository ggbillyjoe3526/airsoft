// A model painted in vertex colours (the CC0 props, the roof's steel), in the shared light (look_light.gdshaderinc).
// Its roughness and metalness per material; ALBEDO is the vertex colour as the model stores it, times `tint`: linear
// (a glTF's), or sRGB with `srgb_colours` (a mesh or MultiMesh built in code: Woodland's greybox, woods and bushes).
// With `paint_by_custom` (PropDress's MultiMeshes), each instance's custom data is a paint (linear) over the parts whose
// vertex alpha is 1; a part with alpha 0 (a container's bare steel, tools/blender/maps' kit.bare) keeps its colour.
// With `perforations` (PropDress's), a part whose UV x is over 1 (kit.perforated: x 2 plus metres across its row's
// middle, y metres along it) has a row of round holes punched down it, a crate's edge profiles' dense holes for no
// triangles; from far off, where a hole is under a pixel, they fade to the row's average shade so they never shimmer.
// With `wear` (SL2, docs/ART.md › Surfaces), times the look's `look_wear`, the model is worn in world space: grime up
// its foot (from its floor, `wear_floor` m up its own y: PropDress sets its box's bottom, where PropLayout stands it),
// streaks down its sides, broad stains, and dust settled on its tops, so no two props wear alike. Edge scuffs are the
// models' own paint (tools/blender). 0 (foliage, the greybox) is clean.
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
uniform float wear : hint_range(0.0, 1.0) = 0.0;
instance uniform float wear_floor = 0.0;
// How high (m) a foot's grime climbs, at most; how strong each wear is at full wear, of the paint it covers.
uniform float grime_height = 0.9;
uniform vec4 wear_strengths = vec4(0.6, 0.28, 0.15, 0.4); // foot grime, streaks, stains, dust

global uniform float look_wear;
global uniform vec4 look_grime;
global uniform vec4 look_dust;

varying vec3 paint;
varying vec2 perforation;
varying vec3 wear_at; // world position
varying float wear_foot; // metres over the model's floor

// A smooth value noise in 0..1, a cell a unit (Hoskins's sin-free hash, steady far from the origin).
float wear_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float wear_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(wear_hash(i), wear_hash(i + vec2(1.0, 0.0)), f.x),
			mix(wear_hash(i + vec2(0.0, 1.0)), wear_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	paint = paint_by_custom ? mix(vec3(1.0), INSTANCE_CUSTOM.rgb, COLOR.a) : vec3(1.0);
	perforation = perforations ? UV : vec2(0.0);
	wear_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wear_foot = wear_at.y - (MODEL_MATRIX * vec4(0.0, wear_floor, 0.0, 1.0)).y;
}

void fragment() {
	vec3 own = COLOR.rgb;
	if (srgb_colours && !OUTPUT_IS_SRGB) {
		own = mix(pow((own + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), own * (1.0 / 12.92), lessThan(own, vec3(0.04045)));
	}
	// Metres a pixel across the strip, either way (fwidth outside the branch: every pixel of a quad takes the same).
	float pixel = max(max(fwidth(perforation.x), fwidth(perforation.y)), 1e-5);
	if (perforation.x > 1.0) {
		vec2 off = vec2(perforation.x - 2.0, (fract(perforation.y / perforation_pitch) - 0.5) * perforation_pitch);
		float hole = 1.0 - smoothstep(perforation_radius - pixel, perforation_radius + pixel, length(off));
		// Far off: the row's average, PI r / (2 pitch) of it dark across the holes' width, spread over a pixel.
		float row = (1.0 - smoothstep(perforation_radius - pixel, perforation_radius + pixel, abs(off.x)))
				* 1.5708 * perforation_radius / perforation_pitch;
		hole = mix(hole, row, smoothstep(0.5, 1.0, pixel / perforation_radius));
		own *= mix(1.0, perforation_shade, hole);
	}
	vec3 col = own * paint * tint.rgb;
	float rough = roughness;
	float worn = wear * look_wear;
	// Uniform (a material's and the look's), so fwidth inside is safe and a clean model pays nothing.
	if (worn > 0.0) {
		// The face's own plane in the world, so the wear lies on it unstretched: a side's across and up, blended by
		// which way it faces; a top's x and z, blended into the side's between (critic), so a round model shows no seam.
		vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float facing_x = n.x * n.x / max(n.x * n.x + n.z * n.z, 1e-4);
		float across = mix(wear_at.x, wear_at.z, facing_x);
		vec2 p_side = vec2(across, wear_at.y);
		float top = smoothstep(0.5, 0.7, abs(n.y));
		// Streaks fade out where they'd be finer than a few pixels (far off), so they never shimmer.
		float fine = 1.0 - smoothstep(0.015, 0.05, fwidth(across));
		float blotch = mix(wear_noise(p_side * 0.7), wear_noise(wear_at.xz * 0.7), top);
		float side = 1.0 - smoothstep(0.4, 0.7, abs(n.y));
		// None under the floor: a model sunk into the ground keeps its paint there.
		float foot = (1.0 - smoothstep(0.0, grime_height * (0.35 + 0.65 * blotch), wear_foot)) * side
				* step(-0.05, wear_foot);
		float streak = side * fine * smoothstep(0.6, 0.85, wear_noise(vec2(across * 14.0, wear_at.y * 0.5)))
				* smoothstep(0.25, 0.65, wear_noise(vec2(across * 0.8, wear_at.y * 0.2) + 5.3));
		float stain = smoothstep(0.55, 0.85,
				mix(wear_noise(p_side * 0.3 + 11.7), wear_noise(wear_at.xz * 0.3 + 11.7), top));
		float dust = smoothstep(0.7, 0.95, n.y) * (0.4 + 0.6 * blotch);
		float dirt = clamp(foot * wear_strengths.x + streak * wear_strengths.y + stain * wear_strengths.z, 0.0, 1.0);
		col = mix(col, look_grime.rgb, dirt * worn);
		col = mix(col, look_dust.rgb, dust * wear_strengths.w * worn);
		rough = mix(rough, 1.0, max(foot, dust) * worn);
	}
	ALBEDO = look_paint(col);
	ROUGHNESS = rough;
	METALLIC = metallic;
}
