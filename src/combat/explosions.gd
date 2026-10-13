class_name Explosions
extends RefCounted
## Gray-box explosion drawing shared by air and ground enemies: an orange ring
## that grows and fades around a shrinking bright core. A few fixed frames, so
## the baked textures stay cached.

const FRAMES: float = 6.0
const RING_COLOR: Color = Color(1.0, 0.55, 0.15)
const CORE_COLOR: Color = Color(1.0, 0.95, 0.7)


## `t` = 0..1 through the explosion; `size` scales it (1 = a small air enemy).
static func draw(canvas: CanvasItem, center: Vector2, t: float, size: float) -> void:
	var step := floorf(clampf(t, 0.0, 0.999) * FRAMES) / FRAMES
	var fade := 1.0 - step
	var outer := PixelArt.disc_texture(roundf((4.0 + 10.0 * step) * size), Color(RING_COLOR, fade),
		roundf(8.0 * step * size), Color(0, 0, 0, 0))
	var core := PixelArt.disc_texture(roundf(6.0 * fade * size) + 1.0, Color(CORE_COLOR, fade))
	canvas.draw_texture(outer, (center - Vector2(outer.get_size()) / 2.0).round())
	canvas.draw_texture(core, (center - Vector2(core.get_size()) / 2.0).round())
