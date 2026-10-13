class_name ScreenFit
extends RefCounted
## Where the 960x540 game picture goes in the window, and how big (DESIGN.md §2).
##   SHARP:         as big as fits (2.67x at 1440p); Main smooths the uneven
##                  pixel edges with the sharp-bilinear shader.
##   PIXEL_PERFECT: the biggest whole multiple that fits (2x at 1440p), with
##                  black borders around it. Falls back to SHARP's size when the
##                  window is smaller than the game.

enum Mode { SHARP, PIXEL_PERFECT }

const BASE: Vector2i = Vector2i(960, 540)


## The picture's rectangle in window pixels (position = top-left corner).
static func fit(window: Vector2i, mode: Mode) -> Rect2:
	var scale := minf(float(window.x) / BASE.x, float(window.y) / BASE.y)
	if mode == Mode.PIXEL_PERFECT and scale >= 1.0:
		scale = floorf(scale)
	var size := Vector2(BASE) * scale
	return Rect2(((Vector2(window) - size) / 2.0).floor(), size)


## True when the picture is scaled by a whole number (no smoothing needed).
static func is_whole(scale: float) -> bool:
	return absf(scale - roundf(scale)) < 0.001
