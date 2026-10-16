extends GutTest
## The art comparison: missions that replay Planet Base with other art sets
## (StageDef `use` / `art`, PixelArt.art_set) and ship skins (Skins).


func after_each() -> void:
	PixelArt.art_set = ""
	RunSetup.mission = 0
	RunSetup.skins.clear()
	RunSetup.ships.clear()


func test_art_missions_play_exactly_the_classic_stage() -> void:
	var classic := Stages.get_stage(0)
	for index: int in range(1, Stages.PATHS.size()):
		var mission := Stages.get_stage(index)
		assert_eq(mission.errors, PackedStringArray(), Stages.PATHS[index])
		assert_false(mission.art.is_empty(), "%s names its art set" % Stages.PATHS[index])
		assert_ne(mission.name, classic.name, "a name of its own for the lobby")
		assert_eq(mission.waves.size(), classic.waves.size(), "same waves")
		assert_eq(mission.grounds.size(), classic.grounds.size(), "same ground objects (their index is a network id)")
		assert_eq(mission.boss_type, classic.boss_type, "same boss")
		assert_eq(mission.length, classic.length)
	assert_eq(classic.art, "", "the classic mission keeps the classic art")


func test_use_reads_another_file_and_later_settings_win() -> void:
	var def := StageDef.parse("use = planet_base.stage\nname = Test\nart = klaed\n")
	assert_eq(def.errors, PackedStringArray())
	assert_eq(def.name, "Test")
	assert_eq(def.art, "klaed")
	assert_gt(def.waves.size(), 10)
	assert_false(StageDef.parse("use = nope.stage\n").errors.is_empty(), "a missing file is an error")


func test_every_art_set_has_its_air_enemies_and_tank() -> void:
	for index: int in range(1, Stages.PATHS.size()):
		var art := Stages.get_stage(index).art
		if art == "shootemup" and not DirAccess.dir_exists_absolute("res://assets/art/sets/shootemup"):
			continue  # Git-ignored (its license doesn't allow sharing the files): only on the dev PC.
		PixelArt.art_set = art
		for sprite: String in ["drone", "fighter", "gunship", "kamikaze", "ground_tank"]:
			assert_true(PixelArt.has_file(sprite), "%s has %s" % [art, sprite])
	PixelArt.art_set = ""
	assert_false(PixelArt.has_file("drone"), "the classic art has no file for the drone")
	assert_eq(PixelArt.size_of("drone"), Vector2i(15, 11), "the classic drone is still the text sprite")


func test_every_skin_has_art_and_belongs_to_a_real_ship() -> void:
	assert_eq(Skins.SHIPS.size(), Skins.SPRITES.size())
	assert_eq(Skins.NAMES.size(), Skins.SPRITES.size())
	for skin: int in range(1, Skins.SPRITES.size()):
		assert_true(PixelArt.has_file(Skins.SPRITES[skin]), Skins.SPRITES[skin])
		assert_between(Skins.SHIPS[skin], 0, Ships.ALL.size() - 1)
	for ship: int in Ships.ALL.size():
		var list := Skins.for_ship(ship)
		assert_eq(list[0], Skins.CLASSIC, "Classic comes first")
		assert_gt(list.size(), 3, "%s has skins" % Ships.ALL[ship].display_name)
		assert_eq(Skins.sprite_for(ship, Skins.CLASSIC), Ships.ALL[ship].sprite)


func test_a_skin_from_another_ship_falls_back_to_classic() -> void:
	var striker_skin := Skins.for_ship(0)[1]
	assert_true(Skins.fits(0, striker_skin))
	assert_false(Skins.fits(1, striker_skin))
	assert_eq(Skins.sprite_for(1, striker_skin), Ships.ALL[1].sprite)
	var state := LobbyState.new()
	state.add(1, 0, Specials.Kind.MEGA_BOMB, striker_skin)
	assert_eq(state.skins[1], striker_skin)
	state.choose(1, 1)
	assert_eq(state.skins[1], Skins.CLASSIC, "a new ship starts in Classic")
	assert_false(state.choose_skin(1, striker_skin), "not a Lancer skin")
	assert_true(state.choose_skin(1, Skins.for_ship(1)[1]))


func test_skin_and_mission_carry_into_the_run() -> void:
	var skin := Skins.for_ship(2)[2]
	RunSetup.ships = {7: 2}
	RunSetup.skins = {7: skin}
	RunSetup.mission = 3
	var rng := RandomNumberGenerator.new()
	var run := RunState.start([7], rng)
	assert_eq(run.stage_plan, [3, 3] as Array[int], "every stage plays the mission")
	assert_eq(run.player(7).skin, skin)
	var copy := RunState.from_dict(run.to_dict())
	assert_eq(copy.player(7).skin, skin, "clients get it too")
	assert_eq(RunState.PlayerRun.from_dict({"ship": 0, "skin": skin}).skin, Skins.CLASSIC, "a skin must fit its ship")


func test_player_color_recolors_skin_files() -> void:
	var tint := PlayerNames.color_of(1)
	var image := PixelArt.texture("skins/tiny01", tint).get_image()
	var found := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			assert_false(color.a > 0.0 and Color(color, 1.0).is_equal_approx(PixelArt.FILE_TINT), "no magenta left")
			# (8-bit pixels: compare within a rounding step.)
			if color.a > 0.0 and absf(color.r - tint.r) + absf(color.g - tint.g) + absf(color.b - tint.b) < 0.02:
				found = true
	assert_true(found, "the player color shows")
