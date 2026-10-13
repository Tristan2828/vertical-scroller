class_name ShotPatterns
extends RefCounted
## Bullet patterns (copied from Medieval Survival). A shot is described by
## (pattern id, origin, aim angle, seed, fire time); every peer turns that small
## description into identical bullets with build(), so bullets themselves never
## need to be sent over the network.
##
## Each bullet is five numbers: angle (radians), speed (px/s), delay (s) before
## it appears, and a spawn offset (x, y) from the origin. Delays let one event
## describe something that unfolds over time (spirals); offsets let it describe
## shapes that don't start from a single point (parallel streams, walls).
##
## Ids are sent over the network: only add new patterns at the end.
## (Enemy patterns arrive with the enemies in M3.)

enum Id { SHIP_SPREAD, SHIP_FOCUS }

const STRIDE: int = 5
## SHIP_SPREAD: angle of the outer streams.
const SPREAD_DEGREES: float = 6.0
## SHIP_SPREAD: side streams start this far left/right of the muzzle.
const SPREAD_OFFSET: float = 5.0
## SHIP_FOCUS: gap between the two parallel streams.
const FOCUS_GAP: float = 8.0


## A seed both the host and the shooting client can compute on their own.
static func make_seed(peer_id: int, input_seq: int) -> int:
	return peer_id * 1_000_003 + input_seq


## Builds every bullet of a pattern: [angle, speed, delay, offset_x, offset_y, ...].
## `count` (main gun power, later) and `base_speed` come from the shooter.
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
	return out


## Just the angles (handy for tests and simple callers).
static func angles(pattern: Id, aim: float, seed_value: int, count: int = 1) -> PackedFloat32Array:
	var bullets := build(pattern, aim, seed_value, count)
	var result := PackedFloat32Array()
	for i: int in range(0, bullets.size(), STRIDE):
		result.append(bullets[i])
	return result


static func _add(out: PackedFloat32Array, angle: float, speed: float, delay: float, offset: Vector2 = Vector2.ZERO) -> void:
	out.append(angle)
	out.append(speed)
	out.append(delay)
	out.append(offset.x)
	out.append(offset.y)
