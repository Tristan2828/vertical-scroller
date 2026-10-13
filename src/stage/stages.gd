class_name Stages
extends RefCounted
## Every stage file, in run order (DESIGN.md §3 Stages). The index is sent over
## the network: only add new stages at the end.

const PATHS: Array[String] = [
	"res://src/stage/stages/planet_base.stage",
]

static var _cache: Dictionary[int, StageDef] = {}


static func get_stage(index: int) -> StageDef:
	if not _cache.has(index):
		_cache[index] = StageDef.load_file(PATHS[clampi(index, 0, PATHS.size() - 1)])
	return _cache[index]
