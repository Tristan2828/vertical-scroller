class_name ShipPicker
extends PanelContainer
## The lobby's "Choose your ship" panel: the five ships (gun and stats) on top,
## then the chosen ship's skins (looks only), all drawn big in the player's
## color. Picks apply at once (the lobby sends them to the host); Done closes.
## Built in code; buttons only, so mouse, keyboard and gamepad all work.

signal ship_chosen(ship: int)
signal skin_chosen(skin: int)
signal closed

const TITLE_COLOR: Color = Color(0.95, 0.78, 0.4)
const DIM_COLOR: Color = Color(0.65, 0.66, 0.75)
const SHIP_CARD: Vector2 = Vector2(84, 74)
const SKIN_CARD: Vector2 = Vector2(64, 66)

var _ships_row: HBoxContainer
var _blurb: Label
var _skins_row: HFlowContainer
var _done: Button
var _ship: int = 0
var _skin: int = Skins.CLASSIC
var _color: Color = Color.WHITE


func _ready() -> void:
	hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title := Label.new()
	title.text = "Choose your ship"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_ships_row = HBoxContainer.new()
	_ships_row.add_theme_constant_override("separation", 4)
	_ships_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_ships_row)
	_blurb = Label.new()
	_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(440, 0)
	_blurb.add_theme_color_override("font_color", DIM_COLOR)
	column.add_child(_blurb)
	var skin_title := Label.new()
	skin_title.text = "Skin (looks only)"
	skin_title.add_theme_color_override("font_color", TITLE_COLOR)
	skin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(skin_title)
	_skins_row = HFlowContainer.new()
	_skins_row.add_theme_constant_override("h_separation", 4)
	_skins_row.add_theme_constant_override("v_separation", 4)
	_skins_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_skins_row.custom_minimum_size = Vector2(440, 0)
	column.add_child(_skins_row)
	_done = Button.new()
	_done.text = "Done"
	_done.pressed.connect(close)
	column.add_child(_done)


## Shows the panel with this player's current pick, in their color.
func open(ship: int, skin: int, color: Color) -> void:
	_ship = ship
	_skin = skin
	_color = color
	_rebuild()
	show()
	(_ships_row.get_child(_ship) as Button).grab_focus()


func close() -> void:
	hide()
	closed.emit()


## The host's answer (or a teammate's change) arrived: show it without
## stealing focus.
func show_choice(ship: int, skin: int) -> void:
	if ship == _ship and skin == _skin:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var focus_index := focused.get_index() if focused != null and focused.get_parent() == _ships_row else -1
	_ship = ship
	_skin = skin
	_rebuild()
	if focus_index >= 0:
		(_ships_row.get_child(focus_index) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for child: Node in _ships_row.get_children():
		_ships_row.remove_child(child)
		child.queue_free()
	for ship: int in Ships.ALL.size():
		var card := _card(Ships.ALL[ship].display_name, Ships.ALL[ship].sprite, SHIP_CARD, ship == _ship)
		card.tooltip_text = Ships.ALL[ship].blurb
		card.pressed.connect(func() -> void:
			if ship != _ship:
				_ship = ship
				if not Skins.fits(ship, _skin):
					_skin = Skins.CLASSIC
				_rebuild()
				(_ships_row.get_child(ship) as Button).grab_focus()
				ship_chosen.emit(ship))
		_ships_row.add_child(card)
	_blurb.text = Ships.ALL[_ship].blurb
	for child: Node in _skins_row.get_children():
		_skins_row.remove_child(child)
		child.queue_free()
	for skin: int in Skins.for_ship(_ship):
		var card := _card(Skins.NAMES[skin], Skins.sprite_for(_ship, skin), SKIN_CARD, skin == _skin)
		card.pressed.connect(func() -> void:
			if skin != _skin:
				_skin = skin
				_rebuild()
				_focus_skin(skin)
				skin_chosen.emit(skin))
		_skins_row.add_child(card)


func _focus_skin(skin: int) -> void:
	var index := Skins.for_ship(_ship).find(skin)
	if index >= 0 and index < _skins_row.get_child_count():
		(_skins_row.get_child(index) as Button).grab_focus()


## A button with the sprite drawn big above its name; the chosen one stays lit.
func _card(text: String, sprite: String, size: Vector2, chosen: bool) -> Button:
	var card := Button.new()
	card.text = text
	card.custom_minimum_size = size
	card.icon = PixelArt.texture(sprite, _color)
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.add_theme_constant_override("icon_max_width", int(size.x) - 16)
	if chosen:
		card.add_theme_color_override("font_color", TITLE_COLOR)
		card.add_theme_color_override("font_focus_color", TITLE_COLOR)
		card.add_theme_color_override("font_hover_color", TITLE_COLOR)
		card.add_theme_stylebox_override("normal", card.get_theme_stylebox("pressed"))
	return card
