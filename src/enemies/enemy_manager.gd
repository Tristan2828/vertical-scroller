class_name EnemyManager
extends Node2D
## A pool of air enemies in flat arrays (like ProjectileManager).
##
## An enemy is a spawn record: type, path shape, spawn time, origin, mirror,
## pace. Its position is PathShapes.position() of (stage time - spawn time), so
## every peer computes it from the stage clock. Homing enemies (EnemyType.Homing)
## get a "redirect" from the host now and then: from that moment they fly in a
## straight line from a given point toward a target, which is still a pure
## function of time, so it's just one more small event.
##
## Only the host spawns, damages, aims and redirects enemies; it sends each
## spawn record with its pool index (so "enemy #12" is the same enemy
## everywhere), each redirect, and each death. Clients' bullets only flash enemies.

const CAPACITY: int = 128
## Enemies further than this outside the screen are removed.
const LEAVE_MARGIN: float = 48.0
## How long a hit enemy stays white.
const FLASH_SECONDS: float = 0.05
const EXPLOSION_SECONDS: float = 0.3
## Enemies only shoot while this far inside the top of the screen and above the
## bottom part where the ships fly (no point-blank shots from behind).
const FIRE_TOP: float = 8.0
const FIRE_BOTTOM: float = 380.0

## Enemy `index` died at `at` (host: from damage(); clients: from kill()).
## `by_peer` is the killer's peer id on the host, 0 on clients.
signal killed(index: int, at: Vector2, by_peer: int)

## Screen rectangle in stage coordinates.
var play_area: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))
## Host: damage dealt by each peer (run stats; the online smoke test checks it).
var damage_by_peer: Dictionary[int, int] = {}
## Host: guns fire this much more often (harder later stages: below 1).
var fire_interval_scale: float = 1.0

var _active: PackedByteArray = PackedByteArray()
var _types: PackedInt32Array = PackedInt32Array()
var _shapes: PackedInt32Array = PackedInt32Array()
var _spawn_times: PackedFloat32Array = PackedFloat32Array()
var _origins: PackedVector2Array = PackedVector2Array()
var _mirrors: PackedByteArray = PackedByteArray()
var _paces: PackedFloat32Array = PackedFloat32Array()
var _hp: PackedInt32Array = PackedInt32Array()
var _flash: PackedFloat32Array = PackedFloat32Array()
## Position on the last tick (computed from the path; cached for hits and drawing).
var _positions: PackedVector2Array = PackedVector2Array()
## True once the enemy has appeared (stage time reached its spawn time).
var _appeared: PackedByteArray = PackedByteArray()
## Redirect: from _redirect_times on, fly from _redirect_origins toward
## _redirect_targets at _redirect_speeds; stop there unless _redirect_keep_going.
## A time below 0 = no redirect.
var _redirect_times: PackedFloat32Array = PackedFloat32Array()
var _redirect_origins: PackedVector2Array = PackedVector2Array()
var _redirect_targets: PackedVector2Array = PackedVector2Array()
var _redirect_speeds: PackedFloat32Array = PackedFloat32Array()
var _redirect_keep_going: PackedByteArray = PackedByteArray()
## Host: stage time of the next volley / homing decision.
var _next_fire: PackedFloat32Array = PackedFloat32Array()
var _next_homing: PackedFloat32Array = PackedFloat32Array()
## Host: trackers that gave up following and are flying away.
var _leaving: PackedByteArray = PackedByteArray()
## Elite Wing modifier: tougher, faster-shooting, gold enemies.
var _elite: PackedByteArray = PackedByteArray()
## Explosions: x, y, age.
var _explosions: Array[Vector3] = []


func _init() -> void:
	# (Packed arrays are values: each one must be resized directly, not through a list.)
	_active.resize(CAPACITY)
	_types.resize(CAPACITY)
	_shapes.resize(CAPACITY)
	_spawn_times.resize(CAPACITY)
	_origins.resize(CAPACITY)
	_mirrors.resize(CAPACITY)
	_paces.resize(CAPACITY)
	_hp.resize(CAPACITY)
	_flash.resize(CAPACITY)
	_positions.resize(CAPACITY)
	_appeared.resize(CAPACITY)
	_redirect_times.resize(CAPACITY)
	_redirect_origins.resize(CAPACITY)
	_redirect_targets.resize(CAPACITY)
	_redirect_speeds.resize(CAPACITY)
	_redirect_keep_going.resize(CAPACITY)
	_next_fire.resize(CAPACITY)
	_next_homing.resize(CAPACITY)
	_leaving.resize(CAPACITY)
	_elite.resize(CAPACITY)


## Host: adds an enemy that appears at `spawn_time` (may be in the future).
## `hp_scale` is the co-op HP scaling. Returns its pool index, or -1 if full.
func spawn(type_id: int, shape: PathShapes.Id, spawn_time: float, origin: Vector2, mirror: bool = false,
		pace: float = 1.0, hp_scale: float = 1.0, elite: bool = false) -> int:
	for i: int in CAPACITY:
		if _active[i] == 0:
			spawn_at(i, type_id, shape, spawn_time, origin, mirror, pace, elite)
			var scale := hp_scale * (StageModifiers.ELITE_HP if elite else 1.0)
			_hp[i] = maxi(roundi(EnemyTypes.ALL[type_id].max_hp * scale), 1)
			return i
	return -1


## Puts an enemy in pool slot `index` (clients: the slot the host chose).
func spawn_at(index: int, type_id: int, shape: PathShapes.Id, spawn_time: float, origin: Vector2, mirror: bool,
		pace: float = 1.0, elite: bool = false) -> void:
	if index < 0 or index >= CAPACITY or not EnemyTypes.is_valid_id(type_id):
		return
	var type := EnemyTypes.ALL[type_id]
	_active[index] = 1
	_types[index] = type_id
	_shapes[index] = shape
	_spawn_times[index] = spawn_time
	_origins[index] = origin
	_mirrors[index] = 1 if mirror else 0
	_paces[index] = pace
	_hp[index] = type.max_hp
	_flash[index] = 0.0
	_positions[index] = origin
	_appeared[index] = 0
	_redirect_times[index] = -1.0
	_next_fire[index] = spawn_time + type.first_shot_delay
	_next_homing[index] = spawn_time + type.homing_delay
	_leaving[index] = 0
	_elite[index] = 1 if elite else 0


## From `time` on, enemy `index` flies straight from `origin` toward `target`.
func redirect(index: int, time: float, origin: Vector2, target: Vector2, speed: float, keep_going: bool) -> void:
	if index < 0 or index >= CAPACITY or _active[index] == 0:
		return
	_redirect_times[index] = time
	_redirect_origins[index] = origin
	_redirect_targets[index] = target
	_redirect_speeds[index] = speed
	_redirect_keep_going[index] = 1 if keep_going else 0


## Where enemy `index` is at `stage_time` (pure: spawn record + redirect).
func position_at(index: int, stage_time: float) -> Vector2:
	if _redirect_times[index] >= 0.0 and stage_time >= _redirect_times[index]:
		var from := _redirect_origins[index]
		var to := _redirect_targets[index]
		var distance := _redirect_speeds[index] * (stage_time - _redirect_times[index])
		if _redirect_keep_going[index] == 0:
			distance = minf(distance, from.distance_to(to))
		return from + (to - from).normalized() * distance
	var age := (stage_time - _spawn_times[index]) * _paces[index]
	return PathShapes.position(_shapes[index] as PathShapes.Id, age, _origins[index], _mirrors[index] == 1)


## Every active enemy's spawn record, for a peer that just arrived (each array
## in pool order; `apply_records` takes them back): indices, types, shapes,
## spawn times, origins, mirrors, paces, redirect times / origins / targets /
## speeds / keep-going.
func records(only: PackedInt32Array = PackedInt32Array()) -> Array:
	# Filled as locals and put in the Array at the end: packed arrays are values,
	# so appending to one taken out of an Array would only change a copy.
	var indices := PackedInt32Array()
	var types := PackedInt32Array()
	var shapes := PackedInt32Array()
	var times := PackedFloat32Array()
	var origins := PackedVector2Array()
	var mirrors := PackedByteArray()
	var paces := PackedFloat32Array()
	var r_times := PackedFloat32Array()
	var r_origins := PackedVector2Array()
	var r_targets := PackedVector2Array()
	var r_speeds := PackedFloat32Array()
	var r_keep := PackedByteArray()
	var elites := PackedByteArray()
	for i: int in CAPACITY:
		if _active[i] == 0 or (not only.is_empty() and not only.has(i)):
			continue
		indices.append(i)
		types.append(_types[i])
		shapes.append(_shapes[i])
		times.append(_spawn_times[i])
		origins.append(_origins[i])
		mirrors.append(_mirrors[i])
		paces.append(_paces[i])
		r_times.append(_redirect_times[i])
		r_origins.append(_redirect_origins[i])
		r_targets.append(_redirect_targets[i])
		r_speeds.append(_redirect_speeds[i])
		r_keep.append(_redirect_keep_going[i])
		elites.append(_elite[i])
	return [indices, types, shapes, times, origins, mirrors, paces, r_times, r_origins, r_targets, r_speeds, r_keep, elites]


## Client: spawn records from the host (see records()).
func apply_records(data: Array) -> void:
	if data.size() != 13:
		return
	var indices: PackedInt32Array = data[0]
	var types: PackedInt32Array = data[1]
	var shapes: PackedInt32Array = data[2]
	var times: PackedFloat32Array = data[3]
	var origins: PackedVector2Array = data[4]
	var mirrors: PackedByteArray = data[5]
	var paces: PackedFloat32Array = data[6]
	var r_times: PackedFloat32Array = data[7]
	var r_origins: PackedVector2Array = data[8]
	var r_targets: PackedVector2Array = data[9]
	var r_speeds: PackedFloat32Array = data[10]
	var r_keep: PackedByteArray = data[11]
	var elites: PackedByteArray = data[12]
	var n := indices.size()
	for array_size: int in [types.size(), shapes.size(), times.size(), origins.size(), mirrors.size(), paces.size(),
			r_times.size(), r_origins.size(), r_targets.size(), r_speeds.size(), r_keep.size(), elites.size()]:
		n = mini(n, array_size)
	for i: int in n:
		if shapes[i] < 0 or shapes[i] >= PathShapes.Id.size():
			continue
		spawn_at(indices[i], types[i], shapes[i] as PathShapes.Id, times[i], origins[i], mirrors[i] == 1, paces[i], elites[i] == 1)
		if r_times[i] >= 0.0:
			redirect(indices[i], r_times[i], r_origins[i], r_targets[i], r_speeds[i], r_keep[i] == 1)


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
		_positions[i] = position_at(i, stage_time)
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


## Host: enemies whose gun is ready now (and resets their timers).
func take_ready_guns(stage_time: float) -> PackedInt32Array:
	var ready := PackedInt32Array()
	for i: int in CAPACITY:
		if not is_alive(i) or stage_time < _next_fire[i]:
			continue
		var type := EnemyTypes.ALL[_types[i]]
		if type.shot_pattern < 0:
			continue
		_next_fire[i] = stage_time + type.fire_interval * fire_interval_scale * (StageModifiers.ELITE_FIRE_INTERVAL if _elite[i] == 1 else 1.0)
		var y := _positions[i].y
		if y >= FIRE_TOP and y <= FIRE_BOTTOM and play_area.has_point(_positions[i]):
			ready.append(i)
	return ready


## Host: homing enemies due for a decision now; the next one is `every` seconds later.
func take_due_homing(stage_time: float, every: float) -> PackedInt32Array:
	var due := PackedInt32Array()
	for i: int in CAPACITY:
		if not is_alive(i) or stage_time < _next_homing[i]:
			continue
		if EnemyTypes.ALL[_types[i]].homing == EnemyType.Homing.NONE:
			continue
		_next_homing[i] = stage_time + every
		due.append(i)
	return due


func is_alive(index: int) -> bool:
	return _active[index] == 1 and _appeared[index] == 1


func type_of(index: int) -> EnemyType:
	return EnemyTypes.ALL[_types[index]]


func position_of(index: int) -> Vector2:
	return _positions[index]


func hp_of(index: int) -> int:
	return _hp[index]


func is_elite(index: int) -> bool:
	return _elite[index] == 1


func has_redirect(index: int) -> bool:
	return _redirect_times[index] >= 0.0


func spawn_time_of(index: int) -> float:
	return _spawn_times[index]


func is_leaving(index: int) -> bool:
	return _leaving[index] == 1


func mark_leaving(index: int) -> void:
	_leaving[index] = 1


## Enemies on screen or still to appear.
func active_count() -> int:
	var total := 0
	for i: int in CAPACITY:
		total += _active[i]
	return total


## Live enemies, for contact checks.
func alive_indices() -> PackedInt32Array:
	var alive := PackedInt32Array()
	for i: int in CAPACITY:
		if is_alive(i):
			alive.append(i)
	return alive


## The first live enemy touching the segment `from`-`to` (a bullet's path this
## tick), skipping `ignore`. Returns its pool index or -1.
func find_hit_on_path(from: Vector2, to: Vector2, bullet_radius: float, ignore: int = -1) -> int:
	for i: int in CAPACITY:
		if i == ignore or not is_alive(i):
			continue
		var reach := EnemyTypes.ALL[_types[i]].radius + bullet_radius
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


func clear() -> void:
	_active.fill(0)
	_explosions.clear()
	queue_redraw()


func _remove(index: int, by_peer: int) -> void:
	_active[index] = 0
	if _appeared[index] == 1:
		_explosions.append(Vector3(_positions[index].x, _positions[index].y, 0.0))
	killed.emit(index, _positions[index], by_peer)


func _draw() -> void:
	for i: int in CAPACITY:
		if is_alive(i):
			var tint := StageModifiers.ELITE_TINT if _elite[i] == 1 else Color.WHITE
			PixelArt.draw(self, EnemyTypes.ALL[_types[i]].sprite, _positions[i], Color.WHITE, _flash[i] > 0.0, false, 1.0, tint)
	for explosion: Vector3 in _explosions:
		Explosions.draw(self, Vector2(explosion.x, explosion.y), explosion.z / EXPLOSION_SECONDS, 1.0)
