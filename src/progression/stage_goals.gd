class_name StageGoals
extends RefCounted
## Stage goals (Sky Force's medals, DESIGN.md §4) and the light score. Pure:
## the stage counts what happened (Stats), evaluate() says which goals were met
## and what they pay. Draft numbers.
## Goal ids are sent over the network: only add new goals at the end.
## Playtest 3: kills and ground targets pay in tiers (50 / 75 / 90%, and the
## tiers stack), and "nobody takes damage" became "the team keeps 75% of its
## HP": on the busier stage 100% and no-damage were out of reach. The old ids
## stay (append only) but are RETIRED: never awarded or shown.

enum Id {
	KILLS_70, KILLS_100, NO_DAMAGE, ALL_GROUND, FAST_BOSS, TWIST,
	KILLS_50, KILLS_75, KILLS_90, GROUND_50, GROUND_75, GROUND_90, LOW_DAMAGE,
}

const NAMES: Array[String] = [
	"Destroy 70% of the enemies",
	"Destroy every enemy",
	"Nobody takes damage",
	"Destroy every ground target",
	"Beat the boss in under 90 s",
	"Beat the stage's twist",
	"Destroy 50% of the enemies",
	"Destroy 75% of the enemies",
	"Destroy 90% of the enemies",
	"Destroy 50% of the ground targets",
	"Destroy 75% of the ground targets",
	"Destroy 90% of the ground targets",
	"The team loses under 25% of its HP",
]
const REWARDS: Array[int] = [30, 60, 50, 50, 40, StageModifiers.BONUS_SCRAP, 20, 25, 30, 15, 20, 25, 40]
const RETIRED: Array[int] = [Id.KILLS_70, Id.KILLS_100, Id.NO_DAMAGE, Id.ALL_GROUND]
## The order the results panel lists goals in.
const SHOWN: Array[int] = [
	Id.KILLS_50, Id.KILLS_75, Id.KILLS_90, Id.GROUND_50, Id.GROUND_75, Id.GROUND_90, Id.LOW_DAMAGE, Id.FAST_BOSS, Id.TWIST,
]
## LOW_DAMAGE: the team may lose up to this share of its total max HP.
const LOW_DAMAGE_SHARE: float = 0.25
const FAST_BOSS_SECONDS: float = 90.0
## Unused special charges pay out at the end of a stage (DESIGN.md §3 Specials).
const CHARGE_PAYOUT: int = 15
## Score: per point of Scrap a kill is worth, per goal met, for the boss.
const SCORE_PER_SCRAP: int = 10
const SCORE_PER_GOAL: int = 500
const SCORE_BOSS: int = 2000


## What the host counted during a stage.
class Stats:
	extends RefCounted
	var air_spawned: int = 0
	var air_killed: int = 0
	var ground_total: int = 0
	var ground_destroyed: int = 0
	var damage_taken: int = 0
	## Every ship's max HP added up (for LOW_DAMAGE).
	var team_max_hp: int = 0
	## Seconds from the boss appearing to its death (-1 = not beaten).
	var boss_seconds: float = -1.0
	var modifier: int = StageModifiers.Id.NONE
	var unused_charges: int = 0
	## Score from kills (Scrap value x SCORE_PER_SCRAP).
	var kill_score: int = 0


## The goal ids met in a cleared stage.
static func met(stats: Stats) -> Array[int]:
	var goals: Array[int] = []
	var kills := float(stats.air_killed) / maxf(stats.air_spawned, 1.0)
	var ground := float(stats.ground_destroyed) / maxf(stats.ground_total, 1.0)
	if stats.air_spawned > 0:
		for tier: Array in [[0.5, Id.KILLS_50], [0.75, Id.KILLS_75], [0.9, Id.KILLS_90]]:
			if kills >= tier[0]:
				goals.append(tier[1])
	if stats.ground_total > 0:
		for tier: Array in [[0.5, Id.GROUND_50], [0.75, Id.GROUND_75], [0.9, Id.GROUND_90]]:
			if ground >= tier[0]:
				goals.append(tier[1])
	if stats.team_max_hp > 0 and stats.damage_taken < stats.team_max_hp * LOW_DAMAGE_SHARE:
		goals.append(Id.LOW_DAMAGE)
	if stats.boss_seconds >= 0.0 and stats.boss_seconds < FAST_BOSS_SECONDS:
		goals.append(Id.FAST_BOSS)
	if stats.modifier != StageModifiers.Id.NONE:
		goals.append(Id.TWIST)
	return goals


## Scrap the stage pays at the end: goals met plus unused charges.
static func payout(stats: Stats) -> int:
	var total := stats.unused_charges * CHARGE_PAYOUT
	for goal: int in met(stats):
		total += REWARDS[goal]
	return total


static func score(stats: Stats) -> int:
	return stats.kill_score + met(stats).size() * SCORE_PER_GOAL + (SCORE_BOSS if stats.boss_seconds >= 0.0 else 0)
