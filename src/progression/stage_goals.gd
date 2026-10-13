class_name StageGoals
extends RefCounted
## Stage goals (Sky Force's medals, DESIGN.md §4) and the light score. Pure:
## the stage counts what happened (Stats), evaluate() says which goals were met
## and what they pay. Draft numbers.
## Goal ids are sent over the network: only add new goals at the end.

enum Id { KILLS_70, KILLS_100, NO_DAMAGE, ALL_GROUND, FAST_BOSS, TWIST }

const NAMES: Array[String] = [
	"Destroy 70% of the enemies",
	"Destroy every enemy",
	"Nobody takes damage",
	"Destroy every ground target",
	"Beat the boss in under 60 s",
	"Beat the stage's twist",
]
const REWARDS: Array[int] = [30, 60, 50, 50, 40, StageModifiers.BONUS_SCRAP]
const FAST_BOSS_SECONDS: float = 60.0
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
	## Seconds from the boss appearing to its death (-1 = not beaten).
	var boss_seconds: float = -1.0
	var modifier: int = StageModifiers.Id.NONE
	var unused_charges: int = 0
	## Score from kills (Scrap value x SCORE_PER_SCRAP).
	var kill_score: int = 0


## The goal ids met in a cleared stage.
static func met(stats: Stats) -> Array[int]:
	var goals: Array[int] = []
	var share := float(stats.air_killed) / maxf(stats.air_spawned, 1.0)
	if share >= 0.7:
		goals.append(Id.KILLS_70)
	if stats.air_spawned > 0 and stats.air_killed >= stats.air_spawned:
		goals.append(Id.KILLS_100)
	if stats.damage_taken == 0:
		goals.append(Id.NO_DAMAGE)
	if stats.ground_total > 0 and stats.ground_destroyed >= stats.ground_total:
		goals.append(Id.ALL_GROUND)
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
