extends Node
## Root scene. The whole game (stage and menus) draws into GameViewport, a
## 960x540 SubViewport (an off-screen canvas). _fit_view() then puts that
## picture on screen, scaled to the window (DESIGN.md §2 Scaling):
##   Sharp:         as big as fits; at fractional sizes (1440p = 2.67x) the
##                  sharp-bilinear shader keeps every game pixel the same size.
##   Pixel-perfect: whole multiples only, black borders around the picture.
## The window itself is not stretched (project setting stretch/mode = disabled).

const SHARP_SHADER: Shader = preload("res://src/main/sharp_bilinear.gdshader")
const SCREENSHOT_EVERY: float = 4.0
const SCREENSHOT_COUNT: int = 3
const SCALING_NAMES: Array[String] = ["sharp", "pixel"]

var _sharp_material: ShaderMaterial = ShaderMaterial.new()

@onready var _view: SubViewportContainer = $GameView


func _ready() -> void:
	LaunchOptions.parse(OS.get_cmdline_user_args())
	LaunchOptions.apply_to_settings()
	Settings.apply()
	if LaunchOptions.window_size != Vector2i.ZERO and DisplayServer.get_name() != "headless":
		get_window().size = LaunchOptions.window_size
		get_window().move_to_center()
	_sharp_material.shader = SHARP_SHADER
	get_window().size_changed.connect(_fit_view)
	Settings.changed.connect(_fit_view)
	_fit_view()
	if not LaunchOptions.screenshot_dir.is_empty():
		_take_screenshots()
	if LaunchOptions.run_for_seconds > 0.0:
		get_tree().create_timer(LaunchOptions.run_for_seconds, true).timeout.connect(get_tree().quit)


func _fit_view() -> void:
	var rect := ScreenFit.fit(get_window().size, Settings.scaling_mode)
	var scale := rect.size.x / ScreenFit.BASE.x
	_view.position = rect.position
	_view.scale = Vector2(scale, scale)
	# Whole-number scales are already perfectly sharp with plain nearest filtering.
	var smooth := Settings.scaling_mode == ScreenFit.Mode.SHARP and not ScreenFit.is_whole(scale)
	_view.material = _sharp_material if smooth else null
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	_sharp_material.set_shader_parameter("scale", scale)


static func save_screenshot(tree: SceneTree, file_name: String) -> void:
	if LaunchOptions.screenshot_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := LaunchOptions.screenshot_dir.path_join(file_name)
	tree.root.get_texture().get_image().save_png(path)
	print("Saved screenshot %s" % path)


## --screenshot-dir: a few gameplay pictures named after the window size and scaling mode.
func _take_screenshots() -> void:
	var size := get_window().size
	for index: int in range(1, SCREENSHOT_COUNT + 1):
		await get_tree().create_timer(SCREENSHOT_EVERY, true).timeout
		var file := "%dx%d_%s_%d.png" % [size.x, size.y, SCALING_NAMES[Settings.scaling_mode], index]
		await save_screenshot(get_tree(), file)
	# Then the pause menu and its settings page.
	var pause_menu := $GameView/GameViewport/PauseMenu as PauseMenu
	pause_menu.open()
	await save_screenshot(get_tree(), "pause_menu.png")
	pause_menu.open_settings()
	await save_screenshot(get_tree(), "settings.png")
	pause_menu.close()
