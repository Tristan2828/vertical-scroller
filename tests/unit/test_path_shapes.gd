extends GutTest
## Named enemy flight paths must be pure functions of time (every peer computes them).

const ORIGIN: Vector2 = Vector2(300, -16)


func test_s_curve_starts_at_its_origin() -> void:
	assert_eq(PathShapes.position(PathShapes.Id.S_CURVE, 0.0, ORIGIN), ORIGIN)


func test_s_curve_flies_down_the_screen() -> void:
	var previous := PathShapes.position(PathShapes.Id.S_CURVE, 0.0, ORIGIN)
	for i: int in range(1, 100):
		var now := PathShapes.position(PathShapes.Id.S_CURVE, i * 0.1, ORIGIN)
		assert_gt(now.y, previous.y)
		previous = now


func test_s_curve_sways_both_ways_within_its_width() -> void:
	var min_x := INF
	var max_x := -INF
	for i: int in 100:
		var x := PathShapes.position(PathShapes.Id.S_CURVE, i * 0.1, ORIGIN).x
		min_x = minf(min_x, x)
		max_x = maxf(max_x, x)
	assert_lt(min_x, ORIGIN.x - PathShapes.S_CURVE_WIDTH * 0.9)
	assert_gt(max_x, ORIGIN.x + PathShapes.S_CURVE_WIDTH * 0.9)


func test_mirror_flips_left_and_right() -> void:
	for age: float in [0.3, 1.1, 2.7]:
		var normal := PathShapes.position(PathShapes.Id.S_CURVE, age, ORIGIN)
		var mirrored := PathShapes.position(PathShapes.Id.S_CURVE, age, ORIGIN, true)
		assert_almost_eq(mirrored.x - ORIGIN.x, -(normal.x - ORIGIN.x), 0.001)
		assert_eq(mirrored.y, normal.y)


func test_same_time_same_place() -> void:
	assert_eq(PathShapes.position(PathShapes.Id.S_CURVE, 1.234, ORIGIN), PathShapes.position(PathShapes.Id.S_CURVE, 1.234, ORIGIN))
