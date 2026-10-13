extends GutTest
## Ground objects: placed by the stage file, scrolled by stage time, destroyed
## by the host and announced by index.

const STAGE: String = """
scroll_speed = 60
ground 2 turret x=200
ground 2 tank x=600
ground 3 bunker x=480
"""

var ground: GroundManager


func before_each() -> void:
	ground = GroundManager.new()
	add_child_autofree(ground)
	ground.setup(StageDef.parse(STAGE))


func _no_ships() -> PackedVector2Array:
	return PackedVector2Array()


func test_objects_scroll_in_at_their_time() -> void:
	var turret_size := EnemyTypes.ALL[EnemyTypes.from_key("turret")].size
	assert_eq(ground.position_at(0, 2.0), Vector2(200, -turret_size.y / 2.0), "at the top edge")
	assert_eq(ground.position_at(0, 4.0).y, ground.position_at(0, 2.0).y + 120.0, "60 px/s")


func test_tanks_drive_along_the_map() -> void:
	var drift := EnemyTypes.ALL[EnemyTypes.from_key("tank")].drift
	assert_almost_eq(ground.position_at(1, 4.0).y - ground.position_at(1, 2.0).y, 120.0 + drift.y * 2.0, 0.001)


func test_objects_off_screen_cannot_be_hit() -> void:
	ground.tick(0.0, 0.0, _no_ships(), 1.0)
	assert_false(ground.is_alive(0))
	ground.tick(5.0, 0.0, _no_ships(), 1.0)
	assert_true(ground.is_alive(0))


func test_host_destroys_an_object_and_rubble_stays() -> void:
	ground.tick(5.0, 0.0, _no_ships(), 1.0)
	watch_signals(ground)
	assert_true(ground.damage(2, 9999, 7))
	assert_true(ground.is_destroyed(2))
	assert_false(ground.is_alive(2))
	assert_signal_emitted_with_parameters(ground, "destroyed", [2, ground.position_of(2), 7])
	assert_eq(ground.destroyed_indices(), PackedInt32Array([2]))


func test_client_destroys_by_index() -> void:
	ground.destroy(1)
	assert_true(ground.is_destroyed(1))
	ground.destroy(99)  # Unknown ids are ignored.
	assert_eq(ground.destroyed_count(), 1)


func test_co_op_hp_scaling_applies_when_an_object_appears() -> void:
	var hp := EnemyTypes.ALL[EnemyTypes.from_key("bunker")].max_hp
	ground.tick(5.0, 0.0, _no_ships(), 1.6)
	assert_false(ground.damage(2, roundi(hp * 1.6) - 1))
	assert_true(ground.damage(2, 1))


func test_turrets_fire_but_bunkers_have_no_gun() -> void:
	var ships := PackedVector2Array([Vector2(200, 400)])
	ground.tick(4.0, 0.0, ships, 1.0)
	var delay := EnemyTypes.ALL[EnemyTypes.from_key("turret")].first_shot_delay
	ground.tick(4.0 + delay, 0.0, ships, 1.0)
	var ready := ground.take_ready_guns(4.0 + delay)
	assert_true(ready.has(0))
	assert_false(ready.has(2))


func test_player_bullets_hit_ground_objects() -> void:
	var enemies := EnemyManager.new()
	var bullets := ProjectileManager.new()
	add_child_autofree(enemies)
	add_child_autofree(bullets)
	ground.tick(5.0, 0.0, _no_ships(), 1.0)
	var target := ground.position_of(2)
	bullets.spawn(target + Vector2(0, 30), Vector2(0, -6000), 9999, 1.0, 3)
	bullets.step(1.0 / 60.0)
	bullets.resolve_hits(enemies, ground, true)
	assert_true(ground.is_destroyed(2))
	assert_eq(ground.damage_by_peer.keys(), [3])


func test_nearest_point() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(100, 0)])
	assert_eq(GroundManager.nearest(Vector2(12, 0), points), Vector2(10, 0))
	assert_eq(GroundManager.nearest(Vector2.ZERO, PackedVector2Array()), Vector2.INF)
