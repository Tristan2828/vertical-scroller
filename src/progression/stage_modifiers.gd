class_name StageModifiers
extends RefCounted
## A random twist per stage, with a bonus reward for clearing it (DESIGN.md §3
## Variety between runs). Two to start (PLAN.md M5).
## The Id is sent over the network: only add new modifiers at the end.

enum Id { NONE, ARMORED_TURRETS, ELITE_WING }

const NAMES: Array[String] = ["", "Armored Turrets", "Elite Wing"]
const HINTS: Array[String] = ["", "Ground targets are much tougher.", "One wave is replaced by elites."]
## Scrap for clearing a stage with a twist (a bonus stage goal, draft).
const BONUS_SCRAP: int = 40
## ARMORED_TURRETS: ground HP multiplier.
const ARMOR_HP: float = 1.6
## ELITE_WING: elites have this much more HP, shoot this much faster (the
## interval is multiplied) and drop this much more Scrap.
const ELITE_HP: float = 2.5
const ELITE_FIRE_INTERVAL: float = 0.7
const ELITE_SCRAP: int = 2
const ELITE_TINT: Color = Color(1.0, 0.85, 0.35)


## A random twist (never NONE).
static func roll(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, Id.size() - 1)


static func name_of(id: int) -> String:
	return NAMES[clampi(id, 0, NAMES.size() - 1)]


## ELITE_WING: which of a run's waves becomes the elite wave (an air wave with
## more than one enemy, picked from the run's seed).
static func elite_wave(waves: Array[StageDef.WaveDef], seed_value: int) -> int:
	var candidates: Array[int] = []
	for i: int in waves.size():
		if waves[i].count > 1:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return candidates[rng.randi_range(0, candidates.size() - 1)]
