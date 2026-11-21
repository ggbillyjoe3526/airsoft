// What a model's parts are made of (TQ1: Subway's trains): each vertex's UV y is SURFACE_KIND_BASE plus its part's kind
// (tools/blender/maps/train.py KINDS, the same numbers), which sets how it shines and what fine pattern it wears for no
// triangles. 0 (or no UVs) keeps the material's own roughness, the rest:
//   1 gloss paint (the cars' clean white sides), 2 satin steel (poles, rails, trims), 3 moquette (the seats' woven
//   cover: rings and dots over its colour, as the owner's photos), 4 the floor's speckled rubber, 5 dark glass (the far
//   side's windows, the cab's mask), 6 rubber (seals, bellows), 7 brushed aluminium (frames, thresholds).
// The patterns lie in the model's own space (`own_at`, `own_n`: the same on every car) and fade to their average
// where they'd be finer than a pixel, so they never shimmer far off.

const float SURFACE_KIND_BASE = 100.0;
const vec3 SURFACE_RING_COLOURS[5] = vec3[5](
		vec3(0.24, 0.24, 0.25), vec3(0.11, 0.11, 0.12), vec3(0.42, 0.42, 0.41), vec3(0.45, 0.11, 0.03),
		vec3(0.20, 0.20, 0.21));
// How far, as a share of the base, the moquette's and the floor's patterns lighten it on average (their far colour).
const float SURFACE_RING_AVERAGE = 0.22;
const float SURFACE_FLECK_AVERAGE = 0.12;

float surface_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// The face's own plane in the model: the two axes across the way it faces most.
vec2 surface_plane(vec3 at, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) {
		return at.xz;
	}
	return a.x > a.z ? at.zy : at.xy;
}

// The moquette's rings over a cell grid `cell` m across: each cell holds a ring (some a ring round a dot), its
// colour and size by the cell's hash; how much of the ring is under this point and its colour.
vec4 surface_rings(vec2 p, float cell, float seed, float pixel) {
	vec2 c = floor(p / cell);
	float h = surface_hash(c + seed);
	float h2 = surface_hash(c * 1.7 + seed + 19.1);
	float h3 = surface_hash(c * 2.3 + seed + 41.7);
	vec2 mid = (c + 0.5 + (vec2(h2, h3) - 0.5) * 0.3) * cell;
	float r = cell * mix(0.18, 0.38, h);
	float w = cell * mix(0.055, 0.1, h3);
	float d = length(p - mid);
	float ring = 1.0 - smoothstep(w - pixel, w + pixel, abs(d - r));
	float dot_r = h2 > 0.55 ? r * 0.35 : 0.0;
	ring = max(ring, 1.0 - smoothstep(dot_r - pixel, dot_r + pixel, d));
	int k = int(floor(h2 * 4.999));
	// orange rings rarer than grey (the photos': a few among many)
	k = (k == 3 && h > 0.45) ? 2 : k;
	return vec4(SURFACE_RING_COLOURS[k], ring * step(0.2, h));
}

// The part of kind `kind` at model point `at` (its model normal `n`): `col` patterned, `rough`, `metal` and `spec` set,
// and how much of the props' world wear it takes (`worn`): the moquette and the floor are swept and hoovered, so the
// dust settled on tops (look_wear.gdshaderinc) would draw them beige.
void look_surface(float kind, vec3 at, vec3 n, inout vec3 col, inout float rough, inout float metal, inout float spec,
		inout float worn) {
	int k = int(kind + 0.5);
	// The pattern's plane and a pixel's size on it, outside the branches (fwidth needs every pixel of a quad).
	vec2 p = surface_plane(at, n);
	// a pixel's size on the face: the mean of its two ways (a face seen edge-on is fine across, coarse along)
	vec2 fw = fwidth(p);
	float pixel = sqrt(max(fw.x * fw.y, 1e-12));
	if (k == 1) {
		rough = 0.26;
		spec = 0.55;
	} else if (k == 2) {
		rough = 0.3;
		metal = 0.35;
		spec = 0.6;
	} else if (k == 3) {
		float fade = smoothstep(0.005, 0.016, pixel);
		vec3 woven = col * (1.0 + SURFACE_RING_AVERAGE);
		// far off the rings are under a pixel: their average alone, none of their work
		if (fade < 1.0) {
			vec3 near = col;
			vec4 a = surface_rings(p, 0.075, 3.0, pixel);
			near = mix(near, a.rgb, a.a);
			vec4 b = surface_rings(p + vec2(0.031, 0.047), 0.045, 11.0, pixel);
			near = mix(near, b.rgb, b.a * 0.85);
			woven = mix(near, woven, fade);
		}
		col = woven;
		rough = 0.95;
		spec = 0.25;
		worn = 0.2;
	} else if (k == 4) {
		float fade = smoothstep(0.003, 0.009, pixel);
		vec3 speckled = col * (1.0 + SURFACE_FLECK_AVERAGE);
		if (fade < 1.0) {
			float cell = 0.022;
			vec2 c = floor(p / cell);
			float h = surface_hash(c + 5.0);
			vec2 mid = (c + 0.25 + 0.5 * vec2(surface_hash(c + 9.1), surface_hash(c + 13.7))) * cell;
			float r = cell * mix(0.07, 0.15, surface_hash(c + 17.3));
			float fleck = (1.0 - smoothstep(r - pixel, r + pixel, length(p - mid))) * step(0.62, h);
			vec3 tone = h > 0.9 ? vec3(0.36, 0.36, 0.35) : vec3(0.12, 0.12, 0.13);
			speckled = mix(mix(col, tone, fleck), speckled, fade);
		}
		col = speckled;
		rough = 0.62;
		worn = 0.25;
	} else if (k == 5) {
		rough = 0.06;
		spec = 0.7;
	} else if (k == 6) {
		rough = 0.88;
		spec = 0.3;
	} else if (k == 7) {
		rough = 0.4;
		metal = 0.3;
		spec = 0.6;
	}
}
