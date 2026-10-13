class_name ProjectileManager
extends Node2D
## Holds every bullet in flat arrays instead of one node per bullet. That's far
## cheaper with hundreds of bullets, and the arrays are allocated once up front,
## so bullets are pooled for free. (Copied from Medieval Survival and trimmed.)
##
## A bullet's position is origin + velocity * age, so any peer that spawns the
## same bullet gets the same path.
##
## A bullet with negative age hasn't appeared yet (patterns like spirals spawn
## all their bullets at once with staggered delays).
##
## Two instances will exist: player bullets (hit enemies) and enemy bullets
## (hit players, M3). Only the host's bullets will deal damage; clients' bullets
## are visual: they vanish on contact, but the host decides the actual hits.

const CAPACITY: int = 4096

## A bullet hit something here (for sparks). Emitted on every peer.
signal hit_at(at: Vector2)

@export var hit_radius: float = 2.0
## A size above zero draws bullets as vertical bolts (player shots) instead of discs.
@export var bolt_size: Vector2i = Vector2i.ZERO
@export var glow_radius: float = 3.0
@export var core_radius: float = 1.5
@export var glow_color: Color = Color(1.0, 0.75, 0.3, 0.45)
@export var core_color: Color = Color(1.0, 0.97, 0.8)

## Bullets outside this rectangle are removed.
var bounds: Rect2 = Rect2(-10000, -10000, 20000, 20000)
## On its first tick a bullet checks for hits back this far behind where it
## appeared (player shots: back to the ship's center, so an enemy right on top
## of the ship still gets hit; they appear at the muzzle).
var spawn_backtrack: float = 0.0
## Length of the last step(), so hits are checked along the path a bullet flew
## this tick (fast bullets would otherwise jump over enemies).
var _last_step: float = 0.0

var _count: int = 0
var _origins: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _lifetimes: PackedFloat32Array = PackedFloat32Array()
var _damages: PackedInt32Array = PackedInt32Array()
var _owners: PackedInt32Array = PackedInt32Array()
## Enemies each bullet can still pass through.
var _pierce: PackedInt32Array = PackedInt32Array()
## Pool index of the enemy last hit, so a piercing bullet doesn't hit it again next tick.
var _last_hit: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_origins.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_ages.resize(CAPACITY)
	_lifetimes.resize(CAPACITY)
	_damages.resize(CAPACITY)
	_owners.resize(CAPACITY)
	_pierce.resize(CAPACITY)
	_last_hit.resize(CAPACITY)


## Returns false if the pool is full.
## `start_age` < 0 delays the bullet; > 0 starts it partway along its path.
func spawn(origin: Vector2, velocity: Vector2, damage: int, lifetime: float, owner_peer_id: int,
		pierce: int = 0, start_age: float = 0.0) -> bool:
	if _count >= CAPACITY:
		return false
	_origins[_count] = origin
	_velocities[_count] = velocity
	_ages[_count] = start_age
	_lifetimes[_count] = lifetime
	_damages[_count] = damage
	_owners[_count] = owner_peer_id
	_pierce[_count] = pierce
	_last_hit[_count] = -1
	_count += 1
	return true


func count() -> int:
	return _count


func position_of(index: int) -> Vector2:
	return _origins[index] + _velocities[index] * _ages[index]


func clear() -> void:
	_count = 0
	queue_redraw()


## Ages every bullet and removes expired or out-of-bounds ones.
func step(delta: float) -> void:
	_last_step = delta
	var i := 0
	while i < _count:
		_ages[i] += delta
		if _ages[i] < 0.0:
			i += 1
		elif _ages[i] >= _lifetimes[i] or not bounds.has_point(position_of(i)):
			_remove(i)
		else:
			i += 1
	queue_redraw()


## Removes bullets touching an enemy (or uses up one pierce). With `apply_damage`
## (host only) they also hurt it.
func resolve_hits(enemies: EnemyManager, apply_damage: bool) -> void:
	var i := 0
	while i < _count:
		if _ages[i] < 0.0:
			i += 1
			continue
		var enemy := enemies.find_hit_on_path(_path_start(i), position_of(i), hit_radius, _last_hit[i])
		if enemy < 0:
			i += 1
			continue
		hit_at.emit(position_of(i))
		if apply_damage:
			enemies.damage(enemy, _damages[i])
		if _pierce[i] > 0:
			_pierce[i] -= 1
			_last_hit[i] = enemy
			i += 1
		else:
			_remove(i)


## Where bullet `i` was at the start of this tick.
func _path_start(i: int) -> Vector2:
	var previous_age := _ages[i] - _last_step
	if previous_age > 0.0001:  # (Ages are 32-bit floats: a fresh bullet can be a hair above 0.)
		return _origins[i] + _velocities[i] * previous_age
	return _origins[i] - _velocities[i].normalized() * spawn_backtrack


## Removes every bullet within `radius` of `center` (bombs, later). Returns how many.
func clear_near(center: Vector2, radius: float) -> int:
	var removed := 0
	var i := 0
	while i < _count:
		if position_of(i).distance_squared_to(center) <= radius * radius:
			_remove(i)
			removed += 1
		else:
			i += 1
	queue_redraw()
	return removed


## One baked texture per bullet (batched into a single draw call); bullets off
## screen are skipped.
func _draw() -> void:
	var texture: Texture2D
	if bolt_size != Vector2i.ZERO:
		texture = PixelArt.bolt_texture(bolt_size, glow_color, core_color)
	else:
		texture = PixelArt.disc_texture(glow_radius, glow_color, core_radius, core_color)
	var half := (Vector2(texture.get_size()) / 2.0).floor()
	var view := PixelArt.visible_rect(self)
	for i: int in _count:
		if _ages[i] < 0.0:
			continue
		var point := position_of(i)
		if view.has_point(point):
			draw_texture(texture, (point - half).round())


## Order doesn't matter, so fill the gap with the last bullet.
func _remove(index: int) -> void:
	var last := _count - 1
	_origins[index] = _origins[last]
	_velocities[index] = _velocities[last]
	_ages[index] = _ages[last]
	_lifetimes[index] = _lifetimes[last]
	_damages[index] = _damages[last]
	_owners[index] = _owners[last]
	_pierce[index] = _pierce[last]
	_last_hit[index] = _last_hit[last]
	_count = last
