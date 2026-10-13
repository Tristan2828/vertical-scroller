extends GutTest
## Guards the project settings that the rest of the game relies on (DESIGN.md §2).


func test_base_resolution_is_960x540() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 960)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 540)


func test_stretch_renders_at_base_resolution() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport")


func test_pixel_art_uses_nearest_filtering() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_untyped_declarations_are_errors() -> void:
	assert_eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"), 2)


func test_main_scene_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var scene := load(path) as PackedScene
	assert_not_null(scene)
	var main := scene.instantiate()
	add_child_autofree(main)
	assert_eq(main.name, &"Main")
