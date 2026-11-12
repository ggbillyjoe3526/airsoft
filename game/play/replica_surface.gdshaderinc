// A replica part's surface (MQ1, 2026-11-12): ReplicaPaint's paint on what the part is made of. Each face of a replica,
// a part or an accessory says its surface kind in its vertex colour's alpha (tools/blender/replicas/surface.py: kind / 8,
// the colour itself white so the model's own materials draw as they did; a mesh with no colours reads 1 and draws as
// `default_kind`), and ReplicaSurfaces' table gives each kind its finish:
// steel and aluminium are metal under the paint (a blued slide, an anodised receiver), polymer is matte, wood shows
// its figure in a walnut stain the paint's colour tints. The fine structure comes from one small tiling texture
// (assets/textures/replica/replica_grain.png, tools/textures/replica_grain.py) read on the model's own space from
// three sides, the bore's length stretched for a brushed finish or a wood grain, so no model needs texture
// coordinates for it. Over that the part wears as before where its model carries a wear mask (RW1: `wear` 1, the mask
// on UV: R occlusion, G rubbed edges, B scratches; tools/blender/replicas/wear.py), times the look's `look_wear`.
// The figures' copies are not drawn with it: they keep ReplicaPaint's plain paints, which HeldMerge merges.

global uniform float look_wear;

const int KINDS = 8;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
// The kind a mesh with no vertex colours is drawn as.
uniform int default_kind : hint_range(0, 7) = 0;
// Per kind: metallic, roughness, how far the slow cloud moves the roughness, and 1 where wear bares metal.
uniform vec4 kind_finish[KINDS];
uniform float z_clip_scale = 1.0;
// Per kind: the grain's tile (m), its stretch along the bore, its relief, and how much wood figure the colour takes.
uniform vec4 kind_grain[KINDS];
// Per kind: the cloud's tile (m), the figure's dark and light gains on the colour, and the colour's own gain.
uniform vec4 kind_tone[KINDS];
uniform sampler2D grain : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// The stain a wood part's colour is drawn towards, and how far at a full figure (the paint tints the rest).
uniform vec3 wood_stain : source_color = vec3(0.48, 0.29, 0.15);
uniform float wood_stain_share : hint_range(0.0, 1.0) = 0.0;
// 1 where the model carries a wear mask (RW1).
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D wear_mask : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
// Each wear at a full mask, as a share of the way from the paint to `scuff` (in perceptual, square-root, light).
uniform float edge_scuff : hint_range(0.0, 1.0) = 0.3;
uniform float scratch_scuff : hint_range(0.0, 1.0) = 0.6;
// The worn grey a scuff goes towards, in square-root light (0.6: about sRGB 0.6).
uniform float scuff : hint_range(0.0, 1.0) = 0.6;
// How much the dirt in a recess darkens the paint (near grey, so light paint doesn't brown), at a full mask.
uniform float grime_shade : hint_range(0.0, 1.0) = 0.12;
uniform vec3 grime_tint : source_color = vec3(0.96, 0.95, 0.94);
// Roughness changes at a full mask: a rubbed edge polishes, a scratch and dirt go matte.
uniform float edge_polish : hint_range(0.0, 1.0) = 0.18;
uniform float scratch_matte : hint_range(0.0, 1.0) = 0.10;
uniform float grime_matte : hint_range(0.0, 1.0) = 0.15;
// Bare metal under a metal part's coat (linear), and how metallic it is.
uniform vec3 bare_colour : source_color = vec3(0.62, 0.62, 0.60);
uniform float bare_metallic : hint_range(0.0, 1.0) = 0.9;
// How sharply the three sides' grain hands over on a slanted face.
const float SIDE_SHARPNESS = 4.0;
// The grain texture's size (px), and the texels a pixel between which its relief fades to nothing.
const float GRAIN_PX = 512.0;
const vec2 GRAIN_FADE = vec2(1.5, 4.0);

varying vec3 model_position;
varying vec3 model_normal;
varying flat int kind;

void vertex() {
	Z_CLIP_SCALE = z_clip_scale;
	// kind / 8 in the colour's alpha; 1 (no colours) is the material's own default.
	int marked = int(COLOR.a * float(KINDS) + 0.5);
	kind = marked >= KINDS ? default_kind : marked;
	model_position = VERTEX;
	model_normal = NORMAL;
}

// `c` (linear) scuffed towards the worn grey by `k`, in square-root light, so it reads alike on dark and light paint.
vec3 scuffed(vec3 c, float k) {
	vec3 p = sqrt(max(c, vec3(0.0)));
	p = mix(p, vec3(scuff), k);
	return p * p;
}

void fragment() {
	vec4 finish = kind_finish[kind];
	vec3 paint = albedo.rgb;
	float rough = finish.y;
	vec4 fine = kind_grain[kind];
	vec4 tone = kind_tone[kind];
	vec3 n = normalize(model_normal);
	vec3 side = pow(abs(n), vec3(SIDE_SHARPNESS));
	side /= side.x + side.y + side.z;
	// The bore runs along the model's z: the two long sides read it as u, stretched; the end-on side reads it plain.
	vec3 p = model_position / fine.x;
	vec4 gx = texture(grain, vec2(p.z / fine.y, p.y));
	vec4 gy = texture(grain, vec2(p.z / fine.y, p.x));
	vec4 gz = texture(grain, p.xy);
	vec3 slope = side.x * vec3(0.0, gx.g - 0.5, (gx.r - 0.5) / fine.y)
			+ side.y * vec3(gy.g - 0.5, 0.0, (gy.r - 0.5) / fine.y)
			+ side.z * vec3(gz.r - 0.5, gz.g - 0.5, 0.0);
	// The relief fades out as the grain shrinks under a pixel (GRAIN_FADE texels a pixel and more: a far or small part),
	// where its smallest levels would only shimmer.
	float texels = max(fwidth(p.x), max(fwidth(p.y), fwidth(p.z))) * GRAIN_PX;
	float relief = fine.z * (1.0 - smoothstep(GRAIN_FADE.x, GRAIN_FADE.y, texels));
	vec3 bumped = normalize(n - slope * relief * 2.0);
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(bumped, 0.0))).xyz);
	vec3 q = model_position / tone.x;
	float cloud = side.x * texture(grain, q.zy).b + side.y * texture(grain, q.zx).b + side.z * texture(grain, q.xy).b;
	float figure = side.x * gx.a + side.y * gy.a + side.z * gz.a;
	paint = mix(paint, wood_stain, fine.w * wood_stain_share);
	paint *= tone.w * mix(1.0, mix(tone.y, tone.z, figure), fine.w);
	rough += (cloud - 0.5) * 2.0 * finish.z;
	vec3 mask = texture(wear_mask, UV).rgb;
	float grime = (1.0 - mask.r) * look_wear * wear;
	float rub = mask.g * look_wear * wear;
	float scratch = mask.b * look_wear * wear;
	// A metal part shows bare metal only where it is rubbed hard (rub squared), so a faint rub never lightens a lip.
	vec3 worn = mix(scuffed(paint, edge_scuff * rub), mix(paint, bare_colour, rub * rub), finish.w);
	vec3 cut = mix(scuffed(paint, scratch_scuff), bare_colour, finish.w);
	worn = mix(worn, cut, scratch);
	worn = mix(worn, worn * grime_tint * (1.0 - grime_shade), grime);
	paint = worn;
	float bare = finish.w * max(rub * rub, scratch);
	METALLIC = mix(finish.x, bare_metallic, bare);
	rough += -edge_polish * rub + scratch_matte * scratch + grime_matte * grime;
	ALBEDO = paint;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	EMISSION = emission * emission_energy;
}
