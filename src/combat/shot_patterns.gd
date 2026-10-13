class_name ShotPatterns
extends RefCounted
## Bullet patterns (copied from Medieval Survival). A shot is described by
## (pattern id, origin, aim angle, seed, fire time); every peer turns that small
## description into identical bullets with build(), so bullets themselves never
## need to be sent over the network.
##
## Each bullet is five numbers: angle (radians), speed (px/s), delay (s) before
## it appears, and a spawn offset (x, y) from the origin. Delays let one event
## describe something that unfolds over time (bursts, spirals); offsets let it
## describe shapes that don't start from a single point (parallel streams).
##
## Ids are sent over the network: only add new patterns at the end (and their
## stage file name to NAMES, in the same order).
## Enemy bullets are slow and readable (DESIGN.md: Sky Force-level density).

enum Id {
	SHIP_SPREAD, SHIP_FOCUS,
	AIMED, AIMED_FAN_3, AIMED_FAN_5, BURST_3, RING_12, DOWN_SPREAD_3,
	RING_24, SPIRAL, AIMED_LINE_5, SPRAY,
}

## What stage files call them (boss_step lines), in Id order.
const NAMES: Array[String] = [
	"ship_spread", "ship_focus",
	"aimed", "aimed_fan_3", "aimed_fan_5", "burst_3", "ring_12", "down_spread_3",
	"ring_24", "spiral", "aimed_line_5", "spray",
]

const STRIDE: int = 5
## SHIP_SPREAD: angle and start offset of each pair of side streams, inner first.
const SPREAD_DEGREES: Array[float] = [6.0, 14.0, 22.0]
const SPREAD_OFFSETS: Array[float] = [5.0, 9.0, 13.0]
## SHIP_FOCUS: gap between neighbouring parallel streams.
const FOCUS_GAP: float = 8.0
## Enemy bullet speeds (px/s).
const SLOW: float = 110.0
const MEDIUM: float = 150.0
const FAST: float = 190.0
const SPIRAL_BULLETS: int = 36
const SPIRAL_INTERVAL: float = 0.07


## A seed both the host and the shooting client can compute on their own.
static func make_seed(peer_id: int, input_seq: int) -> int:
	return peer_id * 1_000_003 + input_seq


## True for patterns players shoot (the rest are enemy patterns).
static func is_ship_pattern(pattern: int) -> bool:
	return pattern == Id.SHIP_SPREAD or pattern == Id.SHIP_FOCUS


static func from_name(pattern_name: String) -> int:
	return NAMES.find(pattern_name)


## Builds every bullet of a pattern: [angle, speed, delay, offset_x, offset_y, ...].
## Ship patterns: `count` = streams (main gun power) and `base_speed` come
## from the ship. Enemy patterns have their own counts and speeds.
static func build(pattern: Id, aim: float, seed_value: int, count: int = 0, base_speed: float = 0.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	var across := Vector2.from_angle(aim + PI / 2.0)
	match pattern:
		Id.SHIP_SPREAD:
			# A straight center stream plus pairs of angled side streams (3, 5 or 7).
			_add(out, aim, base_speed, 0.0)
			var pairs := clampi((maxi(count, 3) - 1) / 2, 1, SPREAD_DEGREES.size())
			for pair: int in pairs:
				for side: float in [-1.0, 1.0]:
					_add(out, aim + side * deg_to_rad(SPREAD_DEGREES[pair]), base_speed, 0.0,
						across * side * SPREAD_OFFSETS[pair])
		Id.SHIP_FOCUS:
			# Tight parallel streams straight ahead (2 or more).
			var streams := maxi(count, 2)
			for i: int in streams:
				_add(out, aim, base_speed, 0.0, across * (i - (streams - 1) / 2.0) * FOCUS_GAP)
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
		Id.RING_24:
			# A ring with its gaps lined up on the aim, so there's always a way through.
			for i: int in 24:
				_add(out, aim + TAU * (i + 0.5) / 24.0, SLOW, 0.0)
		Id.SPIRAL:
			# One arm turning from the aim, a bullet every SPIRAL_INTERVAL.
			var direction := 1.0 if rng.randf() < 0.5 else -1.0
			for i: int in SPIRAL_BULLETS:
				_add(out, aim + direction * i * TAU / 18.0, SLOW, i * SPIRAL_INTERVAL)
		Id.AIMED_LINE_5:
			# Five shots at you, each a little faster: they arrive as a line.
			for i: int in 5:
				_add(out, aim, SLOW + i * 18.0, 0.0)
		Id.SPRAY:
			# A loose shower around the aim over half a second.
			for i: int in 14:
				_add(out, aim + deg_to_rad(rng.randf_range(-35.0, 35.0)), rng.randf_range(SLOW, MEDIUM), rng.randf_range(0.0, 0.5))
	return out


## Just the angles (handy for tests and simple callers).
static func angles(pattern: Id, aim: float, seed_value: int, count: int = 0) -> PackedFloat32Array:
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
