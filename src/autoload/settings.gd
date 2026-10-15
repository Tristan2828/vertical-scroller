extends Node
## Player preferences (reach it anywhere as `Settings`). Saved to
## user://settings.cfg so they survive restarts. Change a value, then call
## apply() to use it right away and save() to keep it.

## Emitted by apply() (Main re-fits the game picture to the window).
signal changed

const PATH: String = "user://settings.cfg"
const SHAKE_NAMES: Array[String] = ["Off", "Low", "Full"]
const SHAKE_STRENGTHS: Array[float] = [0.0, 0.5, 1.0]

var master_volume: float = 0.8
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var fullscreen: bool = true
## How the 960x540 picture fills the screen (DESIGN.md §2 Scaling).
var scaling_mode: ScreenFit.Mode = ScreenFit.Mode.SHARP
var fire_mode: FireControl.Mode = FireControl.Mode.ALWAYS
## The ship glides toward the mouse cursor; right click focus, left click special.
var mouse_mode: bool = false
## Screen shake on big hits and explosions: an index into SHAKE_NAMES.
var screen_shake: int = 2
## Name shown to the other players (title menu).
var player_name: String = ""
## The monitor the game opens on (-1 = not chosen yet: the widest landscape one).
## Remembered when the game closes, so moving the window there sticks.
var screen: int = -1


func _enter_tree() -> void:
	# The pixel font must be in place before any menu is created.
	PixelFont.install()


func _ready() -> void:
	load_settings()
	_move_to_screen()
	apply()


## Closing: remember which monitor the game was on.
func _exit_tree() -> void:
	if _places_window() and DisplayServer.window_get_current_screen() != screen:
		screen = DisplayServer.window_get_current_screen()
		save()


## Opens the game on the remembered monitor, or on the first start on the
## widest landscape one (a 16:9 game on a portrait monitor is a thin band).
func _move_to_screen() -> void:
	if not _places_window():
		return
	var sizes: Array[Vector2i] = []
	for index: int in DisplayServer.get_screen_count():
		sizes.append(DisplayServer.screen_get_size(index))
	var target := screen if screen >= 0 and screen < sizes.size() else best_screen(sizes, DisplayServer.get_primary_screen())
	if target != DisplayServer.window_get_current_screen():
		get_window().current_screen = target


## Not in headless runs, and not when a launch picked the window's place itself
## (Godot's --screen, or the game's --window / --window-at test flags).
static func _places_window() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg == "--screen" or arg.begins_with("--window"):
			return false
	return true


## The widest landscape monitor (the primary one breaks ties; if every monitor
## is portrait, the primary one).
static func best_screen(sizes: Array[Vector2i], primary: int) -> int:
	var best := clampi(primary, 0, maxi(sizes.size() - 1, 0))
	for index: int in sizes.size():
		var size := sizes[index]
		if size.x < size.y:
			continue
		var best_size := sizes[best] if best < sizes.size() else Vector2i.ZERO
		if best_size.x < best_size.y or size.x * size.y > best_size.x * best_size.y:
			best = index
	return best


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	master_volume = clampf(config.get_value("audio", "master_volume", master_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx_volume", sfx_volume), 0.0, 1.0)
	music_volume = clampf(config.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	scaling_mode = clampi(config.get_value("video", "scaling_mode", scaling_mode), 0, ScreenFit.Mode.size() - 1) as ScreenFit.Mode
	fire_mode = clampi(config.get_value("controls", "fire_mode", fire_mode), 0, FireControl.Mode.size() - 1) as FireControl.Mode
	mouse_mode = config.get_value("controls", "mouse_mode", mouse_mode)
	screen_shake = clampi(config.get_value("video", "screen_shake", screen_shake), 0, SHAKE_NAMES.size() - 1)
	player_name = str(config.get_value("player", "name", player_name))
	screen = int(config.get_value("video", "screen", screen))


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "scaling_mode", scaling_mode)
	config.set_value("controls", "fire_mode", fire_mode)
	config.set_value("controls", "mouse_mode", mouse_mode)
	config.set_value("video", "screen_shake", screen_shake)
	config.set_value("player", "name", player_name)
	config.set_value("video", "screen", screen)
	config.save(PATH)


func shake_strength() -> float:
	return SHAKE_STRENGTHS[clampi(screen_shake, 0, SHAKE_STRENGTHS.size() - 1)]


## Index of an audio bus, created (routed to Master) if it doesn't exist yet.
func _bus(bus_name: StringName) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
	return index


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(_bus(&"SFX"), linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(_bus(&"Music"), linear_to_db(music_volume))
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()
