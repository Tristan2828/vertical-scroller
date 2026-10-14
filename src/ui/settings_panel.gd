class_name SettingsPanel
extends PanelContainer
## Volumes, scaling, auto-fire, mouse mode, screen shake and fullscreen. Each
## button steps through its choices (easy with a gamepad; left / right step a
## volume down or up). Changes apply immediately and are saved when the panel
## closes.

signal closed

const SCALING_NAMES: Array[String] = ["Sharp", "Pixel-perfect"]
const SCALING_HINTS: Array[String] = [
	"Fills the screen; smooths uneven pixel sizes.",
	"Whole-number zoom only; black borders.",
]
const VOLUME_STEP: float = 0.1

@onready var _master: Button = %MasterButton
@onready var _sfx: Button = %SfxButton
@onready var _music: Button = %MusicButton
@onready var _scaling: Button = %ScalingButton
@onready var _scaling_hint: Label = %ScalingHint
@onready var _fire: Button = %FireButton
@onready var _mouse: Button = %MouseButton
@onready var _shake: Button = %ShakeButton
@onready var _fullscreen: Button = %FullscreenButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	hide()
	_volume_button(_master, &"master_volume")
	_volume_button(_sfx, &"sfx_volume")
	_volume_button(_music, &"music_volume")
	_shake.pressed.connect(func() -> void:
		Settings.screen_shake = (Settings.screen_shake + 1) % Settings.SHAKE_NAMES.size()
		_changed())
	_scaling.pressed.connect(func() -> void:
		Settings.scaling_mode = ((Settings.scaling_mode + 1) % ScreenFit.Mode.size()) as ScreenFit.Mode
		_changed())
	_fire.pressed.connect(func() -> void:
		Settings.fire_mode = ((Settings.fire_mode + 1) % FireControl.Mode.size()) as FireControl.Mode
		_changed())
	_mouse.pressed.connect(func() -> void:
		Settings.mouse_mode = not Settings.mouse_mode
		_changed())
	_fullscreen.pressed.connect(func() -> void:
		Settings.fullscreen = not Settings.fullscreen
		_changed())
	_back.pressed.connect(close)


func open() -> void:
	_refresh()
	show()
	_master.grab_focus()


## A volume button: press to go up (wrapping to 0 after 100%), left / right to step.
func _volume_button(button: Button, setting: StringName) -> void:
	button.pressed.connect(func() -> void:
		var value: float = Settings.get(setting)
		Settings.set(setting, 0.0 if value >= 1.0 - 0.001 else step_volume(value, 1))
		_changed())
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			Settings.set(setting, step_volume(Settings.get(setting), -1 if event.is_action_pressed("ui_left") else 1))
			_changed()
			button.accept_event())


## One 10% step up or down, kept on whole steps and inside 0..1.
static func step_volume(value: float, direction: int) -> float:
	return clampf(snappedf(value + VOLUME_STEP * direction, VOLUME_STEP), 0.0, 1.0)


func close() -> void:
	Settings.save()
	hide()
	closed.emit()


func _changed() -> void:
	Settings.apply()
	_refresh()


func _refresh() -> void:
	_master.text = "Volume: %d%%" % roundi(Settings.master_volume * 100.0)
	_sfx.text = "Sound effects: %d%%" % roundi(Settings.sfx_volume * 100.0)
	_music.text = "Music: %d%%" % roundi(Settings.music_volume * 100.0)
	_shake.text = "Screen shake: %s" % Settings.SHAKE_NAMES[Settings.screen_shake]
	_scaling.text = "Scaling: %s" % SCALING_NAMES[Settings.scaling_mode]
	_scaling_hint.text = SCALING_HINTS[Settings.scaling_mode]
	_fire.text = "Auto-fire: %s" % FireControl.MODE_NAMES[Settings.fire_mode]
	_mouse.text = "Mouse mode: %s" % ("On" if Settings.mouse_mode else "Off")
	_fullscreen.text = "Fullscreen: %s" % ("On" if Settings.fullscreen else "Off")


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()
