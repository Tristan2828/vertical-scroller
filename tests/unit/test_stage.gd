extends GutTest
## The M1 stage: test waves arrive, the ship's shots kill them, the ground scrolls.

const DELTA: float = 1.0 / 60.0

var stage: Stage


func before_each() -> void:
	stage = (load("res://src/stage/stage.tscn") as PackedScene).instantiate() as Stage
	# Gameplay is driven by tick() below, not by the engine's physics loop.
	stage.set_physics_process(false)
	add_child_autofree(stage)


func _firing(seq: int, focus: bool = false) -> ShipInput:
	var input := ShipInput.new()
	input.seq = seq
	input.fire = true
	input.focus = focus
	return input


func test_test_waves_keep_arriving() -> void:
	for i: int in roundi(Stage.FIRST_WAVE_AT / DELTA) + 2:
		stage.tick(ShipInput.new(), DELTA)
	assert_eq(stage.enemies.active_count(), Stage.WAVE_SIZE)


func test_ship_under_a_wave_kills_enemies() -> void:
	# Park the ship under the first wave's entry point and shoot for 8 seconds.
	stage.ship.state.position = Vector2(Stage.WAVE_ENTRIES[0], 460)
	for i: int in 480:
		stage.tick(_firing(i, true), DELTA)
	assert_gt(stage.kills, 0)


func test_nobody_shooting_kills_nothing() -> void:
	for i: int in 480:
		stage.tick(ShipInput.new(), DELTA)
	assert_eq(stage.kills, 0)


func test_scroll_follows_stage_time() -> void:
	for i: int in 60:
		stage.tick(ShipInput.new(), DELTA)
	assert_almost_eq(stage.background.scroll, Stage.SCROLL_SPEED * stage.stage_time, 0.001)


func test_one_shot_spawns_one_bullet_per_stream() -> void:
	stage.tick(_firing(1), DELTA)
	assert_eq(stage.player_bullets.count(), 3)
