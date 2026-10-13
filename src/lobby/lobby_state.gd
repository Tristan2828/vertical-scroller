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


func add(peer_id: int, ship: int, special: int = Specials.Kind.MEGA_BOMB) -> void:
	if order.has(peer_id):
		return
	order.append(peer_id)
	ships[peer_id] = ship
	specials[peer_id] = special if Specials.is_valid(special) else Specials.Kind.MEGA_BOMB
	ready[peer_id] = false


func remove(peer_id: int) -> void:
	order.erase(peer_id)
	ships.erase(peer_id)
	specials.erase(peer_id)
	ready.erase(peer_id)


func choose(peer_id: int, ship: int) -> bool:
	if not order.has(peer_id) or ship < 0 or ship >= Ships.ALL.size():
		return false
	ships[peer_id] = ship
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
