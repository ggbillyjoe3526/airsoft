// Your arms while a pistol's sight comes up (HA1, the owner: aimed, only the tops of the hands under a pistol): an arms
// material as its StandardMaterial3D draws it (ArmsFade copies its colour, maps and finish), with what lies below the
// sight line faded out by `hint`, in the eye's space: whole down to `hint_from` m under it, gone by `hint_to`. The
// depth is drawn first where the arm is still whole (depth_prepass_alpha), so a faded hand never shows its far side
// through its near one. `z_clip_scale` is the hands' depth press (ReplicaView), as BaseMaterial3D's use_z_clip_scale
// draws it.
shader_type spatial;
render_mode blend_mix, cull_back, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform sampler2D roughness_map : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D metallic_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float z_clip_scale = 1.0;
uniform float hint : hint_range(0.0, 1.0) = 0.0;
uniform float hint_from = 0.08;
uniform float hint_to = 0.12;

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
	Z_CLIP_SCALE = z_clip_scale;
}

void fragment() {
	vec4 colour = albedo * texture(albedo_map, UV);
	ALBEDO = colour.rgb;
	ROUGHNESS = roughness * texture(roughness_map, UV).g;
	// A glTF material's metal is its roughness map's blue (BaseMaterial3D's own default channels).
	METALLIC = metallic * texture(metallic_map, UV).b;
	SPECULAR = specular;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	// VERTEX is the fragment's place in the eye's space: y up from the sight line once the sight is raised.
	float below = 1.0 - smoothstep(-hint_to, -hint_from, VERTEX.y);
	ALPHA = colour.a * (1.0 - hint * below);
}
