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
const MAX_POWER: int = 5
## Rapid Fire boost: shots come this much faster (the interval is multiplied).
const RAPID_FIRE_INTERVAL: float = 0.6


## Advances `state` by one tick. Returns FIRED if the main gun shot.
static func step(state: ShipState, input: ShipInput, stats: ShipStats, bounds: Rect2, delta: float) -> int:
	var result := 0
	state.focused = input.focus
	state.fire_cooldown_left = maxf(state.fire_cooldown_left - delta, 0.0)
	state.rapid_fire_left = maxf(state.rapid_fire_left - delta, 0.0)
	state.wingmen_left = maxf(state.wingmen_left - delta, 0.0)
	state.shield_left = maxf(state.shield_left - delta, 0.0)
	var move := input.move.limit_length(1.0)
	state.position = clamp_to_bounds(state.position + move * speed_of(stats, input.focus) * delta, bounds, stats.body_radius)
	if input.fire and state.fire_cooldown_left <= COOLDOWN_EPSILON:
		state.fire_cooldown_left = fire_interval(stats, state, input.focus)
		result |= FIRED
	return result


static func fire_interval(stats: ShipStats, state: ShipState, focus: bool) -> float:
	var interval := stats.focus_fire_interval if focus else stats.fire_interval
	return interval * RAPID_FIRE_INTERVAL if state.rapid_fire_left > 0.0 else interval


## Streams and damage of a shot at the ship's power level.
static func streams(stats: ShipStats, power: int, focus: bool) -> int:
	var table := stats.focus_streams if focus else stats.spread_streams
	return table[clampi(power, 1, table.size()) - 1]


static func damage(stats: ShipStats, power: int, focus: bool) -> int:
	var base := stats.focus_bullet_damage if focus else stats.bullet_damage
	return roundi(base * stats.power_damage[clampi(power, 1, stats.power_damage.size()) - 1])


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
