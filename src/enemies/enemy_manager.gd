class_name EnemyManager
extends Node2D
## A pool of scripted air enemies in flat arrays (like ProjectileManager).
## An enemy is a spawn record: path shape, spawn time, origin, mirror. Its
## position is PathShapes.position() of (stage time - spawn time), so every peer
## computes it from the stage clock. Only the host spawns and damages enemies;
## it sends each spawn record (with its pool index, so "enemy #12" is the same
## enemy everywhere) and each death. Clients' bullets only flash enemies.
##
## M1 version: one enemy look and HP for the test wave. Enemy types as data
## (HP, speed, sprite, gun, drops) arrive in M3.

const CAPACITY: int = 128
## Enemies further than this outside the screen are removed.
const LEAVE_MARGIN: float = 48.0
## How long a hit enemy stays white.
const FLASH_SECONDS: float = 0.05
const EXPLOSION_SECONDS: float = 0.3
const EXPLOSION_FRAMES: float = 6.0

## Enemy `index` died at `at` (host: from damage(); clients: from kill()).
## `by_peer` is the killer's peer id on the host, 0 on clients.
signal killed(index: int, at: Vector2, by_peer: int)

@export var sprite: String = "drone"
@export var max_hp: int = 40
@export var hit_radius: float = 8.0

## Screen rectangle in stage coordinates.
var play_area: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))

var _active: PackedByteArray = PackedByteArray()
var _shapes: PackedInt32Array = PackedInt32Array()
var _spawn_times: PackedFloat32Array = PackedFloat32Array()
var _origins: PackedVector2Array = PackedVector2Array()
var _mirrors: PackedByteArray = PackedByteArray()
var _hp: PackedInt32Array = PackedInt32Array()
var _flash: PackedFloat32Array = PackedFloat32Array()
## Position on the last tick (computed from the path; cached for hits and drawing).
var _positions: PackedVector2Array = PackedVector2Array()
## True once the enemy has appeared (stage time reached its spawn time).
var _appeared: PackedByteArray = PackedByteArray()
## Explosions: x, y, age.
var _explosions: Array[Vector3] = []
## Host: damage dealt by each peer (run stats; the online smoke test checks it).
var damage_by_peer: Dictionary[int, int] = {}


func _init() -> void:
	_active.resize(CAPACITY)
	_shapes.resize(CAPACITY)
	_spawn_times.resize(CAPACITY)
	_origins.resize(CAPACITY)
	_mirrors.resize(CAPACITY)
	_hp.resize(CAPACITY)
	_flash.resize(CAPACITY)
	_positions.resize(CAPACITY)
	_appeared.resize(CAPACITY)


## Host: adds an enemy that appears at `spawn_time` (may be in the future).
## Returns its pool index, or -1 if the pool is full.
func spawn(shape: PathShapes.Id, spawn_time: float, origin: Vector2, mirror: bool = false) -> int:
	for i: int in CAPACITY:
		if _active[i] == 0:
			spawn_at(i, shape, spawn_time, origin, mirror)
			return i
	return -1


## Puts an enemy in pool slot `index` (clients: the slot the host chose).
func spawn_at(index: int, shape: PathShapes.Id, spawn_time: float, origin: Vector2, mirror: bool) -> void:
	if index < 0 or index >= CAPACITY:
		return
	_active[index] = 1
	_shapes[index] = shape
	_spawn_times[index] = spawn_time
	_origins[index] = origin
	_mirrors[index] = 1 if mirror else 0
	_hp[index] = max_hp
	_flash[index] = 0.0
	_positions[index] = origin
	_appeared[index] = 0


## Every active enemy's spawn record, for a peer that just arrived:
## [indices, shapes, spawn times, origins, mirrors]. spawn_at() takes them back.
func records() -> Array:
	var indices := PackedInt32Array()
	var shapes := PackedInt32Array()
	var times := PackedFloat32Array()
	var origins := PackedVector2Array()
	var mirrors := PackedByteArray()
	for i: int in CAPACITY:
		if _active[i] == 1:
			indices.append(i)
			shapes.append(_shapes[i])
			times.append(_spawn_times[i])
			origins.append(_origins[i])
			mirrors.append(_mirrors[i])
	return [indices, shapes, times, origins, mirrors]


## Moves every enemy to where its path puts it at `stage_time`; removes the ones
## that flew off screen.
func tick(stage_time: float, delta: float) -> void:
	var leave_area := play_area.grow(LEAVE_MARGIN)
	for i: int in CAPACITY:
		if _active[i] == 0:
			continue
		var age := stage_time - _spawn_times[i]
		if age < 0.0:
			continue
		_appeared[i] = 1
		_positions[i] = PathShapes.position(_shapes[i] as PathShapes.Id, age, _origins[i], _mirrors[i] == 1)
		_flash[i] = maxf(_flash[i] - delta, 0.0)
		if age > 1.0 and not leave_area.has_point(_positions[i]):
			_active[i] = 0
	var e := 0
	while e < _explosions.size():
		_explosions[e].z += delta
		if _explosions[e].z >= EXPLOSION_SECONDS:
			_explosions.remove_at(e)
		else:
			e += 1
	queue_redraw()


func is_alive(index: int) -> bool:
	return _active[index] == 1 and _appeared[index] == 1


func position_of(index: int) -> Vector2:
	return _positions[index]


func hp_of(index: int) -> int:
	return _hp[index]


## Enemies on screen or still to appear.
func active_count() -> int:
	var total := 0
	for i: int in CAPACITY:
		total += _active[i]
	return total


## The first live enemy touching the segment `from`-`to` (a bullet's path this
## tick), skipping `ignore`. Returns its pool index or -1.
func find_hit_on_path(from: Vector2, to: Vector2, bullet_radius: float, ignore: int = -1) -> int:
	var reach := hit_radius + bullet_radius
	for i: int in CAPACITY:
		if i == ignore or not is_alive(i):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(_positions[i], from, to)
		if closest.distance_squared_to(_positions[i]) <= reach * reach:
			return i
	return -1


## Host: hurts enemy `index` (`by_peer` shot it). Returns true if this killed it.
func damage(index: int, amount: int, by_peer: int = 1) -> bool:
	if not is_alive(index):
		return false
	damage_by_peer[by_peer] = damage_by_peer.get(by_peer, 0) + mini(amount, _hp[index])
	_hp[index] -= amount
	_flash[index] = FLASH_SECONDS
	if _hp[index] > 0:
		return false
	_remove(index, by_peer)
	return true


## Client: the host says enemy `index` died.
func kill(index: int) -> void:
	if index >= 0 and index < CAPACITY and _active[index] == 1:
		_remove(index, 0)


## A hit seen on this screen (clients' bullets don't deal damage).
func flash(index: int) -> void:
	if is_alive(index):
		_flash[index] = FLASH_SECONDS


func _remove(index: int, by_peer: int) -> void:
	_active[index] = 0
	if _appeared[index] == 1:
		_explosions.append(Vector3(_positions[index].x, _positions[index].y, 0.0))
	killed.emit(index, _positions[index], by_peer)


func clear() -> void:
	_active.fill(0)
	_explosions.clear()
	queue_redraw()


func _draw() -> void:
	for i: int in CAPACITY:
		if is_alive(i):
			PixelArt.draw(self, sprite, _positions[i], Color.WHITE, _flash[i] > 0.0)
	for explosion: Vector3 in _explosions:
		# A few fixed frames, so the baked textures stay cached.
		var t := floorf(explosion.z / EXPLOSION_SECONDS * EXPLOSION_FRAMES) / EXPLOSION_FRAMES
		var center := Vector2(explosion.x, explosion.y)
		var outer := PixelArt.disc_texture(roundf(4.0 + 10.0 * t), Color(1.0, 0.55, 0.15, 1.0 - t), roundf(8.0 * t), Color(0, 0, 0, 0))
		var core := PixelArt.disc_texture(roundf(6.0 * (1.0 - t)) + 1.0, Color(1.0, 0.95, 0.7, 1.0 - t))
		draw_texture(outer, (center - Vector2(outer.get_size()) / 2.0).round())
		draw_texture(core, (center - Vector2(core.get_size()) / 2.0).round())
