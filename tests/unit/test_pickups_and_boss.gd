extends GutTest
## Drops, pickups, the boss script and power levels.


func test_scrap_is_split_into_pieces() -> void:
	var type := EnemyType.new()
	type.scrap = 12
	var drops := Pickups.roll_drops(type, RandomNumberGenerator.new())
	var total := 0
	for i: int in range(0, drops.size(), 2):
		assert_eq(drops[i], Pickups.Kind.SCRAP)
		assert_lte(drops[i + 1], Pickups.SCRAP_PIECE)
		total += drops[i + 1]
	assert_eq(total, 12)


func test_rare_drops_follow_their_chances() -> void:
	var type := EnemyType.new()
	type.scrap = 0
	type.orb_chance = 1.0
	type.charge_chance = 1.0
	var drops := Pickups.roll_drops(type, RandomNumberGenerator.new())
	assert_eq(drops, PackedInt32Array([Pickups.Kind.POWER_ORB, 1, Pickups.Kind.SPECIAL_CHARGE, 1]))


func test_every_pickup_has_a_sprite() -> void:
	assert_eq(Pickups.SPRITES.size(), Pickups.Kind.size())
	for sprite: String in Pickups.SPRITES:
		assert_true(PixelArt.has_sprite(sprite), sprite)


func _manager() -> PickupManager:
	var manager := PickupManager.new()
	add_child_autofree(manager)
	return manager


func test_floating_pickups_drift_down_the_same_way_everywhere() -> void:
	var manager := _manager()
	var id := manager.spawn_host(Pickups.Kind.SCRAP, 1, Vector2(100, 100), 0.0)
	var a := manager.float_position(id, 2.0)
	var b := manager.float_position(id, 2.0)
	assert_eq(a, b)
	assert_gt(manager.float_position(id, 3.0).y, a.y)


func test_the_magnet_pulls_scrap_in_and_the_host_collects_it() -> void:
	var manager := _manager()
	watch_signals(manager)
	manager.spawn_host(Pickups.Kind.SCRAP, 5, Vector2(100, 100), 0.0)
	var ships: Dictionary[int, Vector2] = {7: Vector2(100, 150)}
	for i: int in 60:
		manager.tick(i / 60.0, 1.0 / 60.0, ships, true)
	assert_signal_emitted_with_parameters(manager, "collected", [Pickups.Kind.SCRAP, 5, 7])
	assert_eq(manager.count(), 0)


func test_power_ups_must_be_touched() -> void:
	var manager := _manager()
	manager.spawn_host(Pickups.Kind.POWER_ORB, 1, Vector2(100, 100), 0.0)
	var ships: Dictionary[int, Vector2] = {7: Vector2(160, 100)}
	manager.tick(0.0, 1.0 / 60.0, ships, true)
	assert_eq(manager.count(), 1, "60 px away is outside the power-up magnet")


func test_clients_dont_collect() -> void:
	var manager := _manager()
	manager.spawn_host(Pickups.Kind.SCRAP, 5, Vector2(100, 100), 0.0)
	var ships: Dictionary[int, Vector2] = {7: Vector2(100, 110)}
	for i: int in 60:
		manager.tick(i / 60.0, 1.0 / 60.0, ships, false)
	assert_eq(manager.count(), 1)


func test_pickups_below_the_screen_are_gone() -> void:
	var manager := _manager()
	manager.spawn_host(Pickups.Kind.SCRAP, 1, Vector2(100, 530), 0.0)
	var none: Dictionary[int, Vector2] = {}
	manager.tick(5.0, 1.0 / 60.0, none, true)
	assert_eq(manager.count(), 0)


func _step(pattern: String) -> BossStep:
	var step := BossStep.new()
	step.pattern = ShotPatterns.from_name(pattern)
	step.wait = 1.0
	return step


func test_boss_brain_waits_then_loops_its_steps() -> void:
	var one: Array[BossStep] = [_step("aimed"), _step("ring_12")]
	var brain := BossBrain.new(one)
	assert_null(brain.tick(BossBrain.INTRO_DELAY - 0.1, 1.0))
	assert_same(brain.tick(0.2, 1.0), one[0])
	assert_null(brain.tick(0.5, 1.0))
	assert_same(brain.tick(0.6, 1.0), one[1])
	assert_same(brain.tick(1.0, 1.0), one[0], "loops")


func test_boss_brain_switches_to_phase_two_below_half_hp() -> void:
	var one: Array[BossStep] = [_step("aimed")]
	var two: Array[BossStep] = [_step("spiral")]
	var brain := BossBrain.new(one, two)
	brain.tick(BossBrain.INTRO_DELAY, 1.0)
	assert_same(brain.tick(1.0, 0.4), two[0])
	assert_eq(brain.phase, 2)


func test_planet_base_has_a_boss_with_two_phases() -> void:
	var def := Stages.get_stage(0)
	assert_true(def.has_boss())
	assert_true(EnemyTypes.ALL[def.boss_type].is_boss)
	assert_gt(def.boss_steps_one.size(), 1)
	assert_gt(def.boss_steps_two.size(), 1)


func test_boss_lines_are_checked() -> void:
	var def := StageDef.parse("boss drone\nboss_step 3 aimed\nboss_step 1 ship_spread\nboss_step 1 aimed aim=sideways")
	assert_eq(def.errors.size(), 4, "%s" % [def.errors])
	var good := StageDef.parse("boss base_boss x=300\nboss_step 1 ring_24 aim=spin angle=45 wait=0.5 dx=-10 dy=4")
	assert_eq(good.errors, PackedStringArray())
	assert_eq(good.boss_x, 300.0)
	var step := good.boss_steps_one[0]
	assert_eq(step.aim, BossStep.Aim.SPIN)
	assert_almost_eq(step.angle, deg_to_rad(45.0), 0.0001)
	assert_eq(step.offset, Vector2(-10, 4))


func test_scroll_stops_when_the_boss_comes() -> void:
	var def := StageDef.parse("length = 10\nscroll_speed = 60\nboss base_boss")
	assert_eq(def.scroll_distance(5.0), 300.0)
	assert_eq(def.scroll_distance(20.0), 600.0)
	var no_boss := StageDef.parse("length = 10\nscroll_speed = 60")
	assert_eq(no_boss.scroll_distance(20.0), 1200.0)


func test_every_pattern_has_a_name() -> void:
	assert_eq(ShotPatterns.NAMES.size(), ShotPatterns.Id.size())


func test_power_levels_add_streams_and_damage() -> void:
	var stats := Ships.ALL[0]
	assert_eq(ShipMotor.streams(stats, 1, false), 3)
	assert_eq(ShipMotor.streams(stats, 5, false), 7)
	assert_eq(ShipMotor.streams(stats, 1, true), 2)
	assert_gt(ShipMotor.damage(stats, 5, false), ShipMotor.damage(stats, 1, false))
	assert_eq(ShotPatterns.angles(ShotPatterns.Id.SHIP_SPREAD, -PI / 2.0, 1, 7).size(), 7)
	assert_eq(ShotPatterns.angles(ShotPatterns.Id.SHIP_FOCUS, -PI / 2.0, 1, 4).size(), 4)


func test_rapid_fire_shoots_faster() -> void:
	var stats := Ships.ALL[0].duplicate() as ShipStats
	var state := ShipState.new()
	state.rapid_fire_left = 10.0
	var input := ShipInput.new()
	input.fire = true
	var shots := 0
	for i: int in 60:
		shots += ShipMotor.step(state, input, stats, Rect2(0, 0, 960, 540), 1.0 / 60.0) & ShipMotor.FIRED
	assert_gt(shots, roundi(1.0 / stats.fire_interval))


func test_lobby_special_pick() -> void:
	var state := LobbyState.new()
	state.add(1, 0)
	assert_eq(state.specials[1], Specials.Kind.MEGA_BOMB)
	assert_true(state.choose_special(1, Specials.Kind.SHIELD))
	assert_false(state.choose_special(1, 99))
	RunSetup.specials = {5: 99}
	assert_eq(RunSetup.special_for(5), Specials.Kind.MEGA_BOMB)
	RunSetup.specials = {}
