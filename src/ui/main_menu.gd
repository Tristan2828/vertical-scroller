class_name MainMenu
extends CanvasLayer
## Title menu: your display name, play solo, host a game (on a port), or join a
## host (the Join dialog takes the invite they sent), Settings, Send feedback
## and Quit. Shows the build in the corner and, in the exported game, a newer
## release with an Update button (see Updater).
## Trimmed from Medieval Survival's and built in code.

signal solo_requested
signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal feedback_requested

const TITLE_COLOR: Color = Color(0.4, 0.85, 1.0)
const DIM_COLOR: Color = Color(0.65, 0.66, 0.75)
const MESSAGE_COLOR: Color = Color(0.95, 0.75, 0.55)
const UPDATE_COLOR: Color = Color(0.55, 0.9, 0.45)
const ERROR_COLOR: Color = Color(0.95, 0.5, 0.45)
const SETTINGS_SCENE: PackedScene = preload("res://src/ui/settings_panel.tscn")

var join_dialog: JoinDialog = null
var settings: SettingsPanel = null
var updater: Updater = null

var _panel: VBoxContainer
var _name_edit: LineEdit
var _port_edit: LineEdit
var _solo_button: Button
var _host_button: Button
var _join_button: Button
var _settings_button: Button
var _feedback_button: Button
var _status: Label
var _version_label: Label
var _update_row: HBoxContainer
var _update_label: Label
var _update_button: Button
var _page_button: Button


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
	_feedback_button = _button("Send feedback", func() -> void:
		_panel.hide()
		feedback_requested.emit())
	_button("Quit", func() -> void: get_tree().quit())
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(220, 0)
	_status.add_theme_color_override("font_color", MESSAGE_COLOR)
	_panel.add_child(_status)
	_build_update_row()
	_version_label = Label.new()
	_version_label.add_theme_color_override("font_color", DIM_COLOR)
	_version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 6)
	_version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_version_label)
	updater = Updater.new()
	add_child(updater)
	updater.changed.connect(_refresh_update)
	_refresh_update()
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


func _build_update_row() -> void:
	_update_row = HBoxContainer.new()
	_update_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_update_row.add_theme_constant_override("separation", 4)
	_panel.add_child(_update_row)
	_update_label = Label.new()
	_update_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_label.custom_minimum_size = Vector2(120, 0)
	_update_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_row.add_child(_update_label)
	_update_button = Button.new()
	_update_row.add_child(_update_button)
	_page_button = Button.new()
	_page_button.text = "Open page"
	_update_row.add_child(_page_button)
	_update_button.pressed.connect(func() -> void: updater.press())
	_page_button.pressed.connect(func() -> void: updater.open_release_page())


## The update line under the menu buttons, from the updater's state.
func _refresh_update() -> void:
	var latest := updater.latest.version if updater.latest != null else "?"
	var text := ""
	var color := UPDATE_COLOR
	_update_button.visible = false
	_page_button.visible = false
	match updater.state:
		Updater.State.AVAILABLE:
			text = "Version %s is out!" % latest
			_update_button.text = "Update now"
			_update_button.visible = true
		Updater.State.DOWNLOADING:
			text = "Downloading %s... %d%%" % [latest, roundi(updater.progress() * 100.0)]
		Updater.State.INSTALLING:
			text = "Installing... the game will restart."
		Updater.State.FAILED:
			text = updater.error
			color = ERROR_COLOR
			_update_button.text = "Try again"
			_update_button.visible = true
			_page_button.visible = true
		Updater.State.CHECK_FAILED:
			# Quiet (gray): being offline is normal.
			text = updater.error
			color = DIM_COLOR
			_update_button.text = "Check again"
			_update_button.visible = true
			_page_button.visible = true
		Updater.State.RESTART_NEEDED:
			text = updater.error
	_update_label.text = text
	_update_label.add_theme_color_override("font_color", color)
	_update_row.visible = not text.is_empty()
	var suffix := ""
	if updater.state == Updater.State.UP_TO_DATE:
		suffix = "   (latest version)"
	elif updater.state == Updater.State.CHECKING:
		suffix = "   checking for updates..."
	_version_label.text = BuildInfo.describe() + suffix
	# No starting a game mid-update (enabled again if the update fails).
	if updater.state == Updater.State.DOWNLOADING or updater.state == Updater.State.INSTALLING:
		_set_buttons_enabled(false)
	elif updater.state == Updater.State.FAILED or updater.state == Updater.State.RESTART_NEEDED:
		_set_buttons_enabled(true)


## Shows the menu, with an optional message (e.g. why a connection ended).
func show_menu(message: String = "") -> void:
	show()
	_panel.show()
	_name_edit.text = PlayerNames.sanitize(Settings.player_name)  # The feedback screen can change it too.
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


## Back from the feedback screen.
func show_panel_after_feedback() -> void:
	_panel.show()
	_name_edit.text = PlayerNames.sanitize(Settings.player_name)
	_feedback_button.grab_focus()


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
