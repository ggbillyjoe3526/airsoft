// The models' wear (SL2, docs/ART.md › Surfaces), shared by look_vertex.gdshader and door_leaf.gdshader: with `wear`,
// times the look's `look_wear`, a model is worn in world space: grime up its foot (from its floor, `wear_floor` m up
// its own y), streaks down its sides, broad stains, and dust settled on its tops. A shader declares the varyings
// `wear_at` (world position) and `wear_foot` (metres over the model's floor), sets them in vertex() and hands them
// with the world normal to look_worn().
uniform float wear : hint_range(0.0, 1.0) = 0.0;
instance uniform float wear_floor = 0.0;
// How high (m) a foot's grime climbs, at most; how strong each wear is at full wear, of the paint it covers.
uniform float grime_height = 0.9;
uniform vec4 wear_strengths = vec4(0.6, 0.28, 0.15, 0.4); // foot grime, streaks, stains, dust

global uniform float look_wear;
global uniform vec4 look_grime;
global uniform vec4 look_dust;

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

// `col` and `rough` worn at world point `at`, `foot_height` m over the model's floor, its world normal `n`.
void look_worn(inout vec3 col, inout float rough, vec3 n, vec3 at, float foot_height) {
	float worn = wear * look_wear;
	// Uniform (a material's and the look's), so fwidth inside is safe and a clean model pays nothing.
	if (worn > 0.0) {
		// The face's own plane in the world, so the wear lies on it unstretched: a side's across and up, blended by
		// which way it faces; a top's x and z, blended into the side's between (critic), so a round model shows no seam.
		float facing_x = n.x * n.x / max(n.x * n.x + n.z * n.z, 1e-4);
		float across = mix(at.x, at.z, facing_x);
		vec2 p_side = vec2(across, at.y);
		float top = smoothstep(0.5, 0.7, abs(n.y));
		// Streaks fade out where they'd be finer than a few pixels (far off), so they never shimmer.
		float fine = 1.0 - smoothstep(0.015, 0.05, fwidth(across));
		float blotch = mix(wear_noise(p_side * 0.7), wear_noise(at.xz * 0.7), top);
		float side = 1.0 - smoothstep(0.4, 0.7, abs(n.y));
		// None under the floor: a model sunk into the ground keeps its paint there.
		float foot = (1.0 - smoothstep(0.0, grime_height * (0.35 + 0.65 * blotch), foot_height)) * side
				* step(-0.05, foot_height);
		float streak = side * fine * smoothstep(0.6, 0.85, wear_noise(vec2(across * 14.0, at.y * 0.5)))
				* smoothstep(0.25, 0.65, wear_noise(vec2(across * 0.8, at.y * 0.2) + 5.3));
		float stain = smoothstep(0.55, 0.85,
				mix(wear_noise(p_side * 0.3 + 11.7), wear_noise(at.xz * 0.3 + 11.7), top));
		float dust = smoothstep(0.7, 0.95, n.y) * (0.4 + 0.6 * blotch);
		float dirt = clamp(foot * wear_strengths.x + streak * wear_strengths.y + stain * wear_strengths.z, 0.0, 1.0);
		col = mix(col, look_grime.rgb, dirt * worn);
		col = mix(col, look_dust.rgb, dust * wear_strengths.w * worn);
		rough = mix(rough, 1.0, max(foot, dust) * worn);
	}
}
