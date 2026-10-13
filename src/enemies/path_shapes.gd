class_name PathShapes
extends RefCounted
## Named flight paths for scripted enemies (DESIGN.md §3 Enemies). A position
## is a pure function of how long the enemy has been flying, so every peer
## computes it from the spawn record alone and nothing is sent per frame.
## Stage files say which shape, when, where; the shapes live here.
##
## `mirror` flips a path left/right (waves often come in mirrored pairs).
## Ids are sent over the network: only add new shapes at the end. NAMES are
## what stage files call them, in Id order.

enum Id { S_CURVE, STRAIGHT, DIVE_RETREAT, CIRCLE_STRAFE, CROSS_SCREEN, HOVER_LEAVE, BOSS }

const NAMES: Array[String] = ["s_curve", "straight", "dive_retreat", "circle_strafe", "cross_screen", "hover_leave", "boss"]

## S_CURVE: down the screen, swaying left and right.
const S_CURVE_SPEED: float = 90.0
const S_CURVE_WIDTH: float = 120.0
## Radians of sway per second.
const S_CURVE_RATE: float = 1.6
## STRAIGHT: straight down.
const STRAIGHT_SPEED: float = 110.0
## DIVE_RETREAT: dive in, stop to shoot, pull back up and out sideways.
const DIVE_DEPTH: float = 230.0
const DIVE_SECONDS: float = 1.2
const DIVE_HOLD_UNTIL: float = 2.8
const RETREAT_SPEED: float = 140.0
## CIRCLE_STRAFE: down, one loop, then on down.
const CIRCLE_ENTRY: float = 180.0
const CIRCLE_SPEED: float = 120.0
const CIRCLE_RADIUS: float = 70.0
const CIRCLE_SECONDS: float = 2.6
## CROSS_SCREEN: across from one side (start off screen at the side; mirror = from the right).
const CROSS_SPEED: float = 150.0
const CROSS_DRIFT: float = 25.0
## HOVER_LEAVE: drift down, hover and sway, then leave upward.
const HOVER_DEPTH: float = 150.0
const HOVER_ARRIVE_SECONDS: float = 1.5
const HOVER_LEAVE_AT: float = 7.0
const HOVER_SWAY: float = 30.0
const LEAVE_SPEED: float = 90.0
## BOSS: fly in from above, then sway slowly across the top of the screen (never leaves).
const BOSS_DEPTH: float = 190.0
const BOSS_ARRIVE_SECONDS: float = 3.0
const BOSS_SWAY_WIDTH: float = 220.0
const BOSS_SWAY_RATE: float = 0.45
const BOSS_BOB: float = 20.0


static func from_name(shape_name: String) -> int:
	return NAMES.find(shape_name)


## Where an enemy on `shape` is `age` seconds after it appeared at `origin`.
static func position(shape: Id, age: float, origin: Vector2, mirror: bool = false) -> Vector2:
	var side := -1.0 if mirror else 1.0
	match shape:
		Id.S_CURVE:
			return origin + Vector2(side * S_CURVE_WIDTH * sin(age * S_CURVE_RATE), S_CURVE_SPEED * age)
		Id.STRAIGHT:
			return origin + Vector2(0.0, STRAIGHT_SPEED * age)
		Id.DIVE_RETREAT:
			if age < DIVE_SECONDS:
				return origin + Vector2(0.0, DIVE_DEPTH * _ease_out(age / DIVE_SECONDS))
			var bottom := origin + Vector2(0.0, DIVE_DEPTH)
			if age < DIVE_HOLD_UNTIL:
				return bottom
			var away := age - DIVE_HOLD_UNTIL
			return bottom + Vector2(side * RETREAT_SPEED * 0.5 * away, -RETREAT_SPEED * away)
		Id.CIRCLE_STRAFE:
			var entry_seconds := CIRCLE_ENTRY / CIRCLE_SPEED
			if age < entry_seconds:
				return origin + Vector2(0.0, CIRCLE_SPEED * age)
			var loop_start := origin + Vector2(0.0, CIRCLE_ENTRY)
			if age < entry_seconds + CIRCLE_SECONDS:
				# Start on the circle's edge moving down, go once around.
				var center := loop_start + Vector2(side * CIRCLE_RADIUS, 0.0)
				var start_angle := PI if side > 0.0 else 0.0
				var angle := start_angle - side * TAU * (age - entry_seconds) / CIRCLE_SECONDS
				return center + Vector2.from_angle(angle) * CIRCLE_RADIUS
			return loop_start + Vector2(0.0, CIRCLE_SPEED * (age - entry_seconds - CIRCLE_SECONDS))
		Id.CROSS_SCREEN:
			return origin + Vector2(side * CROSS_SPEED * age, CROSS_DRIFT * age)
		Id.HOVER_LEAVE:
			var depth := HOVER_DEPTH * _ease_out(minf(age / HOVER_ARRIVE_SECONDS, 1.0))
			var sway := side * HOVER_SWAY * sin(maxf(age - HOVER_ARRIVE_SECONDS, 0.0) * 1.2)
			var rise := LEAVE_SPEED * maxf(age - HOVER_LEAVE_AT, 0.0)
			return origin + Vector2(sway, depth - rise)
		Id.BOSS:
			var arrived := origin + Vector2(0.0, BOSS_DEPTH * _ease_out(age / BOSS_ARRIVE_SECONDS))
			var t := maxf(age - BOSS_ARRIVE_SECONDS, 0.0)
			# Starts swaying from rest (sin(0) = 0), so there's no jump on arrival.
			return arrived + Vector2(side * BOSS_SWAY_WIDTH * sin(t * BOSS_SWAY_RATE), BOSS_BOB * sin(t * BOSS_SWAY_RATE * 2.0))
	return origin


static func _ease_out(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)
