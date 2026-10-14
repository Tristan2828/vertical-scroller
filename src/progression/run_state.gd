class_name RunState
extends RefCounted
## Everything a run keeps between its stages and shops (DESIGN.md §4): the
## team's wallet, respawn credits and score, which stage comes next, and each
## player's ship upgrades. The host owns it (the static `current`); each scene
## sends clients a copy (to_dict / from_dict) when it loads.

## One player's part of the run.
class PlayerRun:
	extends RefCounted
	var ship: int = 0
	var special: int = Specials.Kind.MEGA_BOMB
	## HP carries over between stages (the shop sells repairs). -1 = full.
	var hp: int = -1
	var max_hp_bonus: int = 0
	var power: int = 1
	## Move and focus speed bonus (0.08 = +8%).
	var speed_bonus: float = 0.0
	## Extra special charges for the next stage only (shop).
	var extra_charges: int = 0
	var kills: int = 0
	var damage: int = 0
	var downs: int = 0

	func to_dict() -> Dictionary:
		return {"ship": ship, "special": special, "hp": hp, "max_hp_bonus": max_hp_bonus, "power": power,
			"speed_bonus": speed_bonus, "extra_charges": extra_charges, "kills": kills, "damage": damage, "downs": downs}

	static func from_dict(data: Dictionary) -> PlayerRun:
		var player := PlayerRun.new()
		player.ship = clampi(int(data.get("ship", 0)), 0, Ships.ALL.size() - 1)
		var special_kind := int(data.get("special", 0))
		player.special = special_kind if Specials.is_valid(special_kind) else Specials.Kind.MEGA_BOMB
		player.hp = int(data.get("hp", -1))
		player.max_hp_bonus = maxi(int(data.get("max_hp_bonus", 0)), 0)
		player.power = clampi(int(data.get("power", 1)), 1, ShipMotor.MAX_POWER)
		player.speed_bonus = clampf(float(data.get("speed_bonus", 0.0)), 0.0, 1.0)
		player.extra_charges = maxi(int(data.get("extra_charges", 0)), 0)
		player.kills = int(data.get("kills", 0))
		player.damage = int(data.get("damage", 0))
		player.downs = int(data.get("downs", 0))
		return player


## The run in progress (host: the real one; clients: the last copy they got).
static var current: RunState = RunState.new()

## Stages.PATHS index of each stage of the run, in order. v0.1.0: Planet Base,
## then Planet Base again, harder (PLAN.md M5).
var stage_plan: Array[int] = [0, 0]
## How many stages have been played (the next one is stage_plan[stages_done]).
var stages_done: int = 0
## StageModifiers.Id of each planned stage.
var modifiers: Array[int] = []
var team_scrap: int = 0
var credits: int = 3
var score: int = 0
## Team boost bought in the shop, for the start of the next stage (0 = none).
var team_rapid_fire: float = 0.0
## "won" / "lost" / "" while playing.
var result: String = ""
## Boss only (lobby switch, for testing): every stage starts just before its
## boss. Doesn't count toward the personal best.
var boss_only: bool = false
var seed_value: int = 0
## peer id -> their part of the run.
var players: Dictionary[int, PlayerRun] = {}


## Host: a fresh run for the lobby's players.
static func start(order: Array[int], rng: RandomNumberGenerator) -> RunState:
	var run := RunState.new()
	run.seed_value = rng.randi()
	run.credits = Stage.START_CREDITS
	run.boss_only = RunSetup.boss_only
	for i: int in run.stage_plan.size():
		# The first stage plays straight; later ones roll a twist (draft).
		run.modifiers.append(StageModifiers.Id.NONE if i == 0 else StageModifiers.roll(rng))
	for peer_id: int in order:
		run.player(peer_id)
	current = run
	return run


## This player's part (made with the lobby's choices if they're new, e.g. a
## friend who joined mid-run).
func player(peer_id: int) -> PlayerRun:
	if not players.has(peer_id):
		var fresh := PlayerRun.new()
		fresh.ship = RunSetup.ship_for(peer_id)
		fresh.special = RunSetup.special_for(peer_id)
		players[peer_id] = fresh
	return players[peer_id]


func is_over() -> bool:
	return not result.is_empty()


func has_next_stage() -> bool:
	return stages_done < stage_plan.size()


## Stages.PATHS index of the stage being (or about to be) played.
func stage_index() -> int:
	return stage_plan[clampi(stages_done, 0, stage_plan.size() - 1)]


func modifier() -> int:
	var at := clampi(stages_done, 0, stage_plan.size() - 1)
	return modifiers[at] if at < modifiers.size() else StageModifiers.Id.NONE


## Enemy HP and gun speed grow with each stage played (draft).
func difficulty() -> float:
	return 1.0 + 0.3 * stages_done


func to_dict() -> Dictionary:
	var player_data: Dictionary = {}
	for peer_id: int in players:
		player_data[peer_id] = players[peer_id].to_dict()
	return {"stage_plan": stage_plan, "stages_done": stages_done, "modifiers": modifiers, "team_scrap": team_scrap,
		"credits": credits, "score": score, "team_rapid_fire": team_rapid_fire, "result": result, "boss_only": boss_only,
		"seed": seed_value, "players": player_data}


static func from_dict(data: Dictionary) -> RunState:
	var run := RunState.new()
	run.stage_plan.clear()
	for index: Variant in data.get("stage_plan", [0]):
		run.stage_plan.append(clampi(int(index), 0, Stages.PATHS.size() - 1))
	run.stages_done = int(data.get("stages_done", 0))
	for id: Variant in data.get("modifiers", []):
		run.modifiers.append(clampi(int(id), 0, StageModifiers.Id.size() - 1))
	run.team_scrap = int(data.get("team_scrap", 0))
	run.credits = int(data.get("credits", 0))
	run.score = int(data.get("score", 0))
	run.team_rapid_fire = float(data.get("team_rapid_fire", 0.0))
	run.result = str(data.get("result", ""))
	run.boss_only = bool(data.get("boss_only", false))
	run.seed_value = int(data.get("seed", 0))
	var player_data: Dictionary = data.get("players", {})
	for key: Variant in player_data:
		run.players[int(key)] = PlayerRun.from_dict(player_data[key])
	return run
