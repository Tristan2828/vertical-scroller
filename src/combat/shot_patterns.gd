class_name ShotPatterns
extends RefCounted
## Bullet patterns (copied from Medieval Survival). A shot is described by
## (pattern id, origin, aim angle, seed, fire time); every peer turns that small
## description into identical bullets with build(), so bullets themselves never
## need to be sent over the network.
##
## Each bullet is five numbers: angle (radians), speed (px/s), delay (s) before
## it appears, and a spawn offset (x, y) from the origin. Delays let one event
## describe something that unfolds over time (bursts); offsets let it describe
## shapes that don't start from a single point (parallel streams).
##
## Ids are sent over the network: only add new patterns at the end.
## Enemy bullets are slow and readable (DESIGN.md: Sky Force-level density).

enum Id {
	SHIP_SPREAD, SHIP_FOCUS,
	AIMED, AIMED_FAN_3, AIMED_FAN_5, BURST_3, RING_12, DOWN_SPREAD_3,
}

const STRIDE: int = 5
## SHIP_SPREAD: angle of the outer streams.
const SPREAD_DEGREES: float = 6.0
## SHIP_SPREAD: side streams start this far left/right of the muzzle.
const SPREAD_OFFSET: float = 5.0
## SHIP_FOCUS: gap between the two parallel streams.
const FOCUS_GAP: float = 8.0
## Enemy bullet speeds (px/s).
const SLOW: float = 110.0
const MEDIUM: float = 150.0
const FAST: float = 190.0


## A seed both the host and the shooting client can compute on their own.
static func make_seed(peer_id: int, input_seq: int) -> int:
	return peer_id * 1_000_003 + input_seq


## True for patterns players shoot (the rest are enemy patterns).
static func is_ship_pattern(pattern: int) -> bool:
	return pattern == Id.SHIP_SPREAD or pattern == Id.SHIP_FOCUS


## Builds every bullet of a pattern: [angle, speed, delay, offset_x, offset_y, ...].
## `count` (main gun power, later) and `base_speed` come from the shooter
## (ship patterns); enemy patterns have their own speeds.
static func build(pattern: Id, aim: float, seed_value: int, count: int = 1, base_speed: float = 0.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	var across := Vector2.from_angle(aim + PI / 2.0)
	match pattern:
		Id.SHIP_SPREAD:
			# A straight center stream and two slightly angled side streams.
			_add(out, aim, base_speed, 0.0)
			for side: float in [-1.0, 1.0]:
				_add(out, aim + side * deg_to_rad(SPREAD_DEGREES), base_speed, 0.0, across * side * SPREAD_OFFSET)
		Id.SHIP_FOCUS:
			# Two tight parallel streams straight ahead.
			for side: float in [-1.0, 1.0]:
				_add(out, aim, base_speed, 0.0, across * side * FOCUS_GAP / 2.0)
		Id.AIMED:
			_add(out, aim, MEDIUM, 0.0)
		Id.AIMED_FAN_3:
			_fan(out, aim, 3, deg_to_rad(14.0), MEDIUM)
		Id.AIMED_FAN_5:
			_fan(out, aim, 5, deg_to_rad(12.0), SLOW)
		Id.BURST_3:
			# Three quick shots in a line at you.
			for i: int in 3:
				_add(out, aim, FAST, i * 0.12)
		Id.RING_12:
			var rotation := rng.randf() * TAU
			for i: int in 12:
				_add(out, rotation + TAU * i / 12.0, SLOW, 0.0)
		Id.DOWN_SPREAD_3:
			# Not aimed: straight down and slightly out (the aim is ignored).
			_fan(out, PI / 2.0, 3, deg_to_rad(20.0), SLOW)
	return out


## Just the angles (handy for tests and simple callers).
static func angles(pattern: Id, aim: float, seed_value: int, count: int = 1) -> PackedFloat32Array:
	var bullets := build(pattern, aim, seed_value, count)
	var result := PackedFloat32Array()
	for i: int in range(0, bullets.size(), STRIDE):
		result.append(bullets[i])
	return result


static func _fan(out: PackedFloat32Array, aim: float, count: int, spacing: float, speed: float) -> void:
	for i: int in count:
		_add(out, aim + (i - (count - 1) / 2.0) * spacing, speed, 0.0)


static func _add(out: PackedFloat32Array, angle: float, speed: float, delay: float, offset: Vector2 = Vector2.ZERO) -> void:
	out.append(angle)
	out.append(speed)
	out.append(delay)
	out.append(offset.x)
	out.append(offset.y)
