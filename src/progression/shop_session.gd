class_name ShopSession
extends RefCounted
## One shop visit between stages (host only). Pure logic, no networking; the
## idea comes from Medieval Survival's ShopSession (DESIGN.md §4 Shop).
##
## - The team's wallet is split evenly when the shop opens; each player spends
##   their share (the remainder of an uneven split goes to the first players).
## - "Chip in" gives some of your Scrap to a teammate, so the team can pool money.
## - Each player has their own personal offers; the team offer is shared and
##   can be bought once, by anyone.
## - Ready-up: the shop closes when everyone is ready, or when the soft timer
##   runs out; the timer starts once half the team is ready.
## - What's left in everyone's wallet goes back to the team's wallet.

const SOFT_TIMER_SECONDS: float = 60.0
const CHIP_IN_STEP: int = 10

## peer id -> Scrap they can spend now.
var wallets: Dictionary[int, int] = {}
## peer id -> offered ShopItems ids (personal).
var offers: Dictionary[int, Array] = {}
## peer id -> items they bought.
var bought: Dictionary[int, Array] = {}
var team_offer: int = ShopItems.Id.RESPAWN_CREDIT
var team_offer_sold: bool = false
var ready: Dictionary[int, bool] = {}
## Seconds left on the soft timer; negative = not started yet.
var countdown_left: float = -1.0


## `team_scrap` is split between `players` (in lobby order).
func start(players: Array[int], team_scrap: int, personal_offers: Dictionary[int, Array], team_item: int) -> void:
	wallets.clear()
	ready.clear()
	bought.clear()
	offers = personal_offers
	team_offer = team_item
	team_offer_sold = false
	countdown_left = -1.0
	var share := team_scrap / maxi(players.size(), 1)
	var remainder := team_scrap - share * players.size()
	for i: int in players.size():
		wallets[players[i]] = share + (1 if i < remainder else 0)
		bought[players[i]] = []


## A player who arrives during the shop: an empty wallet (teammates can chip in).
func add_player(peer_id: int, personal_offers: Array) -> void:
	if wallets.has(peer_id):
		return
	wallets[peer_id] = 0
	offers[peer_id] = personal_offers
	bought[peer_id] = []


func remove(peer_id: int) -> void:
	wallets.erase(peer_id)
	offers.erase(peer_id)
	bought.erase(peer_id)
	ready.erase(peer_id)


func can_buy(peer_id: int, item: int, run: RunState) -> bool:
	if not wallets.has(peer_id) or ready.has(peer_id) or not ShopItems.is_valid(item):
		return false
	if ShopItems.is_team(item):
		if item != team_offer or team_offer_sold:
			return false
	elif not (offers.get(peer_id, []) as Array).has(item) or (bought[peer_id] as Array).has(item):
		return false
	return wallets[peer_id] >= ShopItems.price(item) and ShopItems.is_useful(item, run, peer_id)


## Returns true if bought (and applies it to the run).
func buy(peer_id: int, item: int, run: RunState) -> bool:
	if not can_buy(peer_id, item, run):
		return false
	wallets[peer_id] -= ShopItems.price(item)
	(bought[peer_id] as Array).append(item)
	if ShopItems.is_team(item):
		team_offer_sold = true
	ShopItems.apply(item, run, peer_id)
	return true


## Gives up to `amount` of `from`'s Scrap to `to`. Returns how much moved.
func chip_in(from: int, to: int, amount: int = CHIP_IN_STEP) -> int:
	if from == to or not wallets.has(from) or not wallets.has(to) or ready.has(from):
		return 0
	var moved := mini(amount, wallets[from])
	wallets[from] -= moved
	wallets[to] += moved
	return moved


## Returns true if this changed anything.
func mark_ready(peer_id: int) -> bool:
	if not wallets.has(peer_id) or ready.has(peer_id):
		return false
	ready[peer_id] = true
	if countdown_left < 0.0 and ready.size() * 2 >= wallets.size():
		countdown_left = SOFT_TIMER_SECONDS
	return true


func tick(delta: float) -> void:
	if countdown_left > 0.0:
		countdown_left = maxf(countdown_left - delta, 0.0)


func is_finished() -> bool:
	return ready.size() >= wallets.size() or countdown_left == 0.0


func waiting_for() -> Array[int]:
	var waiting: Array[int] = []
	for peer_id: int in wallets:
		if not ready.has(peer_id):
			waiting.append(peer_id)
	return waiting


## What goes back to the team's wallet when the shop closes.
func leftovers() -> int:
	var total := 0
	for peer_id: int in wallets:
		total += wallets[peer_id]
	return total
