// A tree, thicket spruce, fern or bush (WQ1, docs/ART.md › Woodland): its vertex colours (linear, the look's palette,
// as look_vertex.gdshader draws them, times each instance's shade and light) times twice a detail map, so a texel of
// 0.5 draws the paint as it is. Two kinds of face in one model, told apart by their UV x:
// - leaves (UV x 0 to 1): the leaf sheet (assets/textures/woodland/leaves.png, its cells treekit.CELLS), cut out at
//   `alpha_cut`: needle tufts, sprays, sprigs and fronds on cards, and the opaque masses and twig bark of the crowns'
//   cores and branches. The cut-out's cover grows a little with each mip level, so a far crown keeps its fill instead
//   of thinning to sky. Both sides drawn, each lit by the model's own normals (leant out from the crown's middle).
// - bark (UV x under -1: x + 4 the way round, y along, in tiles of the bark map): `bark` with its normal map
//   `bark_relief`, and `bark_b` (a pine's flaking upper bole) blended over it by UV2 x.
// Leaves lit from behind glow a little where the sun shines through them toward the eye (look_light's
// LOOK_TRANSLUCENT). Worn as look_vertex (SL2, `wear`: a trunk's foot; the crowns clean).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

#define LOOK_TRANSLUCENT
#include "res://game/play/look/look_light.gdshaderinc"
#include "res://game/play/look/retro_vertex.gdshaderinc"
#include "res://game/play/look/look_wear.gdshaderinc"

uniform sampler2D sheet : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D bark : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_b : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_b_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_bark_b = false;
// How much sun a leaf lets through toward the eye (look_light's LOOK_TRANSLUCENT, through BACKLIGHT).
uniform float leaf_translucency : hint_range(0.0, 1.0) = 0.35;
uniform float relief_depth : hint_range(0.0, 2.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
// How much a leaf's cover grows a mip level (so a far crown keeps its fill).
uniform float mip_cover : hint_range(0.0, 1.0) = 0.35;
uniform bool retro_wobble = true;
// Each instance's custom data paints the parts whose vertex alpha is 1 (PropDress's, DM1; look_vertex.gdshader's).
uniform bool paint_by_custom = true;

varying vec3 paint;
varying vec3 wear_at;
varying float wear_foot;
varying float flake;

void vertex() {
	paint = paint_by_custom ? mix(vec3(1.0), INSTANCE_CUSTOM.rgb, COLOR.a) : vec3(1.0);
	flake = UV2.x;
	wear_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wear_foot = wear_at.y - (MODEL_MATRIX * vec4(0.0, wear_floor, 0.0, 1.0)).y;
	VERTEX = retro_vertex(MODEL_MATRIX, VERTEX, retro_wobble && retro_snaps(IN_SHADOW_PASS, PROJECTION_MATRIX));
}

void fragment() {
	vec3 d;
	float cover = 1.0;
	float through = 0.0;
	vec3 relief = vec3(0.5, 0.5, 1.0);
	if (UV.x < -1.0) {
		vec2 at = UV + vec2(4.0, 0.0);
		d = texture(bark, at).rgb;
		relief = texture(bark_relief, at).rgb;
		if (use_bark_b && flake > 0.0) {
			d = mix(d, texture(bark_b, at).rgb, flake);
			relief = mix(relief, texture(bark_b_relief, at).rgb, flake);
		}
	} else {
		vec4 s = texture(sheet, UV);
		d = s.rgb;
		float mip = max(textureQueryLod(sheet, UV).y, 0.0);
		cover = s.a * (1.0 + mip * mip_cover);
		// both sides lit as the crown's one soft shape: undo the engine's flip on a back face
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
		through = leaf_translucency;
	}
	vec3 col = COLOR.rgb * paint * d * 2.0;
	float rough = roughness;
	look_worn(col, rough, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, wear_at, wear_foot);
	ALBEDO = LOOK_ALBEDO(look_paint(col));
	ALPHA = cover;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	NORMAL_MAP = relief;
	NORMAL_MAP_DEPTH = relief_depth;
	ROUGHNESS = rough;
	SPECULAR = specular;
	BACKLIGHT = vec3(through);
}
