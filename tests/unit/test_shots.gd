extends GutTest
## The ship's shot patterns and the bullet pool hitting enemies.

const UP: float = -PI / 2.0


func test_spread_is_a_straight_stream_and_two_angled_ones() -> void:
	var angles := ShotPatterns.angles(ShotPatterns.Id.SHIP_SPREAD, UP, 1)
	assert_eq(angles.size(), 3)
	assert_almost_eq(angles[0], UP, 0.0001)
	assert_almost_eq(angles[1], UP - deg_to_rad(ShotPatterns.SPREAD_DEGREES), 0.0001)
	assert_almost_eq(angles[2], UP + deg_to_rad(ShotPatterns.SPREAD_DEGREES), 0.0001)


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
	enemies.max_hp = 10
	var index := enemies.spawn(PathShapes.Id.S_CURVE, 0.0, Vector2(100, 100))
	enemies.tick(0.0, 0.0)
	# Fast enough to jump past the enemy in one tick: the path check must still catch it.
	bullets.spawn(Vector2(100, 160), Vector2(0, -6000), 10, 1.0, 1)
	bullets.step(1.0 / 60.0)
	bullets.resolve_hits(enemies, true)
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
	var index := enemies.spawn(PathShapes.Id.S_CURVE, 5.0, Vector2(100, 100))
	enemies.tick(1.0, 1.0)
	assert_false(enemies.is_alive(index))
	assert_eq(enemies.find_hit_on_path(Vector2(100, 120), Vector2(100, 80), 2.0), -1)
