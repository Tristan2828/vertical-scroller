class_name Pickups
extends RefCounted
## What enemies drop (DESIGN.md §3/§4): Scrap (the shop currency), power orbs
## (main gun power +1, run-long) and rare timed boosts and special charges.
## Whoever touches a pickup gets it (draft); Scrap goes to the team's wallet.
## The Kind is a network id: only add new kinds at the end.

enum Kind { SCRAP, POWER_ORB, RAPID_FIRE, WINGMEN, SPECIAL_CHARGE }

const SPRITES: Array[String] = ["pickup_scrap", "pickup_orb", "pickup_rapid", "pickup_wingmen", "pickup_charge"]
const NAMES: Array[String] = ["Scrap", "Power up", "Rapid Fire", "Wingmen", "Special +1"]

## Timed boosts last this long (draft: 10-15 s).
const BOOST_SECONDS: float = 12.0
## A power orb at full power is worth this much Scrap instead.
const MAX_POWER_SCRAP: int = 10
## Scrap from one kill is split into pieces of at most this value.
const SCRAP_PIECE: int = 5
## The boosts a "boost" drop picks from.
const BOOSTS: Array[Kind] = [Kind.RAPID_FIRE, Kind.WINGMEN]


## Host: what a kill of `type` drops, as [kind, value, kind, value, ...].
static func roll_drops(type: EnemyType, rng: RandomNumberGenerator) -> PackedInt32Array:
	var drops := PackedInt32Array()
	var scrap := type.scrap
	while scrap > 0:
		var piece := mini(scrap, SCRAP_PIECE)
		_add(drops, Kind.SCRAP, piece)
		scrap -= piece
	if rng.randf() < type.orb_chance:
		_add(drops, Kind.POWER_ORB, 1)
	if rng.randf() < type.boost_chance:
		_add(drops, BOOSTS[rng.randi_range(0, BOOSTS.size() - 1)], 1)
	if rng.randf() < type.charge_chance:
		_add(drops, Kind.SPECIAL_CHARGE, 1)
	return drops


static func _add(drops: PackedInt32Array, kind: Kind, value: int) -> void:
	drops.append(kind)
	drops.append(value)
