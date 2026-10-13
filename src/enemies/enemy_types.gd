class_name EnemyTypes
extends RefCounted
## Every enemy type, air and ground. The index is a network id: only add new
## types at the end. Stage files name them by EnemyType.key.

const ALL: Array[EnemyType] = [
	preload("res://src/enemies/types/drone.tres"),
	preload("res://src/enemies/types/fighter.tres"),
	preload("res://src/enemies/types/gunship.tres"),
	preload("res://src/enemies/types/kamikaze.tres"),
	preload("res://src/enemies/types/turret.tres"),
	preload("res://src/enemies/types/heavy_turret.tres"),
	preload("res://src/enemies/types/tank.tres"),
	preload("res://src/enemies/types/bunker.tres"),
	preload("res://src/enemies/types/radar.tres"),
]


## Index of the type with this key, or -1.
static func from_key(key: String) -> int:
	for i: int in ALL.size():
		if ALL[i].key == key:
			return i
	return -1


static func is_valid_id(id: int) -> bool:
	return id >= 0 and id < ALL.size()
