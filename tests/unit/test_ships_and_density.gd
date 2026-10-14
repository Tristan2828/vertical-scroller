extends GutTest
## Playtest 1: more ships, a busier stage, co-op scaling by wave size.

const UP: float = -PI / 2.0
const DELTA: float = 1.0 / 60.0

var stage: Stage


func before_each() -> void:
	RunSetup.order = []
	RunSetup.ships = {}
	RunSetup.specials = {}
	RunState.current = RunState.new()
	LaunchOptions.invincible = false


func after_each() -> void:
	RunSetup.ships = {}
	RunState.current = RunState.new()


func _make_stage(ship: int = 0) -> void:
	RunSetup.ships = {1: ship}
	RunState.current = RunState.new()
	stage = (load("res://src/stage/stage.tscn") as PackedScene).instantiate() as Stage
	stage.set_physics_process(false)
	add_child_autofree(stage)
	var input := ShipInput.new()
	input.fire = true
	stage.local_ship().test_input = input


func test_every_ship_is_complete() -> void:
	assert_eq(Ships.ALL.size(), 5)
	for ship: ShipStats in Ships.ALL:
		assert_true(PixelArt.has_sprite(ship.sprite), ship.display_name)
		assert_true(PixelArt.has_sprite(ship.sprite + "_1"), "%s engine flicker" % ship.display_name)
		assert_true(ShotPatterns.is_ship_pattern(ship.gun_pattern), ship.display_name)
		assert_true(ShotPatterns.is_ship_pattern(ship.focus_pattern), ship.display_name)
		for table: Array in [ship.spread_streams, ship.focus_streams, ship.power_damage, ship.missiles]:
			assert_eq(table.size(), ShipMotor.MAX_POWER, ship.display_name)
		assert_false(ship.blurb.is_empty(), ship.display_name)


func test_every_ship_flies_and_fires_in_a_stage() -> void:
	for id: int in Ships.ALL.size():
		_make_stage(id)
		assert_eq(stage.local_ship().ship_id, id)
		stage.tick(DELTA)
		assert_gt(stage.player_bullets.count(), 0, Ships.ALL[id].display_name)
		stage.free()


func test_lancer_shots_pierce_a_line_of_enemies() -> void:
	_make_stage(1)
	var drone := EnemyTypes.from_key("drone")
	var ship := stage.local_ship()
	var first := stage.enemies.spawn(drone, PathShapes.Id.STRAIGHT, 0.0, Vector2(ship.state.position.x, 300), false, 0.0)
	var second := stage.enemies.spawn(drone, PathShapes.Id.STRAIGHT, 0.0, Vector2(ship.state.position.x, 250), false, 0.0)
	# 14 damage a shot, 30 HP drones: three shots each, but the same shots hit both.
	for i: int in 60:
		stage.tick(DELTA)
	assert_false(stage.enemies.is_alive(first))
	assert_false(stage.enemies.is_alive(second), "one shot goes through both")


func test_hornet_fires_homing_missiles() -> void:
	_make_stage(2)
	var drone := EnemyTypes.from_key("drone")
	stage.enemies.spawn(drone, PathShapes.Id.STRAIGHT, 0.0, Vector2(100, 150), false, 0.0)
	var missiles := 0
	for i: int in 120:
		stage.tick(DELTA)
		missiles = maxi(missiles, _count_style(ProjectileManager.Style.MISSILE))
	assert_gt(missiles, 0)


func _count_style(style: ProjectileManager.Style) -> int:
	var count := 0
	for i: int in stage.player_bullets.count():
		if stage.player_bullets._styles[i] == style:
			count += 1
	return count


func test_missiles_turn_toward_enemies() -> void:
	var enemies := EnemyManager.new()
	var bullets := ProjectileManager.new()
	add_child_autofree(enemies)
	add_child_autofree(bullets)
	enemies.spawn(EnemyTypes.from_key("drone"), PathShapes.Id.STRAIGHT, 0.0, Vector2(300, 100), false, 0.0)
	enemies.tick(0.0, 0.0)
	bullets.spawn(Vector2(100, 300), Vector2(0, -300), 10, 3.0, 1, 0, 0.0, ProjectileManager.Style.MISSILE, 5.0)
	for i: int in 20:
		bullets.steer(enemies, DELTA)
		bullets.step(DELTA)
	var heading := bullets._velocities[0].normalized()
	assert_gt(heading.x, 0.3, "turned right, toward the drone")


func test_vulcan_sweeps_side_to_side() -> void:
	var angles: Array[float] = []
	for seq: int in 40:
		angles.append(ShotPatterns.angles(ShotPatterns.Id.VULCAN_SWEEP, UP, ShotPatterns.make_seed(7, seq), 2)[0])
	assert_lt(angles.min(), UP - deg_to_rad(5.0))
	assert_gt(angles.max(), UP + deg_to_rad(5.0))
	assert_eq(ShotPatterns.build(ShotPatterns.Id.VULCAN_SWEEP, UP, 99, 3, 700.0), ShotPatterns.build(ShotPatterns.Id.VULCAN_SWEEP, UP, 99, 3, 700.0))


func test_wave_arc_spreads_its_bullets_wide() -> void:
	var angles := ShotPatterns.angles(ShotPatterns.Id.WAVE_ARC, UP, 1, 9)
	assert_eq(angles.size(), 9)
	assert_almost_eq(angles[0], UP - deg_to_rad(ShotPatterns.ARC_DEGREES), 0.0001)
	assert_almost_eq(angles[8], UP + deg_to_rad(ShotPatterns.ARC_DEGREES), 0.0001)


func test_lobby_ship_pick() -> void:
	var state := LobbyState.new()
	state.add(1, 0)
	assert_true(state.choose(1, Ships.ALL.size() - 1))
	assert_false(state.choose(1, Ships.ALL.size()))


func _add_teammate(peer_id: int) -> void:
	var mate := Ship.new()
	mate.setup(peer_id, 1, 0, Vector2(500, 460), stage.play_area)
	stage.ships_node.add_child(mate)


func test_co_op_makes_waves_bigger_with_a_small_hp_bump() -> void:
	_make_stage()
	assert_eq(stage._wave_count(10), 10)
	assert_almost_eq(stage._hp_scale(), Stage.ENEMY_HP, 0.0001)
	_add_teammate(42)
	assert_eq(stage._wave_count(10), roundi(10 * (1.0 + Stage.COUNT_PER_EXTRA_PLAYER)))
	assert_almost_eq(stage._hp_scale(), (1.0 + Stage.HP_PER_EXTRA_PLAYER) * Stage.ENEMY_HP, 0.0001)


func test_the_boss_gets_more_hp_per_player_than_regular_enemies() -> void:
	assert_gt(Stage.BOSS_HP_PER_EXTRA_PLAYER, Stage.HP_PER_EXTRA_PLAYER)


func test_planet_base_is_busy() -> void:
	var def := Stages.get_stage(0)
	var air := 0
	for wave: StageDef.WaveDef in def.waves:
		air += wave.count
	assert_gt(air, 500, "about 2x the 258 enemies before playtest 1")
	assert_gt(def.grounds.size(), 90)


func test_drones_shoot_now() -> void:
	assert_gte(EnemyTypes.ALL[EnemyTypes.from_key("drone")].shot_pattern, 0)
