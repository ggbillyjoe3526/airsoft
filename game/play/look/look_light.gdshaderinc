// The game's shared light (docs/ART.md › Light; LookConfig's Light group): Valorant's clean forms under BOTW's soft
// light. A spatial shader opts in with `#include "res://game/play/look/look_light.gdshaderinc"` and gets this light():
// soft cel bands with a gentle mid step, the sun's far side lit in the look's cool violet (never black), a warm rim on
// an edge seen against the light, and a small soft highlight on smooth surfaces. Its values are global shader
// uniforms (project.godot [shader_globals], set by LookConfig.push_globals), so every map's materials follow one
// place. Ambient light, global illumination and reflections are the engine's and come on top.

global uniform vec4 look_shade;
global uniform float look_band;
global uniform float look_band_soft;
global uniform float look_mid_band;
global uniform vec4 look_rim;
global uniform float look_rim_power;
global uniform float look_spec;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(look_band - look_band_soft, look_band + look_band_soft, ndl);
	float hi = smoothstep(0.5 - look_band_soft, 0.5 + look_band_soft, ndl);
	float tone = lit * ATTENUATION * ((1.0 - look_mid_band) + look_mid_band * hi);
	// the sun's far side takes the shade colour; a lamp's or torch's reach ends in the dark, as light does
	vec3 fill = LIGHT_IS_DIRECTIONAL ? look_shade.rgb : vec3(0.0);
	DIFFUSE_LIGHT += mix(fill, vec3(1.0), tone) * LIGHT_COLOR / PI;
	// the warm rim: strongest on an edge seen against the light, on the side the light reaches
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), look_rim_power);
	float against = 0.4 + 0.6 * clamp(dot(LIGHT, -VIEW) * 0.5 + 0.5, 0.0, 1.0);
	float reach = smoothstep(-0.2, 0.3, ndl) * ATTENUATION;
	SPECULAR_LIGHT += look_rim.rgb * look_rim.a * edge * against * reach * LIGHT_COLOR / PI;
	// a soft highlight, small and bright on a smooth surface, none on a rough one
	if (look_spec > 0.0 && ROUGHNESS < 0.75) {
		float size = mix(0.004, 0.06, ROUGHNESS);
		float nh = dot(NORMAL, normalize(LIGHT + VIEW));
		float s = smoothstep(1.0 - size, 1.0 - size * 0.5, nh) * tone;
		SPECULAR_LIGHT += s * look_spec * (1.0 - ROUGHNESS) * LIGHT_COLOR / PI;
	}
}
