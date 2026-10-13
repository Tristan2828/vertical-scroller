extends GutTest
## Guards the project settings that the rest of the game relies on (DESIGN.md §2).


func test_base_resolution_is_960x540() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), ScreenFit.BASE.x)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), ScreenFit.BASE.y)
	assert_eq(ScreenFit.BASE, Vector2i(960, 540))


func test_window_is_not_stretched_main_scales_the_game_itself() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "disabled")


func test_pixel_art_uses_nearest_filtering() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_untyped_declarations_are_errors() -> void:
	assert_eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"), 2)


func test_main_scene_draws_the_game_at_base_size_with_nearest_filtering() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var main := (load(path) as PackedScene).instantiate()
	add_child_autofree(main)
	var viewport := main.get_node("GameView/GameViewport") as SubViewport
	assert_eq(viewport.size, ScreenFit.BASE)
	# A SubViewport's own default is linear (blurry), not the project setting.
	assert_eq(viewport.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
