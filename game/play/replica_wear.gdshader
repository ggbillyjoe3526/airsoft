// A painted replica part, lightly used (RW1, 2026-11-10): ReplicaPaint's paint (albedo, roughness, metalness, as its
// plain StandardMaterial3D draws it) worn by the model's own mask, baked in Blender (tools/blender/replicas/wear.py)
// on the model's `Wear` UV layer (glTF TEXCOORD_1, which Godot's import makes these surfaces' UV, as their material's
// occlusion texture reads it; tests/unit/test_replica_wear.gd holds it): R the ambient occlusion (dirt settles where it is low), G the rubbed edges and
// patches, B the scratches. A rub or a scratch scuffs the paint towards a worn mid grey (perceptually: black paint
// greys up, white paint dirties down, a bright colour dulls) and changes its sheen; a metal part wears to bare metal. Times the look's `look_wear`
// (LookConfig.wear: 0 draws every replica clean, as it does the maps' models). `z_clip_scale` is the hands' depth
// press (ReplicaView), as BaseMaterial3D's use_z_clip_scale draws it.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float look_wear;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.64;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// 1 on a metal part: it wears to bare metal, not to a lighter coat.
uniform float bare_metal : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D wear_mask : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
// Each wear at a full mask, as a share of the way from the paint to `scuff` (in perceptual, square-root, light).
uniform float edge_scuff : hint_range(0.0, 1.0) = 0.3;
uniform float scratch_scuff : hint_range(0.0, 1.0) = 0.6;
// The worn grey a scuff goes towards, in square-root light (0.6: about sRGB 0.6).
uniform float scuff : hint_range(0.0, 1.0) = 0.6;
// How much the dirt in a recess darkens and browns the paint, at a full mask.
uniform float grime_shade : hint_range(0.0, 1.0) = 0.2;
uniform vec3 grime_tint : source_color = vec3(0.85, 0.78, 0.70);
// Roughness changes at a full mask: a rubbed edge polishes, a scratch and dirt go matte.
uniform float edge_polish : hint_range(0.0, 1.0) = 0.18;
uniform float scratch_matte : hint_range(0.0, 1.0) = 0.10;
uniform float grime_matte : hint_range(0.0, 1.0) = 0.15;
// Bare metal under a metal part's coat (linear), and how metallic it is.
uniform vec3 bare_colour : source_color = vec3(0.62, 0.62, 0.60);
uniform float bare_metallic : hint_range(0.0, 1.0) = 0.85;
uniform float z_clip_scale = 1.0;

void vertex() {
	Z_CLIP_SCALE = z_clip_scale;
}

// `c` (linear) scuffed towards the worn grey by `k`, in square-root light, so it reads alike on dark and light paint.
vec3 scuffed(vec3 c, float k) {
	vec3 p = sqrt(max(c, vec3(0.0)));
	p = mix(p, vec3(scuff), k);
	return p * p;
}

void fragment() {
	vec3 mask = texture(wear_mask, UV).rgb;
	float grime = (1.0 - mask.r) * look_wear;
	float rub = mask.g * look_wear;
	float scratch = mask.b * look_wear;
	vec3 paint = albedo.rgb;
	vec3 worn = mix(scuffed(paint, edge_scuff * rub), mix(paint, bare_colour, rub), bare_metal);
	vec3 cut = mix(scuffed(paint, scratch_scuff), bare_colour, bare_metal);
	worn = mix(worn, cut, scratch);
	worn = mix(worn, worn * grime_tint * (1.0 - grime_shade), grime);
	ALBEDO = worn;
	float bare = bare_metal * max(rub, scratch);
	METALLIC = mix(metallic, bare_metallic, bare);
	ROUGHNESS = clamp(roughness - edge_polish * rub + scratch_matte * scratch + grime_matte * grime, 0.05, 1.0);
}
