class_name StageHud
extends CanvasLayer
## M2's bare HUD: the auto-fire state, kills, who's playing (each name in their
## ship color), and (host, online) the invite to send friends. The real HUD (HP
## bars for 1–4 players, specials, Scrap) comes with M4–M6.

@onready var _left: Label = $Left
@onready var _right: Label = $Right
@onready var _players: VBoxContainer = $Players
@onready var _invite: Label = $Invite

## Names and slots last shown, so the player list is only rebuilt when it changes.
var _players_signature: String = ""


func _ready() -> void:
	Net.invite.changed.connect(_show_invite)
	_show_invite()


func show_state(fire_mode: FireControl.Mode, firing: bool, kills: int, ships: Array[Ship]) -> void:
	var fire_text := "Auto-fire: %s" % FireControl.MODE_NAMES[fire_mode]
	if fire_mode != FireControl.Mode.ALWAYS:
		fire_text += " (%s)" % ("firing" if firing else "off")
	var left := "%s\nMouse mode: %s\nEsc / Start: menu" % [fire_text, "on" if Settings.mouse_mode else "off"]
	if _left.text != left:
		_left.text = left
	var right := "Kills: %d" % kills
	if _right.text != right:
		_right.text = right
	_show_players(ships)


func _show_players(ships: Array[Ship]) -> void:
	var signature := ""
	if ships.size() > 1:
		for ship: Ship in ships:
			signature += "%d:%s;" % [ship.slot, ship.display_name()]
	if signature == _players_signature:
		return
	_players_signature = signature
	for child: Node in _players.get_children():
		child.queue_free()
	if ships.size() <= 1:
		return
	for ship: Ship in ships:
		var label := Label.new()
		label.text = ship.display_name()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_color_override("font_color", ship.tint())
		_players.add_child(label)


func _show_invite() -> void:
	var text := ""
	if Net.is_online() and multiplayer.is_server():
		if Net.invite.address.is_empty():
			text = Net.invite.status
		else:
			text = "Invite: %s (copied; F1 copies again)\n%s" % [Net.invite.address, Net.invite.status]
	_invite.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("copy_invite") and Net.invite.copy_to_clipboard():
		_invite.text = "Invite: %s (copied!)\n%s" % [Net.invite.address, Net.invite.status]
