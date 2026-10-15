class_name Main
extends Node
## Root scene. Shows the title menu, starts solo/host/join sessions, and owns
## the `Level` slot. The host puts the lobby, a stage, the shop or the run
## summary into that slot through `LevelSpawner` (a MultiplayerSpawner), which
## recreates it on every client, including friends who join later. The spawn
## data carries the run (RunState) so clients have it before the scene starts.
## (Session flow from Medieval Survival.)
##
## A run: lobby -> stage -> shop -> stage ... -> run summary -> lobby.
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
const SHOP_SCENE: PackedScene = preload("res://src/shop/shop.tscn")
const SUMMARY_SCENE: PackedScene = preload("res://src/ui/run_summary.tscn")
const SCENES: Dictionary[String, PackedScene] = {
	"lobby": LOBBY_SCENE, "stage": STAGE_SCENE, "shop": SHOP_SCENE, "summary": SUMMARY_SCENE,
}
const SHARP_SHADER: Shader = preload("res://src/main/sharp_bilinear.gdshader")
const SCREENSHOT_EVERY: float = 4.0
const SCREENSHOT_COUNT: int = 3
const SCALING_NAMES: Array[String] = ["sharp", "pixel"]

var _sharp_material: ShaderMaterial = ShaderMaterial.new()
var _run_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _feedback: FeedbackScreen = null

@onready var _view: SubViewportContainer = $GameView
@onready var _game_viewport: SubViewport = $GameView/GameViewport
@onready var _level: Node = $GameView/GameViewport/Level
@onready var _level_spawner: MultiplayerSpawner = $GameView/GameViewport/LevelSpawner
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
	# Every peer needs the spawn function (clients run it when a spawn arrives).
	_level_spawner.spawn_function = _spawn_level
	_run_rng.randomize()
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
	_feedback = FeedbackScreen.new()
	_game_viewport.add_child(_feedback)
	_menu.feedback_requested.connect(func() -> void: _feedback.open(null, _feedback_context()))
	_pause_menu.feedback_requested.connect(_open_feedback_from_pause)
	_feedback.closed.connect(func() -> void:
		if _menu.visible:
			_menu.show_panel_after_feedback()
		elif _level.get_child_count() > 0:
			_pause_menu.show_after_feedback())
	# Clients get the lobby / stage from LevelSpawner: hide the menu when it arrives.
	_level.child_entered_tree.connect(func(node: Node) -> void:
		_screenshot_scene(node)
		_menu.hide()
		_pause_menu.allowed = true
		var lobby := node as Lobby
		if lobby != null and not multiplayer.is_server():
			lobby.leave_requested.connect(_leave_game.bind("You left the game.")))
	_menu.show_menu()
	Music.play(&"menu")
	# Every button anywhere clicks softly when pressed (menus, lobby, shop).
	get_tree().node_added.connect(func(node: Node) -> void:
		var button := node as BaseButton
		if button != null:
			button.pressed.connect(func() -> void: Sfx.play(&"ui", -8.0)))
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


## From the pause menu: hide it for a moment so the screenshot shows the game.
func _open_feedback_from_pause() -> void:
	_pause_menu.hide()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _game_viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)  # The SubViewport's picture has an alpha channel.
	_feedback.open(image, _feedback_context())


## Version, OS and where the player is (title menu, lobby, shop, or the stage's details).
func _feedback_context() -> String:
	var where := "Title menu"
	var scene := _level.get_child(0) if _level.get_child_count() > 0 else null
	if scene is Stage:
		where = (scene as Stage).feedback_context()
	elif scene != null:
		var run := RunState.current
		where = "In the %s (%s), %d of %d stages done" % [String(scene.name).to_snake_case().replace("_", " "),
			"host" if multiplayer.is_server() else "client", run.stages_done, run.stage_plan.size()]
	return "%s, %s\n%s" % [BuildInfo.describe(), OS.get_name(), where]


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


## Every peer: makes the scene the host spawned. Clients take the run from the
## spawn data first, so the scene can read it in _ready().
func _spawn_level(data: Variant) -> Node:
	var info: Dictionary = data
	if not multiplayer.is_server():
		RunState.current = RunState.from_dict(info.get("run", {}))
	var scene: PackedScene = SCENES.get(str(info.get("kind", "lobby")), LOBBY_SCENE)
	return scene.instantiate()


## Host: swaps the Level slot to `kind`. Deferred callers only: never in the
## middle of the old scene's own tick.
func _load(kind: String) -> Node:
	_clear_level()
	return _level_spawner.spawn({"kind": kind, "run": RunState.current.to_dict()})


## Host: show the lobby (start of a session, and after every run).
func _load_lobby() -> void:
	var lobby := _load("lobby") as Lobby
	lobby.start_requested.connect(_start_run, CONNECT_DEFERRED)
	lobby.leave_requested.connect(_leave_game.bind(""), CONNECT_DEFERRED)


## Host: the lobby's Start: a fresh run, then its first stage.
func _start_run() -> void:
	RunState.start(RunSetup.order, _run_rng)
	_load_stage()


## Host: the run's next stage. LevelSpawner removes the old scene and creates
## the stage on every client too.
func _load_stage() -> void:
	var stage := _load("stage") as Stage
	stage.finished.connect(_after_stage, CONNECT_DEFERRED)


func _after_stage() -> void:
	if RunState.current.is_over() or not RunState.current.has_next_stage():
		var summary := _load("summary") as RunSummary
		summary.finished.connect(_load_lobby, CONNECT_DEFERRED)
	else:
		var shop := _load("shop") as Shop
		shop.finished.connect(_load_stage, CONNECT_DEFERRED)


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
	Music.play(&"menu")


func _report_and_quit() -> void:
	var scene := _level.get_child(0) if _level.get_child_count() > 0 else null
	if scene != null and scene.has_method("debug_report"):
		print(scene.call("debug_report"))
	else:
		print("[report] peer %d: nothing loaded" % multiplayer.get_unique_id())
	print("[report]   music: %s  (output device: %s, master %.0f dB, music %.0f dB, sfx %.0f dB)" % [
		Music.now_playing() if not Music.now_playing().is_empty() else &"none", AudioServer.output_device,
		AudioServer.get_bus_volume_db(0), AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")),
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))])
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


## --screenshot-dir: one picture of each shop and run summary (and the stage
## results panel) a moment after it appears.
func _screenshot_scene(node: Node) -> void:
	if LaunchOptions.screenshot_dir.is_empty():
		return
	var role := "_client" if LaunchOptions.mode == LaunchOptions.Mode.JOIN else ""
	var stage := node as Stage
	if stage != null:
		await stage.ended
		await get_tree().create_timer(1.0, true).timeout
		await save_screenshot(get_tree(), "results_%d%s.png" % [RunState.current.stages_done, role])
	elif node is Shop or node is RunSummary:
		await get_tree().create_timer(0.8, true).timeout
		await save_screenshot(get_tree(), "%s_%d%s.png" % ["shop" if node is Shop else "summary", RunState.current.stages_done, role])


## --screenshot-dir: the title menu (no mode flag) or the lobby, then gameplay
## pictures named after the window size and scaling mode, then the pause menu.
## Clients add "_client" so a host and a client can share one folder.
func _take_screenshots() -> void:
	var role := "_client" if LaunchOptions.mode == LaunchOptions.Mode.JOIN else ""
	await get_tree().create_timer(1.5, true).timeout
	if LaunchOptions.mode == LaunchOptions.Mode.MENU:
		await save_screenshot(get_tree(), "title.png")
		_feedback.open(null, _feedback_context())
		await save_screenshot(get_tree(), "feedback_title.png")
		_feedback.close()
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
	_pause_menu.open()
	await _open_feedback_from_pause()
	await save_screenshot(get_tree(), "feedback%s.png" % role)
	_feedback.close()
	_pause_menu.close()
