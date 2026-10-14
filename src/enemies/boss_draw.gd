class_name BossDraw
extends RefCounted
## Gray-box drawing for boss cores and boss parts (types with no sprite): plain
## shapes at the type's `size`, like ground objects, until the art pass. Parts
## get a small HP bar; an armored core shows closed plates.

const OUTLINE: Color = Color(0.05, 0.06, 0.08)
const DARK: Color = Color(0.18, 0.2, 0.24)
const CORE_OPEN: Color = Color(1.0, 0.3, 0.45)
const CORE_GLOW: Color = Color(1.0, 0.85, 0.9)
const LIGHT: Color = Color(1.0, 0.75, 0.3)
const BAR_BACK: Color = Color(0.05, 0.05, 0.08, 0.85)
const BAR_FILL: Color = Color(0.95, 0.4, 0.45)
const BAR_SIZE: Vector2 = Vector2(40, 3)
## An armored core that's hit flashes this gray (a "ping": no damage), not white.
const ARMOR_PING: Color = Color(0.55, 0.58, 0.64)


## `ratio` is the part's HP left (0..1); `time` animates lights.
static func draw(canvas: CanvasItem, type: EnemyType, at: Vector2, flash: bool, armored: bool, ratio: float,
		time: float) -> void:
	var center := at.round()
	var color := Color.WHITE if flash else type.body_color
	var half := type.size / 2.0
	match type.key:
		"fortress_core":
			# A wide armored hull, narrower at the bottom, with the core in the middle.
			var hull := PackedVector2Array([
				center + Vector2(-half.x, -half.y * 0.4), center + Vector2(half.x, -half.y * 0.4),
				center + Vector2(half.x * 0.88, half.y * 0.5), center + Vector2(half.x * 0.4, half.y),
				center + Vector2(-half.x * 0.4, half.y), center + Vector2(-half.x * 0.88, half.y * 0.5),
			])
			var outline := PackedVector2Array()
			for point: Vector2 in hull:
				outline.append(point + (point - center).normalized() * 2.0)
			canvas.draw_colored_polygon(outline, OUTLINE)
			# Only the core flashes when hit, never the whole hull.
			canvas.draw_colored_polygon(hull, type.body_color)
			# Panel lines and running lights.
			for x: float in [-0.66, -0.33, 0.33, 0.66]:
				canvas.draw_rect(Rect2(center + Vector2(half.x * x - 1.0, -half.y * 0.3), Vector2(2, half.y * 0.9)), DARK)
			if int(time * 2.0) % 2 == 0:
				for x: float in [-0.8, 0.8]:
					canvas.draw_rect(Rect2(center + Vector2(half.x * x - 2.0, -2.0), Vector2(4, 4)), LIGHT)
			var dome_color := CORE_OPEN
			if armored:
				dome_color = ARMOR_PING if flash else DARK
			elif flash:
				dome_color = Color.WHITE
			var dome := PixelArt.disc_texture(type.radius, OUTLINE, type.radius - 2.0, dome_color)
			canvas.draw_texture(dome, center - (Vector2(dome.get_size()) / 2.0).floor())
			if armored:
				# Closed plates over the core.
				canvas.draw_rect(Rect2(center + Vector2(-type.radius + 4.0, -1.0), Vector2(type.radius * 2.0 - 8.0, 2)), OUTLINE)
				canvas.draw_rect(Rect2(center + Vector2(-1.0, -type.radius + 4.0), Vector2(2, type.radius * 2.0 - 8.0)), OUTLINE)
			else:
				var pulse := PixelArt.disc_texture(roundf(type.radius * (0.35 + 0.1 * sin(time * 6.0))), CORE_GLOW)
				canvas.draw_texture(pulse, center - (Vector2(pulse.get_size()) / 2.0).floor())
		"wing_cannon":
			canvas.draw_rect(Rect2(center - half, type.size).grow(1.0), OUTLINE)
			canvas.draw_rect(Rect2(center - half, type.size), color)
			for x: float in [-10.0, 10.0]:
				canvas.draw_rect(Rect2(center + Vector2(x - 3.0, half.y - 4.0), Vector2(6, 14)), OUTLINE)
				canvas.draw_rect(Rect2(center + Vector2(x - 2.0, half.y - 4.0), Vector2(4, 13)), DARK)
		"missile_pod":
			canvas.draw_rect(Rect2(center - half, type.size).grow(1.0), OUTLINE)
			canvas.draw_rect(Rect2(center - half, type.size), color)
			for x: float in [-9.0, 0.0, 9.0]:
				var tube := PixelArt.disc_texture(3.0, OUTLINE, 2.0, LIGHT if int(time * 3.0) % 3 == int(x / 9.0 + 1.0) else DARK)
				canvas.draw_texture(tube, center + Vector2(x, 4.0) - (Vector2(tube.get_size()) / 2.0).floor())
		"hangar":
			canvas.draw_rect(Rect2(center - half, type.size).grow(1.0), OUTLINE)
			canvas.draw_rect(Rect2(center - half, type.size), color)
			canvas.draw_rect(Rect2(center + Vector2(-half.x + 8.0, half.y - 10.0), Vector2(type.size.x - 16.0, 6)), OUTLINE)
		_:
			canvas.draw_rect(Rect2(center - half, type.size), color)
	if type.boss_part:
		var bar := Rect2(center + Vector2(-BAR_SIZE.x / 2.0, -half.y - 7.0), BAR_SIZE)
		canvas.draw_rect(bar.grow(1.0), BAR_BACK)
		canvas.draw_rect(Rect2(bar.position, Vector2(roundf(BAR_SIZE.x * clampf(ratio, 0.0, 1.0)), BAR_SIZE.y)), BAR_FILL)
