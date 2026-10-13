extends GutTest
## The stage (solo here: GUT runs with an offline peer, which acts as the host):
## test waves arrive, the ship's shots kill them, the ground scrolls with stage time.

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


func test_solo_has_one_ship_in_slot_0() -> void:
	assert_eq(stage.ships().size(), 1)
	assert_not_null(stage.local_ship())
	assert_eq(stage.local_ship().slot, 0)


func test_test_waves_keep_arriving() -> void:
	stage.local_ship().test_input = ShipInput.new()
	_ticks(roundi(Stage.FIRST_WAVE_AT / DELTA) + 2)
	assert_eq(stage.enemies.active_count(), Stage.WAVE_SIZE)


func test_ship_under_a_wave_kills_enemies() -> void:
	# Park the ship under the first wave's entry point and shoot for 8 seconds.
	var ship := stage.local_ship()
	ship.state.position = Vector2(Stage.WAVE_ENTRIES[0], 460)
	ship.test_input = _firing(true)
	_ticks(480)
	assert_gt(stage.kills, 0)
	assert_gt(stage.enemies.damage_by_peer.get(1, 0), 0)


func test_nobody_shooting_kills_nothing() -> void:
	stage.local_ship().test_input = ShipInput.new()
	_ticks(480)
	assert_eq(stage.kills, 0)


func test_scroll_follows_stage_time() -> void:
	stage.local_ship().test_input = ShipInput.new()
	_ticks(60)
	assert_almost_eq(stage.background.scroll, Stage.SCROLL_SPEED * stage.stage_time, 0.001)


func test_one_shot_spawns_one_bullet_per_stream() -> void:
	stage.local_ship().test_input = _firing()
	_ticks(1)
	assert_eq(stage.player_bullets.count(), 3)


func test_debug_report_names_the_host() -> void:
	assert_string_contains(stage.debug_report(), "(host)")
