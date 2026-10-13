extends GutTest
## The stage file format (StageDef) and the real stage files.

const SAMPLE: String = """
# A comment line
name = Test Base   # a comment after a setting
length = 60
scroll_speed = 30

wave 2 drone s_curve x=300 count=3 spacing=0.5 dx=10 mirror
wave 4 fighter dive_retreat x=480 pace=1.5
wave 6 drone straight x=100 variant=a1
wave 6 kamikaze straight x=100 variant=a2
wave 1 drone cross_screen x=-20 y=80
ground 5 turret x=200
ground 7 tank x=100 mirror
"""


func test_settings_are_read() -> void:
	var def := StageDef.parse(SAMPLE)
	assert_eq(def.errors, PackedStringArray())
	assert_eq(def.name, "Test Base")
	assert_eq(def.length, 60.0)
	assert_eq(def.scroll_speed, 30.0)


func test_wave_lines_are_read() -> void:
	var def := StageDef.parse(SAMPLE)
	assert_eq(def.waves.size(), 5)
	var wave := def.waves[0]
	assert_eq(wave.time, 2.0)
	assert_eq(wave.type_id, EnemyTypes.from_key("drone"))
	assert_eq(wave.shape, PathShapes.Id.S_CURVE)
	assert_eq(wave.origin, Vector2(300, -16))
	assert_eq(wave.count, 3)
	assert_eq(wave.spacing, 0.5)
	assert_eq(wave.dx, 10.0)
	assert_true(wave.mirror)
	assert_eq(def.waves[1].pace, 1.5)
	assert_eq(def.waves[4].origin, Vector2(-20, 80))


func test_ground_lines_are_read_in_file_order() -> void:
	var def := StageDef.parse(SAMPLE)
	assert_eq(def.grounds.size(), 2)
	assert_eq(def.grounds[0].type_id, EnemyTypes.from_key("turret"))
	assert_eq(def.grounds[1].x, 100.0)
	assert_true(def.grounds[1].mirror)


func test_mistakes_are_reported_with_line_numbers() -> void:
	var text := "wave 2 dron s_curve\nwave 3 drone zigzag\nground 4 drone x=1\nwave x drone s_curve\nlenght = 3\nground 5 turret"
	var def := StageDef.parse(text)
	assert_eq(def.errors.size(), 6, "%s" % [def.errors])
	assert_string_contains(def.errors[0], "line 1")
	assert_string_contains(def.errors[0], "dron")
	assert_string_contains(def.errors[1], "zigzag")
	assert_string_contains(def.errors[2], "ground type")
	assert_string_contains(def.errors[3], "line 4")
	assert_string_contains(def.errors[4], "lenght")
	assert_string_contains(def.errors[5], "x=")


func test_each_run_flies_one_option_of_each_variant_group() -> void:
	var def := StageDef.parse(SAMPLE)
	var seen: Dictionary[int, bool] = {}
	for seed_value: int in 40:
		var waves := def.waves_for_seed(seed_value)
		assert_eq(waves.size(), 4, "3 always-on waves + 1 option of group a")
		for wave: StageDef.WaveDef in waves:
			if wave.variant_group == "a":
				seen[wave.type_id] = true
	assert_eq(seen.size(), 2, "both options come up over 40 runs")


func test_the_same_seed_picks_the_same_waves() -> void:
	var def := StageDef.parse(SAMPLE)
	var a := def.waves_for_seed(1234)
	var b := def.waves_for_seed(1234)
	assert_eq(a.size(), b.size())
	for i: int in a.size():
		assert_same(a[i], b[i])


func test_waves_come_out_sorted_by_time() -> void:
	var waves := StageDef.parse(SAMPLE).waves_for_seed(1)
	for i: int in range(1, waves.size()):
		assert_lte(waves[i - 1].time, waves[i].time)


func test_every_stage_file_loads_without_mistakes() -> void:
	for i: int in Stages.PATHS.size():
		var def := StageDef.load_file(Stages.PATHS[i])
		assert_eq(def.errors, PackedStringArray(), Stages.PATHS[i])
		assert_false(def.name.is_empty())
		assert_gt(def.waves.size(), 0)


func test_planet_base_is_about_four_minutes_with_ground_targets() -> void:
	var def := Stages.get_stage(0)
	assert_between(def.length, 200.0, 260.0)
	assert_gt(def.grounds.size(), 40)
	assert_eq(def.variant_groups().size(), 3)
	for wave: StageDef.WaveDef in def.waves:
		assert_lte(wave.time, def.length, "every wave starts before the boss")
	for ground: StageDef.GroundDef in def.grounds:
		assert_between(ground.x, 0.0, 960.0)


func test_stage_files_are_included_in_exported_builds() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	assert_string_contains(str(presets.get_value("preset.0", "include_filter", "")), "src/stage/stages/*.stage")
