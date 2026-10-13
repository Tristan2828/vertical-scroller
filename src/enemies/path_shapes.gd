class_name PathShapes
extends RefCounted
## Named flight paths for scripted enemies (DESIGN.md §3 Enemies). A position
## is a pure function of how long the enemy has been flying, so every peer
## computes it from the spawn event alone and nothing is sent per frame.
## Stage files will say which shape, when, where; the shapes live here.
##
## Ids are sent over the network: only add new shapes at the end.
## (More shapes arrive in M3: dive-and-retreat, circle-strafe, cross-screen...)

enum Id { S_CURVE }

## S_CURVE: down the screen, swaying left and right.
const S_CURVE_SPEED: float = 90.0
const S_CURVE_WIDTH: float = 120.0
## Radians of sway per second.
const S_CURVE_RATE: float = 1.6


## Where an enemy on `shape` is `age` seconds after it appeared at `origin`.
## `mirror` flips the path left/right (waves often come in mirrored pairs).
static func position(shape: Id, age: float, origin: Vector2, mirror: bool = false) -> Vector2:
	var side := -1.0 if mirror else 1.0
	match shape:
		Id.S_CURVE:
			return origin + Vector2(side * S_CURVE_WIDTH * sin(age * S_CURVE_RATE), S_CURVE_SPEED * age)
	return origin
