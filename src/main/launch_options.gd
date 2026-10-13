class_name LaunchOptions
extends RefCounted
## Optional command-line flags for quick testing without clicking through menus
## (copied from Medieval Survival and trimmed to what exists so far).
## Pass them after a lone `--` so Godot hands them to the game:
##   godot --path . -- --host --autopilot
##
##   --solo | --host | --join=<ip[:port]>   start immediately in that mode (else: title menu)
##   --port=<n>                   port to host on / connect to (default 7777)
##   --local-only                 host without touching the router or looking up the public IP
##                                (automated tests must use it)
##   --autopilot                  the ship flies and shoots by itself; the host starts the
##                                lobby by itself, clients ready up by themselves
##   --run-for=<seconds>          print a report and quit (headless smoke tests)
##   --start-at=<seconds>         host starts the stage clock here (test later parts of a stage)
##   --weak-bosses                bosses have 2% HP (test the stage ending quickly)
##   --invincible                 hits still land and count, but HP refills at once
##   --screenshot-dir=<folder>    save PNGs: title menu, lobby, gameplay, pause menu, settings
##                                (needs a real window, not --headless)
##   --window=<width>x<height>    windowed at this size (ignores the fullscreen setting)
##   --window-at=<x>,<y>          with --window: top-left corner on the screen (else centered)
##   --scaling=sharp|pixel        override the scaling setting (not saved)
##   --fire-mode=always|toggle|hold   override the auto-fire setting (not saved)
##   --mouse-mode                 turn mouse mode on (not saved)

enum Mode { MENU, SOLO, HOST, JOIN }

const NetScript: GDScript = preload("res://src/autoload/net.gd")

static var mode: Mode = Mode.MENU
static var address: String = "127.0.0.1"
static var port: int = NetScript.DEFAULT_PORT
static var local_only: bool = false
static var autopilot: bool = false
static var run_for_seconds: float = 0.0
static var start_at_seconds: float = 0.0
static var weak_bosses: bool = false
static var invincible: bool = false
static var screenshot_dir: String = ""
## Zero = use the fullscreen setting.
static var window_size: Vector2i = Vector2i.ZERO
## -1,-1 = centered.
static var window_at: Vector2i = Vector2i(-1, -1)
## -1 = the saved setting.
static var scaling_mode: int = -1
static var fire_mode: int = -1
static var mouse_mode: bool = false


static func parse(args: PackedStringArray) -> void:
	for arg: String in args:
		if arg == "--solo":
			mode = Mode.SOLO
		elif arg == "--host":
			mode = Mode.HOST
		elif arg.begins_with("--join="):
			mode = Mode.JOIN
			address = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg == "--local-only":
			local_only = true
		elif arg == "--autopilot":
			autopilot = true
		elif arg.begins_with("--run-for="):
			run_for_seconds = arg.trim_prefix("--run-for=").to_float()
		elif arg.begins_with("--start-at="):
			start_at_seconds = maxf(arg.trim_prefix("--start-at=").to_float(), 0.0)
		elif arg == "--weak-bosses":
			weak_bosses = true
		elif arg == "--invincible":
			invincible = true
		elif arg.begins_with("--screenshot-dir="):
			screenshot_dir = arg.trim_prefix("--screenshot-dir=")
		elif arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			if parts.size() == 2:
				window_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif arg.begins_with("--window-at="):
			var at := arg.trim_prefix("--window-at=").split(",")
			if at.size() == 2:
				window_at = Vector2i(at[0].to_int(), at[1].to_int())
		elif arg.begins_with("--scaling="):
			scaling_mode = ScreenFit.Mode.PIXEL_PERFECT if arg.ends_with("pixel") else ScreenFit.Mode.SHARP
		elif arg.begins_with("--fire-mode="):
			fire_mode = maxi(FireControl.MODE_NAMES.find(arg.trim_prefix("--fire-mode=").capitalize()), 0)
		elif arg == "--mouse-mode":
			mouse_mode = true
		else:
			push_warning("Unknown launch option: %s" % arg)


## Puts the overrides into Settings (without saving them).
static func apply_to_settings() -> void:
	if window_size != Vector2i.ZERO:
		Settings.fullscreen = false
	if scaling_mode >= 0:
		Settings.scaling_mode = scaling_mode as ScreenFit.Mode
	if fire_mode >= 0:
		Settings.fire_mode = fire_mode as FireControl.Mode
	if mouse_mode:
		Settings.mouse_mode = true
