extends GutTest
## The ship's shot patterns and the bullet pool hitting enemies.

const UP: float = -PI / 2.0


func test_spread_is_a_straight_stream_and_two_angled_ones() -> void:
	var angles := ShotPatterns.angles(ShotPatterns.Id.SHIP_SPREAD, UP, 1)
	assert_eq(angles.size(), 3)
	assert_almost_eq(angles[0], UP, 0.0001)
	assert_almost_eq(angles[1], UP - deg_to_rad(ShotPatterns.SPREAD_DEGREES[0]), 0.0001)
	assert_almost_eq(angles[2], UP + deg_to_rad(ShotPatterns.SPREAD_DEGREES[0]), 0.0001)


func test_focus_is_two_parallel_streams() -> void:
	var bullets := ShotPatterns.build(ShotPatterns.Id.SHIP_FOCUS, UP, 1, 1, 600.0)
	assert_eq(bullets.size(), 2 * ShotPatterns.STRIDE)
	assert_almost_eq(bullets[0], UP, 0.0001)
	assert_almost_eq(bullets[ShotPatterns.STRIDE], UP, 0.0001)
	var gap := absf(bullets[3] - bullets[ShotPatterns.STRIDE + 3])
	assert_almost_eq(gap, ShotPatterns.FOCUS_GAP, 0.001)


func test_patterns_are_deterministic() -> void:
	assert_eq(ShotPatterns.build(ShotPatterns.Id.SHIP_SPREAD, UP, 42, 1, 600.0), ShotPatterns.build(ShotPatterns.Id.SHIP_SPREAD, UP, 42, 1, 600.0))


func test_bullet_kills_an_enemy_in_its_path() -> void:
	var enemies := EnemyManager.new()
	var bullets := ProjectileManager.new()
	add_child_autofree(enemies)
	add_child_autofree(bullets)
	var index := enemies.spawn(EnemyTypes.from_key("drone"), PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100))
	enemies.tick(0.0, 0.0)
	# Fast enough to jump past the enemy in one tick: the path check must still catch it.
	bullets.spawn(Vector2(100, 160), Vector2(0, -6000), 999, 1.0, 1)
	bullets.step(1.0 / 60.0)
	bullets.resolve_hits(enemies, null, true)
	assert_false(enemies.is_alive(index))
	assert_eq(bullets.count(), 0)


func test_bullets_leaving_the_screen_are_removed() -> void:
	var bullets := ProjectileManager.new()
	add_child_autofree(bullets)
	bullets.bounds = Rect2(0, 0, 960, 540)
	bullets.spawn(Vector2(100, 10), Vector2(0, -600), 1, 5.0, 1)
	bullets.step(0.1)
	assert_eq(bullets.count(), 0)


func test_enemy_not_yet_appeared_cannot_be_hit() -> void:
	var enemies := EnemyManager.new()
	add_child_autofree(enemies)
	var index := enemies.spawn(EnemyTypes.from_key("drone"), PathShapes.Id.S_CURVE, 5.0, Vector2(100, 100))
	enemies.tick(1.0, 1.0)
	assert_false(enemies.is_alive(index))
	assert_eq(enemies.find_hit_on_path(Vector2(100, 120), Vector2(100, 80), 2.0), -1)


func test_enemy_patterns_are_slow_and_readable() -> void:
	for pattern: int in ShotPatterns.Id.size():
		if ShotPatterns.is_ship_pattern(pattern) or pattern == ShotPatterns.Id.LASER:
			continue  # The laser is fast, but comes after a warning line.
		var bullets := ShotPatterns.build(pattern as ShotPatterns.Id, PI / 2.0, 7)
		assert_gt(bullets.size(), 0, "pattern %d fires something" % pattern)
		for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
			assert_lte(bullets[i + 1], ShotPatterns.FAST, "pattern %d is not too fast" % pattern)


func test_aimed_shot_flies_at_the_target() -> void:
	var angles := ShotPatterns.angles(ShotPatterns.Id.AIMED, 1.0, 3)
	assert_almost_eq(angles[0], 1.0, 0.0001)


func _ship_at(at: Vector2) -> Ship:
	var ship := Ship.new()
	ship.setup(1, 0, 0, at, Rect2(0, 0, 960, 540))
	add_child_autofree(ship)
	return ship


func test_enemy_bullet_hurts_a_ship_once_then_it_blinks() -> void:
	var ship := _ship_at(Vector2(100, 100))
	var bullets := ProjectileManager.new()
	add_child_autofree(bullets)
	bullets.spawn(Vector2(100, 99), Vector2.ZERO, 12, 5.0, 0)
	bullets.spawn(Vector2(101, 100), Vector2.ZERO, 12, 5.0, 0)
	bullets.step(0.01)
	var ships: Array[Ship] = [ship]
	bullets.resolve_ship_hits(ships, true)
	assert_eq(ship.health.hp, ship.stats.max_hp - 12, "the second bullet passed through the blinking ship")
	assert_true(ship.health.is_invulnerable())


func test_bullets_miss_outside_the_tiny_hitbox() -> void:
	var ship := _ship_at(Vector2(100, 100))
	var bullets := ProjectileManager.new()
	add_child_autofree(bullets)
	# Well inside the 23 px sprite, but outside the hitbox.
	bullets.spawn(Vector2(108, 100), Vector2.ZERO, 12, 5.0, 0)
	bullets.step(0.01)
	var ships: Array[Ship] = [ship]
	bullets.resolve_ship_hits(ships, true)
	assert_eq(ship.health.hp, ship.stats.max_hp)
