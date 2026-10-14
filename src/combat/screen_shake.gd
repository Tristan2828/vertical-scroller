class_name ScreenShake
extends RefCounted
## Screen shake as "trauma" (0..1): big events add some, it fades over time, and
## the picture shakes by trauma squared, so small bumps stay subtle and big
## ones kick. Visual only: every peer shakes from events it already sees, and
## the Settings strength scales it (Off / Low / Full).

## Pixels at full trauma and full strength (the game is 960x540).
const MAX_OFFSET: float = 5.0
## Trauma lost per second.
const FADE_PER_SECOND: float = 1.6

var trauma: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func add(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Advances by `delta` seconds and returns this frame's offset. `strength` is
## the Settings multiplier (0 = off).
func step(delta: float, strength: float) -> Vector2:
	trauma = maxf(trauma - FADE_PER_SECOND * delta, 0.0)
	if trauma <= 0.0 or strength <= 0.0:
		return Vector2.ZERO
	var size := MAX_OFFSET * strength * trauma * trauma
	return Vector2(_rng.randf_range(-size, size), _rng.randf_range(-size, size)).round()
