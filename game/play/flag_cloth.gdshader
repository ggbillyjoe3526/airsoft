// A flag's cloth, rippling more towards its free edge. UV.x runs from the pole (0) to the free edge (1).
// Attack / Defend's (FlagView): canvas in the attacking team's colour with pale stripes near the top and bottom and a
// BB roundel. Elimination's overtime flag (OvertimeFlagView, `chequer` on): `checks` squares of `team_colour` (its
// off-white until a team touches it, then that team's colour) and `dark`.

shader_type spatial;
render_mode cull_disabled;

#include "res://game/play/look/retro_vertex.gdshaderinc"

uniform vec3 team_colour : source_color = vec3(0.23, 0.53, 0.96);
uniform vec3 pale : source_color = vec3(0.95, 0.94, 0.89);
// Width and height of the cloth (m), so the roundel stays round.
uniform vec2 cloth_size = vec2(0.95, 0.62);
// How far the free edge swings (m), waves along the cloth, and their speed (radians a second).
uniform float wave = 0.07;
uniform float waves = 6.0;
uniform float wave_speed = 7.0;
// The overtime flag's chequer: on, the squares across and down, and the dark squares' colour.
uniform bool chequer = false;
uniform vec2 checks = vec2(6.0, 4.0);
uniform vec3 dark : source_color = vec3(0.15, 0.16, 0.17);

void vertex() {
	float u = UV.x;
	VERTEX.z += sin(u * waves - TIME * wave_speed + UV.y * 1.4) * wave * u;
	// Dev › Retro filter: corners on the retro screen's pixels while it is on (RF1).
	POSITION = retro_position(PROJECTION_MATRIX, VIEW_MATRIX, MODEL_MATRIX, VERTEX, true);
}

void fragment() {
	vec3 c = team_colour;
	if (chequer) {
		vec2 cell = floor(UV * checks);
		c = mod(cell.x + cell.y, 2.0) < 0.5 ? team_colour : dark;
	} else {
		float v = UV.y;
		if ((v > 0.07 && v < 0.15) || (v > 0.85 && v < 0.93)) {
			c = pale;
		}
		vec2 p = (UV - vec2(0.5)) * cloth_size / cloth_size.y;
		float d = length(p);
		if (d < 0.25) {
			c = (d > 0.2 || (d > 0.08 && d < 0.13)) ? pale : team_colour;
		}
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = c * 0.35;
}
