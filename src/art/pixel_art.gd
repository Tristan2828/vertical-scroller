class_name PixelArt
extends RefCounted
## Every sprite as text rows (one character per pixel, shared PALETTE), built into
## cached textures. Copied from Medieval Survival and trimmed: these are
## placeholder sprites until the asset packs arrive (M6). Edit sprites directly
## here; keep rows equal length. "P"/"p" pixels are recolored per player.

const PALETTE: Dictionary[String, Color] = {
	".": Color(0, 0, 0, 0),
	"k": Color(0.06, 0.07, 0.11),
	"w": Color(0.95, 0.96, 1.0),
	"l": Color(0.62, 0.66, 0.74),
	"L": Color(0.38, 0.41, 0.5),
	"t": Color(0.4, 0.85, 1.0),
	"T": Color(0.18, 0.5, 0.72),
	"o": Color(0.95, 0.55, 0.17),
	"y": Color(1.0, 0.86, 0.4),
	"e": Color(1.0, 0.95, 0.75),
	"r": Color(0.86, 0.27, 0.27),
	"R": Color(0.52, 0.14, 0.2),
	"g": Color(0.45, 0.85, 0.5),
	"G": Color(0.22, 0.55, 0.28),
	"m": Color(1.0, 0.3, 0.55),
	"O": Color(0.6, 0.27, 0.1),
	"M": Color(0.59, 0.16, 0.35),
}

const SPRITES: Dictionary[String, Array] = {
	# The first ship (placeholder), nose up. 23x22.
	"ship": [
		"...........k...........",
		"..........kwk..........",
		"..........ktk..........",
		".........ktttk.........",
		".........kTtTk.........",
		"........kkTtTkk........",
		"........kPktkPk........",
		"........kPlklPk........",
		".......kPPlllPPk.......",
		"......kkPlllllPkk......",
		".....kLkPlllllPkLk.....",
		"....kLLkPPlllPPkLLk....",
		"...kLLlkPPPlPPPklLLk...",
		"..kLLllkPPPPPPPkllLLk..",
		".kLLlllkPpPPPpPklllLLk.",
		"kLLlllPkPppPppPkPlllLLk",
		"kLlllPPkppPPPppkPPlllLk",
		"kLllPPkkkppPppkkkPPllLk",
		"kLlPPk..kpkkkpk..kPPlLk",
		".kkkk...kok.kok...kkkk.",
		"........kyk.kyk........",
		".........k...k.........",
	],
	# Engine flicker frame.
	"ship_1": [
		"...........k...........",
		"..........kwk..........",
		"..........ktk..........",
		".........ktttk.........",
		".........kTtTk.........",
		"........kkTtTkk........",
		"........kPktkPk........",
		"........kPlklPk........",
		".......kPPlllPPk.......",
		"......kkPlllllPkk......",
		".....kLkPlllllPkLk.....",
		"....kLLkPPlllPPkLLk....",
		"...kLLlkPPPlPPPklLLk...",
		"..kLLllkPPPPPPPkllLLk..",
		".kLLlllkPpPPPpPklllLLk.",
		"kLLlllPkPppPppPkPlllLLk",
		"kLlllPPkppPPPppkPPlllLk",
		"kLllPPkkkppPppkkkPPllLk",
		"kLlPPk..kpkkkpk..kPPlLk",
		".kkkk...kyk.kyk...kkkk.",
		"........kek.kek........",
		".........y...y.........",
	],
	# A small enemy drone (placeholder), facing down. 15x11.
	"drone": [
		"..kkk.....kkk..",
		".kRrrk...krrRk.",
		"kRrrrrkkkrrrrRk",
		"kRrrRRrrrRRrrRk",
		".kRRkkkrkkkRRk.",
		"..kkkeekeekkk..",
		"...kRkekekRk...",
		"...kRRkkkRRk...",
		"..kRrk...krRk..",
		"..kRk.....kRk..",
		"...k.......k...",
	],
	# Fighter: a tougher drone that shoots aimed fans. 17x14.
	"fighter": [
		"k...............k",
		"kk.............kk",
		"kRk...........kRk",
		"kRRk..kkkkk..kRRk",
		"kRrRkkRRRRRkkRrRk",
		"kRrrRRrrrrrRRrrRk",
		".kRrrrrrrrrrrrRk.",
		"..kRrrrrrrrrrRk..",
		"...kRrrrkrrrRk...",
		"....kRrkekrRk....",
		".....kRkekRk.....",
		"......kRkRk......",
		".......kRk.......",
		"........k........",
	],
	# Gunship: armored, hovers and tracks a player. 23x14.
	"gunship": [
		"kkk.................kkk",
		"kRRk.....kkkkk.....kRRk",
		"kRrRk...kLLLLLk...kRrRk",
		"kRrrRkkkLlllllLkkkRrrRk",
		"kRrrrRLLlllllllLLRrrrRk",
		".kRrrRLlllLLLlllLRrrRk.",
		"..kRRLlllLRRRLlllLRRk..",
		"...kkLllLRrrrRLllLkk...",
		"....kLllLRrkrRLllLk....",
		"....kLllLRkekRLllLk....",
		"....kLllLRkekRLllLk....",
		".....kLlLRrkrRLlLk.....",
		"......kLLRRRRRLLk......",
		".......kkkkkkkkk.......",
	],
	# Kamikaze: locks onto a player and rams them. 11x12.
	"kamikaze": [
		"k.........k",
		"kk...k...kk",
		"kok.kok.kok",
		".koyoyoyok.",
		".kooyyyook.",
		"..kooyook..",
		"..koyyyok..",
		"...koyok...",
		"...koeok...",
		"....kok....",
		"....kyk....",
		".....k.....",
	],
	# More ships (placeholders), each with an engine flicker frame: Lancer 21x20,
	# Hornet 19x13, Vulcan 21x16, Wave 25x13.
	"ship_lancer": [
		"..........k..........",
		"..........w..........",
		".........ktk.........",
		".........ktk.........",
		".........kTk.........",
		"........kPlPk........",
		"........kPlPk........",
		"........kPlPk........",
		".......kPPlPPk.......",
		".......kPLlLPk.......",
		"......kLPLlLPLk......",
		".....kLLPLlLPLLk.....",
		"....kLLkPPlPPkLLk....",
		"...kLLkkPpPpPkkLLk...",
		"..kLLk.kPpPpPk.kLLk..",
		".kLLk..kppPppk..kLLk.",
		"kLLk...kpkkkpk...kLLk",
		"kkk....kok.kok....kkk",
		".......kyk.kyk.......",
		"........k...k........",
	],
	"ship_lancer_1": [
		"..........k..........",
		"..........w..........",
		".........ktk.........",
		".........ktk.........",
		".........kTk.........",
		"........kPlPk........",
		"........kPlPk........",
		"........kPlPk........",
		".......kPPlPPk.......",
		".......kPLlLPk.......",
		"......kLPLlLPLk......",
		".....kLLPLlLPLLk.....",
		"....kLLkPPlPPkLLk....",
		"...kLLkkPpPpPkkLLk...",
		"..kLLk.kPpPpPk.kLLk..",
		".kLLk..kppPppk..kLLk.",
		"kLLk...kpkkkpk...kLLk",
		"kkk....kyk.kyk....kkk",
		".......kek.kek.......",
		"........k...k........",
	],
	"ship_hornet": [
		".........k.........",
		"........ktk........",
		"........ktk........",
		".......kPTPk.......",
		"..k....kPlPk....k..",
		".kLk..kPPlPPk..kLk.",
		".kLk.kPPlllPPk.kLk.",
		".kLkkPPpPlPpPPkkLk.",
		"kLLLkPpppPpppPkLLLk",
		"kLyLkPpkpPpkpPkLyLk",
		"kkokkPk.kPk.kPkkokk",
		".kyk.kk..k..kk.kyk.",
		"..k.............k..",
	],
	"ship_hornet_1": [
		".........k.........",
		"........ktk........",
		"........ktk........",
		".......kPTPk.......",
		"..k....kPlPk....k..",
		".kLk..kPPlPPk..kLk.",
		".kLk.kPPlllPPk.kLk.",
		".kLkkPPpPlPpPPkkLk.",
		"kLLLkPpppPpppPkLLLk",
		"kLeLkPpkpPpkpPkLeLk",
		"kkykkPk.kPk.kPkkykk",
		".kek.kk..k..kk.kek.",
		"..k.............k..",
	],
	"ship_vulcan": [
		"....k...........k....",
		"...klk.........klk...",
		"...klk.........klk...",
		"...klk...k.k...klk...",
		"...kLk..kt.tk..kLk...",
		"..kLLLk.kt.tk.kLLLk..",
		"..kLLLkkPT.TPkkLLLk..",
		".kLLLLkPPlllPPkLLLLk.",
		".kLLLkPPPlllPPPkLLLk.",
		".kLLkPPpPPlPPpPPkLLk.",
		"kLLLkPpppPPPpppPkLLLk",
		"kLLkkPpkppPppkpPkkLLk",
		"kkk.kPk.kpkpk.kPk.kkk",
		"....kok..kok..kok....",
		"....kyk..kyk..kyk....",
		".....k....k....k.....",
	],
	"ship_vulcan_1": [
		"....k...........k....",
		"...klk.........klk...",
		"...klk.........klk...",
		"...klk...k.k...klk...",
		"...kLk..kt.tk..kLk...",
		"..kLLLk.kt.tk.kLLLk..",
		"..kLLLkkPT.TPkkLLLk..",
		".kLLLLkPPlllPPkLLLLk.",
		".kLLLkPPPlllPPPkLLLk.",
		".kLLkPPpPPlPPpPPkLLk.",
		"kLLLkPpppPPPpppPkLLLk",
		"kLLkkPpkppPppkpPkkLLk",
		"kkk.kPk.kpkpk.kPk.kkk",
		"....kyk..kyk..kyk....",
		"....kek..kek..kek....",
		".....k....k....k.....",
	],
	"ship_wave": [
		"............k............",
		"...........ktk...........",
		"..........ktTtk..........",
		"kk........kPlPk........kk",
		"kLkk.....kPPlPPk.....kkLk",
		".kLLkk..kPPPlPPPk..kkLLk.",
		"..kLLLkkPPpPlPpPPkkLLLk..",
		"...kLLLLPpppPpppPLLLLk...",
		"....kkLLPpkpPpkpPLLkk....",
		"......kkkPk.k.kPkkk......",
		"........kok...kok........",
		"........kyk...kyk........",
		".........k.....k.........",
	],
	"ship_wave_1": [
		"............k............",
		"...........ktk...........",
		"..........ktTtk..........",
		"kk........kPlPk........kk",
		"kLkk.....kPPlPPk.....kkLk",
		".kLLkk..kPPPlPPPk..kkLLk.",
		"..kLLLkkPPpPlPpPPkkLLLk..",
		"...kLLLLPpppPpppPLLLLk...",
		"....kkLLPpkpPpkpPLLkk....",
		"......kkkPk.k.kPkkk......",
		"........kyk...kyk........",
		"........kek...kek........",
		".........k.....k.........",
	],
	# Pickups (Pickups.SPRITES): Scrap is a small gem (7x7); power-ups are
	# bigger round badges (13x13) so they stand out (playtest 1).
	"pickup_scrap": [
		"...k...",
		"..kyk..",
		".kyoyk.",
		"kyoeoyk",
		".kyoyk.",
		"..kyk..",
		"...k...",
	],
	# 9x9
	"pickup_orb": [
		"....kkkkk....",
		"..kkTTTTTkk..",
		".kkTtttttTkk.",
		".kTtttwtttTk.",
		"kTtttwwwtttTk",
		"kTttwwwwwttTk",
		"kTttttwttttTk",
		"kTttttwttttTk",
		"kTttttwttttTk",
		".kTTTTwTTTTk.",
		".kkTTTTTTTkk.",
		"..kkTTTTTkk..",
		"....kkkkk....",
	],
	# 9x8
	"pickup_rapid": [
		"....kkkkk....",
		"..kkOOOOOkk..",
		".kkOoooooOkk.",
		".kOooowoooOk.",
		"kOooowowoooOk",
		"kOoowooowooOk",
		"kOoooowooooOk",
		"kOooowowoooOk",
		"kOoowooowooOk",
		".kOOOOOOOOOk.",
		".kkOOOOOOOkk.",
		"..kkOOOOOkk..",
		"....kkkkk....",
	],
	# 9x8
	"pickup_wingmen": [
		"....kkkkk....",
		"..kkGGGGGkk..",
		".kkGgggggGkk.",
		".kGgggwgggGk.",
		"kGggggwggggGk",
		"kGgggggggggGk",
		"kGgggggggggGk",
		"kGgwgggggwgGk",
		"kGgwggwggwgGk",
		".kGGGGwGGGGk.",
		".kkGGGGGGGkk.",
		"..kkGGGGGkk..",
		"....kkkkk....",
	],
	# 9x8
	"pickup_charge": [
		"....kkkkk....",
		"..kkMMMMMkk..",
		".kkMmmmmmMkk.",
		".kMmmmwmmmMk.",
		"kMmmmmwmmmmMk",
		"kMmmmmwmmmmMk",
		"kMmwwwwwwwmMk",
		"kMmmmmwmmmmMk",
		"kMmmmmwmmmmMk",
		".kMMMMwMMMMk.",
		".kkMMMMMMMkk.",
		"..kkMMMMMkk..",
		"....kkkkk....",
	],
	# Wingmen boost: a side drone. 5x7
	"wingman": [
		"..k..",
		"..k..",
		".ktk.",
		"kLlLk",
		"kLlLk",
		".kLk.",
		"..k..",
	],
	# Stage 1 boss: a heavy command gunship (placeholder). 65x38
	"base_boss": [
		".....................koyyok...........koyyok.....................",
		"................kkkkkkoyyokkkkkkkkkkkkkoyyokkkkkk................",
		"...............kLLLLLLooooLLLLLLLLLLLLLooooLLLLLLk...............",
		"...............kLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLk...............",
		"...............kLLLlllllllllllllllllllllllllllLLLk...............",
		"...............kLLLlllllllllllllllllllllllllllLLLk...............",
		"...............kLLLlllllllllllllllllllllllllllLLLk...............",
		"......kkkkkkkkkkLLLlllllllllllllllllllllllllllLLLkkkkkkkkkk......",
		".....kLLLLLLLLLLLLLlllllllllllllllllllllllllllLLLLLLLLLLLLLk.....",
		".....kLLLLLLLLLLLLLlllllllllllllllllllllllllllLLLLLLLLLLLLLk.....",
		".....kLLlllllllllllllllllllllllllllllllllllllllllllllllllLLk.....",
		".....kLLlllllllllllllllllllllllllllllllllllllllllllllllllLLk.....",
		".....kLLllrrrrrrrrlllllllllllllllllllllllllllllrrrrrrrrllLLk.....",
		".kkkkkLLllrrrrrrrrlllllllllllllllllllllllllllllrrrrrrrrllLLkkkkk.",
		"kRRRRRRRlllllllllllllllllllRRRRRRRRRRRlllllllllllllllllllRRRRRRRk",
		"kRrrrrrRlllllllllllllllllllRRRRRRRRRRRlllllllllllllllllllRrrrrrRk",
		"kRrrrrrRlllllllllllllllllllRRmmmmmmmRRlllllllllllllllllllRrrrrrRk",
		"kRrrrrrRlllllllllllllllllllRRmmeeemmRRlllllllllllllllllllRrrrrrRk",
		"kRrrrrrRlllllllllllllllllllRRmmeeemmRRlllllllllllllllllllRrrrrrRk",
		"kRrrrrrRllrrrrrrrrlllllllllRRmmeeemmRRlllllllllrrrrrrrrllRrrrrrRk",
		"kRrrrrrRllrrrrrrrrlllllllllRRmmmmmmmRRlllllllllrrrrrrrrllRrrrrrRk",
		"kRrrrrrRlllllllllllllllllllRRRRRRRRRRRlllllllllllllllllllRrrrrrRk",
		"kRrrrrrRlllllllllllllllllllRRRRRRRRRRRlllllllllllllllllllRrrrrrRk",
		"kRrrrrrRLLLLLLLLLLLlllllllllllllllllllllllllllLLLLLLLLLLLRrrrrrRk",
		"kRrrrrrRLLLLLLLLLLLlllllllllllllllllllllllllllLLLLLLLLLLLRrrrrrRk",
		"kRrrrrrRkkkkLlLkLLLlllllllllllllllllllllllllllLLLkLlLkkkkRrrrrrRk",
		"kRrrrrrRk..kLlLkLLLlllllllllllllllllllllllllllLLLkLlLk..kRrrrrrRk",
		"kRrrrrrRk..kLlLkLLLlllllllllllllllllllllllllllLLLkLlLk..kRrrrrrRk",
		"kRRLLLRRk..kLlLkLLLlllllllllllllllllllllllllllLLLkLlLk..kRRLLLRRk",
		".kkLLLkk...kLlLkLLLlllllllllllllllllllllllllllLLLkLlLk...kkLLLkk.",
		"..kLLLk....kLlLkLLLlllllllllllllllllllllllllllLLLkLlLk....kLLLk..",
		"..kLLLk.....klkkLLLlllllllllllLLLLLlllllllllllLLLkklk.....kLLLk..",
		"..kLLLk......k.kLLLLLLLLLLLLLLLlllLLLLLLLLLLLLLLLk.k......kLLLk..",
		"..kLLLk........kLLLLLLLLLLLLLLLlllLLLLLLLLLLLLLLLk........kLLLk..",
		"...kkk..........kkkkkkkkkkkkkkLlllLkkkkkkkkkkkkkk..........kkk...",
		".............................kLlllLk.............................",
		".............................kLlllLk.............................",
		"..............................kkkkk..............................",
	],
}

const TINT_CHAR: String = "P"
const TINT_SHADE_CHAR: String = "p"

static var _cache: Dictionary[String, ImageTexture] = {}
static var _disc_cache: Dictionary[String, ImageTexture] = {}


static func has_sprite(sprite: String) -> bool:
	return SPRITES.has(sprite)


static func size_of(sprite: String) -> Vector2i:
	var rows: Array = SPRITES[sprite]
	return Vector2i(String(rows[0]).length(), rows.size())


## The sprite as a texture. `tint` recolors the P/p pixels; `flash` makes every
## visible pixel white (hit flash).
static func texture(sprite: String, tint: Color = Color.WHITE, flash: bool = false) -> ImageTexture:
	var key := "%s|%s|%s" % [sprite, tint.to_html(), flash]
	if _cache.has(key):
		return _cache[key]
	var rows: Array = SPRITES[sprite]
	var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	var shade := tint.darkened(0.35)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			var ch := row[x]
			var color: Color
			if ch == TINT_CHAR:
				color = tint
			elif ch == TINT_SHADE_CHAR:
				color = shade
			else:
				color = PALETTE.get(ch, Color(0, 0, 0, 0))
			if flash and color.a > 0.0:
				color = Color.WHITE
			image.set_pixel(x, y, color)
	var built := ImageTexture.create_from_image(image)
	_cache[key] = built
	return built


## A filled circle (with an optional inner circle on top) baked into a small
## texture: pixels whose centers are within the radius, like draw_circle. Many
## copies of one texture draw in a single batch, far cheaper than draw_circle
## (which builds a polygon and its own draw call every time). Cached.
static func disc_texture(radius: float, color: Color, inner_radius: float = 0.0, inner_color: Color = Color.WHITE) -> ImageTexture:
	var key := "%s|%s|%s|%s" % [radius, color.to_html(), inner_radius, inner_color.to_html()]
	if _disc_cache.has(key):
		return _disc_cache[key]
	var side := ceili(radius) * 2 + 1
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var middle := side / 2.0
	for y: int in side:
		for x: int in side:
			var distance := Vector2(x + 0.5 - middle, y + 0.5 - middle).length()
			if distance <= inner_radius:
				image.set_pixel(x, y, inner_color)
			elif distance <= radius:
				image.set_pixel(x, y, color)
	var built := ImageTexture.create_from_image(image)
	_disc_cache[key] = built
	return built


## A vertical bolt: a `size` rectangle of `color` with a 1px-narrower `core_color`
## middle. Cached with the discs.
static func bolt_texture(size: Vector2i, color: Color, core_color: Color) -> ImageTexture:
	var key := "bolt|%s|%s|%s" % [size, color.to_html(), core_color.to_html()]
	if _disc_cache.has(key):
		return _disc_cache[key]
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	if size.x > 2 and size.y > 2:
		image.fill_rect(Rect2i(1, 1, size.x - 2, size.y - 2), core_color)
	var built := ImageTexture.create_from_image(image)
	_disc_cache[key] = built
	return built


## The part of the world this canvas item's viewport shows right now (for
## skipping off-screen drawing), grown by `margin`.
static func visible_rect(canvas: CanvasItem, margin: float = 16.0) -> Rect2:
	var viewport := canvas.get_viewport()
	if viewport == null:
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	var to_world := (canvas.get_global_transform_with_canvas().affine_inverse())
	return (to_world * viewport.get_visible_rect()).grow(margin)


## Draws a sprite centered on `center` from a CanvasItem's _draw().
static func draw(canvas: CanvasItem, sprite: String, center: Vector2, tint: Color = Color.WHITE,
		flash: bool = false, flip: bool = false, scale: float = 1.0, modulate: Color = Color.WHITE) -> void:
	var tex := texture(sprite, tint, flash)
	var size := Vector2(tex.get_size()) * scale
	draw_rect_flipped(canvas, tex, Rect2((center - size / 2.0).round(), size), flip, modulate)


## Draws `tex` filling `rect`, mirrored left/right around the rect's center when
## `flip` is set. (A negative rect width does NOT mirror in Godot: it just
## shifts the image, so we mirror with a temporary transform instead.)
static func draw_rect_flipped(canvas: CanvasItem, tex: Texture2D, rect: Rect2, flip: bool, modulate: Color = Color.WHITE) -> void:
	if not flip:
		canvas.draw_texture_rect(tex, rect, false, modulate)
		return
	var mirror_x := rect.position.x * 2.0 + rect.size.x
	canvas.draw_set_transform(Vector2(mirror_x, 0.0), 0.0, Vector2(-1.0, 1.0))
	canvas.draw_texture_rect(tex, rect, false, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
