class_name ShipInput
extends RefCounted
## One physics tick of a player's input. Clients will send these to the host (M2).

## Increases by 1 every tick (the host echoes back the last one it simulated).
var seq: int = 0
## Movement direction, length 0..1. Mouse mode turns the cursor into this too.
var move: Vector2 = Vector2.ZERO
var focus: bool = false
## The auto-fire setting already applied (FireControl).
var fire: bool = false
