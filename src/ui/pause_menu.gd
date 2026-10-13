class_name PauseMenu
extends CanvasLayer
## Esc / Start while in the lobby or a stage. Solo: the whole game pauses (the
## stage is "pausable"; this menu keeps running). Online: the game keeps running
## for everyone (host included), so only your own controls are blocked.

signal leave_requested

## Main allows the menu only while a lobby or stage is loaded.
var allowed: bool = false

@onready var _box: Control = %Box
@onready var _hint: Label = %Hint
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _leave_button: Button = %LeaveButton
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
	_leave_button.pressed.connect(func() -> void:
		close()
		leave_requested.emit())
	_quit_button.pressed.connect(func() -> void: get_tree().quit())


func open() -> void:
	show()
	_box.show()
	_settings.hide()
	LocalInput.blocked = true
	if Net.is_online():
		_hint.text = "The game keeps going for everyone else while this is open."
	else:
		_hint.text = "Paused."
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
		if allowed and event.is_action_pressed("pause"):
			open()
			get_viewport().set_input_as_handled()
	elif _box.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
