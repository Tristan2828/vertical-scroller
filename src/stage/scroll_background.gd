class_name ScrollBackground
extends Node2D
## Placeholder ground: a tiled test pattern that scrolls down as the ship flies
## up. The stage sets `scroll` from stage time, so every peer sees the ground in
## the same place. Real stage art (tilesets, structures, parallax) replaces it.

const TILE: int = 128
## Kept dark and low-contrast so ground targets and bullets stand out.
const GROUND: Color = Color(0.12, 0.135, 0.13)
const GROUND_DARK: Color = Color(0.105, 0.12, 0.115)
const LINE: Color = Color(0.15, 0.165, 0.16)
const PLATE: Color = Color(0.135, 0.15, 0.145)
const RIVET: Color = Color(0.19, 0.21, 0.2)

## Pixels scrolled so far (stage time x scroll speed).
var scroll: float = 0.0:
	set(value):
		scroll = value
		queue_redraw()

static var _tile: ImageTexture = null


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _draw() -> void:
	var offset := fposmod(floorf(scroll), TILE)
	var size := Vector2(ScreenFit.BASE) + Vector2(0, TILE)
	draw_texture_rect(_tile_texture(), Rect2(Vector2(0, offset - TILE), size), true)


static func _tile_texture() -> ImageTexture:
	if _tile != null:
		return _tile
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	image.fill(GROUND)
	# Darker half-tiles in a checker, so the motion is easy to follow.
	image.fill_rect(Rect2i(0, 0, TILE / 2, TILE / 2), GROUND_DARK)
	image.fill_rect(Rect2i(TILE / 2, TILE / 2, TILE / 2, TILE / 2), GROUND_DARK)
	# A raised plate with rivets in one corner.
	image.fill_rect(Rect2i(72, 8, 48, 40), PLATE)
	for corner: Vector2i in [Vector2i(75, 11), Vector2i(116, 11), Vector2i(75, 44), Vector2i(116, 44)]:
		image.set_pixelv(corner, RIVET)
	# Grid lines.
	for i: int in TILE:
		image.set_pixel(i, 0, LINE)
		image.set_pixel(0, i, LINE)
		image.set_pixel(i, TILE / 2, LINE)
		image.set_pixel(TILE / 2, i, LINE)
	_tile = ImageTexture.create_from_image(image)
	return _tile
