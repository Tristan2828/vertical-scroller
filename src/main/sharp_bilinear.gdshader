// Sharp-bilinear upscaling for pixel art at fractional scales (e.g. 2.67x at 1440p).
// Each game pixel is drawn as a solid block; only the one-screen-pixel seam
// between neighbouring blocks is blended. So pixels look evenly sized without
// the blur of plain bilinear or the uneven 2/3-pixel columns of nearest.
// The node drawing with this must use linear texture filtering.
shader_type canvas_item;

// Screen pixels per game pixel.
uniform float scale = 1.0;

void fragment() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = UV * texture_size;
	vec2 texel_floor = floor(texel);
	vec2 inside = fract(texel) - 0.5;
	float flat_region = 0.5 - 0.5 / scale;
	vec2 blend = (inside - clamp(inside, -flat_region, flat_region)) * scale + 0.5;
	COLOR = texture(TEXTURE, (texel_floor + blend) / texture_size);
}
