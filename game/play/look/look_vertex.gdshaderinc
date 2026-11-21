// The body of look_vertex.gdshader and look_surface.gdshader (WQ1): what look_vertex.gdshader's header says, and with
// LOOK_SURFACES defined, Woodland's surface layers.

#include "res://game/play/look/look_light.gdshaderinc"
#include "res://game/play/look/retro_vertex.gdshaderinc"
#include "res://game/play/look/look_wear.gdshaderinc"

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

#ifdef LOOK_SURFACES
// Woodland's surfaces (WQ1, look_surface.gdshader): each face's detail layer (UV2 x; 0 plain) of `surfaces` at its
// UVs (in tiles, along its grain), times twice into its colour (a texel of 0.5 keeps the paint), and its normal map.
uniform sampler2DArray surfaces : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray surfaces_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float relief_depth : hint_range(0.0, 2.0) = 1.0;
// The look's surface detail (GraphicsApply.SURFACE_DETAIL): 0 on Low Mesh detail, where the relief isn't read.
global uniform float look_surface_detail;
varying float layer;
#endif

varying vec3 paint;
varying vec2 perforation;
varying vec3 wear_at; // world position
varying float wear_foot; // metres over the model's floor

void vertex() {
	paint = paint_by_custom ? mix(vec3(1.0), INSTANCE_CUSTOM.rgb, COLOR.a) : vec3(1.0);
	perforation = perforations ? UV : vec2(0.0);
#ifdef LOOK_SURFACES
	layer = UV2.x;
#endif
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
#ifdef LOOK_SURFACES
	if (layer > 0.5) {
		vec3 at = vec3(UV, floor(layer + 0.5));
		own *= texture(surfaces, at).rgb * 2.0;
		if (look_surface_detail >= 0.5) {
			NORMAL_MAP = texture(surfaces_relief, at).rgb;
			NORMAL_MAP_DEPTH = relief_depth;
		}
	}
#endif
	vec3 col = own * paint * LOOK_LINEAR(tint.rgb);
	float rough = roughness;
	look_worn(col, rough, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, wear_at, wear_foot);
	vec3 albedo = look_paint(col);
	if (keep_by_alpha) {
		albedo = mix(albedo, col, COLOR.a);
	}
	ALBEDO = LOOK_ALBEDO(albedo);
	ROUGHNESS = rough;
	METALLIC = metallic;
	SPECULAR = specular;
}
