extends GutTest
## The stage (solo here: GUT runs with an offline peer, which acts as the host).

const DELTA: float = 1.0 / 60.0

var stage: Stage


func before_each() -> void:
	RunSetup.order = []
	RunSetup.ships = {}
	stage = (load("res://src/stage/stage.tscn") as PackedScene).instantiate() as Stage
	# Gameplay is driven by tick() below, not by the engine's physics loop.
	stage.set_physics_process(false)
	add_child_autofree(stage)


func _firing(focus: bool = false) -> ShipInput:
	var input := ShipInput.new()
	input.fire = true
	input.focus = focus
	return input


func _ticks(count: int) -> void:
	for i: int in count:
		stage.tick(DELTA)


## Fires and steers like a player aiming: under the lowest air enemy, or else
## under a standing ground target.
func _hunt(ticks: int) -> void:
	var ship := stage.local_ship()
	ship.test_input = _firing()
	for i: int in ticks:
		var target_x := ship.state.position.x
		var lowest := -INF
		for index: int in stage.enemies.alive_indices():
			var at := stage.enemies.position_of(index)
			if at.y > lowest and at.y < ship.state.position.y - 40.0:
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


func test_solo_has_one_ship_in_slot_0() -> void:
	assert_eq(stage.ships().size(), 1)
	assert_eq(stage.local_ship().slot, 0)


func test_the_first_wave_arrives_on_time() -> void:
	stage.local_ship().test_input = ShipInput.new()
	var first := stage.def.waves_for_seed(0)[0]
	_ticks(roundi(first.time / DELTA) + 2)
	assert_gt(stage.enemies.active_count(), 0)


func test_scroll_follows_stage_time() -> void:
	stage.local_ship().test_input = ShipInput.new()
	_ticks(60)
	assert_almost_eq(stage.background.scroll, stage.def.scroll_speed * stage.stage_time, 0.001)


func test_one_shot_spawns_one_bullet_per_stream() -> void:
	stage.local_ship().test_input = _firing()
	_ticks(1)
	assert_eq(stage.player_bullets.count(), 3)


func test_enemies_shoot_back_and_hurt_a_ship_that_sits_still() -> void:
	var ship := stage.local_ship()
	ship.test_input = ShipInput.new()
	_ticks(60 * 40)
	assert_lt(ship.health.hp, ship.health.max_hp)


func test_contact_with_an_enemy_hurts_and_a_kamikaze_blows_up() -> void:
	var ship := stage.local_ship()
	ship.test_input = ShipInput.new()
	var kamikaze := EnemyTypes.from_key("kamikaze")
	var index := stage.enemies.spawn(kamikaze, PathShapes.Id.STRAIGHT, stage.stage_time, ship.state.position)
	_ticks(2)
	assert_eq(ship.health.hp, ship.health.max_hp - EnemyTypes.ALL[kamikaze].contact_damage)
	assert_false(stage.enemies.is_alive(index))


func test_kamikazes_lock_onto_the_ship() -> void:
	var ship := stage.local_ship()
	ship.test_input = ShipInput.new()
	var kamikaze := EnemyTypes.from_key("kamikaze")
	var index := stage.enemies.spawn(kamikaze, PathShapes.Id.STRAIGHT, stage.stage_time, Vector2(100, 40))
	_ticks(roundi((EnemyTypes.ALL[kamikaze].homing_delay + Stage.HOMING_EVERY) / DELTA) + 1)
	assert_true(stage.enemies.has_redirect(index))
	var now := stage.enemies.position_of(index)
	var heading := (stage.enemies.position_at(index, stage.stage_time + 0.1) - now).normalized()
	var to_ship := (ship.state.position - now).normalized()
	assert_gt(heading.dot(to_ship), 0.9, "flying at the ship")


func test_shooting_for_a_minute_destroys_air_and_ground_targets() -> void:
	_hunt(60 * 60)
	assert_gt(stage.kills, 5)
	assert_gt(stage.ground_kills, 0)
	assert_gt(stage.enemies.damage_by_peer.get(1, 0), 0)


func test_solo_has_no_hp_scaling() -> void:
	assert_eq(stage._hp_scale(), 1.0)


func test_the_whole_stage_plays_to_the_end() -> void:
	watch_signals(stage)
	_hunt(roundi((stage.def.length + 60.0 + Stage.CLEAR_SECONDS) / DELTA))
	assert_eq(stage.phase, Stage.Phase.CLEAR)
	assert_signal_emitted(stage, "finished")


func test_debug_report_names_the_host_and_the_stage() -> void:
	var report := stage.debug_report()
	assert_string_contains(report, "(host)")
	assert_string_contains(report, stage.def.name)
