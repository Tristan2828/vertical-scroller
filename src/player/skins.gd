class_name Skins
extends RefCounted
## Ship looks, picked in the lobby's "Choose your ship" panel. Purely cosmetic:
## the ship (Ships.ALL) decides the gun and stats, the skin only how it looks.
## Each skin belongs to one ship, except Classic (the ship's own sprite).
## Skin art: assets/art/skins/<name>.png, magenta = the player's color.
## The index is sent over the network: only add new skins at the end.

const CLASSIC: int = 0

## PixelArt sprite of each skin ("" = the ship's own sprite).
const SPRITES: Array[String] = [
	"",
	# Striker (balanced)
	"skins/void_main", "skins/tiny01", "skins/tiny03", "skins/tiny05", "skins/tiny12",
	# Lancer (tough, heavy lances)
	"skins/tiny13", "skins/tiny02", "skins/tiny08", "skins/tiny18",
	# Hornet (small, fast)
	"skins/tiny16", "skins/tiny04", "skins/tiny17", "skins/tiny06",
	# Vulcan (fast streams)
	"skins/tiny20", "skins/tiny10", "skins/tiny09", "skins/tiny15",
	# Wave (wide arcs)
	"skins/tiny14", "skins/tiny19", "skins/tiny07", "skins/tiny11",
]
## The Ships.ALL index each skin belongs to (-1 = every ship).
const SHIPS: Array[int] = [
	-1,
	0, 0, 0, 0, 0,
	1, 1, 1, 1,
	2, 2, 2, 2,
	3, 3, 3, 3,
	4, 4, 4, 4,
]
## Where each skin's art comes from (shown on its card).
const NAMES: Array[String] = [
	"Classic",
	"Void", "Tiny 1", "Tiny 3", "Tiny 5", "Tiny 12",
	"Tiny 13", "Tiny 2", "Tiny 8", "Tiny 18",
	"Tiny 16", "Tiny 4", "Tiny 17", "Tiny 6",
	"Tiny 20", "Tiny 10", "Tiny 9", "Tiny 15",
	"Tiny 14", "Tiny 19", "Tiny 7", "Tiny 11",
]


## The skins this ship can wear, Classic first.
static func for_ship(ship: int) -> Array[int]:
	var list: Array[int] = []
	for skin: int in SPRITES.size():
		if SHIPS[skin] == -1 or SHIPS[skin] == ship:
			list.append(skin)
	return list


static func fits(ship: int, skin: int) -> bool:
	return skin >= 0 and skin < SPRITES.size() and (SHIPS[skin] == -1 or SHIPS[skin] == ship)


## The sprite a ship draws with this skin (its own sprite if the skin doesn't fit
## or its art file is missing).
static func sprite_for(ship: int, skin: int) -> String:
	var own := Ships.ALL[clampi(ship, 0, Ships.ALL.size() - 1)].sprite
	if not fits(ship, skin) or SPRITES[skin].is_empty() or not PixelArt.has_sprite(SPRITES[skin]):
		return own
	return SPRITES[skin]
