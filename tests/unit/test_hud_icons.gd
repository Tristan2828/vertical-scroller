extends GutTest
## Playtest 3: HUD icons (filled = have, hollow = don't) and the boss art.


func test_hud_icons_exist() -> void:
	for sprite: String in ["hud_power", "hud_bomb", "hud_shield"]:
		assert_true(PixelArt.has_sprite(sprite), sprite)


func test_hollow_icons_keep_only_the_edge() -> void:
	var filled := PixelArt.texture("hud_shield").get_image()
	var hollow := PixelArt.texture("hud_shield", Color.WHITE, false, true).get_image()
	# The middle is filled in one and empty in the other; the corner is outline in both.
	assert_gt(filled.get_pixel(4, 3).a, 0.0)
	assert_eq(hollow.get_pixel(4, 3).a, 0.0)
	var corner := hollow.get_pixel(0, 0)
	for channel: int in 4:
		assert_almost_eq(corner[channel], PixelArt.HOLLOW[channel], 0.01)
	# Transparent stays transparent.
	assert_eq(hollow.get_pixel(0, 9).a, 0.0)


func test_every_special_has_a_hud_icon() -> void:
	assert_eq(StageHud.SPECIAL_ICONS.size(), Specials.Kind.size())


func test_boss_art_is_baked_at_the_type_size() -> void:
	for key: String in ["fortress_core", "wing_cannon", "missile_pod", "hangar"]:
		var type := EnemyTypes.ALL[EnemyTypes.from_key(key)]
		var art := BossArt.texture(key, type.size)
		assert_not_null(art, key)
		assert_eq(Vector2(art.get_size()), type.size.floor(), key)
	assert_null(BossArt.texture("drone", Vector2(8, 8)))
