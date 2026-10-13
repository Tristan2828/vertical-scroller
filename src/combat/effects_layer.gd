class_name EffectsLayer
extends Node2D
## Big one-off visuals: Mega Bomb rings, ships blowing up, a boss's chain of
## explosions. Every peer makes them itself from events it already sees; they
## are never sent over the network. Gray-box until the art pass.

const RING_SECONDS: float = 0.6
const BLAST_SECONDS: float = 0.5
const RING_WIDTH: float = 3.0
## Explosions: x, y, age (negative = waiting to go off), size.
var _blasts: Array[Vector4] = []
## Rings: x, y, age, max radius.
var _rings: Array[Vector4] = []
var _ring_colors: Array[Color] = []


## An expanding ring (Mega Bomb).
func ring(center: Vector2, radius: float, color: Color) -> void:
	_rings.append(Vector4(center.x, center.y, 0.0, radius))
	_ring_colors.append(color)


## An explosion of `size` (1 = a small enemy) after `delay` seconds.
func blast(center: Vector2, size: float, delay: float = 0.0) -> void:
	_blasts.append(Vector4(center.x, center.y, -delay, size))


## A boss going down: explosions all over it for a moment.
func chain(center: Vector2, spread: Vector2, count: int, rng: RandomNumberGenerator) -> void:
	for i: int in count:
		var offset := Vector2(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y, spread.y))
		blast(center + offset, rng.randf_range(1.2, 2.4), i * 0.12)
	blast(center, 4.0, count * 0.12)


func _process(delta: float) -> void:
	var i := 0
	while i < _blasts.size():
		_blasts[i].z += delta
		if _blasts[i].z >= BLAST_SECONDS:
			_blasts.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _rings.size():
		_rings[i].z += delta
		if _rings[i].z >= RING_SECONDS:
			_rings.remove_at(i)
			_ring_colors.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	for i: int in _rings.size():
		var r := _rings[i]
		var t := r.z / RING_SECONDS
		draw_arc(Vector2(r.x, r.y), r.w * t, 0.0, TAU, 64, Color(_ring_colors[i], 1.0 - t), RING_WIDTH)
	for b: Vector4 in _blasts:
		if b.z >= 0.0:
			Explosions.draw(self, Vector2(b.x, b.y), b.z / BLAST_SECONDS, b.w)
