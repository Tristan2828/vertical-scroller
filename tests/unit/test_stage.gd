extends GutTest
## The stage (solo here: GUT runs with an offline peer, which acts as the host).

const DELTA: float = 1.0 / 60.0

var stage: Stage


func before_each() -> void:
	RunSetup.order = []
	RunSetup.ships = {}
	RunSetup.specials = {}
	RunState.current = RunState.new()
	LaunchOptions.weak_bosses = false
	LaunchOptions.invincible = false
	LaunchOptions.start_at_seconds = 0.0


func after_each() -> void:
	LaunchOptions.weak_bosses = false
	LaunchOptions.invincible = false
	LaunchOptions.start_at_seconds = 0.0


func _make_stage() -> void:
	stage = (load("res://src/stage/stage.tscn") as PackedScene).instantiate() as Stage
	# Gameplay is driven by tick() below, not by the engine's physics loop.
	stage.set_physics_process(false)
	add_child_autofree(stage)
	stage.local_ship().test_input = ShipInput.new()


func _firing(focus: bool = false) -> ShipInput:
	var input := ShipInput.new()
	input.fire = true
	input.focus = focus
	return input


func _ticks(count: int) -> void:
	for i: int in count:
		stage.tick(DELTA)


## Fires and steers like a player aiming: under the lowest air enemy, or else
## under a standing ground target. Every other 4 seconds it goes for ground
## targets first (the stage has so many air enemies that it would never get to them).
func _hunt(ticks: int) -> void:
	var ship := stage.local_ship()
	ship.test_input = _firing()
	for i: int in ticks:
		var target_x := ship.state.position.x
		var lowest := -INF
		var ground_first := (i / 240) % 2 == 1
		for index: int in stage.enemies.alive_indices():
			var at := stage.enemies.position_of(index)
			if not ground_first and at.y > lowest and at.y < ship.state.position.y - 40.0:
				lowest = at.y
				target_x = at.x
		if lowest == -INF:
			for index: int in stage.ground.count():
				if stage.ground.is_alive(index) and stage.ground.position_of(index).y > 0.0:
					target_x = stage.ground.position_of(index).x
					break
		var dx := target_x - ship.state.position.x
		ship.test_input.move = Vector2(clampf(dx / 8.0, -1.0, 1.0), 0.0)
		stage.tick(DELTA)
		if not stage.is_physics_processing() and stage.phase != Stage.Phase.PLAYING and stage.phase != Stage.Phase.BOSS:
			return


func test_solo_has_one_ship_in_slot_0() -> void:
	_make_stage()
	assert_eq(stage.ships().size(), 1)
	assert_eq(stage.local_ship().slot, 0)
	assert_eq(stage.local_ship().special_charges, Specials.charges_of(Specials.Kind.MEGA_BOMB))


func test_the_first_wave_arrives_on_time() -> void:
	_make_stage()
	var first := stage.def.waves_for_seed(0)[0]
	_ticks(roundi(first.time / DELTA) + 2)
	assert_gt(stage.enemies.active_count(), 0)


func test_scroll_follows_stage_time() -> void:
	_make_stage()
	_ticks(60)
	assert_almost_eq(stage.background.scroll, stage.def.scroll_speed * stage.stage_time, 0.001)


func test_one_shot_spawns_one_bullet_per_stream() -> void:
	_make_stage()
	stage.local_ship().test_input = _firing()
	_ticks(1)
	assert_eq(stage.player_bullets.count(), 3)


func test_more_power_means_more_streams() -> void:
	_make_stage()
	stage.local_ship().state.power = 5
	stage.local_ship().test_input = _firing()
	_ticks(1)
	assert_eq(stage.player_bullets.count(), 7)


func test_wingmen_add_two_bolts() -> void:
	_make_stage()
	stage.local_ship().state.wingmen_left = 5.0
	stage.local_ship().test_input = _firing()
	_ticks(1)
	assert_eq(stage.player_bullets.count(), 5)


func test_enemies_shoot_back_and_hurt_a_ship_that_sits_still() -> void:
	_make_stage()
	var ship := stage.local_ship()
	_ticks(60 * 40)
	assert_true(ship.health.hp < ship.health.max_hp or stage.credits < Stage.START_CREDITS)


func test_contact_with_an_enemy_hurts_and_a_kamikaze_blows_up() -> void:
	_make_stage()
	var ship := stage.local_ship()
	var kamikaze := EnemyTypes.from_key("kamikaze")
	var index := stage.enemies.spawn(kamikaze, PathShapes.Id.STRAIGHT, stage.stage_time, ship.state.position)
	_ticks(2)
	assert_eq(ship.health.hp, ship.health.max_hp - EnemyTypes.ALL[kamikaze].contact_damage)
	assert_false(stage.enemies.is_alive(index))


func test_kamikazes_lock_onto_the_ship() -> void:
	_make_stage()
	var ship := stage.local_ship()
	var kamikaze := EnemyTypes.from_key("kamikaze")
	var index := stage.enemies.spawn(kamikaze, PathShapes.Id.STRAIGHT, stage.stage_time, Vector2(100, 40))
	_ticks(roundi((EnemyTypes.ALL[kamikaze].homing_delay + Stage.HOMING_EVERY) / DELTA) + 1)
	assert_true(stage.enemies.has_redirect(index))
	var now := stage.enemies.position_of(index)
	var heading := (stage.enemies.position_at(index, stage.stage_time + 0.1) - now).normalized()
	var to_ship := (ship.state.position - now).normalized()
	assert_gt(heading.dot(to_ship), 0.9, "flying at the ship")


func test_shooting_for_a_minute_destroys_targets_and_collects_scrap() -> void:
	_make_stage()
	LaunchOptions.invincible = true
	_hunt(60 * 60)
	assert_gt(stage.kills, 5)
	assert_gt(stage.ground_kills, 0)
	assert_gt(stage.team_scrap, 0, "the magnet pulls in drops")


func test_killing_an_enemy_drops_its_scrap() -> void:
	_make_stage()
	var drone := EnemyTypes.from_key("drone")
	var index := stage.enemies.spawn(drone, PathShapes.Id.STRAIGHT, stage.stage_time, Vector2(100, 60))
	_ticks(1)
	stage.enemies.damage(index, 999, 1)
	assert_gte(stage.pickups.count(), 1)


func test_a_downed_ship_respawns_from_the_team_pool_with_less_power() -> void:
	_make_stage()
	var ship := stage.local_ship()
	ship.state.power = 3
	ship.take_hit(999)
	assert_true(ship.is_down())
	assert_eq(ship.state.power, 2)
	_ticks(roundi(Ship.RESPAWN_DELAY / DELTA) + 2)
	assert_false(ship.is_down())
	assert_eq(stage.credits, Stage.START_CREDITS - 1)
	assert_true(ship.health.is_invulnerable(), "a moment of safety")


func test_downed_ships_cant_be_hit_or_shoot() -> void:
	_make_stage()
	var ship := stage.local_ship()
	ship.take_hit(999)
	ship.test_input = _firing()
	_ticks(1)
	assert_eq(stage.player_bullets.count(), 0)
	assert_false(ship.take_hit(10))


func test_game_over_when_everyone_is_down_with_no_credits() -> void:
	_make_stage()
	watch_signals(stage)
	stage.credits = 0
	stage.local_ship().take_hit(999)
	_ticks(2)
	assert_eq(stage.phase, Stage.Phase.GAME_OVER)
	_ticks(roundi(Stage.END_SECONDS / DELTA) + 2)
	assert_signal_emitted(stage, "finished")


func test_mega_bomb_clears_bullets_and_hits_everything_once() -> void:
	_make_stage()
	var ship := stage.local_ship()
	var fighter := EnemyTypes.from_key("fighter")
	var index := stage.enemies.spawn(fighter, PathShapes.Id.STRAIGHT, stage.stage_time, Vector2(300, 100))
	_ticks(1)
	stage.enemy_bullets.spawn(Vector2(500, 200), Vector2.ZERO, 10, 5.0, 0)
	ship.test_input.special_count = 1
	_ticks(1)
	assert_eq(stage.enemy_bullets.count(), 0)
	assert_false(stage.enemies.is_alive(index), "250 damage beats a 70 HP fighter")
	assert_eq(ship.special_charges, 0)
	ship.test_input.special_count = 2
	_ticks(1)
	assert_eq(ship.special_charges, 0, "no charges left: nothing happens")


func test_shield_blocks_hits_and_eats_bullets() -> void:
	RunSetup.specials = {1: Specials.Kind.SHIELD}
	_make_stage()
	var ship := stage.local_ship()
	assert_eq(ship.special_charges, 3)
	ship.test_input.special_count = 1
	_ticks(1)
	assert_gt(ship.state.shield_left, 0.0)
	assert_false(ship.take_hit(10))
	stage.enemy_bullets.spawn(ship.state.position + Vector2(10, 0), Vector2.ZERO, 10, 5.0, 0)
	_ticks(1)
	assert_eq(stage.enemy_bullets.count(), 0)
	assert_eq(ship.health.hp, ship.health.max_hp)


func test_power_orb_raises_power_up_to_five() -> void:
	_make_stage()
	var ship := stage.local_ship()
	for i: int in 6:
		stage._on_pickup_collected(Pickups.Kind.POWER_ORB, 1, 1)
	assert_eq(ship.state.power, ShipMotor.MAX_POWER)
	# Power 1 -> 5 takes 4 orbs; the other 2 are Scrap instead.
	assert_eq(stage.team_scrap, 2 * Pickups.MAX_POWER_SCRAP)


func test_boss_comes_when_the_waves_are_over_and_the_scroll_stops() -> void:
	LaunchOptions.start_at_seconds = 239.0
	_make_stage()
	_ticks(120)
	assert_eq(stage.phase, Stage.Phase.BOSS)
	var scroll := stage.background.scroll
	_ticks(60)
	assert_eq(stage.background.scroll, scroll, "the map stopped")
	_ticks(60 * 4)
	assert_gt(stage.enemy_bullets.count(), 0, "the boss attacks")
	assert_lt(stage.boss_hp_ratio, 1.01)


func test_beating_the_boss_clears_the_stage() -> void:
	LaunchOptions.start_at_seconds = 239.0
	LaunchOptions.weak_bosses = true
	LaunchOptions.invincible = true
	_make_stage()
	watch_signals(stage)
	_hunt(60 * 60)
	assert_eq(stage.phase, Stage.Phase.CLEAR)
	assert_eq(stage.boss_hp_ratio, 0.0)


func test_the_whole_stage_plays_to_the_end() -> void:
	LaunchOptions.weak_bosses = true
	LaunchOptions.invincible = true
	_make_stage()
	watch_signals(stage)
	_hunt(roundi((stage.def.length + 60.0 + Stage.END_SECONDS) / DELTA))
	assert_eq(stage.phase, Stage.Phase.CLEAR)
	assert_signal_emitted(stage, "finished")


func test_ships_start_with_what_the_run_kept() -> void:
	var player := RunState.current.player(1)
	player.power = 3
	player.hp = 40
	player.extra_charges = 1
	player.speed_bonus = 0.08
	RunState.current.team_rapid_fire = 20.0
	_make_stage()
	var ship := stage.local_ship()
	assert_eq(ship.state.power, 3)
	assert_eq(ship.health.hp, 40)
	assert_eq(ship.special_charges, Specials.charges_of(Specials.Kind.MEGA_BOMB) + 1)
	assert_almost_eq(ship.stats.move_speed, Ships.ALL[0].move_speed * 1.08, 0.01)
	assert_eq(ship.state.rapid_fire_left, 20.0)


func test_clearing_a_stage_pays_out_and_moves_the_run_on() -> void:
	LaunchOptions.start_at_seconds = 239.0
	LaunchOptions.weak_bosses = true
	LaunchOptions.invincible = true
	_make_stage()
	_hunt(60 * 60)
	assert_eq(stage.phase, Stage.Phase.CLEAR)
	var run := RunState.current
	assert_eq(run.stages_done, 1)
	assert_true(run.has_next_stage())
	assert_true(run.result.is_empty(), "one more stage to go")
	assert_gt(run.score, 0)
	assert_gte(run.team_scrap, StageGoals.CHARGE_PAYOUT, "the unused Mega Bomb paid out")


func test_game_over_ends_the_run() -> void:
	_make_stage()
	stage.credits = 0
	stage.local_ship().take_hit(999)
	_ticks(2)
	assert_eq(RunState.current.result, "lost")


func test_the_second_stage_is_harder() -> void:
	RunState.current.stages_done = 1
	_make_stage()
	assert_gt(stage.difficulty, 1.0)
	assert_gt(stage._hp_scale(), Stage.ENEMY_HP)
	assert_lt(stage.enemies.fire_interval_scale, 1.0)


func test_elite_wing_turns_one_wave_gold() -> void:
	RunState.current.modifiers = [StageModifiers.Id.ELITE_WING, StageModifiers.Id.NONE]
	_make_stage()
	var elite_wave := stage._waves[stage._elite_wave]
	LaunchOptions.invincible = true
	_ticks(roundi(elite_wave.time / DELTA) + 2)
	var elites := 0
	for index: int in EnemyManager.CAPACITY:
		if stage.enemies.is_elite(index):
			elites += 1
	assert_eq(elites, elite_wave.count)


func test_armored_turrets_toughen_the_ground() -> void:
	RunState.current.modifiers = [StageModifiers.Id.ARMORED_TURRETS, StageModifiers.Id.NONE]
	_make_stage()
	assert_almost_eq(stage._ground_hp_scale(), StageModifiers.ARMOR_HP * Stage.ENEMY_HP, 0.001)


func test_solo_has_no_hp_scaling() -> void:
	_make_stage()
	assert_almost_eq(stage._hp_scale(), Stage.ENEMY_HP, 0.0001, "only the global knob")


func test_snapshot_extras_round_trip() -> void:
	_make_stage()
	var ship := stage.local_ship()
	ship.state.power = 4
	ship.special_charges = 2
	ship.state.rapid_fire_left = 3.25
	var extra := Stage.pack_ship_extra(ship)
	assert_eq(extra.size(), 6)
	assert_eq(extra[0], 4)
	assert_eq(extra[1], 2)
	assert_eq(extra[2], 33, "tenths of a second, rounded up")


func test_debug_report_names_the_host_and_the_stage() -> void:
	_make_stage()
	var report := stage.debug_report()
	assert_string_contains(report, "(host)")
	assert_string_contains(report, stage.def.name)
