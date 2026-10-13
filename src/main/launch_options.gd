class_name LaunchOptions
extends RefCounted
## Optional command-line flags for quick testing (copied from Medieval Survival
## and trimmed to what exists so far; the network flags return in M2).
## Pass them after a lone `--` so Godot hands them to the game:
##   godot --path . -- --autopilot --window=2560x1440 --scaling=pixel
##
##   --autopilot                  the ship flies and shoots by itself
##   --run-for=<seconds>          quit after this long
##   --screenshot-dir=<folder>    save gameplay PNGs (needs a real window, not --headless)
##   --window=<width>x<height>    windowed at this size (ignores the fullscreen setting)
##   --scaling=sharp|pixel        override the scaling setting (not saved)
##   --fire-mode=always|toggle|hold   override the auto-fire setting (not saved)
##   --mouse-mode                 turn mouse mode on (not saved)

static var autopilot: bool = false
static var run_for_seconds: float = 0.0
static var screenshot_dir: String = ""
## Zero = use the fullscreen setting.
static var window_size: Vector2i = Vector2i.ZERO
## -1 = the saved setting.
static var scaling_mode: int = -1
static var fire_mode: int = -1
static var mouse_mode: bool = false


static func parse(args: PackedStringArray) -> void:
	for arg: String in args:
		if arg == "--autopilot":
			autopilot = true
		elif arg.begins_with("--run-for="):
			run_for_seconds = arg.trim_prefix("--run-for=").to_float()
		elif arg.begins_with("--screenshot-dir="):
			screenshot_dir = arg.trim_prefix("--screenshot-dir=")
		elif arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			if parts.size() == 2:
				window_size = Vector2i(parts[0].to_int(), parts[1].to_int())
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
