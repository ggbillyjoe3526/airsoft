shader_type canvas_item;
// Retro filter (RetroFilter): the screen in square blocks of pixel_size, each block's colour cut to `levels` shades a
// channel (32: 15-bit colour) after the 1990s console's own 4x4 dither, -4 to +3 eighths of a 32-shade step, on the
// block grid, so it reads as fine stipple in gradients rather than bands.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float pixel_size = 4.0;
uniform float levels = 32.0;

const float DITHER[16] = float[16](-4.0, 0.0, -3.0, 1.0, 2.0, -2.0, 3.0, -1.0, -3.0, 1.0, -4.0, 0.0, 3.0, -1.0, 2.0,
		-2.0);

void fragment() {
	vec2 block = SCREEN_PIXEL_SIZE * pixel_size;
	vec2 cell = floor(SCREEN_UV / block);
	vec3 c = textureLod(screen, (cell + 0.5) * block, 0.0).rgb;
	ivec2 b = ivec2(mod(cell, 4.0));
	float top = levels - 1.0;
	// The dither in steps of the shades kept (the console's eighths of its 32), rounded to the nearest shade.
	float dither = DITHER[b.y * 4 + b.x] / 8.0;
	COLOR = vec4(clamp(floor(c * top + 0.5 + dither) / top, 0.0, 1.0), 1.0);
}
