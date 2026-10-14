class_name BossArt
extends RefCounted
## Pixel art for boss cores and parts, built pixel by pixel into textures the
## first time they're needed (playtest 3: same boss, better look). Placeholder
## until the art pass, but real pixel art: shaded steel plating, seams, rivets,
## trim and lights, with a dark outline. BossDraw puts it on screen and adds the
## moving bits (turret barrels, lights, doors, the core's eye, smoke).

const OUTLINE: Color = Color(0.05, 0.06, 0.08)
const STEEL: Color = Color(0.36, 0.4, 0.47)
const STEEL_LIGHT: Color = Color(0.53, 0.58, 0.66)
const STEEL_DARK: Color = Color(0.24, 0.27, 0.32)
const SEAM: Color = Color(0.17, 0.19, 0.23)
const RIVET: Color = Color(0.68, 0.72, 0.78)
const TRIM: Color = Color(0.68, 0.18, 0.24)
const TRIM_DARK: Color = Color(0.42, 0.1, 0.15)
const WINDOW: Color = Color(0.4, 0.85, 1.0)
const HAZARD: Color = Color(0.95, 0.75, 0.25)

static var _cache: Dictionary[String, ImageTexture] = {}


## The texture for a boss core or part (by its EnemyType key), or null.
static func texture(key: String, size: Vector2) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var image: Image = null
	match key:
		"fortress_core":
			image = _hull(Vector2i(size))
		"wing_cannon":
			image = _block(Vector2i(size), true, false)
		"missile_pod":
			image = _block(Vector2i(size), false, true)
		"hangar":
			image = _block(Vector2i(size), false, false)
	if image == null:
		return null
	_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## The Fortress Gunship's hull: wide at the top, tapering under the core.
static func _hull(size: Vector2i) -> Image:
	var w := float(size.x)
	var h := float(size.y)
	var shape := PackedVector2Array([
		Vector2(14, h * 0.18), Vector2(w * 0.3, h * 0.08), Vector2(w * 0.4, 0), Vector2(w * 0.6, 0),
		Vector2(w * 0.7, h * 0.08), Vector2(w - 14, h * 0.18), Vector2(w - 2, h * 0.45), Vector2(w - 30, h * 0.66),
		Vector2(w * 0.66, h * 0.8), Vector2(w * 0.58, h - 1), Vector2(w * 0.42, h - 1), Vector2(w * 0.34, h * 0.8),
		Vector2(30, h * 0.66), Vector2(2, h * 0.45),
	])
	var image := _fill(size, shape, func(x: int, y: int) -> Color:
		var color := STEEL
		# Light from above: brighter top plates, darker underside.
		if y < h * 0.3:
			color = STEEL_LIGHT
		elif y > h * 0.62:
			color = STEEL_DARK
		# Plate seams: horizontal bands and staggered vertical joints.
		if y % 11 == 0:
			color = SEAM
		elif (x + (y / 11) * 24) % 48 == 0:
			color = SEAM
		# Rivets beside the joints.
		if y % 11 == 3 and (x + (y / 11) * 24) % 48 == 3:
			color = RIVET
		# Red trim along the wings, lit windows along the top deck.
		var wing := absf(x - w / 2.0) > w * 0.16 and absf(x - w / 2.0) < w * 0.44
		if wing and y >= int(h * 0.36) and y <= int(h * 0.36) + 2:
			color = TRIM if y < int(h * 0.36) + 2 else TRIM_DARK
		if wing and y == int(h * 0.22) and x % 7 < 2:
			color = WINDOW
		# Hazard stripes under the core.
		if absf(x - w / 2.0) < w * 0.07 and y > h * 0.86 and (x + y) % 6 < 3:
			color = HAZARD
		return color)
	return image


## A boss part's armored block: bevelled edges, a red band, and either a turret
## ring (wing cannon), launch tubes (missile pod) or bay doors (hangar).
static func _block(size: Vector2i, turret: bool, tubes: bool) -> Image:
	var w := float(size.x)
	var h := float(size.y)
	var cut := 5.0
	var shape := PackedVector2Array([
		Vector2(cut, 0), Vector2(w - cut, 0), Vector2(w, cut), Vector2(w, h - cut),
		Vector2(w - cut, h), Vector2(cut, h), Vector2(0, h - cut), Vector2(0, cut),
	])
	var image := _fill(size, shape, func(x: int, y: int) -> Color:
		var color := STEEL
		# Bevel: lit top-left edges, shaded bottom-right edges.
		if x < 3 or y < 3:
			color = STEEL_LIGHT
		elif x > w - 4 or y > h - 4:
			color = STEEL_DARK
		if y == int(h * 0.3) or y == int(h * 0.3) + 1:
			color = TRIM
		if (x == 6 or x == int(w) - 7) and (y == 6 or y == int(h) - 7):
			color = RIVET
		if turret:
			var ring := Vector2(x, y).distance_to(Vector2(w / 2.0, h * 0.62))
			if ring < 12.0:
				color = SEAM if ring > 10.0 else STEEL_DARK
		elif tubes:
			for i: int in 3:
				var tube := Vector2(x, y).distance_to(Vector2(w * (i + 1) / 4.0, h * 0.65))
				if tube < 4.5:
					color = OUTLINE if tube < 3.0 else SEAM
		else:
			if y > h * 0.5 and y < h - 4 and x > 6 and x < w - 7:
				color = OUTLINE  # The bay (BossDraw slides its doors open and shut).
		return color)
	return image


## Fills `shape` with `paint(x, y)` and gives it a 1 px dark outline.
static func _fill(size: Vector2i, shape: PackedVector2Array, paint: Callable) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var inside: Array[PackedByteArray] = []
	for y: int in size.y:
		var row := PackedByteArray()
		row.resize(size.x)
		for x: int in size.x:
			row[x] = 1 if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), shape) else 0
		inside.append(row)
	for y: int in size.y:
		for x: int in size.x:
			if inside[y][x] == 0:
				continue
			var edge := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1 \
				or inside[y][x - 1] == 0 or inside[y][x + 1] == 0 or inside[y - 1][x] == 0 or inside[y + 1][x] == 0
			image.set_pixel(x, y, OUTLINE if edge else paint.call(x, y))
	return image
