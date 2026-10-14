class_name RunSetup
extends RefCounted
## Choices made in the lobby (host side), read by the stage when it spawns
## ships. Anyone without a choice (a friend who drops in mid-stage) flies the
## first ship.

## peer id -> Ships.ALL index
static var ships: Dictionary[int, int] = {}
## peer id -> Specials.Kind
static var specials: Dictionary[int, int] = {}
## Lobby join order (host first); the stage hands out player slots in this order.
static var order: Array[int] = []
## The lobby's "Boss only" switch (RunState.boss_only).
static var boss_only: bool = false


static func special_for(peer_id: int) -> int:
	var kind: int = specials.get(peer_id, Specials.Kind.MEGA_BOMB)
	return kind if Specials.is_valid(kind) else Specials.Kind.MEGA_BOMB


static func ship_for(peer_id: int) -> int:
	var id: int = ships.get(peer_id, 0)
	return id if id >= 0 and id < Ships.ALL.size() else 0
