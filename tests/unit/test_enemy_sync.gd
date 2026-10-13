extends GutTest
## Enemies are spawn records: a client given the host's records computes the
## same positions from the stage clock alone, and deaths are events.

var host: EnemyManager
var client: EnemyManager


func before_each() -> void:
	host = EnemyManager.new()
	client = EnemyManager.new()
	add_child_autofree(host)
	add_child_autofree(client)


func _copy_records(from: EnemyManager, to: EnemyManager) -> void:
	var all: Array = from.records()
	var indices: PackedInt32Array = all[0]
	for r: int in indices.size():
		to.spawn_at(indices[r], (all[1] as PackedInt32Array)[r] as PathShapes.Id, (all[2] as PackedFloat32Array)[r],
			(all[3] as PackedVector2Array)[r], (all[4] as PackedByteArray)[r] == 1)


func test_client_with_the_host_records_sees_the_same_enemies() -> void:
	host.spawn(PathShapes.Id.S_CURVE, 1.0, Vector2(300, -16))
	host.spawn(PathShapes.Id.S_CURVE, 1.5, Vector2(660, -16), true)
	_copy_records(host, client)
	host.tick(3.2, 0.1)
	client.tick(3.2, 0.1)
	for i: int in EnemyManager.CAPACITY:
		assert_eq(client.is_alive(i), host.is_alive(i))
		if host.is_alive(i):
			assert_eq(client.position_of(i), host.position_of(i))


func test_records_keep_the_host_pool_index() -> void:
	host.spawn(PathShapes.Id.S_CURVE, 0.0, Vector2(100, 0))
	var second := host.spawn(PathShapes.Id.S_CURVE, 0.0, Vector2(200, 0))
	_copy_records(host, client)
	client.tick(0.5, 0.5)
	host.tick(0.5, 0.5)
	assert_eq(client.position_of(second), host.position_of(second))


func test_records_are_empty_with_no_enemies() -> void:
	var indices: PackedInt32Array = host.records()[0]
	assert_eq(indices.size(), 0)


func test_kill_event_removes_the_enemy_on_the_client() -> void:
	var index := host.spawn(PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100))
	_copy_records(host, client)
	client.tick(0.1, 0.1)
	watch_signals(client)
	client.kill(index)
	assert_false(client.is_alive(index))
	assert_signal_emitted(client, "killed")


func test_client_hits_only_flash() -> void:
	var index := client.spawn(PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100))
	client.tick(0.0, 0.0)
	client.flash(index)
	assert_true(client.is_alive(index))
	assert_eq(client.hp_of(index), client.max_hp)


func test_host_counts_damage_by_peer() -> void:
	host.max_hp = 10
	var index := host.spawn(PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100))
	host.tick(0.0, 0.0)
	host.damage(index, 4, 42)
	assert_true(host.damage(index, 99, 7))
	assert_eq(host.damage_by_peer, {42: 4, 7: 6} as Dictionary[int, int])
