class_name Ships
extends RefCounted
## Every playable ship. The index is a network id: only add new ships at the end.

const ALL: Array[ShipStats] = [
	preload("res://src/player/ships/striker.tres"),
	preload("res://src/player/ships/lancer.tres"),
	preload("res://src/player/ships/hornet.tres"),
	preload("res://src/player/ships/vulcan.tres"),
	preload("res://src/player/ships/wave.tres"),
]
