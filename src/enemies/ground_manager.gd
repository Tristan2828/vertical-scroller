class_name GroundManager
extends Node2D
## Ground objects (turrets, tanks, bunkers, radar dishes) placed in the stage
## file (DESIGN.md §3 Enemies: "the world is the target"). They scroll with the
## map, so a position is a pure function of stage time: every peer knows where
## each one is from the stage file alone, and an object's index in the file is
## its network id. The host decides hits and sends "object #47 destroyed".
## Destroyed objects stay on the map as rubble.
##
## Drawn under the air layer, gray-box style (darker, plain shapes) until the
## art pass.

## Ground object `index` was destroyed (host: damage(); clients: destroy()).
signal destroyed(index: int, at: Vector2, by_peer: int)

const FLASH_SECONDS: float = 0.05
const EXPLOSION_SECONDS: float = 0.4
## Same firing band as air enemies (EnemyManager).
const FIRE_TOP: float = 8.0
const FIRE_BOTTOM: float = 380.0
const OUTLINE: Color = Color(0.04, 0.05, 0.06)
const RUBBLE: Color = Color(0.24, 0.22, 0.2)
const SCORCH: Color = Color(0.07, 0.06, 0.06)
const BARREL: Color = Color(0.16, 0.17, 0.17)
const LIGHT: Color = Color(0.85, 0.35, 0.3)

var play_area: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))
## Host: damage dealt by each peer.
var damage_by_peer: Dictionary[int, int] = {}
## Host: guns fire this much more often (harder later stages: below 1).
var fire_interval_scale: float = 1.0

var _defs: Array[StageDef.GroundDef] = []
var _stage: StageDef = null
var _time: float = 0.0
## Host: HP, set when the object first comes on screen (co-op scaling then).
var _hp: PackedInt32Array = PackedInt32Array()
var _destroyed: PackedByteArray = PackedByteArray()
var _on_screen: PackedByteArray = PackedByteArray()
var _flash: PackedFloat32Array = PackedFloat32Array()
var _next_fire: PackedFloat32Array = PackedFloat32Array()
var _positions: PackedVector2Array = PackedVector2Array()
## Gun angle for drawing (toward the nearest ship on this screen).
var _aims: PackedFloat32Array = PackedFloat32Array()
## Explosions: x, y, age.
var _explosions: Array[Vector3] = []
## Indices of the objects standing on screen this tick (rebuilt by tick()), so
## bullets only look at those.
var _live: PackedInt32Array = PackedInt32Array()


func setup(def: StageDef) -> void:
	_defs = def.grounds
	_stage = def
	var n := _defs.size()
	_hp.resize(n)
	_hp.fill(-1)
	_destroyed.resize(n)
	_destroyed.fill(0)
	_on_screen.resize(n)
	_on_screen.fill(0)
	_flash.resize(n)
	_flash.fill(0.0)
	_next_fire.resize(n)
	_next_fire.fill(-1.0)
	_positions.resize(n)
	_aims.resize(n)
	_aims.fill(PI / 2.0)


func count() -> int:
	return _defs.size()


## Where object `index` is at `stage_time`: it scrolls in at the top of the
## screen at its time (and stops when the scroll stops for the boss); tanks
## also drive along the map.
func position_at(index: int, stage_time: float) -> Vector2:
	var def := _defs[index]
	var type := EnemyTypes.ALL[def.type_id]
	var scrolled := _stage.scroll_distance(stage_time) - _stage.scroll_distance(def.time)
	var drift := type.drift
	if def.mirror:
		drift.x = -drift.x
	return Vector2(def.x, -type.size.y / 2.0) + Vector2(0.0, scrolled) + drift * (stage_time - def.time)


## `ships` = ship positions on this screen (guns turn toward the nearest).
## `hp_scale` = co-op HP scaling (host).
func tick(stage_time: float, delta: float, ships: PackedVector2Array, hp_scale: float) -> void:
	_time = stage_time
	var area := play_area.grow(40.0)
	_live.clear()
	for i: int in _defs.size():
		_positions[i] = position_at(i, stage_time)
		var was_on_screen := _on_screen[i] == 1
		_on_screen[i] = 1 if area.has_point(_positions[i]) else 0
		if _on_screen[i] == 0:
			continue
		var type := EnemyTypes.ALL[_defs[i].type_id]
		if not was_on_screen and _hp[i] < 0:
			_hp[i] = maxi(roundi(type.max_hp * hp_scale), 1)
			_next_fire[i] = stage_time + type.first_shot_delay
		_flash[i] = maxf(_flash[i] - delta, 0.0)
		if _destroyed[i] == 0:
			_live.append(i)
		var target := nearest(_positions[i], ships)
		if target.is_finite():
			_aims[i] = (target - _positions[i]).angle()
	var e := 0
	while e < _explosions.size():
		_explosions[e].z += delta
		if _explosions[e].z >= EXPLOSION_SECONDS:
			_explosions.remove_at(e)
		else:
			e += 1
	queue_redraw()


## The closest of `points` to `from` (Vector2.INF if there are none).
static func nearest(from: Vector2, points: PackedVector2Array) -> Vector2:
	var best := Vector2.INF
	var best_distance := INF
	for point: Vector2 in points:
		var distance := from.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = point
	return best


func is_alive(index: int) -> bool:
	return _on_screen[index] == 1 and _destroyed[index] == 0


func is_destroyed(index: int) -> bool:
	return _destroyed[index] == 1


func type_of(index: int) -> EnemyType:
	return EnemyTypes.ALL[_defs[index].type_id]


func position_of(index: int) -> Vector2:
	return _positions[index]


## Host: objects whose gun is ready now (and resets their timers).
func take_ready_guns(stage_time: float) -> PackedInt32Array:
	var ready := PackedInt32Array()
	for i: int in _defs.size():
		if not is_alive(i) or _next_fire[i] < 0.0 or stage_time < _next_fire[i]:
			continue
		var type := EnemyTypes.ALL[_defs[i].type_id]
		if type.shot_pattern < 0:
			continue
		_next_fire[i] = stage_time + type.fire_interval * fire_interval_scale
		var y := _positions[i].y
		if y >= FIRE_TOP and y <= FIRE_BOTTOM:
			ready.append(i)
	return ready


## Indices of every destroyed object (for a peer that arrives late).
func destroyed_indices() -> PackedInt32Array:
	var list := PackedInt32Array()
	for i: int in _defs.size():
		if _destroyed[i] == 1:
			list.append(i)
	return list


## Standing objects destroyed so far / in total (a stage goal later).
func destroyed_count() -> int:
	return destroyed_indices().size()


func find_hit_on_path(from: Vector2, to: Vector2, bullet_radius: float, ignore: int = -1) -> int:
	for i: int in _live:
		if i == ignore or not is_alive(i):
			continue
		var reach := EnemyTypes.ALL[_defs[i].type_id].radius + bullet_radius
		var closest := Geometry2D.get_closest_point_to_segment(_positions[i], from, to)
		if closest.distance_squared_to(_positions[i]) <= reach * reach:
			return i
	return -1


## Host: hurts object `index`. Returns true if this destroyed it.
func damage(index: int, amount: int, by_peer: int = 1) -> bool:
	if not is_alive(index):
		return false
	if _hp[index] < 0:
		_hp[index] = EnemyTypes.ALL[_defs[index].type_id].max_hp
	damage_by_peer[by_peer] = damage_by_peer.get(by_peer, 0) + mini(amount, _hp[index])
	_hp[index] -= amount
	_flash[index] = FLASH_SECONDS
	if _hp[index] > 0:
		return false
	_set_destroyed(index, by_peer)
	return true


## Client: the host says object `index` was destroyed.
func destroy(index: int) -> void:
	if index >= 0 and index < _defs.size() and _destroyed[index] == 0:
		_set_destroyed(index, 0)


func flash(index: int) -> void:
	if is_alive(index):
		_flash[index] = FLASH_SECONDS


func _set_destroyed(index: int, by_peer: int) -> void:
	_destroyed[index] = 1
	if _on_screen[index] == 1:
		_explosions.append(Vector3(_positions[index].x, _positions[index].y, 0.0))
	destroyed.emit(index, _positions[index], by_peer)


# --- Drawing (gray-box) -----------------------------------------------------------

func _draw() -> void:
	for i: int in _defs.size():
		if _on_screen[i] == 0:
			continue
		var type := EnemyTypes.ALL[_defs[i].type_id]
		var center := _positions[i].round()
		var rect := Rect2(center - type.size / 2.0, type.size)
		if _destroyed[i] == 1:
			_draw_rubble(rect)
			continue
		var color := Color.WHITE if _flash[i] > 0.0 else type.body_color
		match type.key:
			"turret", "heavy_turret":
				draw_rect(rect, OUTLINE)
				draw_rect(rect.grow(-1.0), color.darkened(0.25))
				var dome := PixelArt.disc_texture(type.size.x * 0.32, OUTLINE, type.size.x * 0.32 - 1.0, color)
				draw_texture(dome, center - (Vector2(dome.get_size()) / 2.0).floor())
				_draw_barrel(center, _aims[i], type.barrel_length, type.key == "heavy_turret")
			"tank":
				draw_rect(rect, OUTLINE)
				draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(3, rect.size.y - 2)), BARREL)
				draw_rect(Rect2(rect.end - Vector2(4, rect.size.y - 1), Vector2(3, rect.size.y - 2)), BARREL)
				draw_rect(Rect2(rect.position + Vector2(4, 2), rect.size - Vector2(8, 4)), color)
				_draw_barrel(center, _aims[i], type.barrel_length, false)
			"bunker":
				draw_rect(rect, OUTLINE)
				draw_rect(rect.grow(-1.0), color)
				draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 8), Vector2(rect.size.x - 8, 3)), OUTLINE)
				draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(2, 2)), LIGHT)
			"radar":
				draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 10)), OUTLINE)
				var dish := PixelArt.disc_texture(type.size.x / 2.0, OUTLINE, type.size.x / 2.0 - 1.0, color)
				draw_texture(dish, center - (Vector2(dish.get_size()) / 2.0).floor())
				# The dish turns slowly (purely visual, from stage time).
				var sweep := Vector2.from_angle(_time * 1.5 + i) * (type.size.x / 2.0 - 2.0)
				draw_line(center, center + sweep.round(), OUTLINE, 2.0)
			_:
				draw_rect(rect, color)
	for explosion: Vector3 in _explosions:
		Explosions.draw(self, Vector2(explosion.x, explosion.y), explosion.z / EXPLOSION_SECONDS, 1.6)


func _draw_barrel(center: Vector2, angle: float, length: float, double: bool) -> void:
	if length <= 0.0:
		return
	var tip := Vector2.from_angle(angle) * length
	if double:
		var side := Vector2.from_angle(angle + PI / 2.0) * 2.0
		draw_line(center + side, center + side + tip, BARREL, 2.0)
		draw_line(center - side, center - side + tip, BARREL, 2.0)
	else:
		draw_line(center, center + tip, BARREL, 3.0)


func _draw_rubble(rect: Rect2) -> void:
	draw_rect(rect.grow(-2.0), RUBBLE)
	draw_rect(Rect2(rect.get_center() - Vector2(3, 2), Vector2(6, 4)), SCORCH)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(3, 3)), SCORCH)
	draw_rect(Rect2(rect.end - Vector2(6, 5), Vector2(3, 3)), SCORCH)
