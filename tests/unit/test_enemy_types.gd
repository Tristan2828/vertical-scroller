extends GutTest
## Enemy and ground types are data: every one must be usable.


func test_keys_are_unique_and_found() -> void:
	var keys: Array[String] = []
	for i: int in EnemyTypes.ALL.size():
		var type := EnemyTypes.ALL[i]
		assert_false(keys.has(type.key), "duplicate key %s" % type.key)
		keys.append(type.key)
		assert_eq(EnemyTypes.from_key(type.key), i)


func test_air_enemies_have_sprites_and_ground_objects_have_a_size() -> void:
	for type: EnemyType in EnemyTypes.ALL:
		if type.ground:
			assert_gt(type.size.x, 0.0, type.key)
			assert_eq(type.homing, EnemyType.Homing.NONE, "%s: ground objects don't fly" % type.key)
		else:
			assert_true(PixelArt.has_sprite(type.sprite), "%s has sprite %s" % [type.key, type.sprite])


func test_guns_use_enemy_patterns() -> void:
	for type: EnemyType in EnemyTypes.ALL:
		if type.shot_pattern < 0:
			continue
		assert_lt(type.shot_pattern, ShotPatterns.Id.size(), type.key)
		assert_false(ShotPatterns.is_ship_pattern(type.shot_pattern), "%s fires an enemy pattern" % type.key)
		assert_gt(type.fire_interval, 0.5, type.key)


func test_damage_numbers_follow_the_draft() -> void:
	# DESIGN.md §3: enemy bullets 8-20 damage against 100 HP.
	for type: EnemyType in EnemyTypes.ALL:
		if type.shot_pattern >= 0:
			assert_between(type.bullet_damage, 8, 20, type.key)


func test_sprites_have_equal_length_rows() -> void:
	for sprite: String in PixelArt.SPRITES:
		var rows: Array = PixelArt.SPRITES[sprite]
		for row: String in rows:
			assert_eq(row.length(), String(rows[0]).length(), sprite)
