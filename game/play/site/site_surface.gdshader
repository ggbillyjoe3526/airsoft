// The site dress's one surface (DD1, docs/ART.md › Material families): procedural canvases in world space, so blocks
// that meet continue one another, each block's finish and box from its vertices (SiteSurface): CUSTOM0 = the box's
// centre and its finish's slot, CUSTOM1 = its half size and flags. COLOR is the baked light (white without a bake),
// or a detail's own paint (FLAG_TINT). Noise comes from two small tiling textures, never per-pixel octaves.
shader_type spatial;
render_mode blend_mix, cull_back;

// the game's shared light (docs/ART.md › Light)
#include "res://game/play/look/look_light.gdshaderinc"

const int CONCRETE = 0;
const int BLOCK = 1;
const int CORRUGATED = 2;
const int PLYWOOD = 3;
const int OSB = 4;
const int GRAVEL = 5;
const int TREAD = 6;
const int GABION = 7;
const int FILM = 8;
const int PAINT = 9;
const int GROUND = 10;
const int FABRIC = 11;
const int RACK = 12;
const int IBC = 13;
const int PRECAST = 14;
const int TIMBER = 15;

const int FLAG_CHEVRON = 1;
const int FLAG_HAZARD = 2;
const int FLAG_PALETTE = 4;
const int FLAG_TINT = 8;
const int FLAG_NO_BEVEL = 16;
const int FINISHES = 40;
const int MARK_TUFT = 0;
const int MARK_CHIP = 1;
const int MARK_RUST_FOOT = 2;
const int MARK_CHEVRON = 3;
const int MARK_STRIPE = 4;
const int MARK_WIRE = 5;
const int MARK_CARTON = 6;
const int MARK_SLAT_GAP = 7;
const int MARK_SLAT = 8;
const int MARK_GOODS_OLIVE = 9;
const int MARK_GOODS_TAN = 10;
const int MARK_PALLET = 11;
const int MARK_GRASS = 12;
const int MARK_DIRT_FOOT = 13;
const int MARK_BAY_LINE = 14;
const int LINES = 16;

uniform int modes[40];
uniform vec3 paints[40];
uniform vec3 accents[40];
uniform vec2 bands[40];
uniform vec2 pbr[40];
uniform vec3 container_paint[8];
uniform vec3 marks[15];
// The slab's painted bay lines: centre (x, z) and half size (x, z); the dock's hazard lip, from and to below its top.
uniform vec4 lines[LINES];
uniform int line_count = 0;
uniform vec2 hazard_lip = vec2(0.04, 0.22);
uniform int container_count = 6;
uniform float container_unit = 6.1;
uniform float container_split = 7.0;
uniform float container_tier = 2.6;

uniform sampler2D fbm_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cells_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_tex : filter_linear, repeat_disable;
uniform vec4 wet_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform sampler2D slab_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D slab_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ply_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ply_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 slab_set = vec4(3.0, 0.9, 0.7, 0.5);
uniform vec4 ply_set = vec4(1.22, 0.7, 0.8, 0.5);
uniform float joint = 4.0;
uniform float edge_width = 0.02;
uniform float edge_light = 0.16;
// Low mesh detail: no photo relief, no corrugation or stones in relief, flat stones.
uniform bool low = false;
// How much wear and grain the canvases show (SiteLook.grit): 1 the old worn site, 0 the look's clean painted surfaces
// (joints, seams, panels and marks stay; stains, chips, rust, grime and photo grain go).
uniform float grit = 1.0;
// The look's soft vertical gradient: a side this much darker at the ground, full paint `gradient_height` m up.
uniform float gradient = 0.0;
uniform float gradient_height = 2.6;

varying vec3 wpos;
varying vec3 wnrm;
varying flat vec3 box_c;
varying flat vec3 box_h;
varying flat int fin;
varying flat int flags;
varying vec3 tint_in;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	box_c = CUSTOM0.xyz;
	box_h = CUSTOM1.xyz;
	fin = clamp(int(CUSTOM0.w + 0.5), 0, FINISHES - 1);
	flags = int(CUSTOM1.w + 0.5);
	tint_in = COLOR.rgb;
}

// Noise from the tiling textures: `fbm` one feature a unit, `cells` stones a unit (x: centre to edge, 0 to 1; y: the
// stone's own shade).
float fbm(vec2 p) {
	return texture(fbm_tex, p * 0.125).r;
}

vec2 cells(vec2 p) {
	return texture(cells_tex, p * 0.125).rg;
}

// A grain or wear factor `v` (1 = none) as the look's grit shows it.
float gr(float v) {
	return mix(1.0, v, grit);
}

// The face's world coordinates: (along, up) on a side, (x, z) on a top, and which axis runs along it.
vec2 face_coords(vec3 p, vec3 n, out vec3 along, out bool top) {
	vec3 a = abs(n);
	top = a.y > 0.7;
	if (top) {
		along = vec3(1.0, 0.0, 0.0);
		return p.xz;
	}
	if (a.x >= a.z) {
		along = vec3(0.0, 0.0, 1.0);
		return vec2(p.z * sign(n.x), p.y);
	}
	along = vec3(1.0, 0.0, 0.0);
	return vec2(-p.x * sign(n.z), p.y);
}

// A unit's paint on a long or stacked container: SiteLook.container_colour picks the same.
vec3 container_colour() {
	bool along_x = box_h.x >= box_h.z;
	float len_ = (along_x ? box_h.x : box_h.z) * 2.0;
	int units = len_ > container_split ? max(1, int(round(len_ / container_unit))) : 1;
	int tiers = max(1, int(round(box_h.y * 2.0 / container_tier)));
	float from = along_x ? wpos.x - box_c.x + box_h.x : wpos.z - box_c.z + box_h.z;
	int unit = clamp(int(from / (len_ / float(units))), 0, units - 1);
	int tier = clamp(int((wpos.y - box_c.y + box_h.y) / (box_h.y * 2.0 / float(tiers))), 0, tiers - 1);
	// the piece rides in the flags' high bits
	int i = ((flags >> 8) * 5 + unit * 3 + tier * 2) % max(container_count, 1);
	return container_paint[i];
}

vec3 photo_relief(sampler2D nrm, vec2 uv, vec3 n, vec3 along, bool top, float depth) {
	vec3 m = texture(nrm, uv).xyz * 2.0 - 1.0;
	vec3 up_axis = top ? vec3(0.0, 0.0, -1.0) : vec3(0.0, 1.0, 0.0);
	return normalize(n + (along * m.x + up_axis * m.y) * depth);
}

void fragment() {
	vec3 along;
	bool top;
	vec2 c = face_coords(wpos, wnrm, along, top);
	int mode = modes[fin];
	vec3 paint = (flags & FLAG_TINT) != 0 ? tint_in : paints[fin];
	if ((flags & FLAG_PALETTE) != 0) {
		paint = container_colour();
	}
	vec3 accent = accents[fin];
	vec2 band = bands[fin];
	vec3 n = wnrm;
	vec3 col = paint;
	float r = pbr[fin].x;
	float m = pbr[fin].y;
	float low_f = fbm(c * 0.18 + box_c.xz * 0.37);
	float h = wpos.y - (box_c.y - box_h.y);
	bool in_band = !top && h > band.x && h < band.y;

	if (mode == CONCRETE || mode == PRECAST) {
		float mid = grit > 0.0 ? fbm(c * 1.4) : 0.5;
		col = paint * gr((0.84 + 0.24 * low_f) * (0.94 + 0.1 * mid));
		float stain = grit > 0.0 ? smoothstep(0.58, 0.78, fbm(c * 0.35 + 7.0)) * grit : 0.0;
		col *= 1.0 - 0.16 * stain;
		r -= 0.08 * stain;
		if (mode == CONCRETE) {
			vec2 uv = c / slab_set.x;
			if (grit > 0.0) {
				float t = dot(texture(slab_col, uv).rgb, vec3(0.299, 0.587, 0.114));
				col *= mix(1.0, t / slab_set.w, slab_set.y * grit);
				if (!low) {
					n = photo_relief(slab_nrm, uv, n, along, top, slab_set.z);
				}
			}
			if (top && joint > 0.0 && (flags & FLAG_HAZARD) == 0) {
				vec2 g = abs(fract(c / joint + 0.5) - 0.5) * joint;
				float j = min(g.x, g.y);
				col *= mix(mix(0.82, 0.55, grit), 1.0, smoothstep(0.006, 0.018, j));
				float tuft = grit > 0.0 ? step(0.8, fbm(c * 3.1 + 4.0)) * (1.0 - smoothstep(0.0, 0.05, j)) * grit : 0.0;
				col = mix(col, marks[MARK_TUFT], tuft * 0.8);
			}
			if (top && line_count > 0 && (flags & FLAG_HAZARD) == 0) {
				float on = 0.0;
				for (int i = 0; i < line_count; i++) {
					vec2 d = abs(wpos.xz - lines[i].xy) - lines[i].zw;
					float e = max(d.x, d.y);
					on = max(on, 1.0 - smoothstep(-fwidth(e), fwidth(e), e));
				}
				if (on > 0.0) {
					float worn = grit > 0.0 ? smoothstep(0.55, 0.8, fbm(c * 2.3 + 11.0)) * grit : 0.0;
					col = mix(col, marks[MARK_BAY_LINE] * gr(0.88 + 0.16 * low_f), on * 0.92 * (1.0 - 0.4 * worn));
					r = mix(r, 0.6, on);
				}
			}
			float below = 2.0 * box_h.y - h;
			if ((flags & FLAG_HAZARD) != 0 && !top && below > hazard_lip.x && below < hazard_lip.y) {
				col = mix(marks[MARK_STRIPE], accent, step(0.5, fract((c.x + c.y) / 0.5))) * gr(0.9 + 0.15 * low_f);
				r = 0.55;
			}
			if (top && wet_rect.z > 0.0) {
				float wet = texture(wet_tex, (wpos.xz - wet_rect.xy) * wet_rect.zw).r;
				col *= mix(1.0, 0.5, wet);
				r = mix(r, 0.03, wet);
			}
		} else if (in_band) {
			col = accent * gr(0.9 + 0.15 * low_f);
			r = 0.6;
		}
	} else if (mode == BLOCK) {
		vec2 b = vec2(c.x / 0.45, c.y / 0.225);
		b.x += 0.5 * mod(floor(b.y), 2.0);
		vec2 fb = fract(b);
		float mm = min(min(fb.x, 1.0 - fb.x) * 0.45, min(fb.y, 1.0 - fb.y) * 0.225);
		float blk = fbm(floor(b) * 0.731);
		col = paint * gr((0.93 + 0.1 * blk) * (0.88 + 0.18 * low_f));
		col *= mix(mix(0.9, 0.8, grit), 1.0, smoothstep(0.003, 0.01, mm));
		if (grit > 0.0) {
			col *= 1.0 - 0.08 * grit * smoothstep(0.62, 0.9, fbm(vec2(c.x * 5.0, c.y * 0.25)));
		}
		if (top) {
			col = paint * 0.82 * gr(0.9 + 0.15 * fbm(c * 9.0));
		} else if (in_band) {
			col = accent * gr(0.92 + 0.1 * low_f);
		}
	} else if (mode == CORRUGATED) {
		float ph = fract(c.x / 0.28);
		float slope = smoothstep(0.08, 0.14, ph) * (1.0 - smoothstep(0.26, 0.32, ph))
				- smoothstep(0.58, 0.64, ph) * (1.0 - smoothstep(0.76, 0.82, ph));
		if (!low) {
			n = top ? normalize(wnrm + vec3(0.0, 0.0, 1.0) * (step(0.5, fract(c.y / 0.3)) - 0.5) * 0.25)
					: normalize(wnrm + along * slope * 0.75);
		} else {
			col *= 1.0 - 0.06 * slope * slope;
		}
		col *= gr(0.9 + 0.14 * low_f);
		if (grit > 0.0) {
			float chip = smoothstep(0.86, 0.9, fbm(c * 6.0 + 3.0)) * grit;
			col = mix(col, marks[MARK_CHIP], chip * 0.4);
			col *= 1.0 - 0.12 * grit * smoothstep(0.6, 0.85, fbm(vec2(c.x * 2.2, c.y * 0.2)));
		}
		col = mix(col, marks[MARK_RUST_FOOT], (1.0 - smoothstep(0.0, 0.7, wpos.y)) * 0.35 * grit);
		if ((flags & FLAG_CHEVRON) != 0 && !top) {
			// the site's white chevron, centred on each unit's side
			float len_ = max(box_h.x, box_h.z) * 2.0;
			bool long_face = (abs(wnrm.z) > 0.7) == (box_h.x >= box_h.z);
			if (long_face) {
				int units = len_ > container_split ? max(1, int(round(len_ / container_unit))) : 1;
				int tiers = max(1, int(round(box_h.y * 2.0 / container_tier)));
				float ul = len_ / float(units);
				float th = box_h.y * 2.0 / float(tiers);
				float a = dot(wpos - box_c, along) + len_ * 0.5;
				float y = wpos.y - (box_c.y - box_h.y);
				vec2 q = vec2(mod(a, ul) - ul * 0.5, mod(y, th) - th * 0.5) / 1.7;
				q.y += 0.06;
				float s = abs(q.y + 1.15 * abs(q.x) - 0.35);
				float mark = (1.0 - smoothstep(0.13, 0.15, s)) * (1.0 - smoothstep(0.62, 0.64, abs(q.x)));
				if (grit > 0.0) {
					mark *= gr(0.75 + 0.25 * step(0.35, fbm(q * 14.0)));
				}
				col = mix(col, marks[MARK_CHEVRON], mark);
			}
		}
		if ((flags & FLAG_HAZARD) != 0 && in_band) {
			col = mix(marks[MARK_STRIPE], accent, step(0.5, fract((c.x + c.y) / 0.4)));
			n = wnrm;
			r = 0.55;
			m = 0.0;
		}
	} else if (mode == PLYWOOD) {
		vec2 uv = c / ply_set.x;
		col = paint * gr(0.9 + 0.14 * low_f);
		if (grit > 0.0) {
			float t = dot(texture(ply_col, uv).rgb, vec3(0.299, 0.587, 0.114));
			col *= mix(1.0, t / ply_set.w, ply_set.y * grit);
			if (!low) {
				n = photo_relief(ply_nrm, uv, n, along, top, ply_set.z);
			}
		}
		if (!top) {
			vec2 sheet = vec2(1.22, 2.44);
			vec2 g = abs(fract(c / sheet + 0.5) - 0.5) * sheet;
			col *= mix(0.6, 1.0, smoothstep(0.003, 0.009, min(g.x, g.y)));
			vec2 sc = fract(c / 0.3 + 0.5) - 0.5;
			float screw = (1.0 - smoothstep(0.012, 0.02, length(vec2(g.x, sc.y * 0.3))))
					+ (1.0 - smoothstep(0.012, 0.02, length(vec2(sc.x * 0.3, g.y))));
			col *= 1.0 - 0.5 * clamp(screw, 0.0, 1.0);
		}
		col = mix(col, col * vec3(0.78, 0.76, 0.74), (1.0 - smoothstep(0.0, 0.5, h)) * 0.6 * grit);
	} else if (mode == OSB) {
		vec2 cl = cells(c * vec2(9.0, 4.0));
		float f = cl.x;
		float id = cl.y;
		col = paint * gr((0.88 + 0.18 * id) * (0.94 + 0.08 * low_f));
		col *= mix(1.0, mix(0.94, 0.88, grit), smoothstep(0.9, 1.0, f));
	} else if (mode == TIMBER) {
		float grain = fbm(vec2(c.x * 3.0, c.y * 40.0)) * 0.5 + fbm(c * vec2(1.5, 90.0)) * 0.5;
		col = paint * mix(0.95 + 0.06 * grain, 0.85 + 0.2 * grain, grit);
	} else if (mode == GRAVEL || mode == GABION) {
		float sc = mode == GRAVEL ? 18.0 : 16.0;
		vec2 cl = cells(c * sc);
		float f = cl.x;
		float id = cl.y;
		vec3 stone = mix(paint, accent, id) * (0.9 + 0.2 * fbm(c * 60.0));
		col = low ? stone : stone * mix(1.12, 0.88, f) * mix(1.0, 0.6, smoothstep(0.94, 1.0, f));
		r = 0.9;
		if (mode == GABION && !top) {
			vec2 g = abs(fract(c / 0.1 + 0.5) - 0.5) * 0.1;
			float wire = 1.0 - smoothstep(0.003, 0.006, min(g.x, g.y));
			col = mix(col, marks[MARK_WIRE], wire * 0.7);
			m = mix(0.0, 0.7, wire);
			r = mix(0.9, 0.4, wire);
		}
	} else if (mode == TREAD) {
		vec2 q = c * 12.0;
		vec2 cell = fract(q) - 0.5;
		float flip = mod(floor(q.x) + floor(q.y), 2.0);
		vec2 dd = flip > 0.5 ? vec2(cell.x + cell.y, cell.x - cell.y) : vec2(cell.x - cell.y, cell.x + cell.y);
		float bump = (1.0 - smoothstep(0.05, 0.09, abs(dd.x))) * (1.0 - smoothstep(0.25, 0.32, abs(dd.y)));
		col = paint * (0.85 + 0.2 * low_f) * (0.92 + 0.14 * bump);
		if (!low) {
			n = normalize(wnrm + vec3(dd.x, 0.0, dd.y) * bump * 0.4);
		}
		r = mix(r, 0.3, bump);
	} else if (mode == FILM) {
		// stretch-wrapped cartons on a pallet
		vec2 g = abs(fract(c / vec2(0.4, 0.3) + 0.5) - 0.5);
		vec3 carton = marks[MARK_CARTON] * mix(0.75, 1.0, smoothstep(0.0, 0.02, min(g.x, g.y)));
		float wrap = 0.5 + 0.5 * sin(c.y * 22.0 + fbm(c * 3.0) * 3.0);
		col = mix(carton, paint, 0.34 + 0.22 * wrap);
		r = 0.15 + 0.2 * wrap;
		if (!top && h < 0.14) {
			float slat = step(0.3, fract(c.x / 0.4));
			col = mix(marks[MARK_SLAT_GAP], marks[MARK_SLAT], slat * step(0.03, h) * step(h, 0.12));
			r = 0.85;
		}
	} else if (mode == RACK) {
		// pallet racking seen from outside: uprights at the ends, beams at each level, goods between
		float along_len = abs(dot(box_h, along)) * 2.0;
		float a = dot(wpos - box_c, along) + along_len * 0.5;
		float edge = min(a, along_len - a);
		float level = mod(h, 1.2);
		float slot = floor(a / 1.15) + floor(h / 1.2) * 3.0 + floor(box_c.x + box_c.z);
		vec3 goods = mod(slot, 3.0) < 1.0 ? marks[MARK_GOODS_OLIVE] : marks[MARK_GOODS_TAN];
		vec2 cg = abs(fract(c / vec2(0.4, 0.32) + 0.5) - 0.5);
		goods *= mix(0.72, 1.0, smoothstep(0.0, 0.03, min(cg.x, cg.y)));
		col = goods * (0.92 + 0.1 * low_f);
		r = 0.85;
		m = 0.0;
		if (level < 0.12 || h > box_h.y * 2.0 - 0.1) {
			col = accent;
			r = 0.45;
			m = 0.4;
		}
		if (edge < 0.09 || top) {
			col = paint;
			r = 0.45;
			m = 0.5;
		}
	} else if (mode == IBC) {
		// a white tank in a galvanised cage on a dark pallet
		float along_len = abs(dot(box_h, along)) * 2.0;
		float a = dot(wpos - box_c, along) + along_len * 0.5;
		float bar = 1.0 - smoothstep(0.012, 0.02, abs(fract(a / (along_len / 3.0) + 0.5) - 0.5) * (along_len / 3.0));
		float hoop = 1.0 - smoothstep(0.012, 0.02, abs(h - 0.5)) + 1.0 - smoothstep(0.012, 0.02, abs(h - box_h.y * 2.0 + 0.03));
		col = paint * (0.92 + 0.08 * low_f);
		float cage = clamp(bar + hoop, 0.0, 1.0);
		col = mix(col, accent, cage);
		m = mix(0.0, 0.8, cage);
		if (h < 0.14) {
			col = marks[MARK_PALLET];
		}
	} else if (mode == PAINT || mode == GROUND || mode == FABRIC) {
		if (mode == GROUND) {
			float patchy = fbm(c * 0.05);
			col = mix(paint, marks[MARK_GRASS], smoothstep(0.3, 0.8, patchy) * 0.5);
			col *= 0.93 + 0.1 * cells(c * 9.0).y;
			col *= 0.94 + 0.1 * fbm(c * 0.6);
		} else if (mode == FABRIC) {
			col = paint * gr((0.86 + 0.14 * fbm(c * 90.0)) * (0.88 + 0.2 * low_f));
		} else {
			col = paint * gr(0.9 + 0.14 * low_f);
			float chip = grit > 0.0 ? smoothstep(0.86, 0.9, fbm(c * 7.0 + 5.0)) * grit : 0.0;
			col = mix(col, paint * 0.6 + vec3(0.18), chip * 0.5);
			col = mix(col, marks[MARK_DIRT_FOOT], (1.0 - smoothstep(0.0, 0.45, h)) * 0.3 * grit);
			if (in_band) {
				col = (flags & FLAG_HAZARD) != 0 ? mix(marks[MARK_STRIPE], accent, step(0.5, fract((c.x + c.y) / 0.4))) : accent;
			}
		}
	}

	// the "CS edge highlight" on every box's bevels (docs/ART.md › Edges and wear)
	if ((flags & FLAG_NO_BEVEL) == 0) {
		vec3 d = box_h - abs(wpos - box_c);
		vec3 an = abs(wnrm);
		float e = an.x > 0.7 ? min(d.y, d.z) : (an.y > 0.7 ? min(d.x, d.z) : min(d.x, d.y));
		col *= 1.0 + edge_light * (1.0 - smoothstep(edge_width * 0.2, edge_width, e));
	}
	// a soft darkening at a side's foot, where the bake doesn't reach, and the look's smooth vertical gradient
	if (!top && mode != GROUND) {
		col *= mix(mix(0.88, 0.7, grit), 1.0, smoothstep(0.0, 0.35, wpos.y));
		col *= mix(1.0 - gradient, 1.0, clamp(h / gradient_height, 0.0, 1.0));
	}

	ALBEDO = col * ((flags & FLAG_TINT) != 0 ? vec3(1.0) : tint_in);
	ROUGHNESS = r;
	METALLIC = m;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
