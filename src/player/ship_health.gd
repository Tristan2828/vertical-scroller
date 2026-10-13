class_name ShipHealth
extends RefCounted
## A ship's HP bar (DESIGN.md §3 Player ship: Sky Force-style chip damage). The
## host owns it; clients get copies through snapshots. Trimmed from Medieval
## Survival's PlayerHealth: here every hit (bullet or contact) gives the same
## short invulnerability blink.
##
## M3: at 0 HP the ship keeps flying with an empty bar. Death and respawn from
## the team's credit pool come in M4.

## Seconds of invulnerability (blinking) after a hit (draft).
const HIT_SAFE_SECONDS: float = 1.0

var max_hp: int = 100
var hp: int = 100
var invulnerable_left: float = 0.0


func reset(max_value: int) -> void:
	max_hp = max_value
	hp = max_value
	invulnerable_left = 0.0


func is_invulnerable() -> bool:
	return invulnerable_left > 0.0


func is_empty() -> bool:
	return hp <= 0


func ratio() -> float:
	return clampf(float(hp) / maxf(max_hp, 1.0), 0.0, 1.0)


func tick(delta: float) -> void:
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)


## An enemy bullet or a collision. Returns true if it landed.
func take_hit(amount: int) -> bool:
	if is_invulnerable() or amount <= 0:
		return false
	hp = maxi(hp - amount, 0)
	invulnerable_left = HIT_SAFE_SECONDS
	return true


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
