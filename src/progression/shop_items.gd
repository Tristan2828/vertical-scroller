class_name ShopItems
extends RefCounted
## What the shop sells (DESIGN.md §4, draft prices). Personal items change
## your ship for the rest of the run; team items help everyone. Pure: can_buy()
## and apply() work on the RunState.
## The Id is sent over the network: only add new items at the end.

enum Id { POWER_UP, REPAIR, MAX_HP, CHARGE, SWAP_SPECIAL, SPEED, RESPAWN_CREDIT, TEAM_RAPID_FIRE }

const NAMES: Array[String] = ["Power +1", "Repair", "Hull +20", "Special +1", "Swap special", "Engines +8%",
	"Spare ship", "Rapid Fire start"]
const HINTS: Array[String] = [
	"Main gun power +1 (up to 5).",
	"Repairs your ship to full HP.",
	"Max HP +20 (and repairs 20).",
	"One more special charge next stage.",
	"Swap Mega Bomb and Shield.",
	"Fly 8% faster.",
	"One more respawn for the team.",
	"Everyone starts the next stage with Rapid Fire (20 s).",
]
const PRICES: Array[int] = [40, 25, 50, 30, 20, 35, 60, 45]
const PERSONAL: Array[Id] = [Id.POWER_UP, Id.REPAIR, Id.MAX_HP, Id.CHARGE, Id.SWAP_SPECIAL, Id.SPEED]
const TEAM: Array[Id] = [Id.RESPAWN_CREDIT, Id.TEAM_RAPID_FIRE]
const PERSONAL_OFFERS: int = 4
const HP_STEP: int = 20
const SPEED_STEP: float = 0.08
const MAX_SPEED_BONUS: float = 0.24
const TEAM_RAPID_FIRE_SECONDS: float = 20.0


static func is_valid(id: int) -> bool:
	return id >= 0 and id < Id.size()


static func is_team(id: int) -> bool:
	return TEAM.has(id)


static func price(id: int) -> int:
	return PRICES[id]


## A shop visit's offers: PERSONAL_OFFERS different personal items for each
## player, and one team item for everyone.
static func roll_personal(rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	pool.assign(PERSONAL)
	var picks: Array[int] = []
	for i: int in mini(PERSONAL_OFFERS, pool.size()):
		picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picks


static func roll_team(rng: RandomNumberGenerator) -> int:
	return TEAM[rng.randi_range(0, TEAM.size() - 1)]


## Whether buying `id` would do anything for `peer_id` (the price is checked by ShopSession).
static func is_useful(id: int, run: RunState, peer_id: int) -> bool:
	var player := run.player(peer_id)
	match id:
		Id.POWER_UP:
			return player.power < ShipMotor.MAX_POWER
		Id.REPAIR:
			return player.hp >= 0 and player.hp < max_hp_of(player)
		Id.SPEED:
			return player.speed_bonus < MAX_SPEED_BONUS - 0.001
		Id.TEAM_RAPID_FIRE:
			return run.team_rapid_fire <= 0.0
	return true


static func max_hp_of(player: RunState.PlayerRun) -> int:
	return Ships.ALL[player.ship].max_hp + player.max_hp_bonus


## Applies a bought item to the run.
static func apply(id: int, run: RunState, peer_id: int) -> void:
	var player := run.player(peer_id)
	match id:
		Id.POWER_UP:
			player.power = mini(player.power + 1, ShipMotor.MAX_POWER)
		Id.REPAIR:
			player.hp = -1
		Id.MAX_HP:
			player.max_hp_bonus += HP_STEP
			if player.hp >= 0:
				player.hp += HP_STEP
		Id.CHARGE:
			player.extra_charges += 1
		Id.SWAP_SPECIAL:
			player.special = (player.special + 1) % Specials.Kind.size()
		Id.SPEED:
			player.speed_bonus = minf(player.speed_bonus + SPEED_STEP, MAX_SPEED_BONUS)
		Id.RESPAWN_CREDIT:
			run.credits += 1
		Id.TEAM_RAPID_FIRE:
			run.team_rapid_fire = TEAM_RAPID_FIRE_SECONDS
