class_name Main
extends Node
## Root scene. Shows the title menu, starts solo/host/join sessions, and owns
## the `Level` slot. The host puts the lobby or the stage into that slot;
## `LevelSpawner` (a MultiplayerSpawner) then recreates it automatically on every
## client, including friends who join later. (Session flow from Medieval Survival.)
##
## The whole game draws into GameViewport, a 960x540 SubViewport (an off-screen
## canvas). _fit_view() then puts that picture on screen, scaled to the window
## (DESIGN.md §2 Scaling):
##   Sharp:         as big as fits; at fractional sizes (1440p = 2.67x) the
##                  sharp-bilinear shader keeps every game pixel the same size.
##   Pixel-perfect: whole multiples only, black borders around the picture.
## The window itself is not stretched (project setting stretch/mode = disabled).

const STAGE_SCENE: PackedScene = preload("res://src/stage/stage.tscn")
const LOBBY_SCENE: PackedScene = preload("res://src/lobby/lobby.tscn")
const SHARP_SHADER: Shader = preload("res://src/main/sharp_bilinear.gdshader")
const SCREENSHOT_EVERY: float = 4.0
const SCREENSHOT_COUNT: int = 3
const SCALING_NAMES: Array[String] = ["sharp", "pixel"]

var _sharp_material: ShaderMaterial = ShaderMaterial.new()

@onready var _view: SubViewportContainer = $GameView
@onready var _level: Node = $GameView/GameViewport/Level
@onready var _menu: MainMenu = $GameView/GameViewport/MainMenu
@onready var _pause_menu: PauseMenu = $GameView/GameViewport/PauseMenu


func _ready() -> void:
	LaunchOptions.parse(OS.get_cmdline_user_args())
	LaunchOptions.apply_to_settings()
	Settings.apply()
	if LaunchOptions.window_size != Vector2i.ZERO and DisplayServer.get_name() != "headless":
		get_window().size = LaunchOptions.window_size
		if LaunchOptions.window_at.x >= 0:
			get_window().position = DisplayServer.screen_get_position(get_window().current_screen) + LaunchOptions.window_at
		else:
			get_window().move_to_center()
	_sharp_material.shader = SHARP_SHADER
	get_window().size_changed.connect(_fit_view)
	Settings.changed.connect(_fit_view)
	_fit_view()
	_menu.solo_requested.connect(_start_solo)
	_menu.host_requested.connect(_start_host)
	_menu.join_requested.connect(_start_join)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_pause_menu.leave_requested.connect(_leave_game.bind("You left the game."))
	# Clients get the lobby / stage from LevelSpawner: hide the menu when it arrives.
	_level.child_entered_tree.connect(func(node: Node) -> void:
		_menu.hide()
		_pause_menu.allowed = true
		var lobby := node as Lobby
		if lobby != null and not multiplayer.is_server():
			lobby.leave_requested.connect(_leave_game.bind("You left the game.")))
	_menu.show_menu()
	_apply_launch_options()


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


func _apply_launch_options() -> void:
	match LaunchOptions.mode:
		LaunchOptions.Mode.SOLO:
			_start_solo()
		LaunchOptions.Mode.HOST:
			_start_host(LaunchOptions.port)
		LaunchOptions.Mode.JOIN:
			var invite: Dictionary = Net.parse_invite(LaunchOptions.address, LaunchOptions.port)
			_start_join(invite["address"], invite["port"])
	if not LaunchOptions.screenshot_dir.is_empty():
		_take_screenshots()
	if LaunchOptions.run_for_seconds > 0.0:
		get_tree().create_timer(LaunchOptions.run_for_seconds, true).timeout.connect(_report_and_quit)


# --- Sessions ------------------------------------------------------------------

func _start_solo() -> void:
	Net.start_solo()
	_load_lobby()


func _start_host(port: int) -> void:
	var err: Error = Net.host_game(port, not LaunchOptions.local_only)
	if err != OK:
		_menu.show_menu("Could not host on port %d: %s" % [port, error_string(err)])
		return
	print("Hosting on port %d" % port)
	_load_lobby()


func _start_join(address: String, port: int) -> void:
	var err: Error = Net.join_game(address, port)
	if err != OK:
		_menu.show_menu("Could not connect: %s" % error_string(err))
		return
	_menu.show_busy("Connecting to %s:%d..." % [address, port])


func _on_connected_to_server() -> void:
	# Nothing to load here: the host's LevelSpawner sends us the lobby or stage.
	print("Connected as peer %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	Net.leave_game()
	_menu.show_menu("Could not connect to the host.")


func _on_server_disconnected() -> void:
	_leave_game("Disconnected from the host.")


## Host: show the lobby (start of a session).
func _load_lobby() -> void:
	_clear_level()
	var lobby: Lobby = LOBBY_SCENE.instantiate()
	# Deferred: swap scenes after the current frame, never in the middle of one.
	lobby.start_requested.connect(_load_stage, CONNECT_DEFERRED)
	lobby.leave_requested.connect(_leave_game.bind(""), CONNECT_DEFERRED)
	_level.add_child(lobby)


## Host: start the stage. LevelSpawner removes the lobby and creates the stage
## on every client too.
func _load_stage() -> void:
	_clear_level()
	_level.add_child(STAGE_SCENE.instantiate())


func _clear_level() -> void:
	for child: Node in _level.get_children():
		_level.remove_child(child)
		child.queue_free()


func _leave_game(message: String) -> void:
	_pause_menu.close()
	_pause_menu.allowed = false
	Net.leave_game()
	_clear_level()
	_menu.show_menu(message)


func _report_and_quit() -> void:
	var stage := _level.get_node_or_null("Stage") as Stage
	var lobby := _level.get_node_or_null("Lobby") as Lobby
	if stage != null:
		print(stage.debug_report())
	elif lobby != null:
		print(lobby.debug_report())
	else:
		print("[report] peer %d: nothing loaded" % multiplayer.get_unique_id())
	Net.leave_game()
	get_tree().quit()


# --- Screenshots -----------------------------------------------------------------

static func save_screenshot(tree: SceneTree, file_name: String) -> void:
	if LaunchOptions.screenshot_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := LaunchOptions.screenshot_dir.path_join(file_name)
	tree.root.get_texture().get_image().save_png(path)
	print("Saved screenshot %s" % path)


## --screenshot-dir: the title menu (no mode flag) or the lobby, then gameplay
## pictures named after the window size and scaling mode, then the pause menu.
## Clients add "_client" so a host and a client can share one folder.
func _take_screenshots() -> void:
	var role := "_client" if LaunchOptions.mode == LaunchOptions.Mode.JOIN else ""
	await get_tree().create_timer(1.5, true).timeout
	if LaunchOptions.mode == LaunchOptions.Mode.MENU:
		await save_screenshot(get_tree(), "title.png")
		return
	await save_screenshot(get_tree(), "lobby%s.png" % role)
	while _level.get_node_or_null("Stage") == null:
		await get_tree().create_timer(0.5, true).timeout
	var size := get_window().size
	for index: int in range(1, SCREENSHOT_COUNT + 1):
		await get_tree().create_timer(SCREENSHOT_EVERY, true).timeout
		var file := "%dx%d_%s%s_%d.png" % [size.x, size.y, SCALING_NAMES[Settings.scaling_mode], role, index]
		await save_screenshot(get_tree(), file)
	_pause_menu.open()
	await save_screenshot(get_tree(), "pause_menu%s.png" % role)
	_pause_menu.open_settings()
	await save_screenshot(get_tree(), "settings%s.png" % role)
	_pause_menu.close()
