class_name ShipState
extends RefCounted
## Everything the ship simulation remembers between ticks.

var position: Vector2 = Vector2.ZERO
var fire_cooldown_left: float = 0.0
## Focus was held on the last tick (slower, narrow shot, hitbox shown).
var focused: bool = false
## Main gun power, 1..ShipMotor.MAX_POWER (host-owned; clients copy it).
var power: int = 1
## Seconds left on timed boosts and the Shield special (host-owned; clients
## copy them and count down in between).
var rapid_fire_left: float = 0.0
var wingmen_left: float = 0.0
var shield_left: float = 0.0
