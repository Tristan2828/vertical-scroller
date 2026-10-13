class_name MainMenu
extends CanvasLayer
## Title menu: your display name, play solo, host a game (on a port), or join a
## host (the Join dialog takes the invite they sent), Settings and Quit.
## Trimmed from Medieval Survival's and built in code.

signal solo_requested
signal host_requested(port: int)
signal join_requested(address: String, port: int)

const TITLE_COLOR: Color = Color(0.4, 0.85, 1.0)
const DIM_COLOR: Color = Color(0.65, 0.66, 0.75)
const MESSAGE_COLOR: Color = Color(0.95, 0.75, 0.55)
const SETTINGS_SCENE: PackedScene = preload("res://src/ui/settings_panel.tscn")

var join_dialog: JoinDialog = null
var settings: SettingsPanel = null

var _panel: VBoxContainer
var _name_edit: LineEdit
var _port_edit: LineEdit
var _solo_button: Button
var _host_button: Button
var _join_button: Button
var _settings_button: Button
var _status: Label


func _ready() -> void:
	layer = 5
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.04, 0.08)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = VBoxContainer.new()
	_panel.custom_minimum_size = Vector2(220, 0)
	_panel.add_theme_constant_override("separation", 6)
	center.add_child(_panel)
	var title := Label.new()
	title.text = "Vertical Scroller"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "(working title)"
	subtitle.add_theme_color_override("font_color", DIM_COLOR)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(subtitle)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = PlayerNames.MAX_LENGTH
	_name_edit.text = PlayerNames.sanitize(Settings.player_name)
	_name_edit.text_changed.connect(func(text: String) -> void:
		Settings.player_name = PlayerNames.sanitize(text)
		Settings.save())
	_name_edit.text_submitted.connect(func(_text: String) -> void: _solo_button.grab_focus())
	_panel.add_child(_name_edit)
	_solo_button = _button("Play Solo", func() -> void: solo_requested.emit())
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 4)
	_panel.add_child(host_row)
	_host_button = Button.new()
	_host_button.text = "Host Game"
	_host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_button.pressed.connect(func() -> void: host_requested.emit(_port()))
	host_row.add_child(_host_button)
	_port_edit = LineEdit.new()
	_port_edit.text = str(Net.DEFAULT_PORT)
	_port_edit.tooltip_text = "Port to host on"
	_port_edit.custom_minimum_size = Vector2(52, 0)
	host_row.add_child(_port_edit)
	_join_button = _button("Join Game", _open_join_dialog)
	_settings_button = _button("Settings", open_settings)
	_button("Quit", func() -> void: get_tree().quit())
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(220, 0)
	_status.add_theme_color_override("font_color", MESSAGE_COLOR)
	_panel.add_child(_status)
	settings = SETTINGS_SCENE.instantiate() as SettingsPanel
	center.add_child(settings)
	settings.closed.connect(func() -> void:
		_panel.show()
		_settings_button.grab_focus())
	join_dialog = JoinDialog.new()
	center.add_child(join_dialog)
	join_dialog.join_requested.connect(func(address: String, port: int) -> void:
		_panel.show()
		join_requested.emit(address, port))
	join_dialog.closed.connect(func() -> void:
		_panel.show()
		_join_button.grab_focus())


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	_panel.add_child(button)
	return button


## Shows the menu, with an optional message (e.g. why a connection ended).
func show_menu(message: String = "") -> void:
	show()
	_panel.show()
	settings.hide()
	join_dialog.hide()
	_status.text = message
	_set_buttons_enabled(true)
	_solo_button.grab_focus()


## "Connecting..." while a join is in progress.
func show_busy(message: String) -> void:
	show()
	_status.text = message
	_set_buttons_enabled(false)


func open_settings() -> void:
	_panel.hide()
	settings.open()


func _open_join_dialog() -> void:
	_panel.hide()
	join_dialog.open()


func _port() -> int:
	var port := _port_edit.text.strip_edges().to_int()
	return port if port > 0 and port <= 65535 else Net.DEFAULT_PORT


func _set_buttons_enabled(enabled: bool) -> void:
	for button: Button in [_solo_button, _host_button, _join_button]:
		button.disabled = not enabled
