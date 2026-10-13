class_name PickupManager
extends Node2D
## Pickups (Scrap, power orbs, boosts, special charges) in a fixed pool of flat
## arrays, like Medieval Survival's GemManager.
##
## A pickup bursts out of the wreck, then floats down the screen: a pure
## function of the time since it dropped, so every peer moves it the same way.
## When a ship comes close it flies to that ship (the magnet). Every peer pulls
## toward the nearest ship it sees, so the pull looks right on every screen,
## but only the host decides who collects; it sends drops and collections as
## events (batched, reliable, once per tick).

## Host: `peer_id` collected a pickup.
signal collected(kind: int, value: int, peer_id: int)
## Every peer: a pickup was collected here (for effects).
signal picked_up_at(at: Vector2, kind: int)

const CAPACITY: int = 256
const FALL_SPEED: float = 45.0
## The burst out of the wreck: starting speed, and how fast it dies down.
const BURST_SPEED: float = 70.0
const BURST_DAMPING: float = 3.0
## Scrap is pulled from further away than power-ups (you aim for those).
const SCRAP_MAGNET: float = 80.0
const POWER_UP_MAGNET: float = 30.0
const COLLECT_RADIUS: float = 12.0
const PULL_ACCELERATION: float = 1400.0
const MAX_PULL_SPEED: float = 520.0
## Pickups further than this below the screen are gone.
const BOTTOM_MARGIN: float = 24.0
const GLOW: Color = Color(1.0, 1.0, 1.0, 0.18)

var play_area: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))

var _active: PackedByteArray = PackedByteArray()
var _kinds: PackedInt32Array = PackedInt32Array()
var _values: PackedInt32Array = PackedInt32Array()
var _spawn_times: PackedFloat32Array = PackedFloat32Array()
var _origins: PackedVector2Array = PackedVector2Array()
var _bursts: PackedVector2Array = PackedVector2Array()
var _positions: PackedVector2Array = PackedVector2Array()
## Peer id of the ship a pickup flies to (0 = floating).
var _targets: PackedInt32Array = PackedInt32Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()
var _free: Array[int] = []
var _count: int = 0
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Host: events gathered during this tick, sent by flush_events().
var _new_ids: PackedInt32Array = PackedInt32Array()
var _new_kinds: PackedInt32Array = PackedInt32Array()
var _new_values: PackedInt32Array = PackedInt32Array()
var _new_origins: PackedVector2Array = PackedVector2Array()
var _new_bursts: PackedVector2Array = PackedVector2Array()
var _new_times: PackedFloat32Array = PackedFloat32Array()
var _collected_ids: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_active.resize(CAPACITY)
	_kinds.resize(CAPACITY)
	_values.resize(CAPACITY)
	_spawn_times.resize(CAPACITY)
	_origins.resize(CAPACITY)
	_bursts.resize(CAPACITY)
	_positions.resize(CAPACITY)
	_targets.resize(CAPACITY)
	_speeds.resize(CAPACITY)
	for i: int in range(CAPACITY - 1, -1, -1):
		_free.append(i)
	_rng.randomize()


func count() -> int:
	return _count


func kind_of(id: int) -> int:
	return _kinds[id]


func is_active(id: int) -> bool:
	return _active[id] == 1


func position_of(id: int) -> Vector2:
	return _positions[id]


## Host: drops a pickup at `at`. Returns its id, or -1 if the pool is full.
func spawn_host(kind: int, value: int, at: Vector2, stage_time: float) -> int:
	if _free.is_empty():
		return -1
	var burst := Vector2.from_angle(_rng.randf() * TAU) * BURST_SPEED * _rng.randf_range(0.4, 1.0)
	var id: int = _free.pop_back()
	_activate(id, kind, value, at, burst, stage_time)
	_new_ids.append(id)
	_new_kinds.append(kind)
	_new_values.append(value)
	_new_origins.append(at)
	_new_bursts.append(burst)
	_new_times.append(stage_time)
	return id


## Where a floating pickup is (pure: drop point, burst, fall).
func float_position(id: int, stage_time: float) -> Vector2:
	var age := maxf(stage_time - _spawn_times[id], 0.0)
	var burst := _bursts[id] * (1.0 - exp(-BURST_DAMPING * age)) / BURST_DAMPING
	return _origins[id] + burst + Vector2(0.0, FALL_SPEED * age)


## `ships` maps peer id -> position of each ship that can collect (not down).
func tick(stage_time: float, delta: float, ships: Dictionary[int, Vector2], is_host: bool) -> void:
	_time = stage_time
	if _count == 0:
		queue_redraw()
		return
	var bottom := play_area.end.y + BOTTOM_MARGIN
	for id: int in CAPACITY:
		if _active[id] == 0:
			continue
		var target := _targets[id]
		if target != 0 and not ships.has(target):
			# That ship went down: float on from here.
			_origins[id] = _positions[id]
			_bursts[id] = Vector2.ZERO
			_spawn_times[id] = stage_time
			target = 0
		if target == 0:
			_positions[id] = float_position(id, stage_time)
			if _positions[id].y > bottom:
				_release(id)
				continue
			target = _nearest_in_reach(_positions[id], ships, _magnet_of(_kinds[id]))
			_targets[id] = target
			_speeds[id] = 0.0
			if target == 0:
				continue
		var destination: Vector2 = ships[target]
		_speeds[id] = minf(_speeds[id] + PULL_ACCELERATION * delta, MAX_PULL_SPEED)
		_positions[id] = _positions[id].move_toward(destination, _speeds[id] * delta)
		if is_host and _positions[id].distance_to(destination) <= COLLECT_RADIUS:
			var kind := _kinds[id]
			var value := _values[id]
			picked_up_at.emit(_positions[id], kind)
			_release(id)
			_collected_ids.append(id)
			collected.emit(kind, value, target)
	queue_redraw()


func clear() -> void:
	for id: int in CAPACITY:
		if _active[id] == 1:
			_release(id)
	queue_redraw()


## Host: send this tick's drops and collections to the given peers.
func flush_events(peer_ids: Array[int]) -> void:
	if not _new_ids.is_empty():
		for peer_id: int in peer_ids:
			_receive_spawns.rpc_id(peer_id, _new_ids.size(), _new_ids, _new_kinds, _new_values, _new_origins, _new_bursts, _new_times)
		_new_ids.clear()
		_new_kinds.clear()
		_new_values.clear()
		_new_origins.clear()
		_new_bursts.clear()
		_new_times.clear()
	if not _collected_ids.is_empty():
		for peer_id: int in peer_ids:
			_receive_collected.rpc_id(peer_id, _collected_ids.size(), _collected_ids)
		_collected_ids.clear()


## Host: everything floating right now, for a peer that just arrived.
func send_full_state(peer_id: int) -> void:
	var ids := PackedInt32Array()
	var kinds := PackedInt32Array()
	var values := PackedInt32Array()
	var origins := PackedVector2Array()
	var bursts := PackedVector2Array()
	var times := PackedFloat32Array()
	for id: int in CAPACITY:
		if _active[id] == 1:
			ids.append(id)
			kinds.append(_kinds[id])
			values.append(_values[id])
			origins.append(_positions[id])
			bursts.append(Vector2.ZERO)
			times.append(_time)
	_receive_spawns.rpc_id(peer_id, ids.size(), ids, kinds, values, origins, bursts, times)


static func _magnet_of(kind: int) -> float:
	return SCRAP_MAGNET if kind == Pickups.Kind.SCRAP else POWER_UP_MAGNET


static func _nearest_in_reach(from: Vector2, ships: Dictionary[int, Vector2], reach: float) -> int:
	var best := 0
	var best_distance := reach * reach
	for peer_id: int in ships:
		var distance := from.distance_squared_to(ships[peer_id])
		if distance <= best_distance:
			best_distance = distance
			best = peer_id
	return best


func _activate(id: int, kind: int, value: int, at: Vector2, burst: Vector2, stage_time: float) -> void:
	if _active[id] == 0:
		_count += 1
	_free.erase(id)
	_active[id] = 1
	_kinds[id] = kind
	_values[id] = value
	_origins[id] = at
	_bursts[id] = burst
	_spawn_times[id] = stage_time
	_positions[id] = at
	_targets[id] = 0
	_speeds[id] = 0.0


func _release(id: int) -> void:
	if _active[id] == 0:
		return
	_active[id] = 0
	_count -= 1
	_free.append(id)


func _draw() -> void:
	for id: int in CAPACITY:
		if _active[id] == 0:
			continue
		var kind := _kinds[id]
		var at := _positions[id]
		if kind != Pickups.Kind.SCRAP:
			# Power-ups pulse a soft glow so they stand out from Scrap.
			var glow := PixelArt.disc_texture(8.0 if int(_time * 4.0) % 2 == 0 else 7.0, GLOW)
			draw_texture(glow, (at - Vector2(glow.get_size()) / 2.0).round())
		PixelArt.draw(self, Pickups.SPRITES[clampi(kind, 0, Pickups.SPRITES.size() - 1)], at)


@rpc("authority", "call_remote", "reliable")
func _receive_spawns(count_sent: int, ids: PackedInt32Array, kinds: PackedInt32Array, values: PackedInt32Array,
		origins: PackedVector2Array, bursts: PackedVector2Array, times: PackedFloat32Array) -> void:
	var n := count_sent
	for array_size: int in [ids.size(), kinds.size(), values.size(), origins.size(), bursts.size(), times.size()]:
		n = mini(n, array_size)
	for i: int in n:
		if ids[i] >= 0 and ids[i] < CAPACITY:
			_activate(ids[i], kinds[i], values[i], origins[i], bursts[i], times[i])


@rpc("authority", "call_remote", "reliable")
func _receive_collected(count_sent: int, ids: PackedInt32Array) -> void:
	for i: int in mini(count_sent, ids.size()):
		var id := ids[i]
		if id >= 0 and id < CAPACITY and _active[id] == 1:
			picked_up_at.emit(_positions[id], _kinds[id])
			_release(id)
