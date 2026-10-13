class_name Specials
extends RefCounted
## The special button's weapons (DESIGN.md §3 Specials). One is equipped per
## player (picked in the lobby); its charges refill at the start of each stage.
## The Kind is a network id: only add new specials at the end.

enum Kind { MEGA_BOMB, SHIELD }

const NAMES: Array[String] = ["Mega Bomb", "Shield"]
## Charges per stage (draft).
const CHARGES: Array[int] = [1, 3]
const HINTS: Array[String] = [
	"Clears the bullets on screen and hits everything hard.",
	"3 s of safety; bullets that touch it vanish.",
]

## Mega Bomb: damage to every air enemy and ground object on screen (bosses too).
const BOMB_DAMAGE: int = 250
## Mega Bomb: seconds of safety for the player who set it off.
const BOMB_SAFE_SECONDS: float = 1.0
## Shield: seconds it lasts, and its radius (bullets inside vanish).
const SHIELD_SECONDS: float = 3.0
const SHIELD_RADIUS: float = 20.0


static func is_valid(kind: int) -> bool:
	return kind >= 0 and kind < Kind.size()


static func charges_of(kind: int) -> int:
	return CHARGES[clampi(kind, 0, CHARGES.size() - 1)]
