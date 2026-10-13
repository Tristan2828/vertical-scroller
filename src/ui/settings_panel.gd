class_name SettingsPanel
extends PanelContainer
## Scaling, auto-fire, mouse mode and fullscreen. Each button steps through its
## choices (easy with a gamepad). Changes apply immediately and are saved when
## the panel closes. (Volumes return with sound in M6.)

signal closed

const SCALING_NAMES: Array[String] = ["Sharp", "Pixel-perfect"]
const SCALING_HINTS: Array[String] = [
	"Fills the screen; smooths uneven pixel sizes.",
	"Whole-number zoom only; black borders.",
]

@onready var _scaling: Button = %ScalingButton
@onready var _scaling_hint: Label = %ScalingHint
@onready var _fire: Button = %FireButton
@onready var _mouse: Button = %MouseButton
@onready var _fullscreen: Button = %FullscreenButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	hide()
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
	_scaling.grab_focus()


func close() -> void:
	Settings.save()
	hide()
	closed.emit()


func _changed() -> void:
	Settings.apply()
	_refresh()


func _refresh() -> void:
	_scaling.text = "Scaling: %s" % SCALING_NAMES[Settings.scaling_mode]
	_scaling_hint.text = SCALING_HINTS[Settings.scaling_mode]
	_fire.text = "Auto-fire: %s" % FireControl.MODE_NAMES[Settings.fire_mode]
	_mouse.text = "Mouse mode: %s" % ("On" if Settings.mouse_mode else "Off")
	_fullscreen.text = "Fullscreen: %s" % ("On" if Settings.fullscreen else "Off")


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()
