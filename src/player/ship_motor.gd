class_name ShipMotor
extends RefCounted
## Pure, deterministic ship simulation: same state + same input = same result.
## The host runs it to decide what really happens; the owning client runs the
## exact same code to predict its own ship without waiting for the host (M2).

## Bits returned by step().
const FIRED: int = 1
## Cooldowns are summed floats: allow a hair of rounding so 0.1 s really is 6 ticks.
const COOLDOWN_EPSILON: float = 0.0001
## Mouse mode: closer than this to the cursor counts as there.
const GLIDE_ARRIVED: float = 0.5


## Advances `state` by one tick. Returns FIRED if the main gun shot.
static func step(state: ShipState, input: ShipInput, stats: ShipStats, bounds: Rect2, delta: float) -> int:
	var result := 0
	state.focused = input.focus
	state.fire_cooldown_left = maxf(state.fire_cooldown_left - delta, 0.0)
	var move := input.move.limit_length(1.0)
	state.position = clamp_to_bounds(state.position + move * speed_of(stats, input.focus) * delta, bounds, stats.body_radius)
	if input.fire and state.fire_cooldown_left <= COOLDOWN_EPSILON:
		state.fire_cooldown_left = stats.focus_fire_interval if input.focus else stats.fire_interval
		result |= FIRED
	return result


static func speed_of(stats: ShipStats, focus: bool) -> float:
	return stats.focus_speed if focus else stats.move_speed


static func clamp_to_bounds(point: Vector2, bounds: Rect2, radius: float) -> Vector2:
	var inner := bounds.grow(-radius)
	return point.clamp(inner.position, inner.end)


## Mouse mode: the move input that glides toward `target` at `speed`, slowing
## down on the last tick so the ship lands exactly on it instead of shaking.
static func glide_move(position: Vector2, target: Vector2, speed: float, delta: float) -> Vector2:
	var to_target := target - position
	if to_target.length() <= GLIDE_ARRIVED or speed <= 0.0:
		return Vector2.ZERO
	return (to_target / (speed * delta)).limit_length(1.0)
