class_name Shop
extends Control
## The shop between stages (DESIGN.md §4), solo and online. The host runs the
## ShopSession (pure rules) and sends everyone the shop's state; clients ask
## the host to buy, chip in or ready up. Built in code; spawned by Main's
## LevelSpawner like the lobby and the stage.
##
## When the shop closes, what's left in everyone's wallet goes back to the
## team's wallet in RunState.current, and Main starts the next stage.

## Host: the shop closed.
signal finished

const AUTOPILOT_SHOP_DELAY: float = 1.0
const TITLE_COLOR: Color = Color(0.95, 0.78, 0.4)
const DIM_COLOR: Color = Color(0.65, 0.66, 0.75)
const SCRAP_COLOR: Color = Color(1.0, 0.85, 0.35)
const READY_COLOR: Color = Color(0.55, 0.95, 0.5)
const CARD_SIZE: Vector2 = Vector2(150, 64)

## Host only.
var session: ShopSession = ShopSession.new()

## What this screen shows (host: from the session; clients: from _receive_state).
var _wallets: Dictionary = {}
## Players in lobby order (their slot = their color).
var _order: Array = []
var _ready_ids: Array = []
var _bought: Dictionary = {}
var _team_sold: bool = false
var _countdown: float = -1.0
var _my_offers: Array[int] = []
var _team_offer: int = ShopItems.Id.RESPAWN_CREDIT
## Host: peers whose shop has loaded (only they get messages).
var _ready_peers: Dictionary[int, bool] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _autopilot_done: bool = false
var _signature: String = ""

var _header: Label
var _wallet_label: Label
var _cards: HBoxContainer
var _team_row: VBoxContainer
var _status: Label
var _ready_button: Button


func _ready() -> void:
	_build()
	var run := RunState.current
	if multiplayer.is_server():
		_rng.seed = run.seed_value + 7919 * run.stages_done
		var order := _players_in_order()
		var offers: Dictionary[int, Array] = {}
		for peer_id: int in order:
			offers[peer_id] = ShopItems.roll_personal(_rng)
		session.start(order, run.team_scrap, offers, ShopItems.roll_team(_rng))
		run.team_scrap = 0
		_my_offers.assign(offers.get(1, []))
		_team_offer = session.team_offer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_broadcast()
	else:
		_notify_ready.rpc_id(1)
	Net.names_changed.connect(_refresh)
	_ready_button.grab_focus()
	if LaunchOptions.autopilot:
		get_tree().create_timer(AUTOPILOT_SHOP_DELAY).timeout.connect(_autopilot_shop)


## Players in lobby order (the host first), then anyone else connected.
func _players_in_order() -> Array[int]:
	var order: Array[int] = [1]
	for peer_id: int in RunSetup.order:
		if peer_id != 1 and multiplayer.get_peers().has(peer_id):
			order.append(peer_id)
	for peer_id: int in multiplayer.get_peers():
		if not order.has(peer_id):
			order.append(peer_id)
	return order


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
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Shop"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_color_override("font_color", DIM_COLOR)
	column.add_child(_header)
	_wallet_label = Label.new()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.add_theme_color_override("font_color", SCRAP_COLOR)
	column.add_child(_wallet_label)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 6)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cards)
	_team_row = VBoxContainer.new()
	_team_row.add_theme_constant_override("separation", 2)
	column.add_child(_team_row)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", DIM_COLOR)
	column.add_child(_status)
	_ready_button = Button.new()
	_ready_button.text = "Ready for the next stage"
	_ready_button.pressed.connect(_ready_locally)
	column.add_child(_ready_button)


func _process(delta: float) -> void:
	if multiplayer.is_server():
		var was_counting := session.countdown_left
		session.tick(delta)
		if was_counting > 0.0 and int(was_counting) != int(session.countdown_left):
			_broadcast()
		if session.is_finished():
			_close()
	elif _countdown > 0.0:
		_countdown = maxf(_countdown - delta, 0.0)
		_refresh_status()


## Host: the shop is over.
func _close() -> void:
	set_process(false)
	RunState.current.team_scrap += session.leftovers()
	finished.emit()


## Text summary for headless smoke tests.
func debug_report() -> String:
	return "[report] peer %d in the shop: wallets %s  ready %s  team offer %s%s" % [multiplayer.get_unique_id(),
		_wallets, _ready_ids, ShopItems.NAMES[_team_offer], " (sold)" if _team_sold else ""]


# --- Showing the state ----------------------------------------------------------

func _refresh() -> void:
	var me := multiplayer.get_unique_id()
	var run := RunState.current
	var next := Stages.get_stage(run.stage_index()).name
	var twist := StageModifiers.name_of(run.modifier())
	_header.text = "Next: %s (stage %d of %d)%s   Ships left: %d" % [next, run.stages_done + 1, run.stage_plan.size(),
		"   Twist: " + twist if not twist.is_empty() else "", run.credits]
	_wallet_label.text = "Your Scrap: %d" % int(_wallets.get(me, 0))
	var signature := "%s|%s|%s|%s|%s|%s" % [_wallets, _ready_ids, _bought, _team_sold, _my_offers, _team_offer]
	if signature != _signature:
		_signature = signature
		_rebuild_cards(me)
		_rebuild_team(me)
	_ready_button.disabled = _ready_ids.has(me)
	_refresh_status()


func _rebuild_cards(me: int) -> void:
	for child: Node in _cards.get_children():
		child.queue_free()
	var mine: Array = _bought.get(me, [])
	var wallet := int(_wallets.get(me, 0))
	for item: int in _my_offers:
		_cards.add_child(_card(item, mine.has(item), wallet, false))
	_cards.add_child(_card(_team_offer, _team_sold, wallet, true))


func _card(item: int, sold: bool, wallet: int, team: bool) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var label := "%s%s\n%d Scrap\n%s" % ["Team: " if team else "", ShopItems.NAMES[item], ShopItems.price(item), ShopItems.HINTS[item]]
	if sold:
		label = "%s%s\nBought" % ["Team: " if team else "", ShopItems.NAMES[item]]
	card.text = label
	card.disabled = sold or wallet < ShopItems.price(item) or _ready_ids.has(multiplayer.get_unique_id())
	card.pressed.connect(_buy_locally.bind(item))
	return card


func _rebuild_team(me: int) -> void:
	for child: Node in _team_row.get_children():
		child.queue_free()
	var order := _order
	for slot: int in order.size():
		var peer_id: int = order[slot]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = Net.name_of(peer_id, slot) + (" (you)" if peer_id == me else "")
		name_label.add_theme_color_override("font_color", PlayerNames.color_of(slot))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var wallet := Label.new()
		wallet.text = "%d Scrap" % int(_wallets.get(peer_id, 0))
		wallet.add_theme_color_override("font_color", SCRAP_COLOR)
		row.add_child(wallet)
		var ready_label := Label.new()
		ready_label.custom_minimum_size = Vector2(44, 0)
		ready_label.text = "Ready" if _ready_ids.has(peer_id) else ""
		ready_label.add_theme_color_override("font_color", READY_COLOR)
		row.add_child(ready_label)
		if peer_id != me and order.size() > 1:
			var chip := Button.new()
			chip.text = "Chip in %d" % ShopSession.CHIP_IN_STEP
			chip.tooltip_text = "Give this teammate some of your Scrap"
			chip.disabled = int(_wallets.get(me, 0)) <= 0 or _ready_ids.has(me)
			chip.pressed.connect(_chip_in_locally.bind(peer_id))
			row.add_child(chip)
		_team_row.add_child(row)


func _refresh_status() -> void:
	var text := ""
	if _countdown > 0.0:
		text = "Next stage in %d s (or when everyone is ready)" % ceili(_countdown)
	elif _wallets.size() > 1:
		text = "A %d s timer starts when half the team is ready." % roundi(ShopSession.SOFT_TIMER_SECONDS)
	_status.text = text


# --- Local actions (host: straight to the session; clients: ask the host) ------------

func _buy_locally(item: int) -> void:
	if multiplayer.is_server():
		_host_buy(1, item)
	else:
		_request_buy.rpc_id(1, item)


func _chip_in_locally(to: int) -> void:
	if multiplayer.is_server():
		_host_chip_in(1, to)
	else:
		_request_chip_in.rpc_id(1, to)


func _ready_locally() -> void:
	if multiplayer.is_server():
		_host_ready(1)
	else:
		_request_ready.rpc_id(1)


## Autopilot (tests): buy what it can afford, chip in once, then ready up.
func _autopilot_shop() -> void:
	if _autopilot_done or not is_inside_tree():
		return
	_autopilot_done = true
	var me := multiplayer.get_unique_id()
	for item: int in _my_offers + [_team_offer]:
		if int(_wallets.get(me, 0)) >= ShopItems.price(item):
			_buy_locally(item)
	for peer_id: Variant in _wallets:
		if int(peer_id) != me:
			_chip_in_locally(int(peer_id))
			break
	get_tree().create_timer(AUTOPILOT_SHOP_DELAY).timeout.connect(_ready_locally)


# --- Host ----------------------------------------------------------------------

func _host_buy(peer_id: int, item: int) -> void:
	if session.buy(peer_id, item, RunState.current):
		_broadcast()


func _host_chip_in(from: int, to: int) -> void:
	if session.chip_in(from, to) > 0:
		_broadcast()


func _host_ready(peer_id: int) -> void:
	if session.mark_ready(peer_id):
		_broadcast()


func _on_peer_connected(peer_id: int) -> void:
	session.add_player(peer_id, ShopItems.roll_personal(_rng))
	_broadcast()


func _on_peer_disconnected(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	# Their Scrap stays with the team.
	RunState.current.team_scrap += session.wallets.get(peer_id, 0)
	session.remove(peer_id)
	_broadcast()


## Host: everyone (host included) sees the session's state.
func _broadcast() -> void:
	var order: Array[int] = []
	for peer_id: int in _players_in_order():
		if session.wallets.has(peer_id):
			order.append(peer_id)
	var state := {"wallets": session.wallets.duplicate(), "order": order, "ready": session.ready.keys(), "bought": session.bought.duplicate(true),
		"team_sold": session.team_offer_sold, "countdown": session.countdown_left, "run": RunState.current.to_dict()}
	_apply_state(state)
	for peer_id: int in _ready_peers:
		_receive_state.rpc_id(peer_id, state)


func _apply_state(state: Dictionary) -> void:
	_wallets = state.get("wallets", {})
	_order = state.get("order", [])
	_ready_ids = state.get("ready", [])
	_bought = state.get("bought", {})
	_team_sold = bool(state.get("team_sold", false))
	_countdown = float(state.get("countdown", -1.0))
	if not multiplayer.is_server():
		RunState.current = RunState.from_dict(state.get("run", {}))
	_refresh()


# --- Network messages ------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_ready_peers[peer_id] = true
	if not session.wallets.has(peer_id):
		session.add_player(peer_id, ShopItems.roll_personal(_rng))
	var offers := PackedInt32Array()
	for item: Variant in session.offers.get(peer_id, []):
		offers.append(int(item))
	_receive_offers.rpc_id(peer_id, offers.size(), offers, session.team_offer)
	_broadcast()


## The count comes first so the call is valid even with no offers.
@rpc("authority", "call_remote", "reliable")
func _receive_offers(_count: int, offers: PackedInt32Array, team_offer: int) -> void:
	_my_offers.clear()
	for item: int in offers:
		if ShopItems.is_valid(item):
			_my_offers.append(item)
	_team_offer = team_offer if ShopItems.is_valid(team_offer) else ShopItems.Id.RESPAWN_CREDIT
	_signature = ""
	_refresh()


@rpc("authority", "call_remote", "reliable")
func _receive_state(state: Dictionary) -> void:
	_apply_state(state)


@rpc("any_peer", "call_remote", "reliable")
func _request_buy(item: int) -> void:
	if multiplayer.is_server():
		_host_buy(multiplayer.get_remote_sender_id(), item)


@rpc("any_peer", "call_remote", "reliable")
func _request_chip_in(to: int) -> void:
	if multiplayer.is_server():
		_host_chip_in(multiplayer.get_remote_sender_id(), to)


@rpc("any_peer", "call_remote", "reliable")
func _request_ready() -> void:
	if multiplayer.is_server():
		_host_ready(multiplayer.get_remote_sender_id())
