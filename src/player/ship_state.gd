class_name ShipState
extends RefCounted
## Everything the ship simulation remembers between ticks.

var position: Vector2 = Vector2.ZERO
var fire_cooldown_left: float = 0.0
## Focus was held on the last tick (slower, narrow shot, hitbox shown).
var focused: bool = false
