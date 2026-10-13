class_name PauseMenu
extends CanvasLayer
## Esc / Start during play. Solo: the whole game pauses (the stage is
## "pausable"; this menu keeps running). Online pausing (M2) will only block
## your own controls, as in Medieval Survival.

@onready var _box: Control = %Box
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings: SettingsPanel = %Settings


func _ready() -> void:
	# Keep working while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_resume_button.pressed.connect(close)
	_settings_button.pressed.connect(open_settings)
	_settings.closed.connect(func() -> void:
		_box.show()
		_settings_button.grab_focus())
	_quit_button.pressed.connect(func() -> void: get_tree().quit())


func open() -> void:
	show()
	_box.show()
	_settings.hide()
	LocalInput.blocked = true
	get_tree().paused = true
	_resume_button.grab_focus()


func open_settings() -> void:
	_box.hide()
	_settings.open()


func close() -> void:
	hide()
	LocalInput.blocked = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("pause"):
			open()
			get_viewport().set_input_as_handled()
	elif _box.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
