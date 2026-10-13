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



func test_every_shape_has_a_name() -> void:
	assert_eq(PathShapes.NAMES.size(), PathShapes.Id.size())
	assert_eq(PathShapes.from_name("hover_leave"), PathShapes.Id.HOVER_LEAVE)
	assert_eq(PathShapes.from_name("nope"), -1)


func test_every_shape_starts_at_its_origin_and_moves_smoothly() -> void:
	for shape: int in PathShapes.Id.size():
		for mirror: bool in [false, true]:
			assert_eq(PathShapes.position(shape as PathShapes.Id, 0.0, ORIGIN, mirror), ORIGIN, PathShapes.NAMES[shape])
			var previous := ORIGIN
			var worst := 0.0
			for i: int in range(1, 600):
				var now := PathShapes.position(shape as PathShapes.Id, i / 60.0, ORIGIN, mirror)
				worst = maxf(worst, now.distance_to(previous))
				previous = now
			# No jumps between ticks: at most 8 px per tick (480 px/s; dives are fast).
			assert_lt(worst, 8.0, "%s moves at most %.2f px per tick" % [PathShapes.NAMES[shape], worst])


func test_every_shape_eventually_leaves_the_screen() -> void:
	var area := Rect2(0, 0, 960, 540).grow(EnemyManager.LEAVE_MARGIN)
	for shape: int in PathShapes.Id.size():
		var origin := Vector2(-20, 100) if shape == PathShapes.Id.CROSS_SCREEN else ORIGIN
		var gone := not area.has_point(PathShapes.position(shape as PathShapes.Id, 30.0, origin))
		assert_true(gone, "%s leaves within 30 s" % PathShapes.NAMES[shape])


func test_circle_strafe_comes_back_to_where_its_loop_started() -> void:
	var entry := PathShapes.CIRCLE_ENTRY / PathShapes.CIRCLE_SPEED
	var start := PathShapes.position(PathShapes.Id.CIRCLE_STRAFE, entry, ORIGIN)
	var end := PathShapes.position(PathShapes.Id.CIRCLE_STRAFE, entry + PathShapes.CIRCLE_SECONDS, ORIGIN)
	assert_almost_eq(end.x, start.x, 0.01)
	assert_almost_eq(end.y, start.y, 0.01)
