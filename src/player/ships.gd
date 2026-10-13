class_name Ships
extends RefCounted
## Every playable ship. The index is a network id: only add new ships at the end.

const ALL: Array[ShipStats] = [
	preload("res://src/player/ships/striker.tres"),
]
