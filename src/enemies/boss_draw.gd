class_name BossDraw
extends RefCounted
## Draws boss cores and parts (types with no sprite): the baked pixel art from
## BossArt, plus what moves: turret barrels that track the nearest ship, blinking
## launch tubes, sliding bay doors, the core's armor plates or pulsing eye, and
## smoke and sparks on badly damaged parts. Parts get a small HP bar; a hit
## flashes only the part (or the core's dome), never the whole hull.

const OUTLINE: Color = Color(0.05, 0.06, 0.08)
const DARK: Color = Color(0.18, 0.2, 0.24)
const BARREL: Color = Color(0.3, 0.33, 0.38)
const CORE_OPEN: Color = Color(1.0, 0.3, 0.45)
const CORE_GLOW: Color = Color(1.0, 0.85, 0.9)
const PLATE: Color = Color(0.42, 0.46, 0.53)
const LIGHT: Color = Color(1.0, 0.75, 0.3)
const SMOKE: Color = Color(0.2, 0.2, 0.22)
const SPARK: Color = Color(1.0, 0.85, 0.4)
const BAR_BACK: Color = Color(0.05, 0.05, 0.08, 0.85)
const BAR_FILL: Color = Color(0.95, 0.4, 0.45)
const BAR_SIZE: Vector2 = Vector2(40, 3)
## An armored core that's hit flashes this gray (a "ping": no damage), not white.
const ARMOR_PING: Color = Color(0.7, 0.73, 0.8)
## Parts below this much HP smoke and spark.
const DAMAGED: float = 0.5


## `ratio` = HP left (0..1); `time` animates; `aim` = where the part's guns
## point (radians); `seed_value` makes each part's smoke different.
static func draw(canvas: CanvasItem, type: EnemyType, at: Vector2, flash: bool, armored: bool, ratio: float,
		time: float, aim: float = PI / 2.0, seed_value: int = 0) -> void:
	var center := at.round()
	var corner := center - (type.size / 2.0).floor()
	var art := BossArt.texture(type.key, type.size)
	if art != null:
		# A hit part flashes bright; the hull never does (only the core's dome).
		var tint := Color(2.0, 2.0, 2.0) if flash and type.boss_part else Color.WHITE
		canvas.draw_texture(art, corner, tint)
	else:
		canvas.draw_rect(Rect2(corner, type.size), Color.WHITE if flash else type.body_color)
	match type.key:
		"fortress_core":
			_draw_core(canvas, type, center, flash, armored, time)
		"wing_cannon":
			# Twin barrels from the turret ring, toward the nearest ship.
			var ring := corner + Vector2(roundf(type.size.x / 2.0), roundf(type.size.y * 0.62))
			var along := Vector2.from_angle(aim)
			var side := Vector2.from_angle(aim + PI / 2.0) * 3.0
			for s: float in [-1.0, 1.0]:
				canvas.draw_line(ring + side * s, ring + side * s + along * 18.0, OUTLINE, 4.0)
				canvas.draw_line(ring + side * s, ring + side * s + along * 17.0, BARREL, 2.0)
			var cap := PixelArt.disc_texture(6.0, OUTLINE, 5.0, BARREL)
			canvas.draw_texture(cap, ring - (Vector2(cap.get_size()) / 2.0).floor())
		"missile_pod":
			# The tube about to fire glows.
			var lit := int(time * 3.0) % 3
			var light := PixelArt.disc_texture(2.0, LIGHT)
			var tube := corner + Vector2(roundf(type.size.x * (lit + 1) / 4.0), roundf(type.size.y * 0.65))
			canvas.draw_texture(light, tube - (Vector2(light.get_size()) / 2.0).floor())
		"hangar":
			# Bay doors slide open and shut.
			var open := clampf(sin(time * 1.6) * 1.5, 0.0, 1.0)
			var top := floorf(type.size.y * 0.5) + 1.0
			var bay := Rect2(corner + Vector2(7, top), Vector2(type.size.x - 14.0, type.size.y - 4.0 - top))
			var door := roundf(bay.size.x / 2.0 * (1.0 - open))
			canvas.draw_rect(Rect2(bay.position, Vector2(door, bay.size.y)), PLATE)
			canvas.draw_rect(Rect2(bay.end.x - door, bay.position.y, door, bay.size.y), PLATE)
			if open > 0.5:
				canvas.draw_rect(Rect2((bay.get_center() - Vector2(2, 1)).round(), Vector2(4, 2)), LIGHT)
	if type.boss_part:
		if ratio < DAMAGED:
			_draw_damage(canvas, center, type.size, time, seed_value)
		var bar := Rect2(center + Vector2(-BAR_SIZE.x / 2.0, -floorf(type.size.y / 2.0) - 7.0), BAR_SIZE)
		canvas.draw_rect(bar.grow(1.0), BAR_BACK)
		canvas.draw_rect(Rect2(bar.position, Vector2(roundf(BAR_SIZE.x * clampf(ratio, 0.0, 1.0)), BAR_SIZE.y)), BAR_FILL)


static func _draw_core(canvas: CanvasItem, type: EnemyType, center: Vector2, flash: bool, armored: bool, time: float) -> void:
	var radius := type.radius
	var socket := PixelArt.disc_texture(radius + 2.0, OUTLINE, radius, DARK)
	canvas.draw_texture(socket, center - (Vector2(socket.get_size()) / 2.0).floor())
	if armored:
		# Armor plates closed over the core, seams between them, a blinking lock.
		var plates := PixelArt.disc_texture(radius - 2.0, ARMOR_PING if flash else PLATE)
		canvas.draw_texture(plates, center - (Vector2(plates.get_size()) / 2.0).floor())
		canvas.draw_rect(Rect2(center + Vector2(-radius + 2.0, -1.0), Vector2(radius * 2.0 - 4.0, 2)), OUTLINE)
		canvas.draw_rect(Rect2(center + Vector2(-1.0, -radius + 2.0), Vector2(2, radius * 2.0 - 4.0)), OUTLINE)
		var lock := PixelArt.disc_texture(2.0, LIGHT if int(time * 2.0) % 2 == 0 else DARK)
		canvas.draw_texture(lock, center - (Vector2(lock.get_size()) / 2.0).floor())
		return
	# Open: a glowing eye with a pulsing center and a ring sweeping outward.
	var eye := PixelArt.disc_texture(radius - 2.0, Color.WHITE if flash else CORE_OPEN)
	canvas.draw_texture(eye, center - (Vector2(eye.get_size()) / 2.0).floor())
	var pulse := PixelArt.disc_texture(roundf(radius * (0.35 + 0.1 * sin(time * 6.0))), CORE_GLOW)
	canvas.draw_texture(pulse, center - (Vector2(pulse.get_size()) / 2.0).floor())
	var ring := roundf((radius - 3.0) * (0.5 + 0.5 * fposmod(time * 1.2, 1.0)))
	canvas.draw_arc(center, ring, 0.0, TAU, 32, Color(CORE_GLOW, 0.5), 1.0)


## Smoke puffs rising off a badly damaged part, and the odd spark.
static func _draw_damage(canvas: CanvasItem, center: Vector2, size: Vector2, time: float, seed_value: int) -> void:
	for i: int in 3:
		var phase := fposmod(time * 0.8 + i / 3.0 + seed_value * 0.37, 1.0)
		var x := fposmod(seed_value * 13.0 + i * 17.0, size.x * 0.6) - size.x * 0.3
		var puff := PixelArt.disc_texture(roundf(2.0 + phase * 4.0), SMOKE)
		var at := center + Vector2(x, -phase * 22.0)
		canvas.draw_texture(puff, (at - Vector2(puff.get_size()) / 2.0).round(), Color(1, 1, 1, 0.7 * (1.0 - phase)))
	if int(time * 10.0 + seed_value) % 7 == 0:
		var spark := PixelArt.disc_texture(1.0, SPARK)
		var x := fposmod(seed_value * 5.0 + time * 40.0, size.x) - size.x / 2.0
		canvas.draw_texture(spark, (center + Vector2(x, 0.0)).round())
