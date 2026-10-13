extends GutTest
## Sharp and Pixel-perfect scaling (DESIGN.md §2 Scaling).


func test_1080p_is_exactly_2x_in_both_modes() -> void:
	for mode: ScreenFit.Mode in [ScreenFit.Mode.SHARP, ScreenFit.Mode.PIXEL_PERFECT]:
		assert_eq(ScreenFit.fit(Vector2i(1920, 1080), mode), Rect2(0, 0, 1920, 1080))


func test_4k_is_exactly_4x() -> void:
	assert_eq(ScreenFit.fit(Vector2i(3840, 2160), ScreenFit.Mode.PIXEL_PERFECT), Rect2(0, 0, 3840, 2160))


func test_1440p_sharp_fills_the_screen() -> void:
	var rect := ScreenFit.fit(Vector2i(2560, 1440), ScreenFit.Mode.SHARP)
	assert_eq(rect.position, Vector2.ZERO)
	assert_almost_eq(rect.size.x, 2560.0, 0.01)
	assert_almost_eq(rect.size.y, 1440.0, 0.01)
	assert_false(ScreenFit.is_whole(rect.size.x / ScreenFit.BASE.x))


func test_1440p_pixel_perfect_is_2x_with_borders() -> void:
	assert_eq(ScreenFit.fit(Vector2i(2560, 1440), ScreenFit.Mode.PIXEL_PERFECT), Rect2(320, 180, 1920, 1080))


func test_wider_screen_gets_side_borders() -> void:
	var rect := ScreenFit.fit(Vector2i(2560, 1080), ScreenFit.Mode.SHARP)
	assert_eq(rect, Rect2(320, 0, 1920, 1080))


func test_window_smaller_than_the_game_shrinks_even_in_pixel_perfect() -> void:
	var rect := ScreenFit.fit(Vector2i(800, 450), ScreenFit.Mode.PIXEL_PERFECT)
	assert_almost_eq(rect.size.x, 800.0, 0.01)
