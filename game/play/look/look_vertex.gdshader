// A model painted in vertex colours (the CC0 props, the roof's steel), in the shared light (look_light.gdshaderinc).
// Its roughness and metalness per material; ALBEDO is the vertex colour as the model stores it, times `tint`: linear
// (a glTF's), or sRGB with `srgb_colours` (a mesh or MultiMesh built in code: Woodland's greybox, woods and bushes).
// With `paint_by_custom` (PropDress's MultiMeshes), each instance's custom data is a paint (linear) over the parts whose
// vertex alpha is 1; a part with alpha 0 (a container's bare steel, tools/blender/maps' kit.bare) keeps its colour.
// With `perforations` (PropDress's), a part whose UV x is over 1 (kit.perforated: x 2 plus metres across its row's
// middle, y metres along it) has a row of round holes punched down it, a crate's edge profiles' dense holes for no
// triangles; from far off, where a hole is under a pixel, they fade to the row's average shade so they never shimmer.
// A part whose UV x is under -1 (kit.ribbed: y metres across its ribs) is ribbed instead, fine grooves along it (an
// escalator step's cleats), fading to their average shade where a rib is under a pixel.
// With `wear` (SL2, docs/ART.md › Surfaces), times the look's `look_wear`, the model is worn in world space: grime up
// its foot (from its floor, `wear_floor` m up its own y: PropDress sets its box's bottom, where PropLayout stands it),
// streaks down its sides, broad stains, and dust settled on its tops, so no two props wear alike. Edge scuffs are the
// models' own paint (tools/blender). 0 (foliage, the greybox) is clean. With `use_sheet` (SM5, Subway's signs and
// posters: StationFixtures), the vertex colour is printed with `sheet` at the model's UVs.
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_light.gdshaderinc"
#include "res://game/play/look/retro_vertex.gdshaderinc"
#include "res://game/play/look/look_wear.gdshaderinc"
#include "res://game/play/look/look_surface.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// The engine's sheen of the sky at a glancing angle (Godot's default 0.5); the skyline draws none (FT1).
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform bool srgb_colours = false;
// With `keep_by_alpha` (the skyline's, FT1; props in PropDressConfig.full_colour, SM2), a vertex's alpha is how much
// of its colour it keeps against the look's pull toward grey (look_paint): a treeline's greens, which pulled read
// olive-grey under the warm sun; Subway's safety yellow, which pulled read cream.
uniform bool keep_by_alpha = false;
// With `keep_stripe` (Subway's printed signs, TQ2), a printed pixel of `stripe` 's own hue (the owner's orange, the
// trains' stripe and poles, kept whole there by keep_by_alpha) keeps its colour too: the station's orange name boards
// read the same orange as the trains.
uniform bool keep_stripe = false;
uniform vec3 stripe : source_color = vec3(0.918, 0.416, 0.133);
uniform bool paint_by_custom = false;
uniform bool perforations = false;
uniform bool use_sheet = false;
uniform sampler2D sheet : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// kit.PERF_PITCH and kit.PERF_RADIUS (tools/blender/maps/map_kit.py) keep the same.
uniform float perforation_pitch = 0.045;
uniform float perforation_radius = 0.0045;
uniform float perforation_shade : hint_range(0.0, 1.0) = 0.22;
// kit.RIB_PITCH keeps the same; the share of each rib that is groove, and the groove's shade.
uniform float rib_pitch = 0.0085;
uniform float rib_groove : hint_range(0.0, 1.0) = 0.45;
uniform float rib_shade : hint_range(0.0, 1.0) = 0.42;
// Whether Dev › Retro filter wobbles its corners (RF1): not the level's blocks and ground, whose big faces would tilt
// through the floors and cladding laid a few cm over them (LookMaterials.vertex_colour's `wobble`).
uniform bool retro_wobble = true;
// How much a part of kind 9 (look_surface.gdshaderinc: daylight, TQ2's street up Subway's entrance stair) glows by
// its own colour: the sunlit street seen from underground, brighter than any lamp down there makes it.
uniform float daylight_glow : hint_range(0.0, 2.0) = 0.55;

varying vec3 paint;
varying vec2 perforation;
varying vec3 wear_at; // world position
varying float wear_foot; // metres over the model's floor
// A part whose UV y is SURFACE_KIND_BASE or over (TQ1, Subway's trains) is made of kind UV y - SURFACE_KIND_BASE
// (look_surface.gdshaderinc: gloss paint, steel, moquette, the floor's speckle, glass, rubber), its roughness,
// metalness and fine pattern; its UV x is 0, so it is never perforated or ribbed, and no texture's UV reaches it.
varying vec3 own_at; // the model's own position and normal, for its surface kind's pattern
varying vec3 own_n;
varying float surface_kind;

void vertex() {
	paint = paint_by_custom ? mix(vec3(1.0), INSTANCE_CUSTOM.rgb, COLOR.a) : vec3(1.0);
	perforation = perforations ? UV : vec2(0.0);
	own_at = VERTEX;
	own_n = NORMAL;
	surface_kind = UV.y >= SURFACE_KIND_BASE - 0.5 ? UV.y - SURFACE_KIND_BASE : 0.0;
	wear_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wear_foot = wear_at.y - (MODEL_MATRIX * vec4(0.0, wear_floor, 0.0, 1.0)).y;
	// Dev › Retro filter: corners on the retro screen's pixels while it is on (RF1).
	VERTEX = retro_vertex(MODEL_MATRIX, VERTEX, retro_wobble && retro_snaps(IN_SHADOW_PASS, PROJECTION_MATRIX));
}

void fragment() {
	vec3 own = COLOR.rgb;
	// linear on either renderer (look_light.gdshaderinc's LOOK_ALBEDO hands it back to Compatibility as sRGB)
	if (srgb_colours) {
		own = OUTPUT_IS_SRGB ? look_srgb_to_linear(own)
				: mix(pow((own + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), own * (1.0 / 12.92), lessThan(own, vec3(0.04045)));
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
	} else if (perforation.x < -1.0) {
		float edge = pixel / rib_pitch;
		float t = fract(perforation.y / rib_pitch);
		float groove = 1.0 - smoothstep(rib_groove - edge, rib_groove + edge, t);
		groove = mix(groove, rib_groove, smoothstep(0.25, 0.6, edge));
		own *= mix(1.0, rib_shade, groove);
	}
	if (use_sheet) {
		own *= LOOK_LINEAR(texture(sheet, UV).rgb);
	}
	vec3 col = own * paint * LOOK_LINEAR(tint.rgb);
	float rough = roughness;
	float metal = metallic;
	float spec = specular;
	float worn = 1.0;
	if (surface_kind > 0.5) {
		look_surface(surface_kind, own_at, own_n, col, rough, metal, spec, worn);
	}
	vec3 clean = col;
	float clean_rough = rough;
	look_worn(col, rough, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, wear_at, wear_foot);
	col = mix(clean, col, worn);
	rough = mix(clean_rough, rough, worn);
	vec3 albedo = look_paint(col);
	if (keep_by_alpha) {
		albedo = mix(albedo, col, COLOR.a);
	}
	if (keep_stripe) {
		// how near the pixel's hue (its share of each channel) is the stripe's: within a few hundredths, all of it
		vec3 share = col / max(col.r + col.g + col.b, 1e-4);
		vec3 own_share = stripe / max(stripe.r + stripe.g + stripe.b, 1e-4);
		albedo = mix(albedo, col, 1.0 - smoothstep(0.025, 0.05, distance(share, own_share)));
	}
	ALBEDO = LOOK_ALBEDO(albedo);
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	if (surface_kind > 8.5 && surface_kind < 9.5) {
		EMISSION = albedo * daylight_glow;
	}
}
