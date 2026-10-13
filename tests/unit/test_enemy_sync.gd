extends GutTest
## Enemies are spawn records: a client given the host's records computes the
## same positions from the stage clock alone; redirects and deaths are events.

var host: EnemyManager
var client: EnemyManager
var drone: int
var kamikaze: int


func before_each() -> void:
	host = EnemyManager.new()
	client = EnemyManager.new()
	add_child_autofree(host)
	add_child_autofree(client)
	drone = EnemyTypes.from_key("drone")
	kamikaze = EnemyTypes.from_key("kamikaze")


func test_client_with_the_host_records_sees_the_same_enemies() -> void:
	host.spawn(drone, PathShapes.Id.S_CURVE, 1.0, Vector2(300, -16))
	host.spawn(drone, PathShapes.Id.CIRCLE_STRAFE, 1.5, Vector2(660, -16), true, 1.3)
	client.apply_records(host.records())
	host.tick(3.2, 0.1)
	client.tick(3.2, 0.1)
	for i: int in EnemyManager.CAPACITY:
		assert_eq(client.is_alive(i), host.is_alive(i))
		if host.is_alive(i):
			assert_eq(client.position_of(i), host.position_of(i))


func test_records_keep_the_host_pool_index() -> void:
	host.spawn(drone, PathShapes.Id.S_CURVE, 0.0, Vector2(100, 0))
	var second := host.spawn(drone, PathShapes.Id.S_CURVE, 0.0, Vector2(200, 0))
	client.apply_records(host.records(PackedInt32Array([second])))
	client.tick(0.5, 0.5)
	host.tick(0.5, 0.5)
	assert_eq(client.position_of(second), host.position_of(second))
	assert_false(client.is_alive(0), "only the asked-for record was sent")


func test_records_are_empty_with_no_enemies() -> void:
	var data := host.records()
	assert_eq(data.size(), 12)
	assert_eq((data[0] as PackedInt32Array).size(), 0)
	client.apply_records(data)
	assert_eq(client.active_count(), 0)


func test_redirect_flies_straight_and_late_joiners_get_it() -> void:
	var index := host.spawn(kamikaze, PathShapes.Id.STRAIGHT, 0.0, Vector2(100, 0))
	host.tick(1.0, 1.0)
	var at := host.position_of(index)
	host.redirect(index, 1.0, at, at + Vector2(0, 100), 200.0, true)
	client.apply_records(host.records())
	host.tick(1.5, 0.5)
	client.tick(1.5, 0.5)
	assert_almost_eq(host.position_of(index).y, at.y + 100.0, 0.01, "200 px/s for half a second")
	assert_eq(client.position_of(index), host.position_of(index))


func test_redirect_that_stops_at_its_target() -> void:
	var index := host.spawn(drone, PathShapes.Id.STRAIGHT, 0.0, Vector2(100, 0))
	host.redirect(index, 0.0, Vector2(100, 0), Vector2(150, 0), 100.0, false)
	host.tick(5.0, 0.1)
	assert_eq(host.position_of(index), Vector2(150, 0))


func test_kill_event_removes_the_enemy_on_the_client() -> void:
	var index := host.spawn(drone, PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100))
	client.apply_records(host.records())
	client.tick(0.1, 0.1)
	watch_signals(client)
	client.kill(index)
	assert_false(client.is_alive(index))
	assert_signal_emitted(client, "killed")


func test_client_hits_only_flash() -> void:
	var index := client.spawn(drone, PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100))
	client.tick(0.0, 0.0)
	client.flash(index)
	assert_true(client.is_alive(index))
	assert_eq(client.hp_of(index), EnemyTypes.ALL[drone].max_hp)


func test_host_counts_damage_by_peer() -> void:
	var index := host.spawn(drone, PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100))
	host.tick(0.0, 0.0)
	host.damage(index, 4, 42)
	assert_true(host.damage(index, 999, 7))
	assert_eq(host.damage_by_peer, {42: 4, 7: EnemyTypes.ALL[drone].max_hp - 4} as Dictionary[int, int])


func test_co_op_hp_scaling() -> void:
	var index := host.spawn(drone, PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100), false, 1.0, 1.6)
	assert_eq(host.hp_of(index), roundi(EnemyTypes.ALL[drone].max_hp * 1.6))


func test_guns_wait_their_first_delay_then_their_interval() -> void:
	var fighter := EnemyTypes.from_key("fighter")
	var delay := EnemyTypes.ALL[fighter].first_shot_delay
	var index := host.spawn(fighter, PathShapes.Id.STRAIGHT, 0.0, Vector2(400, 100))
	host.tick(delay - 0.05, 0.1)
	assert_false(host.take_ready_guns(delay - 0.05).has(index))
	host.tick(delay + 0.01, 0.1)
	assert_true(host.take_ready_guns(delay + 0.01).has(index))
	assert_false(host.take_ready_guns(delay + 0.02).has(index), "then it waits a fire interval")


func test_guns_hold_fire_low_on_the_screen() -> void:
	var fighter := EnemyTypes.from_key("fighter")
	var delay := EnemyTypes.ALL[fighter].first_shot_delay
	var index := host.spawn(fighter, PathShapes.Id.STRAIGHT, 0.0, Vector2(400, 450))
	host.tick(delay + 0.01, 0.1)
	assert_true(host.is_alive(index))
	assert_false(host.take_ready_guns(delay + 0.01).has(index), "no point-blank shots from behind the ships")
