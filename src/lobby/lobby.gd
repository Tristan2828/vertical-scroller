class_name Lobby
extends Control
## The party screen before a stage (solo too): who's here, their ship and
## special (your row has a button to change yours), who's ready, and the
## host's invite. The host owns the state (LobbyState) and sends
## it to everyone; clients ask the host to change their ship or ready flag.
## Trimmed from Medieval Survival's lobby: no hero picker or difficulty pages.
## Spawned by Main's LevelSpawner on every peer, like the stage.

## Host: Start was pressed with everyone ready.
signal start_requested
signal leave_requested

## Autopilot (tests): the host waits this long for clients before starting by itself.
const AUTOPILOT_HOST_MIN_SECONDS: float = 4.0
const AUTOPILOT_CLIENT_DELAY: float = 0.5
const TITLE_COLOR: Color = Color(0.95, 0.78, 0.4)
const DIM_COLOR: Color = Color(0.65, 0.66, 0.75)
const READY_COLOR: Color = Color(0.55, 0.95, 0.5)

var _state: LobbyState = LobbyState.new()
## Host: peers whose lobby has loaded (only they get the state).
var _ready_peers: Dictionary[int, bool] = {}
var _open_seconds: float = 0.0
var _autopilot_readied: bool = false
## What the party list last showed, so it's only rebuilt when it changes.
var _party_signature: String = ""

var _invite_label: Label
var _party: VBoxContainer
var _status: Label
var _ready_button: Button
var _start_button: Button
var _leave_button: Button
var _mode_button: Button


func _ready() -> void:
	_build()
	var is_host := multiplayer.is_server()
	_start_button.visible = is_host
	_ready_button.visible = not is_host
	if is_host:
		_state.boss_only = RunSetup.boss_only
		_state.add(1, RunSetup.ship_for(1), RunSetup.special_for(1))
		for peer_id: int in RunSetup.order:
			if multiplayer.get_peers().has(peer_id):
				_state.add(peer_id, RunSetup.ship_for(peer_id), RunSetup.special_for(peer_id))
		for peer_id: int in multiplayer.get_peers():
			_state.add(peer_id, RunSetup.ship_for(peer_id), RunSetup.special_for(peer_id))
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		Net.invite.changed.connect(_refresh)
		_start_button.grab_focus()
	else:
		_notify_ready.rpc_id(1)
		_ready_button.grab_focus()
	Net.names_changed.connect(_refresh)
	if LaunchOptions.ship >= 0 and LaunchOptions.ship < Ships.ALL.size():
		_choose_ship_locally(LaunchOptions.ship)
	_refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.06, 0.1)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Lobby"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_invite_label = Label.new()
	_invite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_invite_label.add_theme_color_override("font_color", DIM_COLOR)
	column.add_child(_invite_label)
	_party = VBoxContainer.new()
	_party.add_theme_constant_override("separation", 2)
	column.add_child(_party)
	_mode_button = Button.new()
	_mode_button.tooltip_text = "Boss only: every stage starts just before its boss (for testing)"
	_mode_button.pressed.connect(_toggle_boss_only)
	column.add_child(_mode_button)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", DIM_COLOR)
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)
	_leave_button = Button.new()
	_leave_button.text = "Leave"
	_leave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	buttons.add_child(_leave_button)
	_ready_button = Button.new()
	_ready_button.text = "Ready"
	_ready_button.toggle_mode = true
	_ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_button.toggled.connect(_set_ready_locally)
	buttons.add_child(_ready_button)
	_start_button = Button.new()
	_start_button.text = "Start"
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(_start_locally)
	buttons.add_child(_start_button)


func _process(delta: float) -> void:
	_open_seconds += delta
	if LaunchOptions.autopilot and multiplayer.is_server() and _open_seconds >= _autopilot_min_seconds() \
			and _state.can_start(1):
		_start_locally()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("copy_invite") and Net.invite.copy_to_clipboard():
		_invite_label.text = "Invite %s copied!" % Net.invite.address


func _autopilot_min_seconds() -> float:
	# Solo has nobody to wait for.
	return AUTOPILOT_HOST_MIN_SECONDS if Net.is_online() else 0.5


## Text summary for headless smoke tests.
func debug_report() -> String:
	var parts := PackedStringArray()
	for peer_id: int in _state.order:
		parts.append("%d%s" % [peer_id, "(ready)" if _state.ready.get(peer_id, false) else ""])
	return "[report] peer %d in lobby: %s" % [multiplayer.get_unique_id(), ", ".join(parts)]


func _refresh() -> void:
	var is_host := multiplayer.is_server()
	if not Net.is_online():
		_invite_label.text = "Solo"
	elif is_host:
		if Net.invite.address.is_empty():
			_invite_label.text = "Friends join with your IP:port. %s" % Net.invite.status
		else:
			_invite_label.text = "Invite: %s (copied to the clipboard; F1 copies again)\n%s" % [Net.invite.address, Net.invite.status]
	else:
		_invite_label.text = "Connected. The host starts the game."
	_mode_button.text = "Mode: Boss only (practice)" if _state.boss_only else "Mode: Full stages"
	# Only the host switches; everyone sees which mode is on.
	_mode_button.disabled = not is_host
	_refresh_party()
	if is_host:
		var waiting := _state.not_ready(1)
		_start_button.disabled = not waiting.is_empty()
		var names := PackedStringArray()
		for peer_id: int in waiting:
			names.append(Net.name_of(peer_id, _state.order.find(peer_id)))
		_status.text = "Waiting for %s" % ", ".join(names) if not waiting.is_empty() else ""
	else:
		_status.text = "Press Ready when you're set."


func _refresh_party() -> void:
	var signature := ""
	for peer_id: int in _state.order:
		signature += "%d:%s:%d:%d:%s;" % [peer_id, Net.names.get(peer_id, ""), _state.ships[peer_id],
			_state.specials.get(peer_id, 0), _state.ready.get(peer_id, false)]
	if signature == _party_signature:
		return
	_party_signature = signature
	for child: Node in _party.get_children():
		child.queue_free()
	var me := multiplayer.get_unique_id()
	for slot: int in _state.order.size():
		var peer_id := _state.order[slot]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = PlayerNames.color_of(slot)
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_label := Label.new()
		name_label.text = Net.name_of(peer_id, slot) + (" (you)" if peer_id == me else "")
		name_label.add_theme_color_override("font_color", PlayerNames.color_of(slot))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var ship: int = _state.ships[peer_id]
		if peer_id == me:
			var ship_button := Button.new()
			ship_button.text = Ships.ALL[ship].display_name
			ship_button.tooltip_text = Ships.ALL[ship].blurb
			ship_button.custom_minimum_size = Vector2(64, 0)
			ship_button.pressed.connect(func() -> void: _choose_ship_locally((ship + 1) % Ships.ALL.size()))
			row.add_child(ship_button)
		else:
			var ship_label := Label.new()
			ship_label.text = Ships.ALL[ship].display_name
			ship_label.custom_minimum_size = Vector2(64, 0)
			ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ship_label.add_theme_color_override("font_color", DIM_COLOR)
			row.add_child(ship_label)
		var special: int = _state.specials.get(peer_id, Specials.Kind.MEGA_BOMB)
		if peer_id == me:
			var special_button := Button.new()
			special_button.text = Specials.NAMES[special]
			special_button.tooltip_text = Specials.HINTS[special]
			special_button.custom_minimum_size = Vector2(76, 0)
			special_button.pressed.connect(func() -> void: _choose_special_locally((special + 1) % Specials.Kind.size()))
			row.add_child(special_button)
		else:
			var special_label := Label.new()
			special_label.text = Specials.NAMES[special]
			special_label.custom_minimum_size = Vector2(76, 0)
			special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			special_label.add_theme_color_override("font_color", DIM_COLOR)
			row.add_child(special_label)
		var ready_label := Label.new()
		ready_label.custom_minimum_size = Vector2(56, 0)
		ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if peer_id == 1:
			ready_label.text = "Host"
			ready_label.add_theme_color_override("font_color", TITLE_COLOR)
		elif _state.ready.get(peer_id, false):
			ready_label.text = "Ready"
			ready_label.add_theme_color_override("font_color", READY_COLOR)
		else:
			ready_label.text = "Not ready"
			ready_label.add_theme_color_override("font_color", DIM_COLOR)
		row.add_child(ready_label)
		_party.add_child(row)


func _choose_ship_locally(ship: int) -> void:
	if multiplayer.is_server():
		if _state.choose(1, ship):
			_broadcast()
	else:
		_state.choose(multiplayer.get_unique_id(), ship)
		_party_signature = ""
		_refresh()
		_request_ship.rpc_id(1, ship)


func _choose_special_locally(special: int) -> void:
	if multiplayer.is_server():
		if _state.choose_special(1, special):
			_broadcast()
	else:
		_state.choose_special(multiplayer.get_unique_id(), special)
		_party_signature = ""
		_refresh()
		_request_special.rpc_id(1, special)


## Host: the "Boss only" switch.
func _toggle_boss_only() -> void:
	if multiplayer.is_server():
		_state.boss_only = not _state.boss_only
		_broadcast()


func _set_ready_locally(is_ready: bool) -> void:
	if not multiplayer.is_server():
		_request_ready.rpc_id(1, is_ready)


func _start_locally() -> void:
	if not multiplayer.is_server() or not _state.can_start(1):
		return
	RunSetup.ships = _state.ships.duplicate()
	RunSetup.specials = _state.specials.duplicate()
	RunSetup.boss_only = _state.boss_only
	RunSetup.order = _state.order.duplicate()
	set_process(false)
	start_requested.emit()


# --- Host ----------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	_state.add(peer_id, RunSetup.ship_for(peer_id), RunSetup.special_for(peer_id))
	_broadcast()


func _on_peer_disconnected(peer_id: int) -> void:
	_state.remove(peer_id)
	_ready_peers.erase(peer_id)
	_broadcast()


func _broadcast() -> void:
	var ids := PackedInt32Array(_state.order)
	var ships := PackedInt32Array()
	var specials := PackedInt32Array()
	var readies := PackedByteArray()
	for peer_id: int in _state.order:
		ships.append(_state.ships[peer_id])
		specials.append(_state.specials.get(peer_id, Specials.Kind.MEGA_BOMB))
		readies.append(1 if _state.ready.get(peer_id, false) else 0)
	for peer_id: int in _ready_peers:
		_receive_state.rpc_id(peer_id, ids, ships, specials, readies, _state.boss_only)
	_refresh()


# --- Network messages ------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if multiplayer.is_server():
		_ready_peers[multiplayer.get_remote_sender_id()] = true
		_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func _request_ship(ship: int) -> void:
	if multiplayer.is_server() and _state.choose(multiplayer.get_remote_sender_id(), ship):
		_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func _request_special(special: int) -> void:
	if multiplayer.is_server() and _state.choose_special(multiplayer.get_remote_sender_id(), special):
		_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(is_ready: bool) -> void:
	if multiplayer.is_server():
		_state.set_ready(multiplayer.get_remote_sender_id(), is_ready)
		_broadcast()


## The host is always in the list, so the arrays are never empty.
@rpc("authority", "call_remote", "reliable")
func _receive_state(ids: PackedInt32Array, ships: PackedInt32Array, specials: PackedInt32Array,
		readies: PackedByteArray, boss_only: bool) -> void:
	var fresh := LobbyState.new()
	fresh.boss_only = boss_only
	for i: int in mini(ids.size(), mini(ships.size(), mini(specials.size(), readies.size()))):
		fresh.add(ids[i], clampi(ships[i], 0, Ships.ALL.size() - 1), specials[i])
		fresh.set_ready(ids[i], readies[i] != 0)
	_state = fresh
	_ready_button.set_pressed_no_signal(_state.ready.get(multiplayer.get_unique_id(), false))
	_refresh()
	if LaunchOptions.autopilot and not _autopilot_readied:
		_autopilot_readied = true
		get_tree().create_timer(AUTOPILOT_CLIENT_DELAY).timeout.connect(func() -> void:
			_ready_button.button_pressed = true)
