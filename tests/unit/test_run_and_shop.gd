extends GutTest
## The run between stages: run state, stage goals, the shop's rules and scene,
## modifiers and the personal best.

const RECORDS_PATH: String = "user://test_records.cfg"


func before_each() -> void:
	RunSetup.order = []
	RunSetup.ships = {}
	RunSetup.specials = {}
	RunState.current = RunState.new()


func after_all() -> void:
	DirAccess.remove_absolute(RECORDS_PATH)
	RunState.current = RunState.new()


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- RunState ---------------------------------------------------------------------

func test_a_new_run_has_everyone_and_a_twist_only_after_the_first_stage() -> void:
	var run := RunState.start([1, 42], _rng())
	assert_eq(run.players.keys(), [1, 42])
	assert_eq(run.modifiers[0], StageModifiers.Id.NONE)
	assert_ne(run.modifiers[1], StageModifiers.Id.NONE)
	assert_eq(run.credits, Stage.START_CREDITS)
	assert_same(RunState.current, run)


func test_runs_get_harder_stage_by_stage() -> void:
	var run := RunState.start([1], _rng())
	assert_eq(run.difficulty(), 1.0)
	run.stages_done = 1
	assert_gt(run.difficulty(), 1.0)
	assert_true(run.has_next_stage())
	run.stages_done = 2
	assert_false(run.has_next_stage())


func test_run_state_survives_the_network() -> void:
	var run := RunState.start([1, 42], _rng())
	run.team_scrap = 77
	run.player(42).power = 3
	run.player(42).speed_bonus = 0.16
	var copy := RunState.from_dict(run.to_dict())
	assert_eq(copy.team_scrap, 77)
	assert_eq(copy.players.keys(), [1, 42], "lobby order is kept")
	assert_eq(copy.player(42).power, 3)
	assert_almost_eq(copy.player(42).speed_bonus, 0.16, 0.0001)
	assert_eq(copy.modifiers, run.modifiers)


# --- Stage goals -----------------------------------------------------------------

func _stats() -> StageGoals.Stats:
	var stats := StageGoals.Stats.new()
	stats.air_spawned = 100
	stats.ground_total = 20
	stats.damage_taken = 30
	return stats


func test_goals_are_met_by_what_happened() -> void:
	var stats := _stats()
	stats.air_killed = 70
	stats.ground_destroyed = 20
	stats.boss_seconds = 45.0
	assert_eq(StageGoals.met(stats), [StageGoals.Id.KILLS_70, StageGoals.Id.ALL_GROUND, StageGoals.Id.FAST_BOSS] as Array[int])
	stats.air_killed = 100
	stats.damage_taken = 0
	assert_true(StageGoals.met(stats).has(StageGoals.Id.KILLS_100))
	assert_true(StageGoals.met(stats).has(StageGoals.Id.NO_DAMAGE))


func test_payout_adds_goals_and_unused_charges() -> void:
	var stats := _stats()
	stats.air_killed = 70
	stats.unused_charges = 2
	assert_eq(StageGoals.payout(stats), StageGoals.REWARDS[StageGoals.Id.KILLS_70] + 2 * StageGoals.CHARGE_PAYOUT)


func test_a_twist_is_a_bonus_goal() -> void:
	var stats := _stats()
	stats.modifier = StageModifiers.Id.ELITE_WING
	assert_true(StageGoals.met(stats).has(StageGoals.Id.TWIST))


func test_score_counts_kills_goals_and_the_boss() -> void:
	var stats := _stats()
	stats.kill_score = 1234
	stats.boss_seconds = 90.0
	assert_eq(StageGoals.score(stats), 1234 + StageGoals.SCORE_BOSS)


# --- Shop items and session -------------------------------------------------------

func test_offers_are_four_different_personal_items_and_one_team_item() -> void:
	var offers := ShopItems.roll_personal(_rng(5))
	assert_eq(offers.size(), ShopItems.PERSONAL_OFFERS)
	for item: int in offers:
		assert_false(ShopItems.is_team(item))
		assert_eq(offers.count(item), 1)
	assert_true(ShopItems.is_team(ShopItems.roll_team(_rng(5))))


func test_every_item_has_a_name_a_hint_and_a_price() -> void:
	assert_eq(ShopItems.NAMES.size(), ShopItems.Id.size())
	assert_eq(ShopItems.HINTS.size(), ShopItems.Id.size())
	assert_eq(ShopItems.PRICES.size(), ShopItems.Id.size())


func test_items_change_the_run() -> void:
	var run := RunState.start([1], _rng())
	ShopItems.apply(ShopItems.Id.POWER_UP, run, 1)
	ShopItems.apply(ShopItems.Id.MAX_HP, run, 1)
	ShopItems.apply(ShopItems.Id.SWAP_SPECIAL, run, 1)
	ShopItems.apply(ShopItems.Id.RESPAWN_CREDIT, run, 1)
	assert_eq(run.player(1).power, 2)
	assert_eq(run.player(1).max_hp_bonus, ShopItems.HP_STEP)
	assert_eq(run.player(1).special, Specials.Kind.SHIELD)
	assert_eq(run.credits, Stage.START_CREDITS + 1)


func test_useless_items_cant_be_bought() -> void:
	var run := RunState.start([1], _rng())
	assert_false(ShopItems.is_useful(ShopItems.Id.REPAIR, run, 1), "already at full HP")
	run.player(1).hp = 40
	assert_true(ShopItems.is_useful(ShopItems.Id.REPAIR, run, 1))
	run.player(1).power = ShipMotor.MAX_POWER
	assert_false(ShopItems.is_useful(ShopItems.Id.POWER_UP, run, 1))


func _session(scrap: int, players: Array[int]) -> ShopSession:
	var session := ShopSession.new()
	var offers: Dictionary[int, Array] = {}
	for peer_id: int in players:
		offers[peer_id] = [ShopItems.Id.POWER_UP, ShopItems.Id.MAX_HP, ShopItems.Id.SPEED, ShopItems.Id.CHARGE]
	session.start(players, scrap, offers, ShopItems.Id.RESPAWN_CREDIT)
	return session


func test_the_wallet_is_split_evenly() -> void:
	var session := _session(101, [1, 2, 3])
	assert_eq(session.wallets, {1: 34, 2: 34, 3: 33} as Dictionary[int, int])
	assert_eq(session.leftovers(), 101)


func test_buying_spends_your_share_once() -> void:
	var run := RunState.start([1, 2], _rng())
	var session := _session(200, [1, 2])
	assert_true(session.buy(1, ShopItems.Id.POWER_UP, run))
	assert_eq(session.wallets[1], 100 - ShopItems.price(ShopItems.Id.POWER_UP))
	assert_false(session.buy(1, ShopItems.Id.POWER_UP, run), "each offer once")
	assert_false(session.buy(1, ShopItems.Id.REPAIR, run), "not offered")
	assert_eq(session.wallets[2], 100, "a teammate's share is theirs")


func test_too_expensive_until_a_teammate_chips_in() -> void:
	var run := RunState.start([1, 2], _rng())
	var session := _session(60, [1, 2])
	assert_false(session.buy(1, ShopItems.Id.MAX_HP, run), "50 needed, 30 in the wallet")
	assert_eq(session.chip_in(2, 1), ShopSession.CHIP_IN_STEP)
	assert_eq(session.chip_in(2, 1), ShopSession.CHIP_IN_STEP)
	assert_true(session.buy(1, ShopItems.Id.MAX_HP, run))
	assert_eq(session.leftovers(), 10)


func test_the_team_offer_sells_once() -> void:
	var run := RunState.start([1, 2], _rng())
	var session := _session(400, [1, 2])
	assert_true(session.buy(1, ShopItems.Id.RESPAWN_CREDIT, run))
	assert_false(session.buy(2, ShopItems.Id.RESPAWN_CREDIT, run))


func test_soft_timer_starts_when_half_the_team_is_ready() -> void:
	var session := _session(0, [1, 2, 3, 4])
	session.mark_ready(1)
	assert_lt(session.countdown_left, 0.0)
	session.mark_ready(2)
	assert_eq(session.countdown_left, ShopSession.SOFT_TIMER_SECONDS)
	assert_false(session.is_finished())
	session.tick(ShopSession.SOFT_TIMER_SECONDS)
	assert_true(session.is_finished(), "the timer ran out")


func test_shop_closes_when_everyone_is_ready() -> void:
	var session := _session(0, [1, 2])
	session.mark_ready(1)
	session.mark_ready(2)
	assert_true(session.is_finished())


func test_ready_players_cant_buy_or_give() -> void:
	var run := RunState.start([1, 2], _rng())
	var session := _session(200, [1, 2])
	session.mark_ready(1)
	assert_false(session.buy(1, ShopItems.Id.POWER_UP, run))
	assert_eq(session.chip_in(1, 2), 0)


func test_shop_scene_solo() -> void:
	var run := RunState.start([1], _rng())
	run.team_scrap = 100
	run.stages_done = 1
	var shop := (load("res://src/shop/shop.tscn") as PackedScene).instantiate() as Shop
	add_child_autofree(shop)
	watch_signals(shop)
	assert_eq(shop.session.wallets[1], 100)
	var item: int = shop.session.offers[1][0]
	shop._buy_locally(item)
	assert_eq(shop.session.wallets[1], 100 - ShopItems.price(item))
	shop._ready_locally()
	await wait_process_frames(2)
	assert_signal_emitted(shop, "finished")
	assert_eq(run.team_scrap, 100 - ShopItems.price(item), "leftovers go back to the team")


# --- Modifiers and records ---------------------------------------------------------

func test_elite_wave_is_a_real_wave_picked_from_the_seed() -> void:
	var waves := Stages.get_stage(0).waves_for_seed(3)
	var index := StageModifiers.elite_wave(waves, 99)
	assert_gte(index, 0)
	assert_gt(waves[index].count, 1)
	assert_eq(StageModifiers.elite_wave(waves, 99), index)


func test_personal_best_only_goes_up() -> void:
	DirAccess.remove_absolute(RECORDS_PATH)
	assert_eq(RunRecords.best_score(RECORDS_PATH), 0)
	assert_true(RunRecords.submit(500, RECORDS_PATH))
	assert_false(RunRecords.submit(300, RECORDS_PATH))
	assert_eq(RunRecords.best_score(RECORDS_PATH), 500)


func test_run_summary_shows_the_run() -> void:
	var run := RunState.start([1], _rng())
	run.result = "won"
	run.stages_done = 2
	var summary := (load("res://src/ui/run_summary.tscn") as PackedScene).instantiate() as RunSummary
	add_child_autofree(summary)
	assert_string_contains(summary.debug_report(), "won, 2 of 2 stages")


# --- Boss only (lobby switch, for testing) --------------------------------------------

func test_boss_only_is_part_of_the_run_and_survives_the_network() -> void:
	RunSetup.boss_only = true
	var run := RunState.start([1], _rng())
	RunSetup.boss_only = false
	assert_true(run.boss_only)
	assert_true(RunState.from_dict(run.to_dict()).boss_only)


func test_boss_only_stages_start_just_before_the_boss() -> void:
	var run := RunState.start([1], _rng())
	run.boss_only = true
	var stage := (load("res://src/stage/stage.tscn") as PackedScene).instantiate() as Stage
	stage.set_physics_process(false)
	add_child_autofree(stage)
	assert_almost_eq(stage.stage_time, stage.def.length - Stage.BOSS_ONLY_LEAD, 0.001)
	stage.local_ship().test_input = ShipInput.new()
	for i: int in roundi((Stage.BOSS_ONLY_LEAD + 0.5) * 60.0):
		stage.tick(1.0 / 60.0)
	assert_eq(stage.phase, Stage.Phase.BOSS)


func test_boss_only_runs_dont_count_toward_the_personal_best() -> void:
	var run := RunState.start([1], _rng())
	run.boss_only = true
	run.result = "won"
	run.score = 999999
	var summary := (load("res://src/ui/run_summary.tscn") as PackedScene).instantiate() as RunSummary
	add_child_autofree(summary)
	assert_false(summary.new_best)
