class_name Ship
extends Node2D
## A player's ship on screen. The simulation is ShipMotor (pure); this node owns
## the ship's stats and state, and draws it. The stage calls tick() in its fixed
## order; nothing here runs gameplay on its own.

## Seconds per engine flicker frame.
const FLICKER_SECONDS: float = 0.06
const HITBOX_COLOR: Color = Color(1.0, 0.3, 0.35)
const HITBOX_CORE: Color = Color(1.0, 1.0, 1.0)

var stats: ShipStats = null
var state: ShipState = ShipState.new()
## This player's color (P/p pixels in the sprite).
var tint: Color = Color.WHITE
var _flicker_time: float = 0.0


func setup(ship_stats: ShipStats, player_tint: Color) -> void:
	stats = ship_stats.duplicate() as ShipStats
	tint = player_tint


## One simulation tick. Returns ShipMotor's flags (FIRED).
func tick(input: ShipInput, bounds: Rect2, delta: float) -> int:
	var result := ShipMotor.step(state, input, stats, bounds, delta)
	position = state.position
	return result


func _process(delta: float) -> void:
	_flicker_time += delta
	queue_redraw()


func _draw() -> void:
	if stats == null:
		return
	var frame := stats.sprite
	if int(_flicker_time / FLICKER_SECONDS) % 2 == 1 and PixelArt.has_sprite(stats.sprite + "_1"):
		frame = stats.sprite + "_1"
	PixelArt.draw(self, frame, Vector2.ZERO, tint)
	if state.focused:
		# The real hitbox: a ring the size of the hitbox around a white dot.
		var ring := PixelArt.disc_texture(stats.hitbox_radius + 1.0, HITBOX_COLOR, stats.hitbox_radius - 0.5, HITBOX_CORE)
		draw_texture(ring, -(Vector2(ring.get_size()) / 2.0).floor())
