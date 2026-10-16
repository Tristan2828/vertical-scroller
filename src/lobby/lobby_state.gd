class_name LobbyState
extends RefCounted
## Who's in the lobby, which ship and special each picked, and who's ready.
## Pure data with the start rule; the Lobby node handles networking and UI.
## (Copied from Medieval Survival, with ships instead of heroes.)

## Peer ids in join order (the host first).
var order: Array[int] = []
var ships: Dictionary[int, int] = {}
## peer id -> Specials.Kind
var specials: Dictionary[int, int] = {}
var ready: Dictionary[int, bool] = {}
## The host's "Boss only" switch: every stage starts just before its boss (testing).
var boss_only: bool = false
## peer id -> Skins index (always one that fits their ship)
var skins: Dictionary[int, int] = {}
## The host's mission: a Stages.PATHS index.
var mission: int = 0


func add(peer_id: int, ship: int, special: int = Specials.Kind.MEGA_BOMB, skin: int = Skins.CLASSIC) -> void:
	if order.has(peer_id):
		return
	order.append(peer_id)
	ships[peer_id] = ship
	skins[peer_id] = skin if Skins.fits(ship, skin) else Skins.CLASSIC
	specials[peer_id] = special if Specials.is_valid(special) else Specials.Kind.MEGA_BOMB
	ready[peer_id] = false


func remove(peer_id: int) -> void:
	order.erase(peer_id)
	ships.erase(peer_id)
	skins.erase(peer_id)
	specials.erase(peer_id)
	ready.erase(peer_id)


func choose(peer_id: int, ship: int) -> bool:
	if not order.has(peer_id) or ship < 0 or ship >= Ships.ALL.size():
		return false
	ships[peer_id] = ship
	# Skins belong to a ship: a new ship starts in Classic unless the skin fits.
	if not Skins.fits(ship, skins.get(peer_id, Skins.CLASSIC)):
		skins[peer_id] = Skins.CLASSIC
	return true


## A skin for this player's current ship.
func choose_skin(peer_id: int, skin: int) -> bool:
	if not order.has(peer_id) or not Skins.fits(ships.get(peer_id, 0), skin):
		return false
	skins[peer_id] = skin
	return true


func choose_mission(index: int) -> bool:
	if index < 0 or index >= Stages.PATHS.size():
		return false
	mission = index
	return true


func choose_special(peer_id: int, special: int) -> bool:
	if not order.has(peer_id) or not Specials.is_valid(special):
		return false
	specials[peer_id] = special
	return true


func set_ready(peer_id: int, is_ready: bool) -> void:
	if order.has(peer_id):
		ready[peer_id] = is_ready


## The host can start once every other player is ready (pressing Start counts
## as the host being ready).
func can_start(host_id: int) -> bool:
	return not order.is_empty() and not_ready(host_id).is_empty()


func not_ready(host_id: int) -> Array[int]:
	var waiting: Array[int] = []
	for peer_id: int in order:
		if peer_id != host_id and not ready.get(peer_id, false):
			waiting.append(peer_id)
	return waiting
