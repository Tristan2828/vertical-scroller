class_name SettingsPanel
extends PanelContainer
## Volume sliders, then scaling, auto-fire, mouse mode, screen shake and
## fullscreen: each button steps through its choices (easy with a gamepad;
## sliders move with left / right). Changes apply immediately and are saved
## when the panel closes.

signal closed

const SCALING_NAMES: Array[String] = ["Sharp", "Pixel-perfect"]
const SCALING_HINTS: Array[String] = [
	"Fills the screen; smooths uneven pixel sizes.",
	"Whole-number zoom only; black borders.",
]
@onready var _master: HSlider = %MasterSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _music: HSlider = %MusicSlider
@onready var _master_label: Label = %MasterLabel
@onready var _sfx_label: Label = %SfxLabel
@onready var _music_label: Label = %MusicLabel
@onready var _scaling: Button = %ScalingButton
@onready var _scaling_hint: Label = %ScalingHint
@onready var _fire: Button = %FireButton
@onready var _mouse: Button = %MouseButton
@onready var _shake: Button = %ShakeButton
@onready var _fullscreen: Button = %FullscreenButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	hide()
	_volume_slider(_master, &"master_volume")
	_volume_slider(_sfx, &"sfx_volume", &"scrap")
	_volume_slider(_music, &"music_volume")
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


## A volume slider (0..1). `preview`: a sound played while it moves, so you
## hear the new level.
func _volume_slider(slider: HSlider, setting: StringName, preview: StringName = &"") -> void:
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set(setting, value)
		_changed()
		if not preview.is_empty():
			Sfx.play(preview))


func close() -> void:
	Settings.save()
	hide()
	closed.emit()


func _changed() -> void:
	Settings.apply()
	_refresh()


func _refresh() -> void:
	for row: Array in [[_master, _master_label, "Volume", Settings.master_volume],
			[_sfx, _sfx_label, "Effects", Settings.sfx_volume], [_music, _music_label, "Music", Settings.music_volume]]:
		(row[0] as HSlider).set_value_no_signal(row[3])
		(row[1] as Label).text = "%s %d%%" % [row[2], roundi(float(row[3]) * 100.0)]
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
