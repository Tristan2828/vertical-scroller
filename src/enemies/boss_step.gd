class_name BossStep
extends RefCounted
## One step of a boss's attack script (a `boss_step` line in the stage file):
## fire a pattern, then wait. Copied from Medieval Survival (there a Resource;
## here parsed from the stage file).

enum Aim {
	## Fire at `angle`.
	FIXED,
	## One volley aimed at each ship that's still flying.
	AT_EACH,
	## Aimed at the nearest ship.
	AT_NEAREST,
	## Each use turns `angle` further (rotating rings and spirals).
	SPIN,
}

## What stage files call the aims, in Aim order.
const AIM_NAMES: Array[String] = ["fixed", "each", "nearest", "spin"]
## SPIN: how far each use turns.
const SPIN_STEP: float = deg_to_rad(17.0)

## ShotPatterns.Id of the pattern to fire.
var pattern: int = 0
var aim: Aim = Aim.AT_NEAREST
## Radians (FIXED and SPIN start here; 0 = right, PI/2 = straight down).
var angle: float = PI / 2.0
## Seconds to wait after this step before the next one.
var wait: float = 1.0
## Where it fires from, relative to the boss (its gun pods).
var offset: Vector2 = Vector2.ZERO
