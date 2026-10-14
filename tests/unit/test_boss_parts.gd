extends GutTest
## Playtest 2: the Fortress Gunship, a boss made of parts (Jamestown-style).

const DELTA: float = 1.0 / 60.0

var stage: Stage


func before_each() -> void:
	RunSetup.order = []
	RunSetup.ships = {}
	RunSetup.specials = {}
	RunState.current = RunState.new()
	LaunchOptions.invincible = true
	LaunchOptions.start_at_seconds = 239.0
	stage = (load("res://src/stage/stage.tscn") as PackedScene).instantiate() as Stage
	stage.set_physics_process(false)
	add_child_autofree(stage)
	stage.local_ship().test_input = ShipInput.new()
	# Into the boss fight.
	for i: int in 120:
		stage.tick(DELTA)


func after_each() -> void:
	LaunchOptions.invincible = false
	LaunchOptions.start_at_seconds = 0.0
	RunState.current = RunState.new()


func _kill(index: int) -> void:
	stage.enemies.damage(index, stage.enemies.hp_of(index), 1)


func test_planet_base_boss_has_parts_and_two_are_required() -> void:
	var def := Stages.get_stage(0)
	assert_eq(def.boss_parts.size(), 5)
	var required := def.boss_parts.filter(func(part: StageDef.BossPartDef) -> bool: return part.required)
	assert_eq(required.size(), 2)


func test_the_boss_arrives_with_its_parts() -> void:
	assert_eq(stage.phase, Stage.Phase.BOSS)
	assert_eq(stage._boss_parts.size(), 5)
	for part: int in stage._boss_parts:
		assert_true(stage.enemies.is_alive(part))


func test_parts_fly_with_the_core() -> void:
	var core := stage._boss_index
	var part := stage._boss_parts[0]
	var gap := stage.enemies.position_of(part) - stage.enemies.position_of(core)
	for i: int in 90:
		stage.tick(DELTA)
	assert_almost_eq((stage.enemies.position_of(part) - stage.enemies.position_of(core)).length(), gap.length(), 0.01)


func test_the_core_is_armored_until_the_required_parts_fall() -> void:
	var core := stage._boss_index
	assert_true(stage.enemies.is_armored(core))
	var hp := stage.enemies.hp_of(core)
	stage.enemies.damage(core, 500, 1)
	assert_eq(stage.enemies.hp_of(core), hp, "armored: no damage")
	for part: int in stage._required_parts:
		_kill(part)
	stage.tick(DELTA)
	assert_true(stage.core_open)
	assert_false(stage.enemies.is_armored(core))
	stage.enemies.damage(core, 500, 1)
	assert_eq(stage.enemies.hp_of(core), hp - 500)


func test_optional_parts_dont_open_the_core() -> void:
	for part: int in stage._boss_parts:
		if not stage._required_parts.has(part):
			_kill(part)
	stage.tick(DELTA)
	assert_false(stage.core_open)


func test_missile_pods_launch_shootable_homing_missiles() -> void:
	var missile := EnemyTypes.from_key("boss_missile")
	var seen := false
	for i: int in 60 * 6:
		stage.tick(DELTA)
		for index: int in stage.enemies.alive_indices():
			if stage.enemies.type_of(index) == EnemyTypes.ALL[missile]:
				seen = true
	assert_true(seen)


func test_the_boss_hp_bar_counts_every_part() -> void:
	var before := stage.boss_hp_ratio
	_kill(stage._boss_parts[2])
	stage.tick(DELTA)
	assert_lt(stage.boss_hp_ratio, before)


func test_low_on_hp_the_boss_sinks() -> void:
	for part: int in stage._required_parts:
		_kill(part)
	stage.tick(DELTA)
	var core := stage._boss_index
	stage.enemies.damage(core, roundi(stage._boss_max_hp * 0.75), 1)
	stage.tick(DELTA)
	assert_true(stage._desperate)
	assert_true(stage.enemies.has_redirect(core))
	var y := stage.enemies.position_of(core).y
	for i: int in 60 * 3:
		stage.tick(DELTA)
	assert_gt(stage.enemies.position_of(core).y, y + Stage.DESPERATION_SINK * 0.9)


func test_destroying_the_core_destroys_the_rest_and_clears_the_stage() -> void:
	for part: int in stage._required_parts:
		_kill(part)
	stage.tick(DELTA)
	_kill(stage._boss_index)
	for part: int in stage._boss_parts:
		assert_false(stage.enemies.is_alive(part))
	assert_eq(stage.phase, Stage.Phase.CLEAR)


func test_boss_part_lines_are_checked() -> void:
	var def := StageDef.parse("boss_part drone dx=1\nboss_part wing_cannon dz=3\nboss_part hangar dx=-20 dy=5 required")
	assert_eq(def.errors.size(), 2, "%s" % [def.errors])
	# Like wave lines, a part with a bad option is reported but kept.
	assert_eq(def.boss_parts.size(), 2)
	assert_eq(def.boss_parts[1].offset, Vector2(-20, 5))
	assert_true(def.boss_parts[1].required)


func test_lasers_come_after_a_warning() -> void:
	var bullets := ShotPatterns.build(ShotPatterns.Id.LASER, PI / 2.0, 1)
	for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
		assert_gte(bullets[i + 2], ShotPatterns.LASER_WARNING, "no bullet before the warning ends")
	stage._spawn_pattern(ShotPatterns.Id.LASER, Vector2(480, 200), PI / 2.0, 1, 10, 0.0)
	assert_eq(stage.effects._warnings.size(), 1)
